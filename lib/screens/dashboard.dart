// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../db_helper.dart';
import '../utils/system_type_global.dart';
import '../utils/globals.dart';
import '../utils/sync_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/neo_box.dart';
import 'academic_entry_dashboard.dart';
import 'apply_leave.dart';
import 'attendance.dart';
import 'classes.dart';
import 'complaints.dart';
import 'exams.dart';
import 'manage_users.dart';
import 'notices.dart';
import 'pay_fee.dart';
import 'requests.dart';
import 'settings.dart';
import 'simple_finance.dart';
import 'student_report.dart';
import 'students.dart';
import 'teachers.dart';
import 'masjid_assets.dart';
import 'masjid_itikaf.dart';
import 'academic_view_dashboard.dart';
import 'reports_attendance.dart';
import 'in_kind_donations.dart';


class DashboardPage extends StatefulWidget {
  final bool autoSync;
  const DashboardPage({super.key, this.autoSync = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardCard {
  const _DashboardCard({
    required this.permission,
    required this.urTitle,
    required this.enTitle,
    required this.icon,
    required this.page,
    this.value = '',
  });

  final String permission;
  final String urTitle;
  final String enTitle;
  final IconData icon;
  final Widget page;
  final String value;
}

class _DashboardPageState extends State<DashboardPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color textDark = const Color(0xFF2D2D2D);

  String _userName = '';
  int studentsCount = 0;
  int teachersCount = 0;
  int todayAttendanceCount = 0;
  String todayAttendanceSummary = '';
  double monthlyAttendancePercent = 0.0;
  int alumniCount = 0;
  int noticesCount = 0;
  int classesCount = 0;
  double monthlyExpenses = 0.0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadRealData();
    if (widget.autoSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runLiveTwoWaySync());
    }
  }

  bool _hasPerm(String permission) {
    if (currentUserRole.value == 'admin') return true;
    if (permission.contains('|')) {
      return permission.split('|').any((p) => currentUserPermissions.value.contains(p));
    }
    return currentUserPermissions.value.contains(permission);
  }

  bool get _isStaff =>
      ['admin', 'nazim', 'teacher'].contains(currentUserRole.value);
  bool get _isParent => currentUserRole.value == 'parent';

