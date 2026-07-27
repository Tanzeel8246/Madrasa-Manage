// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/network_service.dart';
import '../widgets/app_drawer.dart';

class AdminAdmissionsPage extends StatefulWidget {
  const AdminAdmissionsPage({super.key});

  @override
  State<AdminAdmissionsPage> createState() => _AdminAdmissionsPageState();
}

class _AdminAdmissionsPageState extends State<AdminAdmissionsPage> {
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color bgColor = const Color(0xFFF1EFE7);

  List<Map<String, dynamic>> _applications = [];
  Map<String, int> _counts = {'pending': 0, 'approved': 0, 'rejected': 0};
  String _selectedFilter = 'all';
  bool _isLoading = true;
  String _errorMsg = '';

  final List<String> _filters = ['all', 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    try {
      final res = await NetworkService.getWithFallbackAction(
          'get_admission_applications&filter=$_selectedFilter');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == 'success') {
          setState(() {
            _applications =
                List<Map<String, dynamic>>.from(body['applications'] ?? []);
            final c = body['counts'] ?? {};
            _counts = {
              'pending': c['pending'] ?? 0,
              'approved': c['approved'] ?? 0,
              'rejected': c['rejected'] ?? 0,
            };
          });
        } else {
          setState(() => _errorMsg = body['message'] ?? 'خرابی');
        }
      }
    } catch (e) {
      setState(() => _errorMsg = 'نیٹ ورک خرابی: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int appId, String status,
      {String? testDate, String? testTime, String? adminNote}) async {
    try {
      final res = await NetworkService.postWithFallbackAction(
        'update_admission_status',
        {
          'id': appId,
          'status': status,
          'test_date': testDate ?? '',
          'test_time': testTime ?? '',
          'admin_note': adminNote ?? '',
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body['message'] ?? 'عمل مکمل'),
            backgroundColor:
                body['status'] == 'success' ? Colors.green : Colors.red,
          ));
        }
        _loadApplications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خرابی: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _resendSms(int appId) async {
    try {
      final res = await NetworkService.postWithFallbackAction(
        'resend_admission_sms',
        {'id': appId},
      );
      final body = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(body['message'] ?? 'SMS عمل مکمل'),
          backgroundColor:
              body['status'] == 'success' ? Colors.green : Colors.red,
        ));
      }
      _loadApplications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('SMS دوبارہ بھیجنے میں خرابی: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showApproveDialog(Map<String, dynamic> app) {
    final testDateCtrl =
        TextEditingController(text: DateTime.now().toString().substring(0, 10));
    final testTimeCtrl = TextEditingController(text: '09:00');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text('درخواست منظور کریں', style: TextStyle(fontSize: 16)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('امیدوار: ${app['student_name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: testDateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                  labelText: 'ٹیسٹ کی تاریخ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today)),
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) {
                  testDateCtrl.text = d.toString().substring(0, 10);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: testTimeCtrl,
              decoration: const InputDecoration(
                  labelText: 'ٹیسٹ کا وقت',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time)),
              onTap: () async {
                final t = await showTimePicker(
                    context: context, initialTime: TimeOfDay.now());
                if (t != null) testTimeCtrl.text = t.format(context);
              },
              readOnly: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'ایڈمن نوٹ (اختیاری)',
                  border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('منسوخ')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label:
                const Text('منظور کریں', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(app['id'], 'Approved',
                  testDate: testDateCtrl.text,
                  testTime: testTimeCtrl.text,
                  adminNote: noteCtrl.text);
            },
          ),
        ],
      ),
    );
  }

  void _showDetailsModal(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 8),
          Text('درخواست کی تفصیلات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('طالب علم', app['student_name']),
              _detailRow('ولدیت', app['father_name']),
              _detailRow('تاریخ پیدائش', app['dob']),
              _detailRow('فون', app['mobile_number'] ?? app['mobile_no']),
              _detailRow('ٹیسٹ کی تاریخ', app['test_date']),
              _detailRow('ٹیسٹ کا وقت', app['test_time']),
              _detailRow(
                'SMS حالت',
                app['status']?.toString().toLowerCase() == 'approved'
                    ? (app['sms_sent']?.toString() == '1'
                        ? 'بھیجا گیا'
                        : 'نہیں بھیجا گیا')
                    : '',
              ),
              _detailRow('شعبہ', app['department']),
              _detailRow('ای میل', app['email']),
              _detailRow('موجودہ پتہ', app['address']),
              _detailRow('مستقل پتہ', app['permanent_address']),
              _detailRow('گزشتہ تعلیم', app['qualification']),
              _detailRow('گزشتہ ادارہ', app['last_studied']),
              _detailRow('مقصدِ داخلہ', app['aim']),
              _detailRow('سابقہ مدارس', app['prev_madaris']),
              _detailRow('مدرسہ چھوڑنے کی وجہ', app['leave_reason']),
              const Divider(),
              Text('سرپرست کی معلومات',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              _detailRow('نام', app['guardian_name']),
              _detailRow('شناختی کارڈ', app['guardian_cnic']),
              _detailRow('رشتہ', app['guardian_relation']),
              _detailRow('پتہ', app['guardian_address']),
            ],
          ),
        ),
        actions: [
          if (app['status']?.toString().toLowerCase() == 'approved' &&
              app['sms_sent']?.toString() != '1')
            TextButton.icon(
              icon: const Icon(Icons.sms),
              label: const Text('SMS دوبارہ بھیجیں'),
              onPressed: () {
                Navigator.pop(context);
                _resendSms(app['id']);
              },
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بند کریں')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    String val = (value ?? '').toString();
    if (val.isEmpty) val = '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text('$label:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade800))),
          Expanded(flex: 3, child: Text(val, style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Color _badgeColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _badgeLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'منظور';
      case 'rejected':
        return 'مسترد';
      default:
        return 'زیر التواء';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text('داخلہ درخواستیں',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadApplications),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(children: [
        // Stats Cards
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _statCard('زیر التواء', _counts['pending']!, Colors.orange),
            _statCard('منظور', _counts['approved']!, Colors.green),
            _statCard('مسترد', _counts['rejected']!, Colors.red),
          ]),
        ),
        // Filter Tabs
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _filters.length,
            itemBuilder: (_, i) {
              final f = _filters[i];
              final label = {
                'all': 'تمام',
                'pending': 'زیر التواء',
                'approved': 'منظور',
                'rejected': 'مسترد'
              }[f]!;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label),
                  selected: _selectedFilter == f,
                  selectedColor: primaryGreen.withValues(alpha: 0.2),
                  onSelected: (_) {
                    setState(() => _selectedFilter = f);
                    _loadApplications();
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMsg.isNotEmpty
                  ? Center(
                      child: Text(_errorMsg,
                          style: const TextStyle(color: Colors.red)))
                  : _applications.isEmpty
                      ? Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              Icon(Icons.inbox_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('کوئی درخواست موجود نہیں',
                                  style:
                                      TextStyle(color: Colors.grey.shade600)),
                            ]))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _applications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final app = _applications[i];
                            final status =
                                (app['status'] ?? 'pending').toString();
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(
                                          app['student_name'] ?? 'نامعلوم',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _badgeColor(status),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(_badgeLabel(status),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12)),
                                      ),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text('والد: ${app['father_name'] ?? ''}',
                                        style: TextStyle(
                                            color: Colors.grey.shade700)),
                                    Text('فون: ${app['mobile_number'] ?? ''}',
                                        style: TextStyle(
                                            color: Colors.grey.shade700)),
                                    if ((app['test_date'] ?? '')
                                            .toString()
                                            .isNotEmpty ||
                                        (app['test_time'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                      Text(
                                        'ٹیسٹ: ${app['test_date'] ?? '-'} ${app['test_time'] ?? ''}',
                                        style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    if (status.toLowerCase() == 'approved')
                                      Text(
                                        (app['sms_sent']?.toString() == '1')
                                            ? 'SMS بھیجا گیا'
                                            : 'SMS نہیں بھیجا گیا',
                                        style: TextStyle(
                                          color: (app['sms_sent']?.toString() ==
                                                  '1')
                                              ? Colors.green.shade700
                                              : Colors.orange.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if ((app['department'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text('شعبہ: ${app['department']}',
                                          style: TextStyle(
                                              color: Colors.grey.shade700)),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.visibility,
                                          size: 16, color: Colors.white),
                                      label: const Text('تفصیلات دیکھیں',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          minimumSize:
                                              const Size(double.infinity, 36)),
                                      onPressed: () => _showDetailsModal(app),
                                    ),
                                    const SizedBox(height: 4),
                                    if (status.toLowerCase() == 'approved' &&
                                        app['sms_sent']?.toString() != '1') ...[
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.sms, size: 16),
                                        label: const Text('SMS دوبارہ بھیجیں'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size(double.infinity, 36),
                                        ),
                                        onPressed: () => _resendSms(app['id']),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if (status == 'pending')
                                      Row(children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.check,
                                                size: 16, color: Colors.white),
                                            label: const Text('منظور',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                minimumSize: const Size(0, 36)),
                                            onPressed: () =>
                                                _showApproveDialog(app),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.close,
                                                size: 16, color: Colors.white),
                                            label: const Text('مسترد',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                minimumSize: const Size(0, 36)),
                                            onPressed: () {
                                              _updateStatus(
                                                  app['id'], 'rejected');
                                            },
                                          ),
                                        ),
                                      ]),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withValues(alpha: 0.4))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: color),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
