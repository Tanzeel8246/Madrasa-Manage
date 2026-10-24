// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../utils/globals.dart';
import '../widgets/sync_summary_dialog.dart';
import 'sync_engine.dart';
import 'sync_models.dart';

class SyncUIHelper {
  static Future<SyncResult?> performManualSync(BuildContext context,
      {bool background = false, bool forceFull = false}) async {
    final isUrdu = isUrduGlobal.value;

    if (!background) {
      // Show Dynamic Progress Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.sync, color: Color(0xFF284D3D)),
                const SizedBox(width: 10),
                Text(
                  forceFull
                      ? (isUrdu
                          ? "مکمل ڈیٹا سنکنگ جاری ہے..."
                          : "Full Sync in progress...")
                      : (isUrdu
                          ? "ڈیٹا سنکنگ جاری ہے..."
                          : "Syncing in progress..."),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: ValueListenableBuilder<SyncProgress?>(
              valueListenable: SyncEngine.progress,
              builder: (context, prog, _) {
                final percent = prog?.percent ?? 0.0;
                final table = prog?.currentTable ?? 'initial';
                final tableTitle = _getTableTitleUrdu(table, isUrdu);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: percent > 0 ? percent : null,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF284D3D),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tableTitle,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(percent * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF284D3D)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                },
                child: Text(
                  isUrdu ? "پس منظر میں چلائیں" : "Run in background",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    try {
      final result =
          await SyncEngine.runTwoWaySyncWithResult(forceFull: forceFull);

      if (!background && Navigator.canPop(context)) {
        Navigator.pop(context); // Close progress dialog

        // Show Beautiful Detailed Summary Dialog
        showDialog(
          context: context,
          builder: (dialogCtx) => SyncSummaryDialog(result: result),
        );
      }
      return result;
    } catch (e) {
      if (!background && Navigator.canPop(context)) {
        Navigator.pop(context); // Close progress dialog

        final errorStr = e.toString();
        String displayMsg = errorStr;
        if (errorStr.contains('401') ||
            errorStr.contains('Unauthorized') ||
            errorStr.contains('Login required')) {
          displayMsg = isUrdu
              ? "لاگ اِن سیشن کی میعاد ختم ہو چکی ہے یا سیکیورٹی کیز ہم آہنگ نہیں ہیں۔ برائے مہربانی ایک بار لاگ آؤٹ کر کے دوبارہ لاگ اِن کریں۔"
              : "Login session expired or unauthorized. Please log out and log in again.";
        }

        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 10),
                Text(isUrdu ? "سنکنگ میں خرابی" : "Sync Failed",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                displayMsg,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        debugPrint('Background sync failed: $e');
      }
      return null;
    }
  }

  static String _getTableTitleUrdu(String table, bool isUrdu) {
    if (!isUrdu) return 'Syncing $table...';
    switch (table) {
      case 'students':
      case 'maktab_students':
        return 'طلباء کا ڈیٹا اپ لوڈ ہو رہا ہے...';
      case 'teachers':
      case 'maktab_teachers':
        return 'اساتذہ کا ریکارڈ اپ لوڈ ہو رہا ہے...';
      case 'attendance':
      case 'attendance_teachers':
      case 'maktab_attendance':
        return 'حاضری رجسٹر اپ لوڈ ہو رہا ہے...';
      case 'finance':
      case 'masjid_finance':
      case 'fee_submissions':
        return 'مالیاتی اندراجات اپ لوڈ ہو رہے ہیں...';
      case 'hifz_record':
      case 'nazira_record':
      case 'qaida_records':
      case 'maktab_hifz_record':
      case 'maktab_qaida_records':
        return 'حفظ و ناظرہ اسباق سنک ہو رہے ہیں...';
      case 'sync_down':
        return 'سرور سے نیا ڈیٹا ڈاؤن لوڈ ہو رہا ہے...';
      case 'done':
        return 'سنکنگ مکمل ہو چکی ہے!';
      default:
        return '$table سنک ہو رہا ہے...';
    }
  }
}
