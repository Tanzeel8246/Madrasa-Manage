// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/ai_service.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import '../widgets/neo_box.dart';
import '../utils/performance_helper.dart';
import 'dashboard.dart';

class ReportsNaziraPage extends StatefulWidget {
  final String? className;
  const ReportsNaziraPage({super.key, this.className});

  @override
  _ReportsNaziraPageState createState() => _ReportsNaziraPageState();
}

class _ReportsNaziraPageState extends State<ReportsNaziraPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);

  List<Map<String, dynamic>> _naziraRecords = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _complaints = [];
  bool isLoading = true;
  String? fromDate;
  String? toDate;
  String? selectedStudentId;

  Map<String, dynamic>? _weeklyStats;
  String _aiInsight = "";
  bool _isAILoading = false;

  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();

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
      final Set<String> seenIds = {};
      final List<Map<String, dynamic>> validStudents = [];
      for (var s in allStudents) {
        bool isActive = s['status'] == 'Active' &&
            (s['is_deleted'] == 0 || s['is_deleted'] == null);
        String cName =
            (s['class_name']?.toString() ?? s['class']?.toString() ?? '')
                .toLowerCase();
        bool isHifz = cName.contains('ناظرہ') ||
            cName.contains('حسن صوت') ||
            cName.contains('گردان');

        final idStr = s['id']?.toString();
        if (isActive && isHifz && idStr != null && !seenIds.contains(idStr)) {
          seenIds.add(idStr);
          validStudents.add(s);
        }
      }
      _students = validStudents;
      if (selectedStudentId != null && !seenIds.contains(selectedStudentId)) {
        selectedStudentId = null;
      }
            final allComplaints = await db.getComplaints();
      _complaints = allComplaints;
      final allHifz = await db.getNaziraRecords();
      final allAttendance =
          await db.database.then((d) => d.query('attendance'));

      List<Map<String, dynamic>> filtered = [];

      final settings = await db.getSettings();
      int weekStartDay =
          int.tryParse(settings['week_start_day']?.toString() ?? '6') ?? 6;

      if (fromDate == null || toDate == null) {
        final boundaries =
            PerformanceCalculator.getWeekBoundaries(weekStartDay);
        fromDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['start']!);
        toDate = intl.DateFormat('dd/MM/yyyy').format(boundaries['end']!);
        _fromDateController.text = fromDate!;
        _toDateController.text = toDate!;
      }

      DateTime sDate = _parseRobust(fromDate!);
      DateTime eDate = _parseRobust(toDate!);

      for (var h in allHifz) {
        if (selectedStudentId != null &&
            h['student_id'].toString() != selectedStudentId) {
          continue;
        }

        if (selectedStudentId == null) {
          bool isStudentValid = _students
              .any((s) => s['id'].toString() == h['student_id'].toString());
          if (!isStudentValid) continue;
        }

        try {
          DateTime fDate = _parseRobust(h['date'] ?? '');
          if (fDate.isBefore(sDate) || fDate.isAfter(eDate)) continue;
        } catch (_) {
          continue;
        }
        filtered.add(h);
      }

      if (selectedStudentId != null) {
        _weeklyStats = PerformanceCalculator.calculateWeeklyPerformance(
          hifzRecords: <Map<String, dynamic>>[],
          attendanceRecords: allAttendance
              .where((a) => a['student_id'].toString() == selectedStudentId)
              .toList(),
          weekStartDay: weekStartDay,
        );
        _fetchAIInsight();
      } else {
        _weeklyStats = null;
        _aiInsight = "";
      }

      filtered.sort((a, b) {
        DateTime dA = _parseRobust(a['date'] ?? '');
        DateTime dB = _parseRobust(b['date'] ?? '');
        int cmp = dB.compareTo(dA); // descending (newest first)
        if (cmp != 0) return cmp;
        return (a['student_id'] ?? 0)
            .toString()
            .compareTo((b['student_id'] ?? 0).toString());
      });

      _naziraRecords = filtered;
    } catch (e) {
      debugPrint("Load Hifz Report Error: $e");
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

  Future<void> _fetchAIInsight() async {
    if (_weeklyStats == null) return;
    setState(() => _isAILoading = true);

    final prompt =
        "You are a senior supervisor of a Hifz Madrasa. Analyze this student's stats for the week: Attendance: ${_weeklyStats!['attendancePerc']}%, Academic Score: ${_weeklyStats!['academicScore']}/100. Provide a concise 2-line strategic advice in URDU for the CLASS TEACHER on how to handle this student. Just Urdu text.";

    try {
      final insight = await AIService.generateInsight(prompt);
      if (!mounted) return;
      setState(() {
        _aiInsight = insight;
      });
    } catch (e) {
      debugPrint("AI Error: $e");
      if (mounted) {
        setState(() {
          _aiInsight = isUrduGlobal.value
              ? "Unable to reach AI service"
              : "Unable to reach AI service";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAILoading = false);
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
    if (match.isNotEmpty) {
      final s = match.first;
      return "${s['name']} - ${s['father_name'] ?? ''}";
    }
    return "ID: $sid";
  }

  String translateStatusClean(String? status) {
    if (status == null) return '-';
    if (isUrduGlobal.value) {
      if (status == 'Excellent') return 'ممتاز';
      if (status == 'Good') return 'بہتر';
      if (status == 'Average') return 'معمولی';
      if (status == 'Weak') return 'کمزور';
    } else {
      return status;
    }
    return status;
  }

  Color getStatusColor(String? status) {
    if (status == 'Excellent' || status == 'ممتاز') return Colors.green;
    if (status == 'Good' || status == 'بہتر') return Colors.blue;
    if (status == 'Weak' || status == 'کمزور') return Colors.red;
    if (status == 'Average' || status == 'معمولی') return Colors.orange;
    if (status == 'غير حاضر' || status == 'Absent') return Colors.red.shade900;
    if (status == 'رخصت' || status == 'Leave') return Colors.orange.shade800;
    return Colors.black;
  }

  String translateQtyClean(String? qty) {
    if (qty == null) return '-';
    // Remove redundant fraction labels if present
    String clean = qty
        .replaceAll('(3/4)', '')
        .replaceAll('(1/2)', '')
        .replaceAll('(1/4)', '')
        .replaceAll('(1)', '')
        .trim();

    if (!isUrduGlobal.value) return clean;
    final map = {
      'Quarter': 'پاؤ',
      'Half': 'آدھا',
      'Three Quarter': 'پونا پارہ',
      'Full': 'مکمل',
      '1.5 Parah': 'ڈیڑھ',
      '2 Parah': 'دو',
      '2.5 Parah': 'ڈھائی',
      '3 Parah': 'تین'
    };
    return map[clean] ?? clean;
  }

  Widget _cell(String text, double width,
      {Color? bgColor,
      Color? textColor,
      bool isHeader = false,
      bool bold = false,
      double? fontSize}) {
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
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontWeight: (bold || isHeader) ? FontWeight.bold : FontWeight.normal,
          fontSize: fontSize ?? (isHeader ? 12 : 11),
          color: textColor ?? Colors.black,
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    bool isIndividual = selectedStudentId != null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(isUrduGlobal.value ? "نمبر شمار" : "Sr No", 40, isHeader: true),
          if (!isIndividual)
            _cell(isUrduGlobal.value ? "رول نمبر" : "Roll No", 60, isHeader: true),
          if (!isIndividual)
            _cell(isUrduGlobal.value ? "طالب علم" : "Student", 180, isHeader: true),
          _cell(isUrduGlobal.value ? "تاریخ" : "Date", 80, isHeader: true),
          Column(
            children: [
              _cell(isUrduGlobal.value ? "صبح کا سبق" : "Morning Sabaq", 330,
                  isHeader: true,
                  bgColor: Colors.green.withOpacity(0.8),
                  textColor: Colors.white),
              Row(
                children: [
                  _cell("پارہ/تختی", 110, isHeader: true),
                  _cell("مقدار", 90, isHeader: true),
                  _cell("وقت", 60, isHeader: true),
                  _cell("کیفیت", 70, isHeader: true),
                ],
              )
            ],
          ),
          Column(
            children: [
              _cell(isUrduGlobal.value ? "شام کا سبق" : "Evening Sabaq", 330,
                  isHeader: true,
                  bgColor: Colors.blue.withOpacity(0.8),
                  textColor: Colors.white),
              Row(
                children: [
                  _cell("پارہ/تختی", 110, isHeader: true),
                  _cell("مقدار", 90, isHeader: true),
                  _cell("وقت", 60, isHeader: true),
                  _cell("کیفیت", 70, isHeader: true),
                ],
              )
            ],
          ),
          _cell(isUrduGlobal.value ? "شکایات" : "Complaints", 150, isHeader: true, bgColor: Colors.red.withOpacity(0.8), textColor: Colors.white),
        ],
      ),
    );
  }

  String cleanUrduString(String? text) {
    if (text == null) return '-';
    return text
        .replaceAll('(3/4)', '')
        .replaceAll('(1/2)', '')
        .replaceAll('(1/4)', '')
        .replaceAll('(1)', '')
        .replaceAll('((', '(')
        .replaceAll('))', ')')
        .replaceAll('پارہ ', '')
        .trim();
  }

  Widget _buildDataRow(Map<String, dynamic> h, int srNo) {
    bool isIndividual = selectedStudentId != null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(srNo.toString(), 40, bold: true, bgColor: Colors.grey.shade100),
          if (!isIndividual)
            _cell(_students.firstWhere((s) => s['id'].toString() == h['student_id'].toString(), orElse: () => {'roll_number': '', 'admission_number': ''})['roll_number']?.toString() ?? _students.firstWhere((s) => s['id'].toString() == h['student_id'].toString(), orElse: () => {'roll_number': '', 'admission_number': ''})['admission_number']?.toString() ?? '', 60),
          if (!isIndividual)
            _cell(_getStudentName(h['student_id'].toString()), 180,
                textColor: Colors.black87, bgColor: Colors.white),
          _cell(h['date'] ?? '-', 80, bold: true, fontSize: 10),
          Row(
            children: [
              _cell(h['morning_sabaq'] ?? '-', 110),
              _cell(h['morning_qty'] ?? '-', 90),
              _cell(h['morning_time'] ?? '-', 60),
              _cell(translateStatusClean(h['morning_status']), 70,
                  textColor: getStatusColor(h['morning_status'])),
            ],
          ),
          Row(
            children: [
              _cell(h['evening_sabaq'] ?? '-', 110),
              _cell(h['evening_qty'] ?? '-', 90),
              _cell(h['evening_time'] ?? '-', 60),
              _cell(translateStatusClean(h['evening_status']), 70,
                  textColor: getStatusColor(h['evening_status'])),
            ],
          ),
          _cell(h['daily_complaint'] ?? '-', 150, textColor: Colors.red),
        ],
      ),
    );
  }

  List<Widget> _buildTableRows() {
    List<Widget> rows = [];
    final List<Map<String, dynamic>> combinedRecords = [];
    combinedRecords.addAll(_naziraRecords);

    // Identify standalone complaints within date range
    if (fromDate != null && toDate != null) {
      DateTime sDate = _parseRobust(fromDate!);
      DateTime eDate = _parseRobust(toDate!);
      for (var c in _complaints) {
        String sid = c['student_id'].toString();
        if (selectedStudentId != null && sid != selectedStudentId) continue;
        if (selectedStudentId == null && !_students.any((s) => s['id'].toString() == sid)) continue;
        
        DateTime? cDate;
        try { cDate = _parseRobust(c['date'] ?? ''); } catch (_) {}
        if (cDate != null && (cDate.isBefore(sDate) || cDate.isAfter(eDate))) continue;
        
        String dt = c['date'] ?? '';
        bool hasHifz = combinedRecords.any((h) => h['student_id'].toString() == sid && h['date'] == dt);
        if (!hasHifz) {
          combinedRecords.add({
            'student_id': sid,
            'date': dt,
            'morning_sabaq': '-', 'morning_status': '-',
            'evening_sabaq': '-', 'evening_status': '-',
          });
        }
      }
    }

    final studentsWithRecords = combinedRecords.map((r) => r['student_id'].toString()).toSet();
    final lazyStudents = _students.where((s) {
      if (selectedStudentId != null && s['id'].toString() != selectedStudentId) return false;
      return !studentsWithRecords.contains(s['id'].toString());
    }).toList();

    for (var s in lazyStudents) {
      combinedRecords.add({
        'student_id': s['id'], 'date': '-',
        'morning_sabaq': '-', 'morning_status': '-',
        'evening_sabaq': '-', 'evening_status': '-',
      });
    }

    // Sort combined records by student first, then date descending
    combinedRecords.sort((a, b) {
      int sCmp = (a['student_id'] ?? 0).toString().compareTo((b['student_id'] ?? 0).toString());
      if (sCmp != 0) return sCmp;

      DateTime dA = _parseRobust(a['date'] ?? '');
      DateTime dB = _parseRobust(b['date'] ?? '');
      return dB.compareTo(dA); // descending
    });

    int srNo = 1;
    for (var origH in combinedRecords) {
      var h = Map<String, dynamic>.from(origH);
      String dt = h['date']?.toString() ?? '';
      String sid = h['student_id']?.toString() ?? '';
      if (dt != '-') {
        var comps = _complaints.where((c) => c['student_id'].toString() == sid && (c['date'] == dt || dt.contains(c['date'] ?? ''))).toList();
        if (comps.isNotEmpty) {
          h['daily_complaint'] = comps.map((c) {
             String raw = c['complaint'] ?? '';
             final match = RegExp(r'^\[.*?\]\s*(.*)$', dotAll: true).firstMatch(raw);
             return match != null ? match.group(1) : raw;
          }).join('\n');
        } else {
          h['daily_complaint'] = '-';
        }
      } else {
        h['daily_complaint'] = '-';
      }
      rows.add(_buildDataRow(h, srNo));
      srNo++;
    }

    if (rows.isEmpty) {
      bool isIndividual = selectedStudentId != null;
      double width = isIndividual ? 830 : 950;
      rows.add(Container(
        width: width,
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: Colors.black87, width: 0.5)),
        child: Text(isUrduGlobal.value ? "کوئی ریکارڈ نہیں ملا" : "No record found", style: const TextStyle(color: Colors.red)),
      ));
    }
    return rows;
  }
  Widget _buildSmartPerformance() {
    if (_weeklyStats == null) return const SizedBox();
    final academic = _weeklyStats!['academicScore'];
    final att = _weeklyStats!['attendancePerc'];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: NeoBox(
        child: Column(
          children: [
            Text(
                isUrduGlobal.value
                    ? "ہفتہ وار اسمارٹ تجزیہ"
                    : "Weekly Smart Analysis",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGauge(isUrduGlobal.value ? "حاضری" : "Att.",
                    att.toDouble(), Colors.blue),
                _buildGauge(isUrduGlobal.value ? "تعلیمی" : "Acad.",
                    academic.toDouble(), Colors.green),
              ],
            ),
            if (_aiInsight.isNotEmpty || _isAILoading) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                            isUrduGlobal.value
                                ? "اے آئی ریمارکس (برائے استاد)"
                                : "AI Remarks (for Teacher)",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    _isAILoading
                        ? const Center(
                            child:
                                LinearProgressIndicator(color: Colors.white24))
                        : Text(_aiInsight,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGauge(String label, double value, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                  value: value / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: color),
            ),
            Text("${value.round()}%",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
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
              isUrduGlobal.value ? "ناظرہ رپورٹس" : "Nazira Detailed Report"),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: _printNaziraPdf,
              tooltip: isUrduGlobal.value ? "پرنٹ PDF" : "Print PDF",
            ),
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
                    value: _students
                            .any((s) => s['id'].toString() == selectedStudentId)
                        ? selectedStudentId
                        : null,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value
                            ? "طالب علم منتخب کریں"
                            : "Select Student",
                        border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(isUrduGlobal.value
                              ? "تمام طلباء"
                              : "All Students")),
                      ..._students.map((s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child:
                              Text("${s['name']} - ${s['father_name'] ?? ''}")))
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
                      child: Column(
                        children: [
                          _buildSmartPerformance(),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTableHeader(),
                                  ..._buildTableRows(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printNaziraPdf() async {
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
      final fallbackData =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      
      final ttf = pw.Font.ttf(fontData);
      final fallbackTtf = pw.Font.ttf(fallbackData);
      
      final bold = pw.TextStyle(font: ttf, fontFallback: [fallbackTtf], fontWeight: pw.FontWeight.bold);
      final normal = pw.TextStyle(font: ttf, fontFallback: [fallbackTtf]);

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(15),
          theme: pw.ThemeData.withFont(
            base: ttf,
            fontFallback: [fallbackTtf],
          ),
          header: (ctx) => pw.Column(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom:
                              pw.BorderSide(color: PdfColors.black, width: 2))),
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("مدرسہ اشرف المدارس — فاروقہ، سرگودھا",
                            style: bold.copyWith(fontSize: 12)),
                        pw.Text("ناظرہ رپورٹس",
                            style: bold.copyWith(fontSize: 14)),
                        pw.Text("مدت: $fromDate تا $toDate",
                            style: normal.copyWith(fontSize: 9)),
                      ]),
                ),
                pw.SizedBox(height: 5),
                if (selectedStudentId != null)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(5),
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    child: pw.Row(children: [
                      pw.Text("طالب علم: ", style: bold.copyWith(fontSize: 10)),
                      pw.Text(_getStudentName(selectedStudentId!),
                          style: normal.copyWith(fontSize: 10)),
                    ]),
                  ),
                pw.SizedBox(height: 5),
              ]),
          build: (pw.Context context) {
            bool isIndiv = selectedStudentId != null;
            // Header Row
            List<pw.Widget> hdr = [
              if (!isIndiv)
                _naziraPdfCell("طالب علم", 90,
                    style: bold, bgColor: PdfColors.grey300),
              _naziraPdfCell("تاریخ", 60,
                  style: bold, bgColor: PdfColors.grey300),
              // Morning
              pw.Column(children: [
                _naziraPdfCell("صبح کا سبق", 265,
                    style: bold, bgColor: PdfColors.green300),
                pw.Row(children: [
                  _naziraPdfCell("تفصیل", 215,
                      style: bold, bgColor: PdfColors.grey200),
                  _naziraPdfCell("کیفیت", 50,
                      style: bold, bgColor: PdfColors.grey200),
                ])
              ]),
              // Evening
              pw.Column(children: [
                _naziraPdfCell("شام کا سبق", 265,
                    style: bold, bgColor: PdfColors.blue300),
                pw.Row(children: [
                  _naziraPdfCell("تفصیل", 215,
                      style: bold, bgColor: PdfColors.grey200),
                  _naziraPdfCell("کیفیت", 50,
                      style: bold, bgColor: PdfColors.grey200),
                ])
              ]),
            ];

            List<pw.Widget> allRows = [
              pw.Row(
                  children: hdr,
                  crossAxisAlignment: pw.CrossAxisAlignment.start)
            ];

            for (var h in _naziraRecords) {
              PdfColor mCol = _getPdfStatusColor(h['morning_status']);
              PdfColor eCol = _getPdfStatusColor(h['evening_status']);

              allRows.add(pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (!isIndiv)
                      _naziraPdfCell(
                          _getStudentName(h['student_id'].toString()), 90),
                    _naziraPdfCell(h['date'] ?? '-', 60),
                    // Morning
                    _naziraPdfCell(h['morning_sabaq'] ?? '-', 215),
                    _naziraPdfCell(translateStatusClean(h['morning_status']), 50,
                        textColor: mCol),
                    // Evening
                    _naziraPdfCell(h['evening_sabaq'] ?? '-', 215),
                    _naziraPdfCell(translateStatusClean(h['evening_status']), 50,
                        textColor: eCol),
                  ]));
            }

            return allRows;
          }));

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Nazira_Report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Print Error: $e")));
      }
    }
  }

  pw.Widget _naziraPdfCell(String text, double w,
      {pw.TextStyle? style, PdfColor? bgColor, PdfColor? textColor}) {
    return pw.Container(
      width: w,
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: PdfColors.grey600, width: 0.5)),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: style?.copyWith(color: textColor) ??
              pw.TextStyle(fontSize: 8, color: textColor)),
    );
  }

  PdfColor _getPdfStatusColor(String? status) {
    if (status == 'Excellent') return PdfColors.green800;
    if (status == 'Good') return PdfColors.blue800;
    if (status == 'Weak') return PdfColors.red800;
    if (status == 'Average') return PdfColors.orange800;
    return PdfColors.black;
  }
}
