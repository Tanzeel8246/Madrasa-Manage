import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class AttendanceSyncSaver {
  static String _normalizeAttendanceStatus(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().trim().toLowerCase();

    if (status == 'a' || status == 'absent' || status.contains('absent')) {
      return 'Absent';
    }
    if (status == 'l' || status == 'leave' || status.contains('leave')) {
      return 'Leave';
    }
    if (status == 'p' || status == 'present' || status.contains('present')) {
      return 'Present';
    }

    return (rawStatus ?? '').toString();
  }

  static String _normalizeShiftLabel(dynamic shiftRaw) {
    final String shift = (shiftRaw ?? '').toString().trim().toLowerCase();

    switch (shift) {
      case '1':
      case 'morning':
        return 'Morning';
      case '2':
      case 'afterbreakfast':
      case 'after_breakfast':
      case 'after breakfast':
        return 'AfterBreakfast';
      case '3':
      case 'noon':
        return 'Noon';
      case '4':
      case 'evening':
        return 'Evening';
      case '5':
      case 'lesson5':
      case 'lesson_5':
      case 'lesson 5':
        return 'Lesson5';
      case '6':
      case 'lesson6':
      case 'lesson_6':
      case 'lesson 6':
        return 'Lesson6';
      case '7':
      case 'study':
        return 'Study';
      case '8':
      case 'revision':
        return 'Revision';
      case 'lesson1':
      case 'lesson_1':
      case 'lesson 1':
        return 'Lesson1';
      case 'lesson2':
      case 'lesson_2':
      case 'lesson 2':
        return 'Lesson2';
      case 'lesson3':
      case 'lesson_3':
      case 'lesson 3':
        return 'Lesson3';
      case 'lesson4':
      case 'lesson_4':
      case 'lesson 4':
        return 'Lesson4';
      default:
        return (shiftRaw ?? '').toString();
    }
  }

  static List<Map<String, String>> _buildAttendanceRows(dynamic attendanceSource) {
    final List<Map<String, String>> rows = [];

    if (attendanceSource is! List) {
      return rows;
    }

    for (final dynamic item in attendanceSource) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> map = Map<String, dynamic>.from(item);
      final String date = map['date']?.toString() ?? '';
      final String studentId = map['student_id']?.toString() ?? '';

      if (date.isEmpty || studentId.isEmpty) {
        continue;
      }

      if (map.containsKey('shift') && map.containsKey('status')) {
        rows.add({
          'date': date,
          'student_id': studentId,
          'shift': _normalizeShiftLabel(map['shift']),
          'status': _normalizeAttendanceStatus(map['status']),
          'delay_minutes': map['delay_minutes']?.toString() ?? '',
        });
        continue;
      }

      if (map.containsKey('period_num') && map.containsKey('status')) {
        final periodStr = map['period_num']?.toString() ?? '1';
        final periodMap = {
          '1': 'Morning',
          '2': 'AfterBreakfast',
          '3': 'Noon',
          '4': 'Evening',
          '5': 'Lesson5',
          '6': 'Lesson6',
          '7': 'Study',
          '8': 'Revision',
        };
        rows.add({
          'date': date,
          'student_id': studentId,
          'shift': periodMap[periodStr] ?? periodStr,
          'status': _normalizeAttendanceStatus(map['status']),
          'delay_minutes': map['delay_minutes']?.toString() ?? '',
        });
        continue;
      }

      const Map<String, String> shiftMap = {
        '1': 'Morning',
        '2': 'AfterBreakfast',
        '3': 'Noon',
        '4': 'Evening',
        '5': 'Lesson5',
        '6': 'Lesson6',
        '7': 'Study',
        '8': 'Revision',
      };

      bool foundAnyShift = false;
      for (int i = 1; i <= 8; i++) {
        final String statusKey = 'status_$i';
        final String lateKey = 'late_$i';
        final dynamic rawStatus = map[statusKey];

        if (rawStatus == null || rawStatus.toString().trim().isEmpty) {
          continue;
        }

        foundAnyShift = true;
        rows.add({
          'date': date,
          'student_id': studentId,
          'shift': shiftMap['$i']!,
          'status': _normalizeAttendanceStatus(rawStatus),
          'delay_minutes': map[lateKey]?.toString() ?? '',
        });
      }

      if (!foundAnyShift && map.containsKey('status')) {
        final st = map['status']?.toString().trim() ?? '';
        if (st.isNotEmpty) {
          rows.add({
            'date': date,
            'student_id': studentId,
            'shift': 'Morning',
            'status': _normalizeAttendanceStatus(st),
            'delay_minutes': map['delay_minutes']?.toString() ?? '',
          });
        }
      }
    }

    return rows;
  }

  static Future<void> _ensureTeacherAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_teachers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER,
        date TEXT,
        status TEXT,
        late_minutes INTEGER DEFAULT 0,
        remarks TEXT,
        system_type TEXT DEFAULT 'Madrasa',
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        UNIQUE(teacher_id, date) ON CONFLICT REPLACE
      )
    ''');
  }

  static Future<void> _ensureTeacherPeriodAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_period_attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER,
        class_id INTEGER,
        class_name TEXT,
        date TEXT,
        period_no INTEGER,
        status TEXT DEFAULT 'P',
        late_minutes INTEGER DEFAULT 0,
        remarks TEXT,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        UNIQUE(teacher_id, class_id, date, period_no) ON CONFLICT REPLACE
      )
    ''');
  }

  static Future<void> _ensureTeacherLeavesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_leaves(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        teacher_id INTEGER,
        leave_type TEXT,
        start_date TEXT,
        end_date TEXT,
        reason TEXT,
        status TEXT DEFAULT 'Pending',
        approved_by TEXT,
        system_type TEXT DEFAULT 'Madrasa',
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    try {
      await db.execute("ALTER TABLE teacher_leaves ADD COLUMN system_type TEXT DEFAULT 'Madrasa'");
    } catch (_) {}
  }

  static Future<void> _ensureActivityLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        user_name TEXT,
        action_type TEXT,
        description TEXT,
        created_at TEXT
      )
    ''');
  }

  static Future<void> _ensureAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        shift TEXT,
        student_id TEXT,
        status TEXT,
        delay_minutes TEXT,
        system_type TEXT DEFAULT 'Madrasa',
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    try {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_date_std_shift 
        ON attendance(date, student_id, shift)
      ''');
    } catch (_) {}
  }

  static Future<void> save(Database db, Batch batch, Map<String, dynamic> data, List<List<int>> teacherIdRemaps) async {
    // 1. Teachers
    if (data['teachers'] != null) {
      try {
        for (var item in data['teachers']) {
          final serverTeacherId =
              int.tryParse(item['id']?.toString() ?? '') ?? 0;
          String cnic = item['cnic']?.toString() ?? '';
          String name = item['name']?.toString() ?? '';
          String fatherName = item['father_name']?.toString() ?? '';

          var existing = <Map<String, dynamic>>[];
          if (serverTeacherId > 0) {
            existing = await db.query('teachers',
                where: 'id = ?', whereArgs: [serverTeacherId], limit: 1);
          }
          if (existing.isEmpty && cnic.trim().isNotEmpty) {
            existing = await db.query('teachers',
                where: 'cnic = ?', whereArgs: [cnic], limit: 1);
          }
          if (existing.isEmpty && name.trim().isNotEmpty) {
            existing = await db.query(
              'teachers',
              where: 'name = ? AND father_name = ?',
              whereArgs: [name, fatherName],
              limit: 1,
            );
          }

          Map<String, dynamic> row = {
            'id': item['id'],
            'name': name,
            'father_name': fatherName,
            'phone': item['phone']?.toString() ?? '',
            'cnic': cnic,
            'qualification': item['qualification']?.toString() ?? '',
            'salary': item['salary']?.toString() ?? '',
            'house_rent': item['house_rent']?.toString() ?? '0',
            'medical_allowance': item['medical_allowance']?.toString() ?? '0',
            'travel_allowance': item['travel_allowance']?.toString() ?? '0',
            'daily_deduction_rate':
                item['daily_deduction_rate']?.toString() ?? '0',
            'joining_date': item['joining_date']?.toString() ?? '',
            'status': item['status']?.toString() ?? '',
            'address': item['address']?.toString() ?? '',
            'photo': item['photo']?.toString() ?? '',
            'assigned_classes': item['assigned_classes']?.toString() ?? '',
            'assigned_periods': item['assigned_periods']?.toString() ?? '',
            'system_type': (item['system_type']?.toString().isNotEmpty == true)
                ? item['system_type'].toString()
                : 'Madrasa',
            'is_deleted':
                int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
            'is_synced': 1,
          };

          if (existing.isNotEmpty) {
            final existingId =
                int.tryParse(existing.first['id']?.toString() ?? '') ?? 0;
            if (serverTeacherId > 0 &&
                existingId > 0 &&
                existingId != serverTeacherId) {
              teacherIdRemaps.add([existingId, serverTeacherId]);
            }
            batch.update('teachers', row,
                where: 'id = ?', whereArgs: [existing.first['id']]);
          } else {
            batch.insert('teachers', row,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      } catch (e) {
        debugPrint("Sync Error (teachers): $e");
      }
    }

    // 2. Student Attendance
    final dynamic attendanceSource =
        data['attendance_history'] ?? data['attendance'];
    if (attendanceSource != null) {
      try {
        await _ensureAttendanceTable(db);
        final List<Map<String, String>> attendanceRows =
            _buildAttendanceRows(attendanceSource);
        for (final row in attendanceRows) {
          batch.insert(
            'attendance',
            {
              'date': row['date'] ?? '',
              'shift': row['shift'] ?? '',
              'student_id': row['student_id'] ?? '',
              'status': row['status'] ?? '',
              'delay_minutes': row['delay_minutes'] ?? '',
              'system_type': 'Madrasa',
              'is_synced': 1,
              'is_deleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (attendance): $e");
      }
    }

    // 3. Attendance Teachers
    if (data['attendance_teachers'] != null) {
      try {
        await _ensureTeacherAttendanceTable(db);
        for (var item in data['attendance_teachers']) {
          batch.insert(
            'attendance_teachers',
            {
              'teacher_id': item['teacher_id'],
              'date': item['date']?.toString() ?? '',
              'status': item['status']?.toString() ?? '',
              'late_minutes':
                  int.tryParse(item['late_minutes']?.toString() ?? '0') ?? 0,
              'remarks': item['remarks']?.toString() ?? '',
              'system_type': item['system_type']?.toString() ?? 'Madrasa',
              'is_synced': 1,
              'is_deleted': int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (attendance_teachers): $e");
      }
    }

    // 4. Teacher Period Attendance
    if (data['teacher_period_attendance'] != null) {
      try {
        await _ensureTeacherPeriodAttendanceTable(db);
        for (var item in data['teacher_period_attendance']) {
          final serverId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
          batch.insert(
            'teacher_period_attendance',
            {
              'id': serverId > 0 ? serverId : null,
              'teacher_id': item['teacher_id'],
              'class_id': int.tryParse(item['class_id']?.toString() ?? ''),
              'class_name': item['class_name']?.toString() ?? '',
              'date': item['date']?.toString() ?? '',
              'period_no':
                  int.tryParse(item['period_no']?.toString() ?? '0') ?? 0,
              'status': item['status']?.toString() ?? 'P',
              'late_minutes':
                  int.tryParse(item['late_minutes']?.toString() ?? '0') ?? 0,
              'remarks': item['remarks']?.toString() ?? '',
              'is_deleted':
                  int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (teacher_period_attendance): $e");
      }
    }

    // 5. Teacher Leaves
    if (data['teacher_leaves'] != null) {
      try {
        await _ensureTeacherLeavesTable(db);
        for (var item in data['teacher_leaves']) {
          final serverId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
          final teacherId = int.tryParse(item['teacher_id']?.toString() ?? '') ?? 0;
          final startDate = item['start_date']?.toString() ?? '';
          if (teacherId <= 0 || startDate.isEmpty) continue;

          int? existingLocalId;
          if (serverId > 0) {
            final check = await db.rawQuery('SELECT id FROM teacher_leaves WHERE server_id = ? OR id = ? LIMIT 1', [serverId, serverId]);
            if (check.isNotEmpty) existingLocalId = check.first['id'] as int?;
          }
          if (existingLocalId == null) {
            final check = await db.rawQuery('SELECT id FROM teacher_leaves WHERE teacher_id = ? AND start_date = ? LIMIT 1', [teacherId, startDate]);
            if (check.isNotEmpty) existingLocalId = check.first['id'] as int?;
          }

          final leaveMap = {
            'server_id': serverId > 0 ? serverId : null,
            'teacher_id': teacherId,
            'leave_type': item['leave_type']?.toString() ?? 'اتفاقی',
            'start_date': startDate,
            'end_date': item['end_date']?.toString() ?? startDate,
            'reason': item['reason']?.toString() ?? '',
            'status': item['status']?.toString() ?? 'Pending',
            'approved_by': item['approved_by']?.toString(),
            'system_type': item['system_type']?.toString() ?? 'Madrasa',
            'created_at': item['created_at']?.toString(),
            'updated_at': item['updated_at']?.toString(),
            'is_deleted': int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
            'is_synced': 1,
          };

          if (existingLocalId != null) {
            batch.update('teacher_leaves', leaveMap, where: 'id = ?', whereArgs: [existingLocalId]);
          } else {
            batch.insert('teacher_leaves', leaveMap);
          }
        }
      } catch (e) {
        debugPrint("Sync Error (teacher_leaves): $e");
      }
    }

    // 6. Activity Logs
    if (data['activity_logs'] != null) {
      try {
        await _ensureActivityLogsTable(db);
        for (var item in data['activity_logs']) {
          final sId = int.tryParse(item['id']?.toString() ?? '') ?? 0;
          if (sId > 0) {
            final check = await db.rawQuery('SELECT id FROM activity_logs WHERE id = ? LIMIT 1', [sId]);
            if (check.isEmpty) {
              batch.insert('activity_logs', {
                'id': sId,
                'user_id': int.tryParse(item['user_id']?.toString() ?? ''),
                'user_name': item['user_name']?.toString() ?? 'سسٹم',
                'action_type': item['action_type']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
                'created_at': item['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              });
            }
          }
        }
      } catch (e) {
        debugPrint("Sync Error (activity_logs): $e");
      }
    }
  }
}
