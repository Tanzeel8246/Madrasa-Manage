// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/sync_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/neo_box.dart';
import 'dashboard.dart';
import 'students.dart';

class AlumniRegisterPage extends StatefulWidget {
  const AlumniRegisterPage({super.key});

  @override
  State<AlumniRegisterPage> createState() => _AlumniRegisterPageState();
}

class _AlumniRegisterPageState extends State<AlumniRegisterPage> {
  final Color primaryGreen = const Color(0xFF284D3D);
  List<Map<String, dynamic>> _alumni = [];
  bool _isLoading = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadAlumni();
  }

  Future<void> _loadAlumni() async {
    final db = DBHelper();
    final all =
        await db.getPagedStudents(limit: 500, offset: 0, status: 'Alumni');
    if (!mounted) return;
    setState(() {
      _alumni = all;
      _isLoading = false;
    });
  }

  String _admissionNo(Map<String, dynamic> student) {
    return (student['admission_number'] ??
            student['roll_number'] ??
            student['serial_no'] ??
            '')
        .toString();
  }

  Future<void> _syncData() async {
    final isUrdu = isUrduGlobal.value;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isUrdu ? 'ڈیٹا سنک ہو رہا ہے...' : 'Syncing data...'),
    ));
    try {
      await SyncService.runTwoWaySync();
      await _loadAlumni();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUrdu ? 'سنک مکمل ہو گیا!' : 'Sync complete!'),
        backgroundColor: Colors.green,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUrdu ? 'سنک میں خرابی آئی' : 'Sync failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _restoreStudent(Map<String, dynamic> student) async {
    final isUrdu = isUrduGlobal.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'بحالی کی تصدیق' : 'Confirm Restore'),
        content: Text(isUrdu
            ? 'کیا اس طالب علم کو دوبارہ فعال طلباء میں شامل کرنا ہے؟'
            : 'Restore this student to active students?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isUrdu ? 'نہیں' : 'No'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.restore, color: Colors.white),
            label: Text(isUrdu ? 'بحال کریں' : 'Restore',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await DBHelper().updateStudent(student['id'] as int, {
      'status': 'Active',
      'graduation_date': '',
      'duration': '',
      'leaving_reason': '',
    });
    await _loadAlumni();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isUrdu ? 'طالب علم بحال کر دیا گیا' : 'Student restored'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _printRegister() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final isUrdu = isUrduGlobal.value;
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          textDirection: isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          build: (_) => [
            pw.Center(
              child: pw.Column(children: [
                pw.Text(
                    isUrdu ? 'رجسٹر فارغ التحصیل طلباء' : 'Alumni Register'),
                pw.SizedBox(height: 4),
                pw.Text('${isUrdu ? 'کل تعداد' : 'Total'}: ${_alumni.length}'),
              ]),
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment:
                  isUrdu ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              headers: [
                '#',
                isUrdu ? 'داخلہ نمبر' : 'Admission No',
                isUrdu ? 'نام طالب علم' : 'Student Name',
                isUrdu ? 'ولدیت' : 'Father Name',
                isUrdu ? 'داخلہ' : 'Admission',
                isUrdu ? 'فراغت' : 'Graduation',
                isUrdu ? 'دورانیہ' : 'Duration',
                isUrdu ? 'وجہ فراغت' : 'Reason',
              ],
              data: List.generate(_alumni.length, (index) {
                final s = _alumni[index];
                return [
                  '${index + 1}',
                  _admissionNo(s),
                  s['name']?.toString() ?? '',
                  s['father_name']?.toString() ?? '',
                  s['admission_date']?.toString() ?? '',
                  s['graduation_date']?.toString() ?? '',
                  s['duration']?.toString() ?? '',
                  s['leaving_reason']?.toString() ?? '',
                ];
              }),
            ),
          ],
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'alumni_register.pdf',
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
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
            textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Scaffold(
              backgroundColor: const Color(0xFFF1EFE7),
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(isUrdu ? 'فارغ التحصیل طلباء' : 'Alumni Register'),
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                actions: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Chip(
                        label: Text('${_alumni.length}'),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isUrdu ? 'پرنٹ' : 'Print',
                    onPressed:
                        _isPrinting || _alumni.isEmpty ? null : _printRegister,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: isUrdu ? 'سنک' : 'Sync',
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: _syncData,
                  ),
                ],
              ),
              drawer: const AppDrawer(),
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _alumni.isEmpty
                      ? Center(
                          child: Text(isUrdu
                              ? 'کوئی فارغ التحصیل ریکارڈ موجود نہیں ہے'
                              : 'No alumni records found'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: _alumni.length,
                          itemBuilder: (context, index) {
                            final student = _alumni[index];
                            return _alumniCard(student, index, isUrdu);
                          },
                        ),
            ),
          ),
        );
      },
    );
  }

  Widget _alumniCard(Map<String, dynamic> student, int index, bool isUrdu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryGreen.withValues(alpha: 0.12),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: primaryGreen, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student['name']?.toString() ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          '${isUrdu ? 'ولدیت' : 'Father'}: ${student['father_name'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_admissionNo(student)),
                  backgroundColor: Colors.blue.withValues(alpha: 0.08),
                ),
              ],
            ),
            const Divider(height: 20),
            _detailRow(
                Icons.calendar_today,
                isUrdu ? 'تاریخ داخلہ' : 'Admission',
                student['admission_date'] ?? 'N/A'),
            _detailRow(
                Icons.event_available,
                isUrdu ? 'تاریخ فراغت' : 'Graduation',
                student['graduation_date'] ?? 'N/A'),
            _detailRow(Icons.timer, isUrdu ? 'تعلیمی دورانیہ' : 'Duration',
                student['duration'] ?? 'N/A'),
            _detailRow(
                Icons.info_outline,
                isUrdu ? 'وجہ فراغت' : 'Reason',
                student['leaving_reason'] ??
                    (isUrdu ? 'درج نہیں' : 'Not entered')),
            _detailRow(Icons.location_on, isUrdu ? 'پتہ' : 'Address',
                student['address'] ?? 'N/A'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentsPage(),
                      ),
                    ),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text(isUrdu ? 'طلباء ریکارڈ' : 'Students'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _restoreStudent(student),
                    icon: const Icon(Icons.restore, size: 18),
                    label: Text(isUrdu ? 'بحال کریں' : 'Restore'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: primaryGreen),
          const SizedBox(width: 10),
          Text('$label:',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
              child: Text((value ?? '').toString(),
                  style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
