import 'sync_table_names.dart';

class SyncProgress {
  final String currentTable;
  final int completed;
  final int total;
  final List<String> errors;

  const SyncProgress({
    required this.currentTable,
    required this.completed,
    required this.total,
    this.errors = const [],
  });

  double get percent => total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
  bool get isDone => completed >= total;
}

class SyncResult {
  final Map<String, int> uploadedPerTable;
  final Map<String, int> downloadedPerTable;
  final List<String> errors;
  final Duration duration;
  final DateTime timestamp;

  const SyncResult({
    this.uploadedPerTable = const {},
    this.downloadedPerTable = const {},
    this.errors = const [],
    required this.duration,
    required this.timestamp,
  });

  int get totalUploaded =>
      uploadedPerTable.values.fold(0, (sum, count) => sum + count);

  int get totalDownloaded =>
      downloadedPerTable.values.fold(0, (sum, count) => sum + count);

  bool get isSuccess => errors.isEmpty;

  static String getUrduTableName(String key) =>
      SyncTableNames.getUrduTableName(key);

  String generateSummaryUrdu() {
    final buffer = StringBuffer();
    buffer.writeln('📋 *سنک رپورٹ خلاصہ*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    buffer.writeln('⬆️ *اپ لوڈ شدہ ڈیٹا:*');
    final validUploads =
        uploadedPerTable.entries.where((e) => e.value > 0).toList();
    if (validUploads.isNotEmpty) {
      for (final entry in validUploads) {
        final label = getUrduTableName(entry.key);
        buffer.writeln('  • $label: ${entry.value}');
      }
      buffer.writeln('  (کل اپ لوڈ: $totalUploaded)');
    } else {
      buffer.writeln('  • کوئی نیا لوکل ریکارڈ نہیں تھا');
    }

    buffer.writeln('');
    buffer.writeln('⬇️ *ڈاؤن لوڈ شدہ ڈیٹا:*');
    final validDownloads =
        downloadedPerTable.entries.where((e) => e.value > 0).toList();
    if (validDownloads.isNotEmpty) {
      for (final entry in validDownloads) {
        final label = getUrduTableName(entry.key);
        buffer.writeln('  • $label: ${entry.value}');
      }
      buffer.writeln('  (کل ڈاؤن لوڈ: $totalDownloaded)');
    } else {
      buffer.writeln('  • سرور سے تازہ ترین ریکارڈز پہلے سے ہم آہنگ ہیں');
    }

    if (errors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('⚠️ *خرابیاں (${errors.length}):*');
      for (final err in errors.take(3)) {
        buffer.writeln('  • $err');
      }
    }

    final seconds = (duration.inMilliseconds / 1000).toStringAsFixed(1);
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('⏱️ *کل وقت:* $seconds سیکنڈ');
    return buffer.toString();
  }
}
