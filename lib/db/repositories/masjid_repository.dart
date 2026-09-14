import 'package:sqflite/sqflite.dart';
import '../../db_helper.dart';

class MasjidRepository {
  final DBHelper _dbHelper;
  MasjidRepository([DBHelper? dbHelper]) : _dbHelper = dbHelper ?? DBHelper();

  Future<Database> get _db async => await _dbHelper.database;

  Future<List<Map<String, dynamic>>> getMaktabStudents({
    bool activeOnly = true,
  }) async {
    final db = await _db;
    final activeCond = activeOnly
        ? "AND (status = 'Active' OR status = '' OR status IS NULL)"
        : "";

    var res = await db.query(
      'students',
      where: "(is_deleted = 0 OR is_deleted IS NULL) $activeCond AND system_type = 'Masjid'",
      orderBy: 'name ASC',
    );

    if (res.isEmpty) {
      try {
        res = await db.query(
          'maktab_students',
          where: "(is_deleted = 0 OR is_deleted IS NULL) $activeCond",
          orderBy: 'name ASC',
        );
      } catch (_) {}
    }
    return res;
  }

  Future<List<Map<String, dynamic>>> getMaktabClasses() async {
    final db = await _db;
    var res = await db.query(
      'classes',
      where: "(is_deleted = 0 OR is_deleted IS NULL) AND system_type = 'Masjid'",
      orderBy: 'name ASC',
    );

    if (res.isEmpty) {
      try {
        res = await db.query(
          'maktab_classes',
          where: "(is_deleted = 0 OR is_deleted IS NULL)",
          orderBy: 'name ASC',
        );
      } catch (_) {}
    }
    return res;
  }

  Future<List<Map<String, dynamic>>> getMaktabAttendance(String date) async {
    final db = await _db;
    try {
      return await db.query(
        'maktab_attendance',
        where: 'date = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
        whereArgs: [date],
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMasjidAssets() async {
    final db = await _db;
    try {
      return await db.query(
        'masjid_assets',
        where: "(is_deleted = 0 OR is_deleted IS NULL)",
        orderBy: 'id DESC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMasjidFinance({
    String? type,
    String? fromDate,
  }) async {
    final db = await _db;
    try {
      final conditions = ["(is_deleted = 0 OR is_deleted IS NULL)"];
      final args = <dynamic>[];
      if (type != null && type.isNotEmpty) {
        conditions.add("LOWER(type) = ?");
        args.add(type.toLowerCase());
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        conditions.add("date >= ?");
        args.add(fromDate);
      }
      return await db.query(
        'masjid_finance',
        where: conditions.join(" AND "),
        whereArgs: args.isNotEmpty ? args : null,
        orderBy: 'date DESC',
      );
    } catch (_) {
      return [];
    }
  }
}
