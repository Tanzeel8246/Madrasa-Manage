import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';

class SystemTypeGlobal {
  static final ValueNotifier<String> currentSystemType = ValueNotifier('Madrasa');
}

class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key});

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color bgColor = const Color(0xFFF1EFE7);

  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime(DateTime.now().year, 12, 31);

  bool _isLoading = true;

  int _totalStudents = 0;
  int _totalTeachers = 0;
  double _avgAttendance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _netSavings = 0.0;
  int _totalHifzRecords = 0;
  int _totalQaidaRecords = 0;

  List<Map<String, dynamic>> _monthlyBreakdown = [];

  @override
  void initState() {
    super.initState();
    _loadAnnualData();
  }

  Future<void> _loadAnnualData() async {
    setState(() => _isLoading = true);
    try {
      final db = DBHelper();
      final database = await db.database;
      final startStr = intl.DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = intl.DateFormat('yyyy-MM-dd').format(_endDate);
      final isMasjid = SystemTypeGlobal.currentSystemType.value == 'Masjid';
      final sysCond = isMasjid ? "system_type = 'Masjid'" : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";

      // 1. Students & Teachers
      List<Map<String, dynamic>> students = [];
      List<Map<String, dynamic>> teachers = [];
      try {
        students = isMasjid
            ? await database.rawQuery("SELECT * FROM students WHERE $sysCond AND (is_deleted = 0 OR is_deleted IS NULL) UNION SELECT * FROM maktab_students WHERE (is_deleted = 0 OR is_deleted IS NULL)")
            : await database.rawQuery("SELECT * FROM students WHERE $sysCond AND (is_deleted = 0 OR is_deleted IS NULL)");
        teachers = isMasjid
            ? await database.rawQuery("SELECT * FROM teachers WHERE $sysCond AND (is_deleted = 0 OR is_deleted IS NULL) UNION SELECT * FROM maktab_teachers WHERE (is_deleted = 0 OR is_deleted IS NULL)")
            : await database.rawQuery("SELECT * FROM teachers WHERE $sysCond AND (is_deleted = 0 OR is_deleted IS NULL)");
      } catch (_) {
        students = await db.getStudents();
        teachers = await db.getTeachers();
      }
      _totalStudents = students.length;
      _totalTeachers = teachers.length;

      // 2. Attendance
      try {
        final attRows = await database.rawQuery('''
          SELECT status_1, status, date 
          FROM attendance 
          WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond
          UNION ALL
          SELECT '' as status_1, status, date 
          FROM maktab_attendance 
          WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL)
        ''', [startStr, endStr, startStr, endStr]);

        if (attRows.isNotEmpty) {
          int present = 0;
          for (var r in attRows) {
            final st = (r['status_1'] ?? r['status'] ?? '').toString().toUpperCase().trim();
            if (st == 'P' || st == 'PRESENT' || st == 'حاضر') present++;
          }
          _avgAttendance = (present / attRows.length) * 100;
        } else {
          _avgAttendance = 0.0;
        }
      } catch (_) {
        _avgAttendance = 0.0;
      }

      // 3. Finance
      double inc = 0.0;
      double exp = 0.0;
      final Map<String, Map<String, double>> monthlyMap = {};

      try {
        final financeRows = isMasjid
            ? await database.rawQuery('''
                SELECT type, amount, date FROM masjid_finance 
                WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL)
                UNION ALL
                SELECT type, amount, date FROM finance 
                WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond
              ''', [startStr, endStr, startStr, endStr])
            : await database.rawQuery('''
                SELECT type, amount, date FROM finance 
                WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond
              ''', [startStr, endStr]);

        for (var f in financeRows) {
          final amt = double.tryParse(f['amount']?.toString() ?? '0') ?? 0.0;
          final type = (f['type'] ?? '').toString().toLowerCase();
          final d = (f['date'] ?? '').toString();
          final ym = d.length >= 7 ? d.substring(0, 7) : '';

          if (ym.isNotEmpty) {
            monthlyMap.putIfAbsent(ym, () => {'income': 0.0, 'expense': 0.0});
          }

          if (type == 'income' || type == 'آمدن') {
            inc += amt;
            if (ym.isNotEmpty) monthlyMap[ym]!['income'] = (monthlyMap[ym]!['income'] ?? 0.0) + amt;
          } else if (type == 'expense' || type == 'خرچ' || type == 'اخراجات') {
            exp += amt;
            if (ym.isNotEmpty) monthlyMap[ym]!['expense'] = (monthlyMap[ym]!['expense'] ?? 0.0) + amt;
          }
        }
      } catch (e) {
        debugPrint("Finance rawQuery error: $e");
      }

      // Add fee submissions to income
      try {
        final feeRows = await database.rawQuery(
          "SELECT amount, status, submission_date FROM fee_submissions WHERE (submission_date >= ? AND submission_date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL)",
          [startStr, endStr],
        );
        for (var f in feeRows) {
          final st = (f['status'] ?? '').toString().toLowerCase();
          if (st == 'approved' || st == 'paid' || st == 'ادا شدہ' || st.isEmpty) {
            final amt = double.tryParse(f['amount']?.toString() ?? '0') ?? 0.0;
            inc += amt;
            final d = (f['submission_date'] ?? '').toString();
            final ym = d.length >= 7 ? d.substring(0, 7) : '';
            if (ym.isNotEmpty) {
              monthlyMap.putIfAbsent(ym, () => {'income': 0.0, 'expense': 0.0});
              monthlyMap[ym]!['income'] = (monthlyMap[ym]!['income'] ?? 0.0) + amt;
            }
          }
        }
      } catch (_) {}

      _totalIncome = inc;
      _totalExpense = exp;
      _netSavings = inc - exp;

      final sortedYm = monthlyMap.keys.toList()..sort();
      _monthlyBreakdown = sortedYm.map((ym) {
        return {
          'month': ym,
          'income': monthlyMap[ym]!['income'] ?? 0.0,
          'expense': monthlyMap[ym]!['expense'] ?? 0.0,
          'savings': (monthlyMap[ym]!['income'] ?? 0.0) - (monthlyMap[ym]!['expense'] ?? 0.0),
        };
      }).toList();

      // 4. Hifz Records (check both hifz_record and daily_hifz)
      int hCnt = 0;
      try {
        final hifz1 = await database.rawQuery(
          "SELECT COUNT(*) as cnt FROM hifz_record WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL)",
          [startStr, endStr],
        );
        hCnt += Sqflite.firstIntValue(hifz1) ?? 0;
      } catch (_) {}
      try {
        final hifz2 = await database.rawQuery(
          "SELECT COUNT(*) as cnt FROM daily_hifz WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL)",
          [startStr, endStr],
        );
        hCnt += Sqflite.firstIntValue(hifz2) ?? 0;
      } catch (_) {}
      _totalHifzRecords = hCnt;

      // 5. Qaida Records (check qaida_records and qaida_progress)
      int qCnt = 0;
      try {
        final q1 = await database.rawQuery(
          "SELECT COUNT(*) as cnt FROM qaida_records WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL)",
          [startStr, endStr],
        );
        qCnt += Sqflite.firstIntValue(q1) ?? 0;
      } catch (_) {}
      try {
        final q2 = await database.rawQuery(
          "SELECT COUNT(*) as cnt FROM qaida_progress WHERE (date >= ? AND date <= ?) AND (is_deleted = 0 OR is_deleted IS NULL)",
          [startStr, endStr],
        );
        qCnt += Sqflite.firstIntValue(q2) ?? 0;
      } catch (_) {}
      _totalQaidaRecords = qCnt;
    } catch (e) {
      debugPrint("Annual Report Load Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAnnualData();
    }
  }

  Future<void> _generateAndPrintPdf() async {
    final pdf = pw.Document();
    final startStr = intl.DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = intl.DateFormat('yyyy-MM-dd').format(_endDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Madrasa Ashraf-ul-Madaris Farooka',
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Annual Report',
                          style: pw.TextStyle(
                              fontSize: 16, color: PdfColors.green800)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Period: $startStr to $endStr',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.Divider(),
                pw.SizedBox(height: 15),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Metric',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Value',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    _buildPdfRow('Total Active Students', '$_totalStudents'),
                    _buildPdfRow('Total Teachers', '$_totalTeachers'),
                    _buildPdfRow('Average Attendance', '${_avgAttendance.toStringAsFixed(1)}%'),
                    _buildPdfRow('Total Revenue / Income', 'Rs. ${_totalIncome.toStringAsFixed(0)}'),
                    _buildPdfRow('Total Expenditure', 'Rs. ${_totalExpense.toStringAsFixed(0)}'),
                    _buildPdfRow(_netSavings >= 0 ? 'Net Savings / Balance' : 'Deficit / Loss', 'Rs. ${_netSavings.abs().toStringAsFixed(0)}'),
                    _buildPdfRow('Hifz Activity Records', '$_totalHifzRecords entries'),
                    _buildPdfRow('Qaida / Nazira Records', '$_totalQaidaRecords entries'),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Principal Signature: __________________'),
                    pw.Text('Date: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Annual_Report_${intl.DateFormat('yyyy').format(_startDate)}.pdf',
    );
  }

  pw.TableRow _buildPdfRow(String key, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(key)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ],
    );
  }

  void _shareAnnualSummaryWhatsApp() {
    final startStr = intl.DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = intl.DateFormat('yyyy-MM-dd').format(_endDate);

    final buffer = StringBuffer();
    buffer.writeln('📋 *سالانہ رپورٹ - مدرسہ اشرف المدارس فروکہ*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📅 *دورانیہ:* $startStr تا $endStr');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👥 *کل طلبہ:* $_totalStudents');
    buffer.writeln('👨‍🏫 *کل اساتذہ:* $_totalTeachers');
    buffer.writeln('📊 *اوسط حاضری:* ${_avgAttendance.toStringAsFixed(1)}%');
    buffer.writeln('💰 *کل آمدن:* ${_totalIncome.toStringAsFixed(0)} روپے');
    buffer.writeln('💸 *کل اخراجات:* ${_totalExpense.toStringAsFixed(0)} روپے');
    buffer.writeln('💵 *خالص بچت:* ${_netSavings.toStringAsFixed(0)} روپے');
    buffer.writeln('📖 *حفظ اندراجات:* $_totalHifzRecords');
    buffer.writeln('📚 *قاعدہ/ناظرہ اندراجات:* $_totalQaidaRecords');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('_اشرف المدارس مینجمنٹ سسٹم_');

    Share.share(buffer.toString(), subject: 'سالانہ رپورٹ');
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = isUrduGlobal.value;
    final startStr = intl.DateFormat('dd MMM yyyy').format(_startDate);
    final endStr = intl.DateFormat('dd MMM yyyy').format(_endDate);

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isUrdu ? 'سالانہ جامع رپورٹ' : 'Annual Comprehensive Report',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: isUrdu ? 'WhatsApp شیئر' : 'Share WhatsApp',
            onPressed: _shareAnnualSummaryWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: isUrdu ? 'PDF پرنٹ' : 'Print PDF',
            onPressed: _generateAndPrintPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Date Filter Selector Card
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isUrdu ? 'منتخب دورانیہ:' : 'Selected Period:',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Text('$startStr - $endStr',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: Text(isUrdu ? 'تاریخ بدلیں' : 'Change Dates'),
                            onPressed: _selectDateRange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu ? 'کل طلبہ' : 'Students',
                          '$_totalStudents',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu ? 'کل اساتذہ' : 'Teachers',
                          '$_totalTeachers',
                          Icons.school,
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu ? 'اوسط حاضری' : 'Avg Attendance',
                          '${_avgAttendance.toStringAsFixed(1)}%',
                          Icons.how_to_reg,
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu
                              ? (_netSavings >= 0 ? 'خالص بچت' : 'خالص خسارہ')
                              : (_netSavings >= 0 ? 'Net Savings' : 'Deficit'),
                          'Rs. ${_netSavings.abs().toStringAsFixed(0)}',
                          _netSavings >= 0 ? Icons.savings : Icons.trending_down,
                          _netSavings >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu ? 'کل آمدن' : 'Total Income',
                          '${_totalIncome.toStringAsFixed(0)} Rs',
                          Icons.arrow_downward,
                          Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu ? 'کل اخراجات' : 'Total Expense',
                          '${_totalExpense.toStringAsFixed(0)} Rs',
                          Icons.arrow_upward,
                          Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu ? 'حفظ ریکارڈز' : 'Hifz Entries',
                          '$_totalHifzRecords',
                          Icons.menu_book,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          isUrdu ? 'قاعدہ ریکارڈز' : 'Qaida Entries',
                          '$_totalQaidaRecords',
                          Icons.auto_stories,
                          Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Monthly Breakdown Section
                  if (_monthlyBreakdown.isNotEmpty) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.table_chart, color: primaryGreen, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isUrdu ? 'ماہانہ مالیاتی گوشوارہ' : 'Monthly Financial Breakdown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(2.5),
                                2: FlexColumnWidth(2.5),
                                3: FlexColumnWidth(2.5),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade200),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: Text(
                                        isUrdu ? 'مہینہ' : 'Month',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: Text(
                                        isUrdu ? 'آمدن (Rs)' : 'Income',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green.shade800),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: Text(
                                        isUrdu ? 'خرچ (Rs)' : 'Expense',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red.shade800),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: Text(
                                        isUrdu ? 'بچت (Rs)' : 'Savings',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                ..._monthlyBreakdown.map((m) {
                                  final double sav = (m['savings'] as num?)?.toDouble() ?? 0.0;
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        child: Text(
                                          m['month']?.toString() ?? '',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        child: Text(
                                          (m['income'] as num?)?.toStringAsFixed(0) ?? '0',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        child: Text(
                                          (m['expense'] as num?)?.toStringAsFixed(0) ?? '0',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        child: Text(
                                          sav.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: sav >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print),
                      label: Text(
                        isUrdu ? 'رپورٹ پرنٹ یا PDF بنائیں' : 'Print or Save PDF',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: _generateAndPrintPdf,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(value,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}
