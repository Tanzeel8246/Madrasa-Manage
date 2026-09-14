import 'package:sqflite/sqflite.dart';
import '../../db_helper.dart';

class StudentRepository {
  final DBHelper _dbHelper;
  StudentRepository([DBHelper? dbHelper]) : _dbHelper = dbHelper ?? DBHelper();

  Future<Database> get _db async => await _dbHelper.database;

  Future<List<Map<String, dynamic>>> getStudents({
    String? systemType,
    bool activeOnly = true,
  }) async {
    final db = await _db;
    final sys = systemType ?? 'Madrasa';
    final sysCond = (sys == 'Masjid')
        ? "system_type = 'Masjid'"
        : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";
    final activeCond = activeOnly
        ? "AND (status = 'Active' OR status = '' OR status IS NULL)"
        : "";

    return await db.query(
      'students',
      where: "(is_deleted = 0 OR is_deleted IS NULL) $activeCond AND $sysCond",
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getStudentById(int id) async {
    final db = await _db;
    final res = await db.query(
      'students',
      where: 'id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getStudentsByClass(
    String className, {
    String? systemType,
  }) async {
    final db = await _db;
    final sys = systemType ?? 'Madrasa';
    final sysCond = (sys == 'Masjid')
        ? "system_type = 'Masjid'"
        : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";

    return await db.query(
      'students',
      where:
          "class_name = ? AND (is_deleted = 0 OR is_deleted IS NULL) AND (status = 'Active' OR status = '' OR status IS NULL) AND $sysCond",
      whereArgs: [className],
      orderBy: 'roll_no ASC, name ASC',
    );
  }

  Future<int> insertStudent(Map<String, dynamic> data) async {
    final db = await _db;
    final values = Map<String, dynamic>.from(data);
    values['is_synced'] = 0;
    return await db.insert('students', values);
  }

  Future<int> updateStudent(int id, Map<String, dynamic> data) async {
    final db = await _db;
    final values = Map<String, dynamic>.from(data);
    values['is_synced'] = 0;
    return await db.update(
      'students',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await _db;
    return await db.update(
      'students',
      {'is_deleted': 1, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAlumni({String? systemType}) async {
    final db = await _db;
    final sys = systemType ?? 'Madrasa';
    final sysCond = (sys == 'Masjid')
        ? "system_type = 'Masjid'"
        : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";

    return await db.query(
      'students',
      where: "status = 'Alumni' AND (is_deleted = 0 OR is_deleted IS NULL) AND $sysCond",
      orderBy: 'id DESC',
    );
  }
}
