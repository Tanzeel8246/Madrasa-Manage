// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';

import '../screens/admin_admissions.dart';
import '../screens/alumni_register.dart';
import '../screens/apply_leave.dart';
import '../screens/attendance.dart';
import '../screens/change_password.dart';
import '../screens/classes.dart';
import '../screens/complaints.dart';
import '../screens/dashboard.dart';
import '../screens/delete_account.dart';
import '../screens/exams.dart';
import '../screens/finance.dart';
import '../screens/simple_finance.dart';
import '../screens/acc_chart.dart';
import '../screens/acc_income_statement.dart';
import '../screens/acc_invoices.dart';
import '../screens/acc_ledger.dart';
import '../screens/acc_payroll.dart';
import '../screens/acc_trial_balance.dart';
import '../screens/acc_balance_sheet.dart';
import '../screens/acc_vouchers.dart';
import '../screens/departments.dart';
import '../screens/manage_complaints.dart';

import '../screens/home.dart';
import '../screens/manage_users.dart';
import '../screens/notices.dart';
import '../screens/pay_fee.dart';
import '../screens/reports_attendance.dart';
import '../screens/reports_finance.dart';
import '../screens/requests.dart';
import '../screens/settings.dart';
import '../screens/student_report.dart';
import '../screens/students.dart';
import '../screens/academic_entry_dashboard.dart';
import '../screens/academic_view_dashboard.dart';
import '../screens/teacher_attendance.dart';
import '../screens/teacher_attendance_report.dart';
import '../screens/teachers.dart';
import '../utils/globals.dart';
import '../utils/session.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color textDark = const Color(0xFF2D2D2D);

  // ERP sub-menu expansion state
  bool _erpExpanded = false;

  bool hasPerm(String perm) {
    if (currentUserRole.value == 'admin') return true;
    return currentUserPermissions.value.contains(perm);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: bgColor,
      child: ValueListenableBuilder<bool>(
        valueListenable: isUrduGlobal,
        builder: (context, isUrdu, child) {
          return Directionality(
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(
                      bottom: BorderSide(
                        color: primaryGreen.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo.png', height: 60),
                      const SizedBox(height: 10),
                      Text(
                        isUrdu
                            ? 'مدرسہ اشرف المدارس'
                            : 'Madrasa Ashraf-ul-Madaris',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(
                  context,
                  isUrdu ? 'ہوم' : 'Home',
                  Icons.home,
                  const HomePage(),
                ),
                _buildDrawerItem(
                  context,
                  isUrdu ? 'ڈیش بورڈ' : 'Dashboard',
                  Icons.dashboard,
                  const DashboardPage(),
                ),
                if (['admin', 'nazim', 'teacher']
                    .contains(currentUserRole.value)) ...[
                  if (hasPerm('manage_admissions'))
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'داخلہ درخواستیں' : 'Admission Applications',
                      Icons.assignment_ind,
                      const AdminAdmissionsPage(),
                    ),
                  if (hasPerm('manage_requests'))
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'درخواستیں و شکایات' : 'Requests & Complaints',
                      Icons.notifications_active,
                      const RequestsPage(),
                    ),
                  if (hasPerm('manage_complaints'))
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'شکایات ریکارڈ' : 'Complaints Record',
                      Icons.report_problem,
                      const ManageComplaintsPage(),
                    ),
                  if (hasPerm('manage_notices'))
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'نوٹس بورڈ' : 'Notice Board',
                      Icons.campaign,
                      const NoticesPage(),
                    ),
                  if (hasPerm('manage_hifz') ||
                      hasPerm('manage_academics')) ...[
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'تعلیمی کارکردگی (اندراج)' : 'Academic Entry',
                      Icons.edit_document,
                      const AcademicEntryDashboardPage(),
                    ),
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'تعلیمی کارکردگی (دیکھیں)' : 'Academic View',
                      Icons.analytics,
                      const AcademicViewDashboardPage(),
                    ),
                  ],
                  if (hasPerm('manage_students')) ...[
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'طلباء کا ریکارڈ' : 'Students',
                      Icons.school,
                      const StudentsPage(),
                    ),
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'فارغ التحصیل طلباء' : 'Alumni Register',
                      Icons.how_to_reg,
                      const AlumniRegisterPage(),
                    ),
                  ],
                  if (hasPerm('manage_classes'))
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'کلاسز' : 'Classes',
                      Icons.class_,
                      const ClassesPage(),
                    ),
                  if (hasPerm('manage_teachers'))
                    _buildDrawerItem(
                      context,
                      isUrdu
                          ? '\u0627\u0633\u0627\u062a\u0630\u06c1 \u06a9\u0627 \u0631\u06cc\u06a9\u0627\u0631\u0688'
                          : 'Teachers',
                      Icons.person_outline,
                      const TeachersPage(),
                    ),
                  if (hasPerm('manage_teacher_attendance') ||
                      hasPerm('manage_attendance')) ...[
                    _buildDrawerItem(
                      context,
                      isUrdu
                          ? '\u0627\u0633\u0627\u062a\u0630\u06c1 \u06a9\u06cc \u062d\u0627\u0636\u0631\u06cc'
                          : 'Teacher Attendance',
                      Icons.how_to_reg,
                      const TeacherAttendancePage(),
                    ),
                    _buildDrawerItem(
                      context,
                      isUrdu
                          ? '\u0627\u0633\u0627\u062a\u0630\u06c1 \u062d\u0627\u0636\u0631\u06cc \u0631\u067e\u0648\u0631\u0679'
                          : 'Teacher Attendance Report',
                      Icons.assignment,
                      const TeacherAttendanceReportPage(),
                    ),
                  ],
                  if (hasPerm('manage_attendance')) ...[
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'حاضری رجسٹر' : 'Attendance',
                      Icons.fact_check,
                      const AttendancePage(),
                    ),
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'حاضری رپورٹ' : 'Attendance Report',
                      Icons.receipt_long,
                      const ReportsAttendancePage(),
                    ),
                  ],
                  // مالیات سب مینیو — finance + ERP grouped together
                  if (hasPerm('manage_finance') || hasPerm('manage_erp'))
                    _buildErpSubMenu(context, isUrdu),
                  if (hasPerm('add_complaint'))
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'شکایت اندراج' : 'Complaint Entry',
                      Icons.warning,
                      const ComplaintsPage(),
                    ),
                  if (hasPerm('manage_exams'))
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'امتحانات' : 'Exams',
                      Icons.assignment,
                      const ExamsPage(),
                    ),
                  if (currentUserRole.value == 'admin') ...[
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'یوزرز کا انتظام' : 'Manage Users',
                      Icons.manage_accounts,
                      const ManageUsersPage(),
                    ),
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'سافٹ ویئر سیٹنگ' : 'Settings',
                      Icons.settings,
                      const SettingsPage(),
                    ),
                  ],
                ],
                if (currentUserRole.value == 'student' ||
                    currentUserRole.value == 'parent') ...[
                  _buildDrawerItem(
                    context,
                    isUrdu ? 'میری تعلیمی رپورٹ' : 'My Report',
                    Icons.school,
                    const StudentReportPage(),
                  ),
                  _buildDrawerItem(
                    context,
                    isUrdu ? 'مدرسہ کے ساتھ تعاون' : 'Cooperate with Madrasa',
                    Icons.handshake,
                    const PayFeePage(),
                  ),
                  _buildDrawerItem(
                    context,
                    isUrdu ? 'چھٹی کی درخواست' : 'Apply Leave',
                    Icons.mark_email_read,
                    const ApplyLeavePage(),
                  ),
                  _buildDrawerItem(
                    context,
                    isUrdu ? 'اصلاحی شکایت درج کریں' : 'Register Complaint',
                    Icons.sentiment_dissatisfied,
                    const ComplaintsPage(),
                  ),
                  _buildDrawerItem(
                    context,
                    isUrdu ? 'پاس ورڈ تبدیل کریں' : 'Change Password',
                    Icons.vpn_key,
                    const ChangePasswordPage(),
                  ),
                  if (currentUserRole.value == 'student')
                    _buildDrawerItem(
                      context,
                      isUrdu ? 'اکاؤنٹ حذف کریں' : 'Delete Account',
                      Icons.delete_forever,
                      const DeleteAccountPage(),
                      iconColor: Colors.red,
                    ),
                ],
                if (currentUserRole.value != null &&
                    currentUserRole.value != 'student' &&
                    currentUserRole.value != 'parent')
                  _buildDrawerItem(
                    context,
                    isUrdu ? 'پاس ورڈ تبدیل کریں' : 'Change Password',
                    Icons.vpn_key,
                    const ChangePasswordPage(),
                  ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    isUrdu ? 'لاگ آؤٹ' : 'Logout',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    currentUserRole.value = null;
                    currentUserId.value = null;
                    currentUserToken.value = null;
                    currentUserPermissions.value = [];
                    await SessionManager.clearSession();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (c) => const HomePage()),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.g_translate, color: primaryGreen),
                  title: Text(
                    isUrdu ? 'English میں تبدیل کریں' : 'Switch to اردو',
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    isUrduGlobal.value = !isUrduGlobal.value;
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  /// مالیات سب مینیو (Expandable ERP tile)
  Widget _buildErpSubMenu(BuildContext context, bool isUrdu) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(Icons.account_balance, color: primaryGreen, size: 22),
        title: Text(
          isUrdu ? 'مالیات' : 'Finance / ERP',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          _erpExpanded ? Icons.expand_less : Icons.expand_more,
          color: primaryGreen,
        ),
        initiallyExpanded: _erpExpanded,
        onExpansionChanged: (val) => setState(() => _erpExpanded = val),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        children: [
          if (hasPerm('manage_finance')) ...[
            _buildSubDrawerItem(
              context,
              isUrdu ? 'آمدن و خرچ' : 'Simple Finance',
              Icons.account_balance_wallet,
              const SimpleFinancePage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'مالیاتی رپورٹ' : 'Finance Report',
              Icons.request_quote,
              const ReportsFinancePage(),
            ),
          ],
          if (hasPerm('manage_erp')) ...[
            _buildSubDrawerItem(
              context,
              isUrdu ? 'فنانس ڈیش بورڈ' : 'Finance Dashboard',
              Icons.wallet,
              const FinancePage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'شعبہ جات' : 'Departments',
              Icons.business,
              const DepartmentsPage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'چارٹ آف اکاؤنٹس' : 'Chart of Accounts',
              Icons.account_tree,
              const AccChartPage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'واؤچرز' : 'Vouchers',
              Icons.receipt_long,
              const AccVouchersPage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'جنرل لیجر' : 'General Ledger',
              Icons.menu_book,
              const AccLedgerPage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'میزان' : 'Trial Balance',
              Icons.balance,
              const AccTrialBalancePage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'گوشوارہ آمدن و اخراجات' : 'Income Statement',
              Icons.pie_chart,
              const AccIncomeStatementPage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'بیلنس شیٹ' : 'Balance Sheet',
              Icons.account_balance,
              const BalanceSheetPage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'فیس انوائسز' : 'Fee Invoices',
              Icons.receipt,
              const AccInvoicesPage(),
            ),
            _buildSubDrawerItem(
              context,
              isUrdu ? 'پے رول' : 'Payroll',
              Icons.people,
              const AccPayrollPage(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    Widget page, {
    Color? iconColor,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor ?? primaryGreen, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: textDark,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => page),
        );
      },
    );
  }

  /// Indented sub-item for ERP submenu
  Widget _buildSubDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    Widget page,
  ) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(right: 32, left: 32),
      leading:
          Icon(icon, color: primaryGreen.withValues(alpha: 0.75), size: 18),
      title: Text(
        title,
        style: TextStyle(
          color: textDark,
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => page),
        );
      },
    );
  }
}
