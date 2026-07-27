// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import '../utils/sync_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';

class AccPayrollPage extends StatefulWidget {
  const AccPayrollPage({super.key});

  @override
  State<AccPayrollPage> createState() => _AccPayrollPageState();
}

class _AccPayrollPageState extends State<AccPayrollPage> {
  final Color primaryGreen = const Color(0xFF284D3D);
  List<Map<String, dynamic>> _payrolls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayrolls();
  }

  Future<void> _loadPayrolls() async {
    setState(() => _isLoading = true);
    final db = DBHelper();
    final allPayrolls = await db.getAccPayroll();
    final teachers = await db.getTeachers();

    List<Map<String, dynamic>> enriched = [];
    for (var p in allPayrolls) {
      final t = teachers.firstWhere((x) => x['id'] == p['teacher_id'],
          orElse: () => {});
      final tName = t['name'] ?? 'Unknown';
      enriched.add({
        ...p,
        'teacher_name': tName,
      });
    }

    setState(() {
      _payrolls = enriched;
      _isLoading = false;
    });
  }

  Future<void> _generateBulkPayroll() async {
    final monthController = TextEditingController(
        text:
            "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}");

    final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title:
                Text(isUrduGlobal.value ? 'پے رول بنائیں' : 'Generate Payroll'),
            content: TextField(
              controller: monthController,
              decoration: InputDecoration(
                labelText:
                    isUrduGlobal.value ? 'مہینہ (YYYY-MM)' : 'Month (YYYY-MM)',
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(isUrduGlobal.value ? 'منسوخ کریں' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: Text(isUrduGlobal.value ? 'بنائیں' : 'Generate'),
              ),
            ],
          );
        });

    if (result == true) {
      final month = monthController.text;
      if (month.isNotEmpty) {
        final db = DBHelper();
        final teachers = await db.getTeachers();
        for (var t in teachers) {
          if (t['is_deleted'] == 1 ||
              (t['status'] != null &&
                  t['status'].toString().toLowerCase() != 'active')) {
            continue;
          }

          final tId = t['id'];
          final salaryStr = t['salary']?.toString() ?? '0';
          final basicSalary = double.tryParse(salaryStr) ?? 0.0;

          final existing = _payrolls
              .where((i) => i['teacher_id'] == tId && i['month_year'] == month)
              .toList();
          if (existing.isEmpty) {
            await db.insertAccPayroll({
              'teacher_id': tId,
              'month_year': month,
              'basic_salary': basicSalary,
              'allowances': 0.0,
              'deductions': 0.0,
              'net_salary': basicSalary,
              'status': 'Unpaid',
            });
          }
        }
        await _loadPayrolls();
        SyncService.runTwoWaySync().catchError((_) {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isUrduGlobal.value
                  ? 'پے رول بن گیا ہے'
                  : 'Payroll Generated')));
        }
      }
    }
  }

  Future<void> _editAllowances(Map<String, dynamic> p) async {
    final allowController =
        TextEditingController(text: p['allowances'].toString());
    final deductController =
        TextEditingController(text: p['deductions'].toString());

    final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(isUrduGlobal.value
                ? 'ترمیم کریں'
                : 'Edit Allowances/Deductions'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: allowController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isUrduGlobal.value
                        ? 'الاؤنسز / اضافی رقم'
                        : 'Allowances / Bonus',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deductController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isUrduGlobal.value ? 'کٹوتی' : 'Deductions',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(isUrduGlobal.value ? 'منسوخ کریں' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: Text(isUrduGlobal.value ? 'محفوظ کریں' : 'Save'),
              ),
            ],
          );
        });

    if (result == true) {
      final allow = double.tryParse(allowController.text) ?? 0.0;
      final deduct = double.tryParse(deductController.text) ?? 0.0;
      final basic = double.tryParse(p['basic_salary'].toString()) ?? 0.0;
      final net = basic + allow - deduct;

      await DBHelper().updateAccPayroll(p['id'], {
        'allowances': allow,
        'deductions': deduct,
        'net_salary': net,
      });
      await _loadPayrolls();
      SyncService.runTwoWaySync().catchError((_) {});
    }
  }

  Future<void> _markPaid(int id) async {
    final date =
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    await DBHelper()
        .updateAccPayroll(id, {'status': 'Paid', 'payment_date': date});
    await _loadPayrolls();
    SyncService.runTwoWaySync().catchError((_) {});
  }

  void _showReceipt(BuildContext context, Map<String, dynamic> p) {
    final ScreenshotController screenshotController = ScreenshotController();
    String? signaturePath;

    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isUrduGlobal.value ? 'پے سلپ' : 'Pay Slip'),
                  TextButton.icon(
                    icon: const Icon(Icons.draw, size: 16),
                    label: Text(isUrduGlobal.value ? 'دستخط' : 'Signature'),
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                          source: ImageSource.gallery, imageQuality: 70);
                      if (picked != null) {
                        setStateDialog(() => signaturePath = picked.path);
                      }
                    },
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Screenshot(
                  controller: screenshotController,
                  child: Container(
                    width: 380,
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo + Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/logo.png',
                                width: 50,
                                height: 50,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.school,
                                    size: 50,
                                    color: Color(0xFF284D3D))),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("مدرسہ اشرف المدارس",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'JameelNooriNastaleeq')),
                                  Text("فاروقہ، ضلع سرگودھا",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontFamily: 'JameelNooriNastaleeq')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          color: const Color(0xFF284D3D),
                          child: const Text("پے سلپ (Pay Slip)",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'JameelNooriNastaleeq')),
                        ),
                        const SizedBox(height: 8),
                        _receiptRow("استاد کا نام", "${p['teacher_name']}"),
                        _receiptRow("مہینہ", "${p['month_year']}"),
                        const Divider(),
                        _receiptRow("بنیادی تنخواہ", "Rs ${p['basic_salary']}"),
                        _receiptRow(
                            "الاؤنسز / اضافی", "+ Rs ${p['allowances']}"),
                        _receiptRow("کٹوتیاں", "- Rs ${p['deductions']}"),
                        const Divider(thickness: 2),
                        _receiptRow("خالص تنخواہ", "Rs ${p['net_salary']}",
                            bold: true),
                        _receiptRow(
                            "سٹیٹس",
                            p['status'] == 'Paid'
                                ? 'ادا شدہ ✓'
                                : 'غیر ادا شدہ'),
                        if (p['payment_date'] != null &&
                            p['payment_date'].toString().isNotEmpty)
                          _receiptRow(
                              "ادائیگی کی تاریخ", p['payment_date'].toString()),
                        const SizedBox(height: 16),
                        const Divider(thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("دستخط / مہر:",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'JameelNooriNastaleeq')),
                            if (signaturePath != null &&
                                File(signaturePath!).existsSync())
                              Image.file(File(signaturePath!),
                                  height: 50, width: 100, fit: BoxFit.contain)
                            else
                              const Text("_____________________",
                                  style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                            "تاریخ اجراء: ${DateTime.now().toString().split(' ')[0]}",
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("بند کریں")),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: Text(isUrduGlobal.value ? "شیئر کریں" : "Share"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    final image = await screenshotController.capture();
                    if (image != null) {
                      final directory =
                          await getApplicationDocumentsDirectory();
                      final imagePath =
                          await File('${directory.path}/payslip_${p['id']}.png')
                              .create();
                      await imagePath.writeAsBytes(image);
                      await Share.shareXFiles([XFile(imagePath.path)],
                          text: 'پے سلپ - ${p['teacher_name']}');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontFamily: 'JameelNooriNastaleeq')),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'JameelNooriNastaleeq',
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Syncing data...')));
              try {
                await SyncService.runTwoWaySync();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync complete')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Sync failed: ')));
                }
              }
            },
          )
        ],
        title: Text(isUrduGlobal.value ? 'پے رول' : 'Payroll'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: const Icon(Icons.people),
                    label: Text(isUrduGlobal.value
                        ? 'اس مہینے کا پے رول بنائیں'
                        : 'Generate This Month Payroll'),
                    onPressed: _generateBulkPayroll,
                  ),
                ),
                Expanded(
                  child: _payrolls.isEmpty
                      ? Center(
                          child: Text(isUrduGlobal.value
                              ? 'کوئی پے رول نہیں'
                              : 'No payroll records'))
                      : ListView.builder(
                          itemCount: _payrolls.length,
                          itemBuilder: (context, index) {
                            final p = _payrolls[index];
                            final isPaid = p['status'] == 'Paid';
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: ListTile(
                                title: Text(
                                    "${p['teacher_name']} (${p['month_year']})",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    "${isUrduGlobal.value ? 'بنیادی' : 'Basic'}: ${p['basic_salary']} | "
                                    "+${p['allowances']} -${p['deductions']} = Rs ${p['net_salary']}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPaid
                                            ? Colors.green
                                            : Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                          isPaid
                                              ? (isUrduGlobal.value
                                                  ? 'ادا شدہ'
                                                  : 'Paid')
                                              : (isUrduGlobal.value
                                                  ? 'غیر ادا'
                                                  : 'Unpaid'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12)),
                                    ),
                                    if (!isPaid) ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () => _editAllowances(p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.check_circle,
                                            color: Colors.green),
                                        onPressed: () => _markPaid(p['id']),
                                      ),
                                    ],
                                    // Receipt button always visible
                                    IconButton(
                                      icon: const Icon(Icons.receipt_long,
                                          color: Colors.indigo),
                                      tooltip: isUrduGlobal.value
                                          ? 'رسید دیکھیں'
                                          : 'View Receipt',
                                      onPressed: () => _showReceipt(context, p),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
