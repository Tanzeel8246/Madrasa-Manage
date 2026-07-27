// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/globals.dart';
import '../utils/network_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/neo_box.dart';
import '../db_helper.dart';
import 'dashboard.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color textDark = const Color(0xFF2D2D2D);

  final _madrasaNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hijriYearController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _groqKeyController = TextEditingController();
  final _whatsappKeyController = TextEditingController();
  final _smsKeyController = TextEditingController();

  String _aiProvider = 'gemini';
  int _weekStartDay = 6;
  int _autoNotifyDay = 4;
  String _autoNotifyTime = '18:00';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // پہلے سرور سے ڈیٹا لانے کی کوشش کریں
      try {
        final res = await NetworkService.getWithFallbackAction('sync_down')
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['data']?['settings'] != null) {
            final s = body['data']['settings'];
            await DBHelper().saveServerData(body['data']);
            setState(() {
              _madrasaNameController.text = s['madrasa_name']?.toString() ?? '';
              _phoneController.text = s['phone']?.toString() ?? '';
              _hijriYearController.text =
                  s['current_hijri_year']?.toString() ?? '1447';
              _geminiKeyController.text = s['gemini_api_key']?.toString() ?? '';
              _groqKeyController.text = s['groq_api_key']?.toString() ?? '';
              _whatsappKeyController.text =
                  s['whatsapp_api_key']?.toString() ?? '';
              _smsKeyController.text = s['sms_api_key']?.toString() ?? '';
              _aiProvider = s['ai_provider']?.toString().isNotEmpty == true
                  ? s['ai_provider'].toString()
                  : 'gemini';
              _weekStartDay =
                  int.tryParse(s['week_start_day']?.toString() ?? '6') ?? 6;
              _autoNotifyDay =
                  int.tryParse(s['auto_notify_day']?.toString() ?? '4') ?? 4;
              _autoNotifyTime =
                  s['auto_notify_time']?.toString().isNotEmpty == true
                      ? s['auto_notify_time'].toString()
                      : '18:00';
              _isLoading = false;
            });
            return;
          }
        }
      } catch (_) {}

      // سرور نہ ملے تو مقامی ڈیٹا بیس سے لائیں
      final s = await DBHelper().getSettings();
      setState(() {
        _madrasaNameController.text = s['madrasa_name']?.toString() ?? '';
        _phoneController.text = s['phone']?.toString() ?? '';
        _hijriYearController.text =
            s['current_hijri_year']?.toString() ?? '1447';
        _geminiKeyController.text = s['gemini_api_key']?.toString() ?? '';
        _groqKeyController.text = s['groq_api_key']?.toString() ?? '';
        _whatsappKeyController.text = s['whatsapp_api_key']?.toString() ?? '';
        _smsKeyController.text = s['sms_api_key']?.toString() ?? '';
        _aiProvider = s['ai_provider']?.toString().isNotEmpty == true
            ? s['ai_provider'].toString()
            : 'gemini';
        _weekStartDay =
            int.tryParse(s['week_start_day']?.toString() ?? '6') ?? 6;
        _autoNotifyDay =
            int.tryParse(s['auto_notify_day']?.toString() ?? '4') ?? 4;
        _autoNotifyTime = s['auto_notify_time']?.toString().isNotEmpty == true
            ? s['auto_notify_time'].toString()
            : '18:00';
        _isLoading = false;
      });
    } catch (e) {
      // کسی بھی ایرر کی صورت میں فوراً لوڈنگ ختم کریں
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSettings() async {
    setState(() => _isLoading = true);

    final payload = <String, dynamic>{
      'madrasa_name': _madrasaNameController.text,
      'phone': _phoneController.text,
      'current_hijri_year': _hijriYearController.text,
      'week_start_day': _weekStartDay,
      'ai_provider': _aiProvider,
      'auto_notify_day': _autoNotifyDay,
      'auto_notify_time': _autoNotifyTime,
    };
    if (_geminiKeyController.text.trim().isNotEmpty) {
      payload['gemini_api_key'] = _geminiKeyController.text.trim();
    }
    if (_groqKeyController.text.trim().isNotEmpty) {
      payload['groq_api_key'] = _groqKeyController.text.trim();
    }
    if (_whatsappKeyController.text.trim().isNotEmpty) {
      payload['whatsapp_api_key'] = _whatsappKeyController.text.trim();
    }
    if (_smsKeyController.text.trim().isNotEmpty) {
      payload['sms_api_key'] = _smsKeyController.text.trim();
    }

    try {
      final res = await NetworkService.postWithFallbackAction(
          'update_settings', payload);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          // مقامی ڈیٹا بیس میں بھی محفوظ کریں
          final db = DBHelper();
          await db.getSettings(); // یہ default row بناتی ہے اگر نہ ہو
          final dbInstance = await db.database;
          await dbInstance.update(
            'settings',
            {
              'madrasa_name': _madrasaNameController.text,
              'phone': _phoneController.text,
              'current_hijri_year': _hijriYearController.text,
              'week_start_day': _weekStartDay,
              'ai_provider': _aiProvider,
              'gemini_api_key': '',
              'groq_api_key': '',
              'whatsapp_api_key': '',
              'sms_api_key': '',
              'auto_notify_day': _autoNotifyDay,
              'auto_notify_time': _autoNotifyTime,
            },
            where: 'id = 1',
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isUrduGlobal.value
                    ? "سیٹنگز کامیابی سے اپڈیٹ ہو گئیں!"
                    : "Settings updated successfully!"),
                backgroundColor: Colors.green),
          );
        } else {
          _showError(data['message'] ?? 'Error updating settings');
        }
      } else {
        _showError('Server Error: ${res.statusCode}');
      }
    } catch (e) {
      _showError('Connection Error: $e');
    }
    setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (c) => const DashboardPage()));
          },
          child: Directionality(
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: bgColor,
              drawer: const AppDrawer(),
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(isUrdu ? "سافٹ ویئر سیٹنگ" : "Settings",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: primaryGreen,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isUrdu
                              ? "ڈیٹا سنک ہو رہا ہے..."
                              : "Syncing data...")));
                      try {
                        await _loadSettings();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isUrdu
                                ? "سیٹنگز ری فریش ہو گئیں!"
                                : "Settings refreshed!"),
                            backgroundColor: Colors.green));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isUrdu
                                ? "ری فریش میں خرابی آئی"
                                : "Refresh failed"),
                            backgroundColor: Colors.red));
                      }
                    },
                  ),
                ],
              ),
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: ListView(
                        children: [
                          NeoBox(
                            padding: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.language, color: primaryGreen),
                                    const SizedBox(width: 10),
                                    Text(
                                      isUrdu ? "زبان (Language)" : "Language",
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: textDark,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text("اردو",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  trailing: Switch(
                                    value: isUrdu,
                                    activeThumbColor: primaryGreen,
                                    onChanged: (val) {
                                      isUrduGlobal.value = val;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          NeoBox(
                            padding: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.settings, color: primaryGreen),
                                    const SizedBox(width: 10),
                                    Text(
                                      isUrdu
                                          ? "مرکزی سیٹنگز"
                                          : "General Settings",
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: textDark,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 15),
                                _buildTextField(_madrasaNameController,
                                    isUrdu ? "مدرسہ کا نام" : "Madrasa Name"),
                                const SizedBox(height: 10),
                                _buildTextField(_phoneController,
                                    isUrdu ? "فون نمبر" : "Phone"),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    _hijriYearController,
                                    isUrdu
                                        ? "ہجری سال (جیسے 1447)"
                                        : "Hijri Year"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          NeoBox(
                            padding: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.api, color: primaryGreen),
                                    const SizedBox(width: 10),
                                    Text(
                                      isUrdu
                                          ? "اے پی آئی (API Keys)"
                                          : "API Settings",
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: textDark,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 15),
                                DropdownButtonFormField<String>(
                                  value: _aiProvider,
                                  decoration: const InputDecoration(
                                      labelText: 'AI Provider',
                                      border: OutlineInputBorder()),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'gemini', child: Text('Gemini')),
                                    DropdownMenuItem(
                                        value: 'groq',
                                        child: Text('Groq (Llama)')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _aiProvider = v!),
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    _geminiKeyController, "Gemini API Keys",
                                    maxLines: 3),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    _groqKeyController, "Groq API Keys",
                                    maxLines: 3),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    _whatsappKeyController, "WhatsApp API Key",
                                    obscure: true),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    _smsKeyController, "SMS API Key",
                                    obscure: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: _updateSettings,
                            child: Text(
                              isUrdu ? "سیٹنگز محفوظ کریں" : "Save Settings",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscure = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      obscureText: obscure && maxLines == 1,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
    );
  }
}
