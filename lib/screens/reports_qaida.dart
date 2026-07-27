// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/performance_helper.dart';
import '../utils/sync_service.dart';
import '../widgets/app_drawer.dart';
import 'dashboard.dart';

class QaidaReportPage extends StatefulWidget {
  final String? className;
  const QaidaReportPage({super.key, this.className});

  @override
  _QaidaReportPageState createState() => _QaidaReportPageState();
}

class _QaidaReportPageState extends State<QaidaReportPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);

  final dbHelper = DBHelper();
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  String? fromDate;
  String? toDate;
  String? selectedStudentId;
  String selectedPeriod = 'current_week';

  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _updateDatesForPeriod(String period) async {
    if (period == 'custom') return;
    final settings = await dbHelper.getSettings();
    int weekStartDay = int.tryParse(settings['week_start_day']?.toString() ?? '6') ?? 6;
    final boundaries = PerformanceCalculator.getPeriodBoundaries(period, weekStartDay);
    setState(() {
      fromDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['start']!);
      toDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['end']!);
      _fromDateController.text = fromDate!;
      _toDateController.text = toDate!;
    });
    _loadData();
  }

  DateTime _parseRobust(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    try {
      return intl.DateFormat('d/M/yyyy').parse(dateStr);
    } catch (_) {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await dbHelper.database;
      final settings = await dbHelper.getSettings();
      int weekStartDay = int.tryParse(settings['week_start_day']?.toString() ?? '6') ?? 6;

      // Load students
      List<Map<String, dynamic>> allStudents;
      if (widget.className != null && widget.className!.isNotEmpty) {
        allStudents = await db.query(
          'students',
          where: '(class_name = ? OR class = ?) AND (is_deleted = 0 OR is_deleted IS NULL)',
          whereArgs: [widget.className, widget.className],
          orderBy: 'name ASC',
        );
      } else {
        allStudents = await db.query(
          'students',
          where: 'is_deleted = 0 OR is_deleted IS NULL',
          orderBy: 'name ASC',
        );
      }
      _students = allStudents;

      // Set default date range
      if (fromDate == null || toDate == null) {
        final boundaries = PerformanceCalculator.getPeriodBoundaries(selectedPeriod, weekStartDay);
        fromDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['start']!);
        toDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['end']!);
        _fromDateController.text = fromDate!;
        _toDateController.text = toDate!;
      }

      DateTime sDate = _parseRobust(fromDate!);
      DateTime eDate = _parseRobust(toDate!);

      // Build student IDs filter
      List<dynamic> stdIds;
      if (selectedStudentId != null) {
        stdIds = [int.tryParse(selectedStudentId!) ?? selectedStudentId];
      } else {
        stdIds = _students.map((s) => s['id']).toList();
      }

      if (stdIds.isEmpty) {
        setState(() => _records = []);
        return;
      }

      final qs = stdIds.map((e) => '?').join(',');
      final allRecords = await db.rawQuery(
        'SELECT q.*, s.name, s.roll_number, s.admission_number FROM qaida_records q '
        'JOIN students s ON q.student_id = s.id '
        'WHERE (q.is_deleted = 0 OR q.is_deleted IS NULL) AND q.student_id IN ($qs) '
        'ORDER BY q.date DESC, s.name ASC',
        [...stdIds],
      );

      // Filter by date range
      final filtered = allRecords.where((r) {
        try {
          DateTime fDate = _parseRobust(r['date']?.toString() ?? '');
          return !fDate.isBefore(sDate) && !fDate.isAfter(eDate);
        } catch (_) {
          return false;
        }
      }).toList();

      setState(() => _records = filtered);
    } catch (e) {
      debugPrint("Error loading Qaida reports: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      String formatted = "${picked.day}/${picked.month}/${picked.year}";
      setState(() {
        if (isFrom) {
          fromDate = formatted;
          _fromDateController.text = formatted;
        } else {
          toDate = formatted;
          _toDateController.text = formatted;
        }
        selectedPeriod = 'custom';
      });
      _loadData();
    }
  }

  Widget _cell(String text, double width,
      {bool isHeader = false, Color? bgColor, Color? textColor, double? fontSize}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor ?? (isHeader ? Colors.grey.shade200 : Colors.white),
        border: Border.all(color: Colors.black87, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: fontSize ?? (isHeader ? 12 : 11),
          color: textColor ?? Colors.black,
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell('#', 40, isHeader: true),
          _cell(isUrduGlobal.value ? 'رول نمبر' : 'Roll No', 70, isHeader: true),
          _cell(isUrduGlobal.value ? 'طالب علم' : 'Student', 160, isHeader: true),
          _cell(isUrduGlobal.value ? 'تاریخ' : 'Date', 80, isHeader: true),
          _cell(isUrduGlobal.value ? 'قسم' : 'Type', 80, isHeader: true),
          _cell(isUrduGlobal.value ? 'وقت' : 'Time', 70, isHeader: true),
          for (int i = 1; i <= 4; i++)
            Column(
              children: [
                _cell('سبق $i', 230, isHeader: true, bgColor: Colors.teal.withOpacity(0.7), textColor: Colors.white),
                Row(children: [
                  _cell(isUrduGlobal.value ? 'تختی/صفحہ' : 'Page', 100, isHeader: true),
                  _cell(isUrduGlobal.value ? 'مقدار' : 'Qty', 60, isHeader: true),
                  _cell(isUrduGlobal.value ? 'کیفیت' : 'Grade', 70, isHeader: true),
                ]),
              ],
            ),
          _cell(isUrduGlobal.value ? 'حاضری' : 'Att.', 70, isHeader: true),
          _cell(isUrduGlobal.value ? 'شکایات' : 'Remarks', 130, isHeader: true,
              bgColor: Colors.red.withOpacity(0.7), textColor: Colors.white),
        ],
      ),
    );
  }

  Color _gradeColor(String? grade) {
    if (grade == null) return Colors.black;
    final g = grade.toLowerCase();
    if (g == 'excellent' || g == 'ممتاز') return Colors.green.shade700;
    if (g == 'good' || g == 'بہتر') return Colors.blue.shade700;
    if (g == 'average' || g == 'معمولی') return Colors.orange.shade700;
    if (g == 'weak' || g == 'کمزور') return Colors.red.shade700;
    return Colors.black;
  }

  Widget _buildDataRow(Map<String, dynamic> r, int srNo) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(srNo.toString(), 40, bgColor: Colors.grey.shade100),
          _cell((r['roll_number'] ?? r['admission_number'] ?? '-').toString(), 70),
          _cell(r['name']?.toString() ?? '-', 160, textColor: Colors.black87),
          _cell(r['date']?.toString() ?? '-', 80, fontSize: 10),
          _cell(r['lesson_type']?.toString() ?? '-', 80),
          _cell(r['hearing_time'] != null && r['hearing_time'].toString().isNotEmpty
              ? r['hearing_time'].toString().substring(0, r['hearing_time'].toString().length > 5 ? 5 : r['hearing_time'].toString().length)
              : '-', 70),
          for (int i = 1; i <= 4; i++) ...[
            _cell(r['sabaq_$i']?.toString().isNotEmpty == true ? r['sabaq_$i'].toString() : '-', 100),
            _cell(r['qty_$i']?.toString().isNotEmpty == true ? r['qty_$i'].toString() : '-', 60),
            _cell(r['grade_$i']?.toString().isNotEmpty == true ? r['grade_$i'].toString() : '-', 70,
                textColor: _gradeColor(r['grade_$i']?.toString())),
          ],
          _cell(r['attendance']?.toString() ?? '-', 70),
          _cell(r['complaint']?.toString() ?? r['remarks']?.toString() ?? '-', 130,
              textColor: Colors.red.shade700),
        ],
      ),
    );
  }

  Future<void> _printQaidaPdf() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
      final fallbackData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final fallbackTtf = pw.Font.ttf(fallbackData);
      final bold = pw.TextStyle(font: ttf, fontFallback: [fallbackTtf], fontWeight: pw.FontWeight.bold);
      final normal = pw.TextStyle(font: ttf, fontFallback: [fallbackTtf]);

      final pdf = pw.Document();

      final headers = ['#', 'رول نمبر', 'طالب علم', 'تاریخ', 'قسم', 'وقت',
        'سبق 1\nتختی', 'سبق 1\nمقدار', 'سبق 1\nکیفیت',
        'سبق 2\nتختی', 'سبق 2\nمقدار', 'سبق 2\nکیفیت',
        'سبق 3\nتختی', 'سبق 3\nمقدار', 'سبق 3\nکیفیت',
        'سبق 4\nتختی', 'سبق 4\nمقدار', 'سبق 4\nکیفیت',
        'حاضری', 'شکایات'];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: ttf,
            fontFallback: [fallbackTtf],
          ),
          build: (context) => [
            pw.Text('قاعدہ / نماز حنفی رپورٹ', style: bold.copyWith(fontSize: 16)),
            pw.Text('کلاس: ${widget.className ?? "تمام"} | تاریخ: $fromDate تا $toDate', style: normal.copyWith(fontSize: 10)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: _records.asMap().entries.map((e) {
                final r = e.value;
                return [
                  (e.key + 1).toString(),
                  r['roll_number']?.toString() ?? '-',
                  r['name']?.toString() ?? '-',
                  r['date']?.toString() ?? '-',
                  r['lesson_type']?.toString() ?? '-',
                  r['hearing_time']?.toString() ?? '-',
                  ...List.generate(4, (i) => [
                    r['sabaq_${i+1}']?.toString() ?? '-',
                    r['qty_${i+1}']?.toString() ?? '-',
                    r['grade_${i+1}']?.toString() ?? '-',
                  ]).expand((x) => x).toList(),
                  r['attendance']?.toString() ?? '-',
                  r['complaint']?.toString() ?? r['remarks']?.toString() ?? '-',
                ];
              }).toList(),
              headerStyle: bold.copyWith(fontSize: 7),
              cellStyle: normal.copyWith(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.center,
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      debugPrint("Print Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isUrduGlobal.value ? "پرنٹ میں خرابی آئی: $e" : "Print error: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (c) => const DashboardPage()));
      },
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
          title: Text(
              isUrduGlobal.value ? "قاعدہ / نماز رپورٹ" : "Qaida / Namaz Report"),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: _printQaidaPdf,
              tooltip: isUrduGlobal.value ? "پرنٹ PDF" : "Print PDF",
            ),
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isUrduGlobal.value ? "ڈیٹا سنک ہو رہا ہے..." : "Syncing...")));
                try {
                  await SyncService.runTwoWaySync();
                  if (mounted) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUrduGlobal.value ? "سنک مکمل!" : "Sync complete!"),
                        backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUrduGlobal.value ? "سنک میں خرابی" : "Sync failed"),
                        backgroundColor: Colors.red));
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // ─── Filter Card ───
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Column(
                children: [
                  // Period Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedPeriod,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value ? "دورانیہ (Period)" : "Period",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      DropdownMenuItem(value: 'current_week',
                          child: Text(isUrduGlobal.value ? "رواں ہفتہ (ڈیفالٹ)" : "Current Week (Default)")),
                      DropdownMenuItem(value: 'weekly',
                          child: Text(isUrduGlobal.value ? "ہفتہ وار (آخری 7 دن)" : "Weekly (Last 7 Days)")),
                      DropdownMenuItem(value: 'monthly',
                          child: Text(isUrduGlobal.value ? "ماہانہ (آخری 30 دن)" : "Monthly (Last 30 Days)")),
                      DropdownMenuItem(value: 'quarterly',
                          child: Text(isUrduGlobal.value ? "سہ ماہی (آخری 90 دن)" : "Quarterly (Last 90 Days)")),
                      DropdownMenuItem(value: 'semi_annually',
                          child: Text(isUrduGlobal.value ? "شش ماہی (آخری 180 دن)" : "Semi-Annually (180 Days)")),
                      DropdownMenuItem(value: 'annually',
                          child: Text(isUrduGlobal.value ? "سالانہ (آخری 365 دن)" : "Annually (365 Days)")),
                      DropdownMenuItem(value: 'custom',
                          child: Text(isUrduGlobal.value ? "کسٹم ڈیٹس" : "Custom Dates")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedPeriod = v);
                        _updateDatesForPeriod(v);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  // Student Dropdown
                  DropdownButtonFormField<String>(
                    value: _students.any((s) => s['id'].toString() == selectedStudentId)
                        ? selectedStudentId
                        : null,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value ? "طالب علم منتخب کریں" : "Select Student",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(isUrduGlobal.value ? "-- تمام طلباء (ڈیفالٹ) --" : "-- All Students (Default) --")),
                      ..._students.map((s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child: Text("${s['admission_number'] ?? s['roll_number'] ?? ''} - ${s['name']} (${s['father_name'] ?? ''})")))],
                    onChanged: (v) {
                      setState(() => selectedStudentId = v);
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 10),
                  // Date Pickers
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value ? "تاریخ سے" : "From Date",
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _toDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value ? "تاریخ تک" : "To Date",
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                          onTap: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ─── Table ───
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? Center(
                          child: Text(
                            isUrduGlobal.value ? "کوئی ریکارڈ نہیں ملا" : "No records found",
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                          ))
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTableHeader(),
                                  ..._records.asMap().entries.map(
                                      (e) => _buildDataRow(e.value, e.key + 1)),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      isUrduGlobal.value
                                          ? "مجموعی ریکارڈ: ${_records.length}"
                                          : "Total Records: ${_records.length}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryGreen,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
