import '../utils/globals.dart';
import 'sync_config.dart';

class SyncPermissions {
  static bool canUploadTable(String table) {
    final role = currentUserRole.value?.toLowerCase();
    if (role == 'admin' || role == 'nazim') return true;

    if (role == 'student' || role == 'parent') {
      return table == 'parent_complaints' ||
          table == 'leave_applications' ||
          table == 'fee_submissions';
    }

    final permissions = currentUserPermissions.value;
    if ((table == 'attendance_teachers' ||
            table == 'teacher_period_attendance') &&
        (permissions.contains('manage_attendance') ||
            permissions.contains('manage_teacher_attendance'))) {
      return true;
    }

    if ((table == 'academic_reports' ||
            table == 'maktab_academic_reports') &&
        (permissions.contains('manage_academics') ||
            permissions.contains('manage_hifz'))) {
      return true;
    }

    if (table == 'acc_payroll' &&
        (permissions.contains('manage_finance') ||
            permissions.contains('manage_erp') ||
            permissions.contains('manage_stipends') ||
            permissions.contains('manage_masjid_stipends'))) {
      return true;
    }

    if ((table == 'acc_vouchers' ||
            table == 'acc_ledger_entries' ||
            table == 'acc_chart_of_accounts') &&
        (permissions.contains('manage_finance') ||
            permissions.contains('manage_erp') ||
            permissions.contains('manage_masjid_finance'))) {
      return true;
    }

    final permission = SyncConfig.uploadPermissionMap[table];
    return permission != null && permissions.contains(permission);
  }
}
