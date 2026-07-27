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
import 'filtered_hifz_report.dart';

class ReportsHifzPage extends StatefulWidget {
  final String? className;
  const ReportsHifzPage({super.key, this.className});

  @override
  _ReportsHifzPageState createState() => _ReportsHifzPageState();
}

class _ReportsHifzPageState extends State<ReportsHifzPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);

  List<Map<String, dynamic>> _hifzRecords = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _complaints = [];
  bool isLoading = true;
  String? fromDate;
  String? toDate;
  String? selectedStudentId;
  String selectedPeriod = 'current_week';

  Map<String, dynamic>? _weeklyStats;
  String _aiInsight = "";
  bool _isAILoading = false;

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
        bool isHifz = cName.contains('حفظ') ||
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
      final allHifz = await db.getHifzRecords();
      final allAttendance =
          await db.database.then((d) => d.query('attendance'));

      List<Map<String, dynamic>> filtered = [];

      final settings = await db.getSettings();
      int weekStartDay =
          int.tryParse(settings['week_start_day']?.toString() ?? '6') ?? 6;

      if (fromDate == null || toDate == null) {
        final boundaries =
            PerformanceCalculator.getPeriodBoundaries(selectedPeriod, weekStartDay);
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
          hifzRecords: filtered,
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

      _hifzRecords = filtered;
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
    if (status == 'Excellent') return Colors.green;
    if (status == 'Good') return Colors.blue;
    if (status == 'Weak') return Colors.red;
    if (status == 'Average') return Colors.orange;
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
      double? fontSize,
      Widget? child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor ?? (isHeader ? Colors.grey.shade200 : Colors.white),
        border: Border.all(color: Colors.black87, width: 0.5),
      ),
      alignment: Alignment.center,
      child: child ?? Text(
        text,
        textAlign: TextAlign.center,
        softWrap: true,
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
            _cell(isUrduGlobal.value ? "طالب علم" : "Student", 180,
                isHeader: true),
          _cell(isUrduGlobal.value ? "تاریخ" : "Date", 80, isHeader: true),
          Column(
            children: [
              _cell(isUrduGlobal.value ? "سبق (نیا)" : "Sabaq (New)", 175,
                  isHeader: true,
                  bgColor: Colors.green.withOpacity(0.8),
                  textColor: Colors.white),
              Row(
                children: [
                  _cell("پارہ", 60, isHeader: true),
                  _cell("لائنیں", 60, isHeader: true),
                  _cell("کیفیت", 55, isHeader: true),
                ],
              )
            ],
          ),
          Column(
            children: [
              _cell(
                  isUrduGlobal.value ? "سبقی (پچھلا سبق)" : "Sabqi (Previous)",
                  305,
                  isHeader: true,
                  bgColor: Colors.blue.withOpacity(0.8),
                  textColor: Colors.white),
              Row(
                children: [
                  _cell("تفصیل", 100, isHeader: true),
                  _cell("مقدار", 60, isHeader: true),
                  _cell("کیفیت", 55, isHeader: true),
                  _cell("سننے والا", 90, isHeader: true),
                ],
              )
            ],
          ),
          Column(
            children: [
              _cell(isUrduGlobal.value ? "منزل (پختہ)" : "Manzil", 355,
                  isHeader: true,
                  bgColor: Colors.orange.withOpacity(0.8),
                  textColor: Colors.black),
              Row(
                children: [
                  _cell("تفصیل", 150, isHeader: true),
                  _cell("مقدار", 60, isHeader: true),
                  _cell("کیفیت", 55, isHeader: true),
                  _cell("سننے والا", 90, isHeader: true),
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

  Widget _gradeWithTimeCell(String grade, String? time, double width, {Color? textColor}) {
    if (time == null || time.isEmpty || time == '-' || time == 'null') {
      return _cell(grade, width, textColor: textColor);
    }
    String formattedTime = time;
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        String ampm = h >= 12 ? "PM" : "AM";
        int h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        formattedTime = "${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm";
      }
    } catch (_) {}

    return _cell(
      "",
      width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(grade, style: TextStyle(color: textColor ?? Colors.black, fontSize: 11)),
          const SizedBox(height: 2),
          Text(formattedTime, style: const TextStyle(color: Colors.black54, fontSize: 8), textDirection: TextDirection.ltr),
        ],
      ),
    );
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
            _cell(_getStudentName(h['student_id'].toString()), 180, bold: true),
          _cell(h['date'] ?? '-', 80, bold: true, fontSize: 10),
          _cell(cleanUrduString(h['sabaq_para']), 60),
          _cell(h['sabaq_lines'] ?? '-', 60),
          _gradeWithTimeCell(translateStatusClean(h['sabaq_grade']), h['sabaq_time']?.toString(), 55, textColor: getStatusColor(h['sabaq_grade'])),
          _cell(cleanUrduString(h['sabqi_para']), 100),
          _cell(translateQtyClean(h['sabqi_qty']), 60),
          _gradeWithTimeCell(translateStatusClean(h['sabqi_grade']), h['sabqi_time']?.toString(), 55, textColor: getStatusColor(h['sabqi_grade'])),
          _cell(
              (h['sabqi_listener']?.toString().isEmpty ?? true)
                  ? '-'
                  : h['sabqi_listener'],
              90,
              fontSize: 9),
          _cell(cleanUrduString(h['manzil_details']), 150),
          _cell(translateQtyClean(h['manzil_total_qty']), 60),
          _gradeWithTimeCell(translateStatusClean(h['manzil_grade']), h['manzil_time']?.toString(), 55, textColor: getStatusColor(h['manzil_grade'])),
          _cell(
              (h['manzil_listener']?.toString().isEmpty ?? true)
                  ? '-'
                  : h['manzil_listener'],
              90,
              fontSize: 9),
          _cell(h['daily_complaint'] ?? '-', 150, textColor: Colors.red),

        ],
      ),
    );
  }


  List<Widget> _buildTableRows() {
    List<Widget> rows = [];
    final List<Map<String, dynamic>> combinedRecords = [];
    combinedRecords.addAll(_hifzRecords);
    
    Map<String, int> freqSabaq = {};
    Map<String, int> freqSabqi = {};
    Map<String, int> freqManzil = {};
    
    int dailyMissedSabaq = 0;
    int dailyMissedSabqi = 0;
    int dailyMissedManzil = 0;
    int dailyComplaints = 0;
    String lastDateFormatted = "";

    if (fromDate != null && toDate != null) {
      DateTime sDate = _parseRobust(fromDate!);
      DateTime eDate = _parseRobust(toDate!);
      
      for (DateTime d = sDate; d.isBefore(eDate.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
        String isoDate = intl.DateFormat('yyyy-MM-dd').format(d);
        
        for (var s in _students) {
          if (selectedStudentId != null && s['id'].toString() != selectedStudentId) continue;
          
          String sid = s['id'].toString();
          
          bool hasRecord = combinedRecords.any((r) {
             if (r['student_id'].toString() != sid) return false;
             String rd = r['date'] ?? '';
             return rd.startsWith(isoDate) || _parseRobust(rd).year == d.year && _parseRobust(rd).month == d.month && _parseRobust(rd).day == d.day;
          });
          
          if (!hasRecord) {
             combinedRecords.add({
                'student_id': s['id'],
                'date': isoDate,
                'sabaq_para': '-', 'sabaq_lines': '-', 'sabaq_grade': '-',
                'sabqi_para': '-', 'sabqi_qty': '-', 'sabqi_grade': '-', 'sabqi_listener': '-',
                'manzil_details': '-', 'manzil_total_qty': '-', 'manzil_grade': '-', 'manzil_listener': '-',
             });
          }
        }
      }
    }

    // Sort combined records by date descending, then record presence, then student
    combinedRecords.sort((a, b) {
      DateTime dA = _parseRobust(a['date'] ?? '');
      DateTime dB = _parseRobust(b['date'] ?? '');
      
      int dCmp = dB.compareTo(dA);
      if (dCmp != 0) return dCmp;

      bool aHasRecord = (a['sabaq_grade'] != null && a['sabaq_grade'] != '-') || (a['sabqi_grade'] != null && a['sabqi_grade'] != '-') || (a['manzil_grade'] != null && a['manzil_grade'] != '-');
      bool bHasRecord = (b['sabaq_grade'] != null && b['sabaq_grade'] != '-') || (b['sabqi_grade'] != null && b['sabqi_grade'] != '-') || (b['manzil_grade'] != null && b['manzil_grade'] != '-');

      if (aHasRecord && !bHasRecord) return -1;
      if (!aHasRecord && bHasRecord) return 1;

      return (a['student_id'] ?? 0).toString().compareTo((b['student_id'] ?? 0).toString());
    });

    int srNo = 1;
    DateTime? currentDate;
    Set<String> processedDates = {};

    void addDailySummary() {
      if (lastDateFormatted.isNotEmpty && selectedStudentId == null) {
        final dSabaq = dailyMissedSabaq;
        final dSabqi = dailyMissedSabqi;
        final dManzil = dailyMissedManzil;
        final ldFormatted = lastDateFormatted;
        
        final tSabaq0 = _students.length - dSabaq;
        final tSabqi0 = _students.length - dSabqi;
        final tManzil0 = _students.length - dManzil;

        void nav(String title, String subtitle, String lType, dynamic count) {
            final fRecs = <Map<String, dynamic>>[];
            for(var s in _students) {
                var sid = s['id'].toString();
                bool hasMiss = false;
                var h = combinedRecords.firstWhere(
                  (r) => r['student_id'].toString() == sid && (r['date'] ?? '').contains(ldFormatted.split('-').reversed.join('-')),
                  orElse: () => {}
                );
                if (h.isNotEmpty) {
                    if (lType == 'sabaq') hasMiss = h['sabaq_grade'] == '-' || h['sabaq_grade'] == 'Absent' || h['sabaq_grade'] == 'ناغہ' || (h['sabaq_para']?.toString().trim().isEmpty ?? true) || h['sabaq_para'] == '-';
                    if (lType == 'sabqi') hasMiss = h['sabqi_grade'] == '-' || h['sabqi_grade'] == 'Absent' || h['sabqi_grade'] == 'ناغہ' || (h['sabqi_para']?.toString().trim().isEmpty ?? true) || h['sabqi_para'] == '-';
                    if (lType == 'manzil') hasMiss = h['manzil_grade'] == '-' || h['manzil_grade'] == 'Absent' || h['manzil_grade'] == 'ناغہ' || (h['manzil_details']?.toString().trim().isEmpty ?? true) || h['manzil_details'] == '-';
                } else {
                    hasMiss = true;
                }
                
                if (count == 0 && !hasMiss) {
                    if(h.isEmpty) h = {'student_id': s['id'], 'date': ldFormatted, 'sabaq_grade': '-', 'sabqi_grade': '-', 'manzil_grade': '-'};
                    fRecs.add(h);
                } else if (count == 'any' && hasMiss) {
                    if(h.isEmpty) h = {'student_id': s['id'], 'date': ldFormatted, 'sabaq_grade': '-', 'sabqi_grade': '-', 'manzil_grade': '-'};
                    fRecs.add(h);
                }
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => FilteredHifzReportPage(title: title, subtitle: subtitle, filteredRecords: fRecs, allStudents: _students)));
        }

        Widget clickable(String label, int c, String type, dynamic countVal, {bool isSuccess = false}) {
            return GestureDetector(
                onTap: () => nav(isUrduGlobal.value ? "$label ($ldFormatted)" : "Detailed List", label, type, countVal),
                child: MouseRegion(cursor: SystemMouseCursors.click, child: Text("$label: $c طلبہ", style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: isSuccess ? Colors.green.shade700 : Colors.red, fontSize: 11))),
            );
        }

        rows.add(
          Container(
            width: 950,
            color: Colors.blueGrey.shade50,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(isUrduGlobal.value ? "آج کی سمری ($ldFormatted)" : "Daily Summary ($ldFormatted)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Column(children: [ clickable("سبق ناغہ", dSabaq, 'sabaq', 'any'), clickable("سنانے والے", tSabaq0, 'sabaq', 0, isSuccess: true) ]),
                Column(children: [ clickable("سبقی ناغہ", dSabqi, 'sabqi', 'any'), clickable("سنانے والے", tSabqi0, 'sabqi', 0, isSuccess: true) ]),
                Column(children: [ clickable("منزل ناغہ", dManzil, 'manzil', 'any'), clickable("سنانے والے", tManzil0, 'manzil', 0, isSuccess: true) ]),
                Text(isUrduGlobal.value ? "شکایات: $dailyComplaints" : "Complaints: $dailyComplaints", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          )
        );
      }
      dailyMissedSabaq = 0;
      dailyMissedSabqi = 0;
      dailyMissedManzil = 0;
      dailyComplaints = 0;
    }

    for (var origH in combinedRecords) {
      var h = Map<String, dynamic>.from(origH);
      DateTime dt = _parseRobust(h['date'] ?? '');
      
      if (currentDate == null || dt.year != currentDate.year || dt.month != currentDate.month || dt.day != currentDate.day) {
        if (currentDate != null) addDailySummary();
        currentDate = dt;
        lastDateFormatted = intl.DateFormat('dd-MM-yyyy').format(dt);
        processedDates.add(lastDateFormatted);
        srNo = 1; 
        
        rows.add(
          Container(
            width: selectedStudentId != null ? 830 : 950,
            color: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            child: Text(
              isUrduGlobal.value ? "تاریخ: ${intl.DateFormat('dd-MM-yyyy').format(dt)}" : "Date: ${intl.DateFormat('dd-MM-yyyy').format(dt)}", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
            ),
          )
        );
      }

      String dtStr = h['date']?.toString() ?? '';
      String sid = h['student_id']?.toString() ?? '';
      
      var comps = _complaints.where((c) => c['student_id'].toString() == sid && (c['date'] == dtStr || dtStr.contains(c['date'] ?? ''))).toList();
      if (comps.isNotEmpty) {
        h['daily_complaint'] = comps.map((c) {
            String raw = c['complaint'] ?? '';
            final match = RegExp(r'^\[.*?\]\s*(.*)$', dotAll: true).firstMatch(raw);
            return match != null ? match.group(1) : raw;
        }).join('\n');
      } else {
        h['daily_complaint'] = '-';
      }

      bool missedSabaq = h['sabaq_grade'] == '-' || h['sabaq_grade'] == 'Absent' || h['sabaq_grade'] == 'ناغہ' || (h['sabaq_para']?.toString().trim().isEmpty ?? true) || h['sabaq_para'] == '-';
      bool missedSabqi = h['sabqi_grade'] == '-' || h['sabqi_grade'] == 'Absent' || h['sabqi_grade'] == 'ناغہ' || (h['sabqi_para']?.toString().trim().isEmpty ?? true) || h['sabqi_para'] == '-';
      bool missedManzil = h['manzil_grade'] == '-' || h['manzil_grade'] == 'Absent' || h['manzil_grade'] == 'ناغہ' || (h['manzil_details']?.toString().trim().isEmpty ?? true) || h['manzil_details'] == '-';
      
      if (missedSabaq) { dailyMissedSabaq++; freqSabaq[sid] = (freqSabaq[sid] ?? 0) + 1; }
      if (missedSabqi) { dailyMissedSabqi++; freqSabqi[sid] = (freqSabqi[sid] ?? 0) + 1; }
      if (missedManzil) { dailyMissedManzil++; freqManzil[sid] = (freqManzil[sid] ?? 0) + 1; }
      if (comps.isNotEmpty) { dailyComplaints += comps.length; }

      rows.add(_buildDataRow(h, srNo));
      srNo++;
    }
    
    if (currentDate != null) addDailySummary(); // Add for the last date

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
    
    if (processedDates.length > 1 && selectedStudentId == null) {
        int s0=0, s1=0, s2=0, s3=0, sMore=0;
        int sq0=0, sq1=0, sq2=0, sq3=0, sqMore=0;
        int m0=0, m1=0, m2=0, m3=0, mMore=0;
        
        for (var s in _students) {
            String sid = s['id'].toString();
            int sq = freqSabaq[sid] ?? 0;
            if (sq==0) s0++; else if (sq==1) s1++; else if (sq==2) s2++; else if (sq==3) s3++; else if (sq>3) sMore++;
            int sqi = freqSabqi[sid] ?? 0;
            if (sqi==0) sq0++; else if (sqi==1) sq1++; else if (sqi==2) sq2++; else if (sqi==3) sq3++; else if (sqi>3) sqMore++;
            int mz = freqManzil[sid] ?? 0;
            if (mz==0) m0++; else if (mz==1) m1++; else if (mz==2) m2++; else if (mz==3) m3++; else if (mz>3) mMore++;
        }
        
        Widget clickableCell(String catName, int c, String type, dynamic countVal, {bool isSuccess = false}) {
            return GestureDetector(
                onTap: () {
                    final fRecs = <Map<String, dynamic>>[];
                    for(var s in _students) {
                        String sid = s['id'].toString();
                        int freq = 0;
                        if(type == 'sabaq') freq = freqSabaq[sid] ?? 0;
                        if(type == 'sabqi') freq = freqSabqi[sid] ?? 0;
                        if(type == 'manzil') freq = freqManzil[sid] ?? 0;
                        
                        bool match = false;
                        if (countVal == 'more' && freq > 3) match = true;
                        else if (countVal != 'more' && freq == countVal) match = true;
                        
                        if (match) {
                           // Collect all records for this student in the period
                           var recs = combinedRecords.where((r) => r['student_id'].toString() == sid).toList();
                           if(recs.isEmpty) {
                              fRecs.add({'student_id': s['id'], 'date': 'N/A', 'sabaq_grade': '-', 'sabqi_grade': '-', 'manzil_grade': '-'});
                           } else {
                              fRecs.addAll(recs);
                           }
                        }
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FilteredHifzReportPage(title: catName, subtitle: "کل دورانیہ: $fromDate تا $toDate", filteredRecords: fRecs, allStudents: _students)));
                },
                child: MouseRegion(cursor: SystemMouseCursors.click, child: Padding(padding: const EdgeInsets.all(8.0), child: Text("$c طلبہ", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: isSuccess ? Colors.green.shade700 : Colors.red)))),
            );
        }

        rows.add(const SizedBox(height: 20));
        rows.add(
            Container(
                width: 950,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                    children: [
                        Text(isUrduGlobal.value ? "مجموعی ناغہ جات سمری (Period Missed Lessons Summary)" : "Period Missed Lessons Summary", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        const SizedBox(height: 10),
                        Table(
                            border: TableBorder.all(color: Colors.grey.shade400),
                            children: [
                                TableRow(
                                    decoration: BoxDecoration(color: Colors.grey.shade200),
                                    children: [
                                        _summaryCell("کیٹیگری", isHeader: true),
                                        _summaryCell("سبق کا ناغہ", isHeader: true, textColor: Colors.green),
                                        _summaryCell("سبقی کا ناغہ", isHeader: true, textColor: Colors.blue),
                                        _summaryCell("منزل کا ناغہ", isHeader: true, textColor: Colors.orange.shade800),
                                    ]
                                ),
                                TableRow(decoration: BoxDecoration(color: Colors.green.shade50), children: [ _summaryCell("بِلا ناغہ (0 ناغے)", textColor: Colors.green.shade700), clickableCell("بِلا ناغہ", s0, 'sabaq', 0, isSuccess: true), clickableCell("بِلا ناغہ", sq0, 'sabqi', 0, isSuccess: true), clickableCell("بِلا ناغہ", m0, 'manzil', 0, isSuccess: true) ]),
                                TableRow(children: [ _summaryCell("صرف 1 ناغہ"), clickableCell("صرف 1 ناغہ", s1, 'sabaq', 1), clickableCell("صرف 1 ناغہ", sq1, 'sabqi', 1), clickableCell("صرف 1 ناغہ", m1, 'manzil', 1) ]),
                                TableRow(children: [ _summaryCell("2 ناغے"), clickableCell("2 ناغے", s2, 'sabaq', 2), clickableCell("2 ناغے", sq2, 'sabqi', 2), clickableCell("2 ناغے", m2, 'manzil', 2) ]),
                                TableRow(children: [ _summaryCell("3 ناغے"), clickableCell("3 ناغے", s3, 'sabaq', 3), clickableCell("3 ناغے", sq3, 'sabqi', 3), clickableCell("3 ناغے", m3, 'manzil', 3) ]),
                                TableRow(decoration: BoxDecoration(color: Colors.red.shade50), children: [ _summaryCell("3 سے زیادہ ناغے", textColor: Colors.red), clickableCell("3 سے زیادہ ناغے", sMore, 'sabaq', 'more'), clickableCell("3 سے زیادہ ناغے", sqMore, 'sabqi', 'more'), clickableCell("3 سے زیادہ ناغے", mMore, 'manzil', 'more') ]),
                            ]
                        )
                    ]
                )
            )
        );
    }
    
    return rows;
  }
  
  Widget _summaryCell(String text, {bool isHeader = false, Color? textColor}) {
      return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, color: textColor ?? Colors.black87)),
      );
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
              isUrduGlobal.value ? "حفظ تعلیمی رپورٹ" : "Hifz Detailed Report"),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: _printHifzPdf,
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
                    value: _students
                            .any((s) => s['id'].toString() == selectedStudentId)
                        ? selectedStudentId
                        : null,
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

  Future<void> _printHifzPdf() async {
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
                        pw.Text("حفظ تعلیمی رپورٹ",
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
            // Header Row (Left-To-Right Order!)
            List<pw.Widget> hdr = [
              // Complaints
              _hifzPdfCell("شکایات", 100,
                  style: bold, bgColor: PdfColors.red300),
              // Manzil
              pw.Column(children: [
                _hifzPdfCell("منزل (پختہ)", 210,
                    style: bold, bgColor: PdfColors.orange300),
                pw.Row(children: [
                  _hifzPdfCell("سننے والا", 50,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("کیفیت", 50,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("مقدار", 50,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("تفصیل", 60,
                      style: bold, bgColor: PdfColors.grey200),
                ])
              ]),
              // Sabqi
              pw.Column(children: [
                _hifzPdfCell("سبقی (پچھلا سبق)", 190,
                    style: bold, bgColor: PdfColors.blue300),
                pw.Row(children: [
                  _hifzPdfCell("سننے والا", 50,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("کیفیت", 50,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("مقدار", 50,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("پارہ", 40,
                      style: bold, bgColor: PdfColors.grey200),
                ])
              ]),
              // Sabaq
              pw.Column(children: [
                _hifzPdfCell("سبق (نیا)", 130,
                    style: bold, bgColor: PdfColors.green300),
                pw.Row(children: [
                  _hifzPdfCell("کیفیت", 50,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("لائنیں", 40,
                      style: bold, bgColor: PdfColors.grey200),
                  _hifzPdfCell("پارہ", 40,
                      style: bold, bgColor: PdfColors.grey200),
                ])
              ]),
              _hifzPdfCell("تاریخ", 60,
                  style: bold, bgColor: PdfColors.grey300),
              if (!isIndiv)
                _hifzPdfCell("طالب علم", 90,
                    style: bold, bgColor: PdfColors.grey300),
            ];

            List<pw.Widget> allRows = [
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Row(
                  children: hdr,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                ),
              )
            ];

            Map<int, pw.TableColumnWidth> colWidths = {};
            int colIdx = 0;
            colWidths[colIdx++] = const pw.FixedColumnWidth(100); // Complaints
            // Manzil
            colWidths[colIdx++] = const pw.FixedColumnWidth(50); // Listener
            colWidths[colIdx++] = const pw.FixedColumnWidth(50); // Grade
            colWidths[colIdx++] = const pw.FixedColumnWidth(50); // Qty
            colWidths[colIdx++] = const pw.FixedColumnWidth(60); // Details
            // Sabqi
            colWidths[colIdx++] = const pw.FixedColumnWidth(50); // Listener
            colWidths[colIdx++] = const pw.FixedColumnWidth(50); // Grade
            colWidths[colIdx++] = const pw.FixedColumnWidth(50); // Qty
            colWidths[colIdx++] = const pw.FixedColumnWidth(40); // Para
            // Sabaq
            colWidths[colIdx++] = const pw.FixedColumnWidth(50); // Grade
            colWidths[colIdx++] = const pw.FixedColumnWidth(40); // Lines
            colWidths[colIdx++] = const pw.FixedColumnWidth(40); // Para
            
            colWidths[colIdx++] = const pw.FixedColumnWidth(60); // Date
            if (!isIndiv) colWidths[colIdx++] = const pw.FixedColumnWidth(90); // Student

            List<pw.TableRow> tableRows = [];

            for (var h in _hifzRecords) {
              PdfColor sCol = _getPdfStatusColor(h['sabaq_grade']);
              PdfColor sqCol = _getPdfStatusColor(h['sabqi_grade']);
              PdfColor mCol = _getPdfStatusColor(h['manzil_grade']);

              String dtStr = h['date']?.toString() ?? '';
              String sid = h['student_id']?.toString() ?? '';
              var comps = _complaints.where((c) => c['student_id'].toString() == sid && (c['date'] == dtStr || dtStr.contains(c['date'] ?? ''))).toList();
              String dailyComp = '-';
              if (comps.isNotEmpty) {
                dailyComp = comps.map((c) {
                    String raw = c['complaint'] ?? '';
                    final match = RegExp(r'^\[.*?\]\s*(.*)$', dotAll: true).firstMatch(raw);
                    return match != null ? match.group(1) : raw;
                }).join('\n');
              }

              tableRows.add(pw.TableRow(
                  children: [
                    // Complaints
                    _hifzPdfCell(cleanUrduString(dailyComp), 100),
                    // Manzil
                    _hifzPdfCell(h['manzil_listener']?.toString() ?? '-', 50),
                    _hifzPdfCell(translateStatusClean(h['manzil_grade']), 50, textColor: mCol),
                    _hifzPdfCell(translateQtyClean(h['manzil_total_qty']), 50),
                    _hifzPdfCell(cleanUrduString(h['manzil_details']), 60),
                    // Sabqi
                    _hifzPdfCell(h['sabqi_listener']?.toString() ?? '-', 50),
                    _hifzPdfCell(translateStatusClean(h['sabqi_grade']), 50, textColor: sqCol),
                    _hifzPdfCell(translateQtyClean(h['sabqi_qty']), 50),
                    _hifzPdfCell(cleanUrduString(h['sabqi_para']), 40),
                    // Sabaq
                    _hifzPdfCell(translateStatusClean(h['sabaq_grade']), 50, textColor: sCol),
                    _hifzPdfCell(h['sabaq_lines'] ?? '-', 40),
                    _hifzPdfCell(cleanUrduString(h['sabaq_para']), 40),
                    // Date
                    _hifzPdfCell(h['date'] ?? '-', 60),
                    // Student
                    if (!isIndiv)
                      _hifzPdfCell(_getStudentName(h['student_id'].toString()), 90),
                  ]));
            }

            allRows.add(pw.Table(
              columnWidths: colWidths,
              children: tableRows,
            ));

            return allRows;
          }));

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Hifz_Report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Print Error: $e")));
      }
    }
  }

  pw.Widget _hifzPdfCell(String text, double w,
      {pw.TextStyle? style, PdfColor? bgColor, PdfColor? textColor}) {
    return pw.Container(
      width: w,
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: PdfColors.grey600, width: 0.5)),
      alignment: pw.Alignment.center,
      child: pw.Center(
        child: pw.Text(text,
            textAlign: pw.TextAlign.center,
            style: style?.copyWith(color: textColor) ??
                pw.TextStyle(fontSize: 8, color: textColor)),
      ),
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
