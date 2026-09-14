import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

extension DbSyncRead on DBHelper {
  Future<List<Map<String, dynamic>>> getUnsyncedData(String table) async {
    Database db = await database;
    try {
      var checkTable = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'");
      if (checkTable.isEmpty) return [];
      if (table == 'acc_ledger_entries') {
        return await db.rawQuery('''
          SELECT e.*, v.voucher_no, a.code AS account_code
          FROM acc_ledger_entries e
          LEFT JOIN acc_vouchers v ON v.id = e.voucher_id
          LEFT JOIN acc_chart_of_accounts a ON a.id = e.account_id
          WHERE COALESCE(e.is_synced, 0) = 0
        ''');
      }
      return await db
          .query(table, where: 'COALESCE(is_synced, 0) = ?', whereArgs: [0]);
    } catch (e) {
      debugPrint("GetUnsynced Error ($table): $e");
      return [];
    }
  }

  Future<void> markAsSynced(String table, int id) async {
    Database db = await database;
    await db.update(table, {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markFinanceAsSynced(int id, int? serverId) async {
    Database db = await database;
    final values = <String, dynamic>{'is_synced': 1};
    if (serverId != null && serverId > 0) {
      values['server_id'] = serverId;
    }
    await db.update('finance', values, where: 'id = ?', whereArgs: [id]);
  }
}
