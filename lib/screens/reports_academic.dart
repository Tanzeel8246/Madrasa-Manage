// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/performance_helper.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import 'dashboard.dart';

class ReportsAcademicPage extends StatefulWidget {
  final String? className;
  const ReportsAcademicPage({super.key, this.className});

  @override
  _ReportsAcademicPageState createState() => _ReportsAcademicPageState();
}

class _ReportsAcademicPageState extends State<ReportsAcademicPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);

  Map<String, List<Map<String, dynamic>>> _reportsGrouped = {};
  List<Map<String, dynamic>> _students = [];
  bool isLoading = true;
  String? fromDate;
  String? toDate;
  String? selectedStudentId;
  String selectedPeriod = 'current_week';

  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();

  Future<void> _updateDatesForPeriod(String period) async {
    if (period == 'custom') return;
    final db = DBHelper();
    final settings = await db.getSettings();
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

  String _normalizeClassName(dynamic value) {
    return (value?.toString() ?? '')
        .trim()
        .replaceAll('ٰ', '')
        .replaceAll('ى', 'ی')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  bool _isActiveStudent(Map<String, dynamic> student) {
    final status = (student['status'] ?? '').toString().trim().toLowerCase();
    final isDeleted =
        int.tryParse(student['is_deleted']?.toString() ?? '0') ?? 0;
    return isDeleted == 0 &&
        (status == 'active' ||
            status == 'present' ||
            status == 'حاضر' ||
            status.isEmpty);
  }

  bool _matchesSelectedClass(Map<String, dynamic> row) {
    if (widget.className == null || widget.className!.trim().isEmpty) {
      return true;
    }
    final selected = _normalizeClassName(widget.className);
    return _normalizeClassName(row['class_name']) == selected ||
        _normalizeClassName(row['class']) == selected;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final db = DBHelper();
      final allStudents = await db.getStudents();
      _students = allStudents.where((s) {
        final cName = _normalizeClassName(
            s['class_name']?.toString().isNotEmpty == true
                ? s['class_name']
                : s['class']);
        final isHifz = cName.contains('حفظ') ||
            cName.contains('حسنصوت') ||
            cName.contains('گردان');
        return _isActiveStudent(s) && !isHifz && _matchesSelectedClass(s);
      }).toList();

      final database = await db.database;
      final allReports = await database.query('academic_reports',
          orderBy: 'date DESC, id DESC');

      Map<String, List<Map<String, dynamic>>> grouped = {};

      final settings = await db.getSettings();
      int weekStartDay = int.tryParse(settings['week_start_day']?.toString() ?? '6') ?? 6;

      if (fromDate == null || toDate == null) {
        final boundaries = PerformanceCalculator.getPeriodBoundaries(selectedPeriod, weekStartDay);
        fromDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['start']!);
        toDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['end']!);
        _fromDateController.text = fromDate!;
        _toDateController.text = toDate!;
      }

      DateTime sDate = _parseRobust(fromDate!);
      DateTime eDate = _parseRobust(toDate!);

      for (var r in allReports) {
        String sid = r['student_id'].toString();

        if (selectedStudentId != null && sid != selectedStudentId) {
          continue;
        }

        if (!_matchesSelectedClass(r)) continue;

        // Only include reports for students currently in the filtered list (unless explicitly selected)
        if (selectedStudentId == null) {
          bool isStudentValid = _students.any((s) => s['id'].toString() == sid);
          if (!isStudentValid) continue;
        }

        try {
          DateTime fDate = _parseRobust(r['date']?.toString() ?? '');
          if (fDate.isBefore(sDate) || fDate.isAfter(eDate)) continue;
        } catch (_) {
          continue;
        }
        grouped.putIfAbsent(sid, () => []).add(r);
      }

      _reportsGrouped = grouped;
    } catch (e) {
      debugPrint("Load Academic Report Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
      });
      _loadData();
    }
  }

  String _getStudentName(String sid) {
    if (sid.isEmpty) return "Unknown";
    var match = _students.where((s) => s['id'].toString() == sid);
    if (match.isNotEmpty) return match.first['name'] ?? "Unknown";
    return "Unknown";
  }

  String _getStudentRollNo(String sid) {
    if (sid.isEmpty) return "-";
    var match = _students.where((s) => s['id'].toString() == sid);
    if (match.isNotEmpty) {
      return match.first['roll_number']?.toString() ??
          match.first['admission_number']?.toString() ??
          "-";
    }
    return "-";
  }

  Color getStatusColor(String? status) {
    if (status == null) return Colors.black;
    if (status.contains('بہترین')) return Colors.green;
    if (status.contains('بہتر')) return Colors.blue;
    if (status.contains('رعایتی پاس')) return Colors.orange;
    if (status.contains('کچا')) return Colors.red;
    if (status.contains('ممتاز') ||
        status.contains('Excellent') ||
        status.contains('پختہ')) {
      return Colors.green;
    }
    if (status.contains('بہتر') || status.contains('Good')) return Colors.blue;
    if (status.contains('معمولی') ||
        status.contains('Average') ||
        status.contains('کچا')) {
      return Colors.orange;
    }
    if (status.contains('کمزور') ||
        status.contains('Weak') ||
        status.contains('ناقص')) {
      return Colors.red;
    }
    return Colors.black;
  }

  Widget _cell(String text, double width,
      {Color? bgColor,
      Color? textColor,
      bool isHeader = false,
      bool bold = false}) {
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
        maxLines: null,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontWeight: (bold || isHeader) ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
          color: textColor ?? Colors.black,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTableHeader() {
    return Row(
      children: [
        _cell(isUrduGlobal.value ? "تاریخ" : "Date", 80, isHeader: true),
        _cell(isUrduGlobal.value ? "کلاس" : "Class", 100, isHeader: true),
        _cell(isUrduGlobal.value ? "مضمون" : "Subject", 120, isHeader: true),
        _cell(isUrduGlobal.value ? "سبق کی تفصیل" : "Lesson Details", 250,
            isHeader: true),
        _cell(isUrduGlobal.value ? "کیفیت" : "Grade", 80, isHeader: true),
        _cell(isUrduGlobal.value ? "ریمارکس" : "Remarks", 200, isHeader: true),
      ],
    );
  }

  double _dynamicSubjectWidth(List<Map<String, dynamic>> reports) {
    var longest = isUrduGlobal.value ? "Subject" : "Subject";
    for (final report in reports) {
      final value = (report['subject'] ?? '-').toString().trim();
      if (value.length > longest.length) longest = value;
    }
    return (longest.length * 9.0).clamp(120.0, 260.0);
  }

  Widget _buildTableHeaderFor(double subjectWidth) {
    return Row(
      children: [
        _cell(isUrduGlobal.value ? "تاریخ" : "Date", 80, isHeader: true),
        _cell(isUrduGlobal.value ? "کلاس" : "Class", 100, isHeader: true),
        _cell(isUrduGlobal.value ? "مضمون" : "Subject", subjectWidth,
            isHeader: true),
        _cell(isUrduGlobal.value ? "سبق کی تفصیل" : "Lesson Details", 250,
            isHeader: true),
        _cell(isUrduGlobal.value ? "کیفیت" : "Grade", 80, isHeader: true),
        _cell(isUrduGlobal.value ? "ریمارکس" : "Remarks", 200, isHeader: true),
      ],
    );
  }

  Widget _buildDataRowFor(Map<String, dynamic> r, double subjectWidth) {
    return Row(
      children: [
        _cell(r['date'] ?? '-', 80, bold: true),
        _cell(r['class_name'] ?? '-', 100),
        _cell(r['subject'] ?? '-', subjectWidth),
        _cell(r['lesson_details'] ?? '-', 250),
        _cell(r['grade'] ?? '-', 80, textColor: getStatusColor(r['grade'])),
        _cell(r['remarks'] ?? '-', 200),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildDataRow(Map<String, dynamic> r) {
    return Row(
      children: [
        _cell(r['date'] ?? '-', 80, bold: true),
        _cell(r['class_name'] ?? '-', 100),
        _cell(r['subject'] ?? '-', 120),
        _cell(r['lesson_details'] ?? '-', 250),
        _cell(r['grade'] ?? '-', 80, textColor: getStatusColor(r['grade'])),
        _cell(r['remarks'] ?? '-', 200),
      ],
    );
  }

  List<Widget> _buildGroupedTables() {
    List<Widget> sections = [];

    if (_reportsGrouped.isEmpty) {
      sections.add(Container(
        width: 830,
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black87, width: 0.5)),
        child: Text(
            isUrduGlobal.value ? "کوئی ریکارڈ نہیں ملا" : "No record found",
            style: const TextStyle(color: Colors.red)),
      ));
      return sections;
    }

    _reportsGrouped.forEach((studentId, reports) {
      sections.add(Container(
        width: 830,
        margin: const EdgeInsets.only(top: 15, bottom: 5),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: primaryGreen.withValues(alpha: 0.1),
            border: Border.all(color: primaryGreen),
            borderRadius: BorderRadius.circular(5)),
        child: Text(
          "${isUrduGlobal.value ? 'رول نمبر:' : 'Roll No:'} ${_getStudentRollNo(studentId)} | ${isUrduGlobal.value ? 'طالب علم:' : 'Student:'} ${_getStudentName(studentId)}",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: primaryGreen),
        ),
      ));

      final subjectWidth = _dynamicSubjectWidth(reports);
      sections.add(_buildTableHeaderFor(subjectWidth));
      for (var r in reports) {
        sections.add(_buildDataRowFor(r, subjectWidth));
      }
    });

    return sections;
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
              isUrduGlobal.value ? "جنرل اکیڈمک رپورٹس" : "Academic Reports"),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isUrduGlobal.value
                        ? "ڈیٹا سنک ہو رہا ہے..."
                        : "Syncing data...")));
                try {
                  await SyncService.runTwoWaySync();
                  if (mounted) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUrduGlobal.value
                            ? "سنک مکمل ہو گیا!"
                            : "Sync complete!"),
                        backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUrduGlobal.value
                            ? "سنک میں خرابی آئی"
                            : "Sync failed"),
                        backgroundColor: Colors.red));
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPeriod,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value ? "دورانیہ (Period)" : "Period",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      DropdownMenuItem(
                          value: 'current_week',
                          child: Text(isUrduGlobal.value ? "رواں ہفتہ (ڈیفالٹ)" : "Current Week (Default)")),
                      DropdownMenuItem(
                          value: 'weekly',
                          child: Text(isUrduGlobal.value ? "ہفتہ وار (آخری 7 دن)" : "Weekly (Last 7 Days)")),
                      DropdownMenuItem(
                          value: 'monthly',
                          child: Text(isUrduGlobal.value ? "ماہانہ (آخری 30 دن)" : "Monthly (Last 30 Days)")),
                      DropdownMenuItem(
                          value: 'quarterly',
                          child: Text(isUrduGlobal.value ? "سہ ماہی (آخری 90 دن)" : "Quarterly (Last 90 Days)")),
                      DropdownMenuItem(
                          value: 'semi_annually',
                          child: Text(isUrduGlobal.value ? "شش ماہی (آخری 180 دن)" : "Semi-Annually (180 Days)")),
                      DropdownMenuItem(
                          value: 'annually',
                          child: Text(isUrduGlobal.value ? "سالانہ (آخری 365 دن)" : "Annually (365 Days)")),
                      DropdownMenuItem(
                          value: 'custom',
                          child: Text(isUrduGlobal.value ? "کسٹم ڈیٹس (Custom)" : "Custom Dates")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedPeriod = v);
                        _updateDatesForPeriod(v);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedStudentId,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value
                            ? "طالب علم منتخب کریں"
                            : "Select Student",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(isUrduGlobal.value
                              ? "-- تمام طلباء (ڈیفالٹ) --"
                              : "-- All Students (Default) --")),
                      ..._students.map((s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child:
                              Text("${s['admission_number'] ?? s['roll_number'] ?? ''} - ${s['name']} (${s['father_name'] ?? ''})")))
                    ],
                    onChanged: (v) {
                      setState(() => selectedStudentId = v);
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "ابتدائی تاریخ"
                                  : "From Date",
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 0)),
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _toDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                              labelText:
                                  isUrduGlobal.value ? "آخری تاریخ" : "To Date",
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 0)),
                          onTap: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._buildGroupedTables(),
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
