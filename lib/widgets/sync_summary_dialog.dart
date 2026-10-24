import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../sync/sync_ui_helper.dart';
import '../utils/globals.dart';
import '../utils/sync_result.dart';

class SyncSummaryDialog extends StatelessWidget {
  final SyncResult result;

  const SyncSummaryDialog({super.key, required this.result});

  IconData _getTableIcon(String key) {
    switch (key.toLowerCase()) {
      case 'students':
      case 'maktab_students':
        return Icons.school;
      case 'teachers':
      case 'maktab_teachers':
        return Icons.person_outline;
      case 'classes':
      case 'maktab_classes':
        return Icons.class_;
      case 'attendance':
      case 'attendance_entries':
      case 'attendance_history':
      case 'attendance_teachers':
      case 'teacher_period_attendance':
      case 'maktab_attendance':
        return Icons.event_available;
      case 'hifz_record':
      case 'hifz_entries':
      case 'hifz_history':
      case 'nazira_record':
      case 'nazira_history':
      case 'qaida_records':
      case 'academic_reports':
      case 'maktab_nazira_record':
      case 'maktab_hifz_record':
      case 'maktab_qaida_records':
      case 'maktab_academic_reports':
        return Icons.menu_book;
      case 'finance':
      case 'finance_entries':
      case 'finance_history':
      case 'masjid_finance':
      case 'masjid_finance_entries':
      case 'masjid_finance_history':
      case 'fee_submissions':
      case 'acc_vouchers':
      case 'acc_ledger_entries':
      case 'acc_payroll':
      case 'acc_invoices':
      case 'staff_loans':
        return Icons.account_balance_wallet;
      case 'notices':
        return Icons.campaign;
      case 'exams':
      case 'exam_results':
      case 'maktab_exams':
      case 'maktab_exam_results':
        return Icons.assignment;
      case 'complaints':
      case 'parent_complaints':
        return Icons.report_problem;
      default:
        return Icons.folder_open;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = isUrduGlobal.value;
    final totalUp = result.totalUploaded;
    final totalDown = result.totalDownloaded;
    final seconds = (result.duration.inMilliseconds / 1000).toStringAsFixed(1);

    final validUploads =
        result.uploadedPerTable.entries.where((e) => e.value > 0).toList();
    final validDownloads =
        result.downloadedPerTable.entries.where((e) => e.value > 0).toList();

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF284D3D),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUrdu
                                ? "سنکنگ مکمل ہو گئی"
                                : "Sync Completed",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isUrdu
                                ? "ڈیٹا کامیابی کے ساتھ اپ ڈیٹ کر دیا گیا ہے"
                                : "Data successfully synchronized",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "$seconds${isUrdu ? ' سیکنڈ' : 's'}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content Area
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Stat Chips
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.blue.shade100,
                                    child: const Icon(Icons.arrow_upward,
                                        size: 16, color: Colors.blue),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isUrdu ? "اپ لوڈ شدہ" : "Uploaded",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade900),
                                        ),
                                        Text(
                                          "$totalUp ${isUrdu ? 'ریکارڈز' : 'records'}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.green.shade100,
                                    child: const Icon(Icons.arrow_downward,
                                        size: 16, color: Colors.green),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isUrdu
                                              ? "ڈاؤن لوڈ شدہ"
                                              : "Downloaded",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade900),
                                        ),
                                        Text(
                                          "$totalDown ${isUrdu ? 'ریکارڈز' : 'records'}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Uploaded Section
                      _buildSectionHeader(
                        icon: Icons.cloud_upload_outlined,
                        title: isUrdu
                            ? "اپ لوڈ شدہ ڈیٹا (موبائل ➔ سرور)"
                            : "Uploaded Data",
                        color: Colors.blue.shade800,
                      ),
                      const SizedBox(height: 6),
                      if (validUploads.isEmpty)
                        _buildEmptyTile(
                          isUrdu
                              ? "✅ کوئی نیا لوکل ریکارڈ نہیں تھا (تمام ڈیٹا پہلے سے اپ ڈیٹڈ ہے)"
                              : "No local changes to upload",
                        )
                      else
                        _buildItemsList(validUploads, Colors.blue.shade700),

                      const SizedBox(height: 16),

                      // Downloaded Section
                      _buildSectionHeader(
                        icon: Icons.cloud_download_outlined,
                        title: isUrdu
                            ? "ڈاؤن لوڈ شدہ ڈیٹا (سرور ➔ موبائل)"
                            : "Downloaded Data",
                        color: Colors.green.shade800,
                      ),
                      const SizedBox(height: 6),
                      if (validDownloads.isEmpty)
                        _buildEmptyTile(
                          isUrdu
                              ? "✅ سرور سے تمام ریکارڈز پہلے سے ہم آہنگ ہیں (کوئی نیا ریکارڈ نہیں تھا)"
                              : "All server records already up-to-date",
                        )
                      else
                        _buildItemsList(validDownloads, Colors.green.shade700),

                      if (result.errors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader(
                          icon: Icons.warning_amber_rounded,
                          title: isUrdu ? "خرابیاں / وارننگ" : "Warnings",
                          color: Colors.red.shade800,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: result.errors
                                .take(3)
                                .map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text("• ",
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              e,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red.shade900),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (totalDown == 0) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF284D3D),
                            side: const BorderSide(color: Color(0xFF284D3D), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.cloud_download, size: 18),
                          label: Text(
                            isUrdu
                                ? "سرور سے تمام ڈیٹا لوڈ کریں (مکمل سنک)"
                                : "Download All From Server (Full Sync)",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            SyncUIHelper.performManualSync(context, forceFull: true);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(
                          isUrdu ? "خلاصہ کاپی کریں" : "Copy Summary",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: result.generateSummaryUrdu()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isUrdu
                                  ? "✅ سنک رپورٹ کاپی ہو گئی!"
                                  : "✅ Sync report copied to clipboard!"),
                              duration: const Duration(seconds: 2),
                              backgroundColor: const Color(0xFF284D3D),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF284D3D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          isUrdu ? "ٹھیک ہے" : "OK",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTile(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildItemsList(
      List<MapEntry<String, int>> items, Color badgeBgColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (context, index) {
          final item = items[index];
          final label = SyncResult.getUrduTableName(item.key);
          final icon = _getTableIcon(item.key);

          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBgColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${item.value}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badgeBgColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