  Future<void> _runLiveTwoWaySync() async {
    if (_isSyncing || !mounted) return;
    setState(() => _isSyncing = true);
    try {
      await SyncService.runTwoWaySync();
      await _loadRealData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrduGlobal.value
                ? 'ڈیٹا کامیابی سے سنک ہو گیا'
                : 'Data synced successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrduGlobal.value ? 'سنک مکمل نہیں ہو سکا' : 'Sync failed: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadRealData() async {
    final db = DBHelper();
    final database = await db.database;

    final sysVal = SystemTypeGlobal.currentSystemType.value;
    final sysCond = sysVal == 'Madrasa'
        ? "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')"
        : "system_type = 'Masjid'";

    // 1. Get counts directly using SQL COUNT
    final activeStudentsCountRes = await database.rawQuery(
        "SELECT COUNT(*) as count FROM students WHERE LOWER(TRIM(status)) IN ('active', 'present', '') AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond");
    final activeStudentsCount =
        (activeStudentsCountRes.first['count'] as num?)?.toInt() ?? 0;

    final alumniCountRes = await database.rawQuery(
        "SELECT COUNT(*) as count FROM students WHERE LOWER(TRIM(status)) IN ('alumni', 'graduated') AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond");
    final activeAlumniCount =
        (alumniCountRes.first['count'] as num?)?.toInt() ?? 0;

    final activeTeachersCountRes = await database.rawQuery(
        "SELECT COUNT(*) as count FROM teachers WHERE (LOWER(status) IN ('active', '') OR status IS NULL) AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond");
    final activeTeachersCount =
        (activeTeachersCountRes.first['count'] as num?)?.toInt() ?? 0;

    final noticesCountRes = await database.rawQuery(
        "SELECT COUNT(*) as count FROM notices WHERE (is_deleted = 0 OR is_deleted IS NULL)");
    final activeNoticesCount =
        (noticesCountRes.first['count'] as num?)?.toInt() ?? 0;

    final classesCountRes = await database.rawQuery(
        "SELECT COUNT(*) as count FROM classes WHERE (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond");
    final activeClassesCount =
        (classesCountRes.first['count'] as num?)?.toInt() ?? 0;

    // 2. Query monthly expenses directly using SQL SUM
    final now = DateTime.now();
    final currentYearMonth =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final monthlyExpensesRes = await database.rawQuery(
        "SELECT SUM(amount) as sum FROM finance WHERE LOWER(TRIM(type)) = 'expense' AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond AND date LIKE ?",
        ['$currentYearMonth%']);
    final monthlyExp =
        (monthlyExpensesRes.first['sum'] as num?)?.toDouble() ?? 0.0;

    // 3. Query today's attendance directly from DB
    final todayStr = intl.DateFormat('yyyy-MM-dd').format(now);
    final todayAtts = await database.rawQuery(
        "SELECT status, delay_minutes FROM attendance WHERE date = ? AND (is_deleted = 0 OR is_deleted IS NULL)",
        [todayStr]);

    var todayPresent = 0;
    var todayAbsent = 0;
    var todayLeave = 0;
    var todayLate = 0;
    var todayTotal = 0;
    for (final a in todayAtts) {
      final s = (a['status'] ?? '').toString().toUpperCase();
      if (s.isEmpty) continue;
      todayTotal++;
      final delayStr = (a['delay_minutes'] ?? '').toString();
      final delay = int.tryParse(delayStr) ?? 0;
      
      if (delay > 0 || s == 'LATE') {
        todayLate++;
      } else if (s == 'A' || s.contains('ABSENT') || s.contains('غائب') || s.contains('غیر حاضر')) {
        todayAbsent++;
      } else if (s == 'L' || s.contains('LEAVE') || s.contains('R') || s.contains('رخصت')) {
        todayLeave++;
      } else if (s == 'P' || s.contains('PRESENT') || s.contains('حاضر')) {
        todayPresent++;
      }
    }
    String pct(int value) {
      if (todayTotal == 0) return '0%';
      return '%';
    }

    final todaySummary = isUrduGlobal.value
        ? 'حاضر:  | غیر: \nرخصت:  | تاخیر: '
        : 'P:  | A: \nL:  | Late: ';

    final monthlyAtts = await database.rawQuery(
        "SELECT status FROM attendance WHERE date LIKE ? AND (is_deleted = 0 OR is_deleted IS NULL)",
        ['$currentYearMonth%']);
    
    var mTotal = 0;
    var mPresent = 0;
    for (final a in monthlyAtts) {
      final s = (a['status'] ?? '').toString().toUpperCase();
      if (s.isEmpty) continue;
      mTotal++;
      if (s == 'P' || s.contains('حاضر')) mPresent++;
    }
    
    final monthlyAttPct = mTotal > 0 ? (mPresent / mTotal) * 100 : 0.0;
    double monthlyPercent = monthlyAttPct;

    // 5. Query user name if student
    String userName =
        isUrduGlobal.value ? 'مدرسہ اشرف المدارس' : 'Madrasa Ashraf-ul-Madaris';

    if (currentUserRole.value == 'student' && currentUserId.value != null) {
      final studentRes = await database.rawQuery(
          "SELECT name FROM students WHERE id = ? AND $sysCond LIMIT 1",
          [currentUserId.value.toString()]);
      if (studentRes.isNotEmpty) {
        userName = studentRes.first['name']?.toString() ?? userName;
      }
    } else if (currentUserRole.value == 'admin') {
      userName = isUrduGlobal.value ? 'مدرسہ اشرف المدارس' : 'Administrator';
    } else if (currentUserRole.value == 'parent') {
      userName = isUrduGlobal.value ? 'والدین ڈیش بورڈ' : 'Parent Dashboard';
    }

    if (!mounted) return;

    // For parents, load children from DB
    List<Map<String, dynamic>> parentChildrenList = [];
    if (currentUserRole.value == 'parent') {
      parentChildrenList = await database.query('students',
          where: '$sysCond AND (is_deleted = 0 OR is_deleted IS NULL)');
    }

    setState(() {
      studentsCount = activeStudentsCount;
      teachersCount = activeTeachersCount;
      alumniCount = activeAlumniCount;
      noticesCount = activeNoticesCount;
      classesCount = activeClassesCount;
      todayAttendanceCount = todayAtts.length;
      todayAttendanceSummary = todaySummary;
      monthlyAttendancePercent = monthlyPercent;
      monthlyExpenses = monthlyExp;
      _userName = userName;
      _parentChildren = parentChildrenList;
    });
  }

  List<Map<String, dynamic>> _parentChildren = [];
  List<_DashboardCard> _staffCards() {
    final isMasjid = SystemTypeGlobal.currentSystemType.value == 'Masjid';
    List<_DashboardCard> cards;

    if (isMasjid) {
      cards = <_DashboardCard>[
        _DashboardCard(
          permission: 'manage_students',
          urTitle: 'مکتب طلباء',
          enTitle: 'Maktab Students',
          value: studentsCount.toString(),
          icon: Icons.school,
          page: const StudentsPage(),
        ),
        _DashboardCard(
          permission: 'manage_teachers',
          urTitle: 'مکتب اساتذہ',
          enTitle: 'Maktab Teachers',
          value: teachersCount.toString(),
          icon: Icons.people,
          page: const TeachersPage(),
        ),
        _DashboardCard(
          permission: 'manage_classes',
          urTitle: 'مکتب کلاسز',
          enTitle: 'Maktab Classes',
          value: classesCount.toString(),
          icon: Icons.class_,
          page: const ClassesPage(),
        ),
        _DashboardCard(
          permission: 'manage_attendance',
          urTitle: 'رجسٹر حاضری',
          enTitle: 'Attendance Register',
          value: todayAttendanceSummary,
          icon: Icons.fact_check,
          page: const AttendancePage(),
        ),
        _DashboardCard(
          permission: 'manage_attendance',
          urTitle: 'حاضری رپورٹ',
          enTitle: 'Attendance Report',
          icon: Icons.receipt_long,
          page: const ReportsAttendancePage(),
        ),
        _DashboardCard(
          permission: 'manage_hifz|manage_academics',
          urTitle: 'تعلیمی رپورٹ (اندراج)',
          enTitle: 'Academic Entry',
          icon: Icons.edit_document,
          page: const AcademicEntryDashboardPage(),
        ),
        _DashboardCard(
          permission: 'manage_hifz|manage_academics',
          urTitle: 'تعلیمی رپورٹ (دیکھیں)',
          enTitle: 'Academic View',
          icon: Icons.analytics,
          page: const AcademicViewDashboardPage(),
        ),
        _DashboardCard(
          permission: 'manage_finance',
          urTitle: 'مسجد آمدن و خرچ',
          enTitle: 'Masjid Finance',
          value: monthlyExpenses.toInt().toString(),
          icon: Icons.account_balance_wallet,
          page: const SimpleFinancePage(),
        ),
        _DashboardCard(
          permission: 'manage_finance',
          urTitle: 'اشیاء عطیات',
          enTitle: 'In-Kind Donations',
          icon: Icons.card_giftcard,
          page: InKindDonationsScreen(),
        ),
        _DashboardCard(
          permission: 'manage_assets',
          urTitle: 'اثاثہ جات',
          enTitle: 'Assets',
          icon: Icons.inventory,
          page: const MasjidAssetsPage(),
        ),
        _DashboardCard(
          permission: 'manage_itikaf',
          urTitle: 'اعتکاف',
          enTitle: 'Itikaf',
          icon: Icons.mosque,
          page: const MasjidItikafPage(),
        ),
      ];
    } else {
      cards = <_DashboardCard>[
        _DashboardCard(
          permission: 'manage_students',
          urTitle: 'زیر تعلیم طلبہ',
          enTitle: 'Enrolled Students',
          value: studentsCount.toString(),
          icon: Icons.school,
          page: const StudentsPage(),
        ),
        _DashboardCard(
          permission: 'manage_teachers',
          urTitle: 'اساتذہ',
          enTitle: 'Teachers',
          value: teachersCount.toString(),
          icon: Icons.people,
          page: const TeachersPage(),
        ),
        _DashboardCard(
          permission: 'manage_classes',
          urTitle: 'کلاسز',
          enTitle: 'Classes',
          value: classesCount.toString(),
          icon: Icons.class_,
          page: const ClassesPage(),
        ),
        _DashboardCard(
          permission: 'manage_attendance',
          urTitle: 'آج کی حاضری',
          enTitle: "Today's Attendance",
          value: todayAttendanceSummary,
          icon: Icons.fact_check,
          page: const AttendancePage(),
        ),
        _DashboardCard(
          permission: 'manage_finance',
          urTitle: 'اس ماہ کے اخراجات',
          enTitle: 'This Month Expenses',
          value: monthlyExpenses.toInt().toString(),
          icon: Icons.money_off,
          page: const SimpleFinancePage(),
        ),
        _DashboardCard(
          permission: 'manage_hifz|manage_academics',
          urTitle: 'تعلیمی کارکردگی (اندراج)',
          enTitle: 'Academic Performance (Entry)',
          icon: Icons.edit_document,
          page: const AcademicEntryDashboardPage(),
        ),
        _DashboardCard(
          permission: 'manage_exams',
          urTitle: 'امتحانات',
          enTitle: 'Exams',
          icon: Icons.assignment,
          page: const ExamsPage(),
        ),
        _DashboardCard(
          permission: 'add_complaint',
          urTitle: 'شکایت اندراج',
          enTitle: 'Complaint Entry',
          icon: Icons.report_problem,
          page: const ComplaintsPage(),
        ),
        _DashboardCard(
          permission: 'manage_requests',
          urTitle: 'درخواستیں و شکایات',
          enTitle: 'Requests & Complaints',
          icon: Icons.notifications_active,
          page: const RequestsPage(),
        ),
        _DashboardCard(
          permission: 'manage_notices',
          urTitle: 'اعلانات',
          enTitle: 'Notices',
          value: noticesCount.toString(),
          icon: Icons.notifications,
          page: const NoticesPage(),
        ),
      ];
    }

    final visible = cards.where((card) => _hasPerm(card.permission)).toList();
    if (currentUserRole.value == 'admin') {
      visible.addAll([
        const _DashboardCard(
          permission: 'admin',
          urTitle: 'یوزرز کا انتظام',
          enTitle: 'Manage Users',
          icon: Icons.manage_accounts,
          page: ManageUsersPage(),
        ),
        const _DashboardCard(
          permission: 'admin',
          urTitle: 'سافٹ ویئر سیٹنگ',
          enTitle: 'Settings',
          icon: Icons.settings,
          page: SettingsPage(),
        ),
      ]);
    }
    return visible;
  }

  List<_DashboardCard> _studentCards() {
    return const [
      _DashboardCard(
        permission: 'student',
        urTitle: 'میری تعلیمی رپورٹ',
        enTitle: 'My Academic Report',
        icon: Icons.school,
        page: StudentReportPage(),
      ),
      _DashboardCard(
        permission: 'student',
        urTitle: 'مدرسہ کے ساتھ تعاون',
        enTitle: 'Cooperate with Madrasa',
        icon: Icons.payments,
        page: PayFeePage(),
      ),
      _DashboardCard(
        permission: 'student',
        urTitle: 'چھٹی کی درخواست',
        enTitle: 'Apply Leave',
        icon: Icons.mark_email_read,
        page: ApplyLeavePage(),
      ),
      _DashboardCard(
        permission: 'student',
        urTitle: 'اصلاحی شکایت',
        enTitle: 'Register Complaint',
        icon: Icons.sentiment_dissatisfied,
        page: ComplaintsPage(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        final cards =
            _isStaff ? _staffCards() : (_isParent ? [] : _studentCards());

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldExit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(isUrdu ? 'ایپ بند کریں؟' : 'Exit App?'),
                content: Text(isUrdu
                    ? 'کیا آپ واقعی ایپ بند کرنا چاہتے ہیں؟'
                    : 'Are you sure you want to exit?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(isUrdu ? 'نہیں' : 'No'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(
                      isUrdu ? 'ہاں، بند کریں' : 'Yes, Exit',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
            if (shouldExit == true) {
              try {
                await SyncService.runTwoWaySync();
              } catch (_) {}
              SystemNavigator.pop();
            }
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
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset('assets/logo.png', height: 30),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUrdu ? (SystemTypeGlobal.currentSystemType.value == 'Masjid' ? 'مسجد ڈیش بورڈ' : 'ڈیش بورڈ') : (SystemTypeGlobal.currentSystemType.value == 'Masjid' ? 'Masjid Dashboard' : 'Dashboard'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: _isSyncing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.sync, color: Colors.white),
                    onPressed: _isSyncing ? null : _runLiveTwoWaySync,
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    NeoBox(
                      padding: 15,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                const AssetImage('assets/logo.png'),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: isUrdu
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isUrdu ? 'خوش آمدید' : 'Welcome',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                                Text(
                                  _userName,
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (cards.isEmpty && !_isParent)
                      Expanded(
                        child: Center(
                          child: Text(
                            isUrdu
                                ? 'آپ کے لیے کوئی ڈیش بورڈ کارڈ اسائن نہیں کیا گیا۔'
                                : 'No dashboard cards have been assigned to you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: _isParent
                            ? _buildParentChildrenList(isUrdu)
                            : GridView.extent(
                                maxCrossAxisExtent: 200,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.3,
                                children: cards
                                    .map((card) => _buildStatCard(card, isUrdu))
                                    .toList(),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParentChildrenList(bool isUrdu) {
    if (_parentChildren.isEmpty) {
      return Center(
        child: Text(
          isUrdu ? 'کوئی طالب علم منسلک نہیں ہے۔' : 'No children linked.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _parentChildren.length,
      itemBuilder: (context, index) {
        final child = _parentChildren[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: CircleAvatar(
              backgroundColor: primaryGreen.withOpacity(0.1),
              child: Icon(Icons.person, color: primaryGreen),
            ),
            title: Text(
              child['name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle:
                Text('${isUrdu ? "کلاس:" : "Class:"} ${child['class'] ?? "-"}'),
            trailing:
                Icon(Icons.arrow_forward_ios, size: 16, color: primaryGreen),
            onTap: () {
              // Set the selected child as the active student and navigate to their report
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentReportPage(
                      forceStudentId: child['id']?.toString()),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatCard(_DashboardCard card, bool isUrdu) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => card.page),
      ),
      child: NeoBox(
        padding: 10.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(card.icon, color: primaryGreen, size: 30),
            const SizedBox(height: 8),
            Text(
              isUrdu ? card.urTitle : card.enTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (card.value.isNotEmpty) ...[
              const SizedBox(height: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    card.value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
