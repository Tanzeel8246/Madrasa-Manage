import 'package:sqflite/sqflite.dart';
import '../../db_helper.dart';

class AcademicRepository {
  final DBHelper _dbHelper;
  AcademicRepository([DBHelper? dbHelper]) : _dbHelper = dbHelper ?? DBHelper();

  Future<Database> get _db async => await _dbHelper.database;

  // 1. Hifz
  Future<List<Map<String, dynamic>>> getHifzEntries(
    int studentId, {
    String? date,
  }) async {
    final db = await _db;
    if (date != null && date.isNotEmpty) {
      return await db.query(
        'daily_hifz',
        where: 'student_id = ? AND date = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
        whereArgs: [studentId, date],
        orderBy: 'date DESC',
      );
    }
    return await db.query(
      'daily_hifz',
      where: 'student_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
  }

  Future<int> saveHifzEntry(Map<String, dynamic> data) async {
    final db = await _db;
    final values = Map<String, dynamic>.from(data);
    values['is_synced'] = 0;
    return await db.insert(
      'daily_hifz',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 2. Nazira
  Future<List<Map<String, dynamic>>> getNaziraEntries(
    int studentId, {
    String? date,
  }) async {
    final db = await _db;
    if (date != null && date.isNotEmpty) {
      return await db.query(
        'daily_nazira',
        where: 'student_id = ? AND date = ?',
        whereArgs: [studentId, date],
        orderBy: 'date DESC',
      );
    }
    return await db.query(
      'daily_nazira',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
  }

  Future<int> saveNaziraEntry(Map<String, dynamic> data) async {
    final db = await _db;
    final values = Map<String, dynamic>.from(data);
    values['is_synced'] = 0;
    return await db.insert(
      'daily_nazira',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 3. Qaida
  Future<List<Map<String, dynamic>>> getQaidaEntries(
    int studentId, {
    String? date,
  }) async {
    final db = await _db;
    if (date != null && date.isNotEmpty) {
      return await db.query(
        'qaida_records',
        where: 'student_id = ? AND date = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
        whereArgs: [studentId, date],
        orderBy: 'date DESC',
      );
    }
    return await db.query(
      'qaida_records',
      where: 'student_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
  }

  Future<int> saveQaidaEntry(Map<String, dynamic> data) async {
    final db = await _db;
    final values = Map<String, dynamic>.from(data);
    values['is_synced'] = 0;
    return await db.insert(
      'qaida_records',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 4. Exams & Results
  Future<List<Map<String, dynamic>>> getExams({String? systemType}) async {
    final db = await _db;
    final sys = systemType ?? 'Madrasa';
    final sysCond = (sys == 'Masjid')
        ? "system_type = 'Masjid'"
        : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";

    return await db.query(
      'exams',
      where: "(is_deleted = 0 OR is_deleted IS NULL) AND $sysCond",
      orderBy: 'exam_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getExamResults(int examId) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT er.*, s.name as student_name, s.roll_no, s.class_name
      FROM exam_results er
      JOIN students s ON er.student_id = s.id
      WHERE er.exam_id = ? AND (er.is_deleted = 0 OR er.is_deleted IS NULL)
      ORDER BY er.obtained_marks DESC
    ''', [examId]);
  }
}
