import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'utils/globals.dart';
import 'utils/system_type_global.dart';

class DBHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'madrasa.db');
    return await openDatabase(
      path,
      version: 36,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE students ADD COLUMN password TEXT");
          } catch (_) {
            // Ignore if column already exists.
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS exams(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              exam_name TEXT,
              exam_date TEXT,
              is_synced INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS notices(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,
              message TEXT,
              date TEXT,
              is_synced INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS complaints(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              student_id INTEGER,
              complaint TEXT,
              date TEXT,
              is_synced INTEGER DEFAULT 0
            )
          ''');
        }

        if (oldVersion < 4) {
          try {
            await db.execute("ALTER TABLE finance ADD COLUMN head_id INTEGER");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE finance ADD COLUMN manual_receipt_no TEXT");
          } catch (_) {}
          try {
            await db
                .execute("ALTER TABLE finance ADD COLUMN server_id INTEGER");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE finance ADD COLUMN donor_name TEXT");
          } catch (_) {}
          try {
            await db
                .execute("ALTER TABLE finance ADD COLUMN donor_address TEXT");
          } catch (_) {}
        }
        if (oldVersion < 17) {
          try {
            await db.execute(
                "ALTER TABLE finance ADD COLUMN computer_receipt_no INTEGER");
          } catch (_) {}
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS parent_complaints(
              id INTEGER PRIMARY KEY,
              student_id INTEGER,
              date TEXT,
              category TEXT,
              description TEXT,
              status TEXT,
              is_synced INTEGER DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS leave_applications(
              id INTEGER PRIMARY KEY,
              student_id INTEGER,
              date_from TEXT,
              date_to TEXT,
              reason TEXT,
              status TEXT,
              is_synced INTEGER DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS fee_submissions(
              id INTEGER PRIMARY KEY,
              student_id INTEGER,
              amount REAL,
              submission_date TEXT,
              screenshot TEXT,
              status TEXT,
              is_synced INTEGER DEFAULT 1
            )
          ''');
        }
        if (oldVersion < 6) {
          try {
            await db.execute(
                "ALTER TABLE students ADD COLUMN status TEXT DEFAULT 'Active'");
            await db
                .execute("ALTER TABLE students ADD COLUMN admission_date TEXT");
            await db.execute(
                "ALTER TABLE students ADD COLUMN graduation_date TEXT");
            await db.execute("ALTER TABLE students ADD COLUMN duration TEXT");
            await db.execute("ALTER TABLE students ADD COLUMN photo TEXT");
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try {
            await db
                .execute("ALTER TABLE students ADD COLUMN leaving_reason TEXT");
            await db.execute(
                "ALTER TABLE students ADD COLUMN serial_no INTEGER DEFAULT 0");
            await db.execute(
                "ALTER TABLE students ADD COLUMN hijri_year INTEGER DEFAULT 1447");
          } catch (_) {}
        }
        if (oldVersion < 9) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS settings(
                id INTEGER PRIMARY KEY,
                madrasa_name TEXT,
                phone TEXT,
                current_hijri_year TEXT,
                week_start_day INTEGER DEFAULT 6,
                ai_provider TEXT,
                gemini_api_key TEXT,
                groq_api_key TEXT,
                whatsapp_api_key TEXT,
                sms_api_key TEXT,
                auto_notify_day INTEGER,
                auto_notify_time TEXT
              )
            ''');
          } catch (_) {}
          try {
            await db
                .execute('ALTER TABLE settings ADD COLUMN ai_provider TEXT');
          } catch (_) {}
          try {
            await db
                .execute('ALTER TABLE settings ADD COLUMN gemini_api_key TEXT');
          } catch (_) {}
          try {
            await db
                .execute('ALTER TABLE settings ADD COLUMN groq_api_key TEXT');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE settings ADD COLUMN whatsapp_api_key TEXT');
          } catch (_) {}
          try {
            await db
                .execute('ALTER TABLE settings ADD COLUMN sms_api_key TEXT');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE settings ADD COLUMN auto_notify_day INTEGER');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE settings ADD COLUMN auto_notify_time TEXT');
          } catch (_) {}
        }
        if (oldVersion < 10) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS classes(
              id INTEGER PRIMARY KEY,
              name TEXT,
              section TEXT,
              status TEXT DEFAULT 'Active',
              class_type TEXT DEFAULT 'Regular',
              main_teacher_ids TEXT,
              p1_name TEXT DEFAULT 'Period 1',
              p2_name TEXT DEFAULT 'Period 2',
              p3_name TEXT DEFAULT 'Period 3',
              p4_name TEXT DEFAULT 'Period 4',
              p5_name TEXT DEFAULT 'Period 5',
              p6_name TEXT DEFAULT 'Period 6',
              subjects_list TEXT,
              is_synced INTEGER DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS exam_results(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              exam_id INTEGER,
              student_id INTEGER,
              subject TEXT DEFAULT 'Quran',
              marks_obtained REAL,
              total_marks REAL,
              grade TEXT,
              status TEXT,
              late_minutes INTEGER DEFAULT 0,
              remarks TEXT,
              pukhtagi INTEGER DEFAULT 0,
              tajweed INTEGER DEFAULT 0,
              lahja INTEGER DEFAULT 0,
              masail INTEGER DEFAULT 0,
              miqdar_khwandgi TEXT DEFAULT '',
              p1 INTEGER DEFAULT 0,
              p2 INTEGER DEFAULT 0,
              p3 INTEGER DEFAULT 0,
              p4 INTEGER DEFAULT 0,
              p5 INTEGER DEFAULT 0,
              p6 INTEGER DEFAULT 0,
              subjects_marks TEXT,
              is_deleted INTEGER DEFAULT 0,
              is_synced INTEGER DEFAULT 1
            )
          ''');
        }
        if (oldVersion < 12) {
          try {
            await db.execute(
                "ALTER TABLE leave_applications ADD COLUMN application_photo TEXT");
          } catch (_) {}
        }
        if (oldVersion < 13) {
          try {
            await db.execute(
                "ALTER TABLE fee_submissions ADD COLUMN head_id INTEGER");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE fee_submissions ADD COLUMN description TEXT");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE fee_submissions ADD COLUMN finance_id INTEGER");
          } catch (_) {}
        }
        if (oldVersion < 14) {
          try {
            await db.execute(
                "ALTER TABLE exam_results ADD COLUMN subject TEXT DEFAULT 'Quran'");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE exam_results ADD COLUMN pukhtagi INTEGER DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE exam_results ADD COLUMN tajweed INTEGER DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE exam_results ADD COLUMN lahja INTEGER DEFAULT 0");
          } catch (_) {}
        }
        if (oldVersion < 16) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS academic_reports(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              student_id INTEGER,
              date TEXT,
              class_name TEXT,
              subject TEXT,
              lesson_details TEXT,
              grade TEXT,
              remarks TEXT,
              is_deleted INTEGER DEFAULT 0,
              is_synced INTEGER DEFAULT 0
            )
          ''');
        }

        if (oldVersion < 18) {
          final tables = [
            'students',
            'teachers',
            'finance',
            'hifz_record',
            'nazira_record',
            'attendance',
            'academic_reports',
            'fee_submissions',
            'leave_applications',
            'parent_complaints',
            'complaints',
            'notices',
            'exams',
            'exam_results'
          ];
          for (var table in tables) {
            try {
              await db.execute(
                  'ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0');
            } catch (_) {}
          }
        }

        if (oldVersion < 19) {
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN masail INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN miqdar_khwandgi TEXT DEFAULT ""');
          } catch (_) {}
        }
        if (oldVersion < 20) {
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN p1 INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN p2 INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN p3 INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN p4 INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN p5 INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE exam_results ADD COLUMN p6 INTEGER DEFAULT 0');
          } catch (_) {}
        }
        if (oldVersion < 21) {
          try {
            await db.execute('ALTER TABLE classes ADD COLUMN section TEXT');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN main_teacher_ids TEXT');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN class_type TEXT DEFAULT "Regular"');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN p1_name TEXT DEFAULT "Period 1"');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN p2_name TEXT DEFAULT "Period 2"');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN p3_name TEXT DEFAULT "Period 3"');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN p4_name TEXT DEFAULT "Period 4"');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN p5_name TEXT DEFAULT "Period 5"');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE classes ADD COLUMN p6_name TEXT DEFAULT "Period 6"');
          } catch (_) {}
        }

        if (oldVersion < 23) {
          final allTables = [
            'students',
            'teachers',
            'finance',
            'hifz_record',
            'nazira_record',
            'attendance',
            'academic_reports',
            'fee_submissions',
            'leave_applications',
            'parent_complaints',
            'complaints',
            'notices',
            'exams',
            'exam_results',
            'classes'
          ];
          for (var table in allTables) {
            try {
              await db.execute(
                  'ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0');
            } catch (_) {}
          }
        }
        if (oldVersion < 24) {
          try {
            await db.execute(
                'ALTER TABLE finance ADD COLUMN user_id INTEGER DEFAULT 1');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE finance ADD COLUMN user_name TEXT');
          } catch (_) {}
        }

        if (oldVersion < 25) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS acc_payroll(
              id INTEGER PRIMARY KEY,
              teacher_id INTEGER,
              month_year TEXT,
              basic_salary REAL DEFAULT 0,
              allowances REAL DEFAULT 0,
              deductions REAL DEFAULT 0,
              net_salary REAL DEFAULT 0,
              status TEXT DEFAULT 'Unpaid',
              payment_date TEXT,
              is_deleted INTEGER DEFAULT 0,
              is_synced INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS acc_invoices(
              id INTEGER PRIMARY KEY,
              student_id INTEGER,
              invoice_no TEXT,
              month_year TEXT,
              amount REAL,
              status TEXT DEFAULT 'Unpaid',
              is_deleted INTEGER DEFAULT 0,
              is_synced INTEGER DEFAULT 0
            )
          ''');
        }

        if (oldVersion < 26) {
          try {
            await db.execute(
                "ALTER TABLE teachers ADD COLUMN house_rent REAL DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE teachers ADD COLUMN medical_allowance REAL DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE teachers ADD COLUMN travel_allowance REAL DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE teachers ADD COLUMN daily_deduction_rate REAL DEFAULT 0");
          } catch (_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS attendance_teachers(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              teacher_id INTEGER,
              date TEXT,
              status TEXT,
              late_minutes INTEGER DEFAULT 0,
              remarks TEXT,
              is_synced INTEGER DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 28) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS nazira_record(
              id INTEGER PRIMARY KEY,
              student_id INTEGER,
              date TEXT,
              morning_sabaq TEXT,
              morning_status TEXT,
              evening_sabaq TEXT,
              evening_status TEXT,
              is_synced INTEGER DEFAULT 0
            )
          ''');
        }
        await forceMigrate(db);

        if (oldVersion < 29) {
          try {
            await db
                .execute("ALTER TABLE hifz_record ADD COLUMN sabaq_time TEXT");
            await db
                .execute("ALTER TABLE hifz_record ADD COLUMN sabqi_time TEXT");
            await db
                .execute("ALTER TABLE hifz_record ADD COLUMN manzil_time TEXT");
          } catch (_) {}
        }
        if (oldVersion < 30) {
          try {
            await db.execute("ALTER TABLE teachers ADD COLUMN photo TEXT");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE teachers ADD COLUMN assigned_classes TEXT");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE teachers ADD COLUMN assigned_periods TEXT");
          } catch (_) {}
        }
        if (oldVersion < 31) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS departments(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              description TEXT,
              status TEXT DEFAULT 'Active',
              is_deleted INTEGER DEFAULT 0,
              is_synced INTEGER DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 32) {
          try {
            await db.execute(
                "ALTER TABLE exams ADD COLUMN total_marks REAL DEFAULT 100");
          } catch (_) {}
          try {
            await db.execute(
                "ALTER TABLE exams ADD COLUMN passing_marks REAL DEFAULT 33");
          } catch (_) {}
        }
        if (oldVersion < 33) {
          await _createAccountingTables(db);
        }
        if (oldVersion < 34) {
          try {
            await db.execute(
                "ALTER TABLE teachers ADD COLUMN status TEXT DEFAULT 'Active'");
          } catch (_) {}
        }
        if (oldVersion < 35) {
          try {
            await db.execute(
                "ALTER TABLE acc_chart_of_accounts ADD COLUMN parent_id INTEGER");
          } catch (_) {}
        }
        if (oldVersion < 36) {
          // مسجد فنانس کی الگ ٹیبل بنائیں
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS masjid_finance(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                server_id INTEGER,
                date TEXT,
                type TEXT,
                amount REAL,
                description TEXT,
                head_id INTEGER,
                head_name TEXT,
                manual_receipt_no TEXT,
                computer_receipt_no INTEGER,
                donor_name TEXT,
                donor_address TEXT,
                spender_name TEXT,
                signature_image TEXT,
                receipt_no TEXT,
                user_id INTEGER DEFAULT 1,
                user_name TEXT,
                system_type TEXT DEFAULT 'Masjid',
                is_deleted INTEGER DEFAULT 0,
                is_synced INTEGER DEFAULT 0
              )
            ''');
          } catch (_) {}
          // finance ٹیبل میں system_type کالم شامل کریں
          try {
            await db.execute("ALTER TABLE finance ADD COLUMN system_type TEXT DEFAULT 'Madrasa'");
            await db.execute("UPDATE finance SET system_type = 'Madrasa' WHERE system_type IS NULL");
          } catch (_) {}
          // مسجد فنانس ہیڈز کی ٹیبل
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS masjid_acc_chart_of_accounts(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT,
                name TEXT,
                type TEXT,
                system_type TEXT DEFAULT 'Masjid',
                is_deleted INTEGER DEFAULT 0,
                is_synced INTEGER DEFAULT 0
              )
            ''');
          } catch (_) {}
        }
      },
      onOpen: (db) async {
        await forceMigrate(db);
      },
      onCreate: (db, version) async {
        await forceMigrate(db);
        await db.execute('''
          CREATE TABLE IF NOT EXISTS students(
            id INTEGER PRIMARY KEY,
            name TEXT,
            father_name TEXT,
            roll_number TEXT,
            class_name TEXT,
            contact_number TEXT,
            address TEXT,
            password TEXT,
            status TEXT DEFAULT 'Active',
            admission_date TEXT,
            graduation_date TEXT,
            duration TEXT,
            photo TEXT,
            leaving_reason TEXT,
            serial_no INTEGER DEFAULT 0,
            hijri_year INTEGER DEFAULT 1447,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS teachers(
            id INTEGER PRIMARY KEY,
            name TEXT,
            father_name TEXT,
            phone TEXT,
            cnic TEXT,
            qualification TEXT,
            salary TEXT,
            house_rent REAL DEFAULT 0,
            medical_allowance REAL DEFAULT 0,
            travel_allowance REAL DEFAULT 0,
            daily_deduction_rate REAL DEFAULT 0,
            joining_date TEXT,
            status TEXT,
            address TEXT,
            photo TEXT,
            assigned_classes TEXT,
            assigned_periods TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS departments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            description TEXT,
            status TEXT DEFAULT 'Active',
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS academic_reports(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            date TEXT,
            class_name TEXT,
            subject TEXT,
            lesson_details TEXT,
            grade TEXT,
            remarks TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS qaida_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            date TEXT,
            sabaq_1 TEXT, qty_1 TEXT, grade_1 TEXT,
            sabaq_2 TEXT, qty_2 TEXT, grade_2 TEXT,
            sabaq_3 TEXT, qty_3 TEXT, grade_3 TEXT,
            sabaq_4 TEXT, qty_4 TEXT, grade_4 TEXT,
            lesson_type TEXT DEFAULT 'نورانی قاعدہ',
            hearing_time TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS hifz_record(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER,
            date TEXT,
            student_id TEXT,
            sabaq_para TEXT,
            sabaq_lines TEXT,
            sabaq_grade TEXT,
            sabqi_para TEXT,
            sabqi_qty TEXT,
            sabqi_grade TEXT,
            sabqi_listener TEXT,
            manzil_total_qty TEXT,
            manzil_details TEXT,
            manzil_grade TEXT,
            manzil_listener TEXT,
            sabaq_time TEXT,
            sabqi_time TEXT,
            manzil_time TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS nazira_record(
            id INTEGER PRIMARY KEY,
            student_id INTEGER,
            date TEXT,
            morning_sabaq TEXT,
            morning_qty TEXT,
            morning_time TEXT,
            morning_status TEXT,
            evening_sabaq TEXT,
            evening_qty TEXT,
            evening_time TEXT,
            evening_status TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS attendance(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            shift TEXT,
            student_id TEXT,
            status TEXT,
            delay_minutes TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS finance(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER,
            date TEXT,
            type TEXT,
            amount REAL,
            description TEXT,
            head_id INTEGER,
            manual_receipt_no TEXT,
            donor_name TEXT,
            donor_address TEXT,
            computer_receipt_no INTEGER,
            user_id INTEGER DEFAULT 1,
            user_name TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS heads(
            id INTEGER PRIMARY KEY,
            name TEXT,
            type TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS exams(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_name TEXT,
            exam_date TEXT,
            total_marks REAL DEFAULT 100,
            passing_marks REAL DEFAULT 33,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS notices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            message TEXT,
            date TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS complaints(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            complaint TEXT,
            date TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS parent_complaints(
            id INTEGER PRIMARY KEY,
            student_id INTEGER,
            date TEXT,
            category TEXT,
            description TEXT,
            status TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS leave_applications(
            id INTEGER PRIMARY KEY,
            student_id INTEGER,
            date_from TEXT,
            date_to TEXT,
            reason TEXT,
            status TEXT,
            application_photo TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS fee_submissions(
            id INTEGER PRIMARY KEY,
            student_id INTEGER,
            amount REAL,
            submission_date TEXT,
            screenshot TEXT,
            status TEXT,
            head_id INTEGER,
            description TEXT,
            finance_id INTEGER,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings(
            id INTEGER PRIMARY KEY,
            madrasa_name TEXT,
            phone TEXT,
            current_hijri_year TEXT,
            week_start_day INTEGER DEFAULT 6,
            ai_provider TEXT,
            gemini_api_key TEXT,
            groq_api_key TEXT,
            whatsapp_api_key TEXT,
            sms_api_key TEXT,
            auto_notify_day INTEGER,
            auto_notify_time TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS classes(
            id INTEGER PRIMARY KEY,
            name TEXT,
            section TEXT,
            status TEXT DEFAULT 'Active',
            class_type TEXT DEFAULT 'Regular',
            main_teacher_ids TEXT,
            p1_name TEXT DEFAULT 'Period 1',
            p2_name TEXT DEFAULT 'Period 2',
            p3_name TEXT DEFAULT 'Period 3',
            p4_name TEXT DEFAULT 'Period 4',
            p5_name TEXT DEFAULT 'Period 5',
            p6_name TEXT DEFAULT 'Period 6',
            subjects_list TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS exam_results(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id INTEGER,
            student_id INTEGER,
            subject TEXT DEFAULT 'Quran',
            marks_obtained REAL,
            total_marks REAL,
            grade TEXT,
            status TEXT,
            remarks TEXT,
            pukhtagi INTEGER DEFAULT 0,
            tajweed INTEGER DEFAULT 0,
            lahja INTEGER DEFAULT 0,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS acc_payroll(
            id INTEGER PRIMARY KEY,
            teacher_id INTEGER,
            month_year TEXT,
            basic_salary REAL DEFAULT 0,
            allowances REAL DEFAULT 0,
            deductions REAL DEFAULT 0,
            net_salary REAL DEFAULT 0,
            status TEXT DEFAULT 'Unpaid',
            payment_date TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS acc_invoices(
            id INTEGER PRIMARY KEY,
            student_id INTEGER,
            invoice_no TEXT,
            month_year TEXT,
            amount REAL,
            status TEXT DEFAULT 'Unpaid',
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getClasses() async {
    Database db = await database;
    return await db.query('classes',
        where: 'is_deleted = 0 OR is_deleted IS NULL', orderBy: 'id ASC');
  }

  /// Role-based class list:
  /// - admin/nazim → تمام classes
  /// - teacher → صرف assigned classes (sync_down پہلے سے filter کر چکا ہے)
  Future<List<Map<String, dynamic>>> getClassesForUser() async {
    final role = currentUserRole.value?.toLowerCase() ?? '';
    // Admin/Nazim کو سب کچھ
    if (role == 'admin' || role == 'nazim') {
      return getClasses();
    }
    // Teacher: صرف allowed classes (جو server سے sync ہوئی ہیں)
    final assigned = currentUserAssignedClasses.value;
    if (assigned.isEmpty) {
      // اگر assigned خالی ہے تو سب classes (backward compatibility)
      return getClasses();
    }
    final db = await database;
    final placeholders = assigned.map((_) => '?').join(',');
    return await db.rawQuery(
      'SELECT * FROM classes WHERE name IN ($placeholders) AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY id ASC',
      assigned,
    );
  }

  /// Role-based student list with pagination:
  /// - admin/nazim → تمام students
  /// - teacher → صرف assigned classes کے students
  Future<List<Map<String, dynamic>>> getPagedStudentsForUser({
    int limit = 30,
    int offset = 0,
    String? searchQuery,
    String? status,
  }) async {
    final role = currentUserRole.value?.toLowerCase() ?? '';
    final assigned = currentUserAssignedClasses.value;

    // Admin/Nazim یا خالی assignment → معمول کی function
    if (role == 'admin' || role == 'nazim' || assigned.isEmpty) {
      return getPagedStudents(
          limit: limit, offset: offset, searchQuery: searchQuery, status: status);
    }

    // Teacher: صرف assigned classes کے students
    Database db = await database;
    final List<String> conditions = [];
    final List<dynamic> args = [];

    conditions.add('(is_deleted = 0 OR is_deleted IS NULL)');

    // Class filter
    final placeholders = assigned.map((_) => '?').join(',');
    conditions.add('class_name IN ($placeholders)');
    args.addAll(assigned);

    if (status != null) {
      if (status == 'Active') {
        conditions.add(
            "(LOWER(TRIM(status)) IN ('active', 'present', '') OR status IS NULL)");
      } else if (status == 'Alumni') {
        conditions.add(
            "LOWER(TRIM(status)) IN ('alumni', 'graduated', 'finished', 'فارغ')");
      } else {
        conditions.add('LOWER(status) = ?');
        args.add(status.toLowerCase());
      }
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(name LIKE ? OR roll_number LIKE ? OR class_name LIKE ?)');
      final q = '%$searchQuery%';
      args.addAll([q, q, q]);
    }

    final where = conditions.join(' AND ');
    return await db.query(
      'students',
      where: where,
      whereArgs: args,
      limit: limit,
      offset: offset,
      orderBy: 'name ASC',
    );
  }

  Future<int> insertClass(Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['status'] = data['status'] ?? 'Active';
    data['class_type'] = data['class_type'] ?? 'Darse Nizami';
    return await db.insert('classes', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateClass(int id, Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return db.update('classes', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteClass(int id) async {
    Database db = await database;
    return db.update('classes', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertStudent(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    final admNo = data['roll_number']?.toString().trim().toLowerCase() ?? '';
    if (admNo.isNotEmpty) {
      final existing = await db.query(
        'students',
        where:
            "LOWER(TRIM(roll_number)) = ? AND (LOWER(status) IN ('active', 'present', '') OR status IS NULL)",
        whereArgs: [admNo],
        limit: 1,
      );
      if (existing.isNotEmpty) return -1;
    }
    return await db.insert('students', data);
  }

  Future<int> updateStudent(int id, Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.update('students', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStudent(int id) async {
    Database db = await database;
    return await db.update(
        'students', {'status': 'Deleted', 'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _createAccountingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS acc_chart_of_accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT,
        name TEXT,
        type TEXT,
        parent_id INTEGER,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS acc_vouchers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_no TEXT,
        date TEXT,
        type TEXT,
        reference TEXT,
        description TEXT,
        department_id INTEGER,
        status TEXT DEFAULT 'Pending',
        created_by INTEGER,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS acc_ledger_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_id INTEGER,
        account_id INTEGER,
        debit REAL DEFAULT 0,
        credit REAL DEFAULT 0,
        department_id INTEGER,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getStudents() async {
    Database db = await database;
    try {
      return await db.query('students',
          where:
              "(status IS NULL OR LOWER(TRIM(status)) IN ('active', '', 'present', 'حاضر')) AND (is_deleted = 0 OR is_deleted IS NULL)",
          orderBy: 'name ASC');
    } catch (e) {
      // Fallback if column missing during mid-sync/upgrade
      debugPrint("getStudents error: $e");
      return await db.query('students', orderBy: 'name ASC');
    }
  }

  Future<List<Map<String, dynamic>>> getPagedStudents({
    int limit = 30,
    int offset = 0,
    String? searchQuery,
    String? status,
  }) async {
    Database db = await database;
    final List<String> conditions = [];
    final List<dynamic> args = [];

    conditions.add("(is_deleted = 0 OR is_deleted IS NULL)");

    if (status != null) {
      if (status == 'Active') {
        conditions.add(
            "LOWER(TRIM(status)) IN ('active', 'present', '') OR status IS NULL");
      } else if (status == 'Alumni') {
        conditions.add(
            "LOWER(TRIM(status)) IN ('alumni', 'graduated', 'finished', 'فارغ')");
      } else {
        conditions.add('LOWER(status) = ?');
        args.add(status.toLowerCase());
      }
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions
          .add('(name LIKE ? OR roll_number LIKE ? OR class_name LIKE ?)');
      final q = '%$searchQuery%';
      args.addAll([q, q, q]);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');

    return await db.query(
      'students',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      limit: limit,
      offset: offset,
      orderBy: 'name ASC',
    );
  }


  Future<List<Map<String, dynamic>>> getQaidaRecords() async {
    final db = await database;
    return await db.query('qaida_records');
  }
  Future<List<Map<String, dynamic>>> getHifzRecords() async {
    Database db = await database;
    return await db.query('hifz_record');
  }

  Future<String> getNextStudentRollNumber({int? hijriYear}) async {
    final db = await database;
    if (hijriYear == null) {
      final s = await db.query('settings', limit: 1);
      hijriYear = (s.isNotEmpty && s.first['current_hijri_year'] != null) ? (int.tryParse(s.first['current_hijri_year'].toString()) ?? 1447) : 1447;
    }
    final prefix = '$hijriYear-';
    final rows = await db.query(
      'students',
      columns: ['roll_number'],
      where: 'roll_number LIKE ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: ['$prefix%'],
    );

    var highestSerial = 0;
    for (final row in rows) {
      final rollNumber = row['roll_number']?.toString() ?? '';
      final serial = int.tryParse(rollNumber.split('-').last);
      if (serial != null && serial > highestSerial) {
        highestSerial = serial;
      }
    }

    return '$prefix${(highestSerial + 1).toString().padLeft(2, '0')}';
  }

  Future<int> insertHifz(Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('hifz_record', data);
  }

  Future<List<Map<String, dynamic>>> getNaziraRecords() async {
    final db = await database;
    return await db.query('nazira_record');
  }

  Future<int> insertNazira(Map<String, dynamic> row) async {
    final db = await database;
    Map<String, dynamic> data = Map.from(row);
    data['is_synced'] = 0;
    return await db.insert('nazira_record', data);
  }

  Future<List<Map<String, dynamic>>> getTeachers() async {
    Database db = await database;
    try {
      return await db.query('teachers',
          where: "is_deleted = 0 OR is_deleted IS NULL");
    } catch (e) {
      debugPrint("getTeachers error: $e");
      return await db.query('teachers');
    }
  }

  Future<int> updateTeacher(int id, Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['status'] = data['status'] ?? 'Active';
    return await db.update('teachers', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertTeacher(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['status'] = data['status'] ?? 'Active';
    return await db.insert('teachers', data);
  }

  Future<void> _createTeacherAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_teachers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER,
        date TEXT,
        status TEXT,
        late_minutes INTEGER DEFAULT 0,
        remarks TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> insertTeacherAttendance(Map<String, dynamic> row) async {
    Database db = await database;
    await _createTeacherAttendanceTable(db);
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;

    final existing = await db.query(
      'attendance_teachers',
      where: 'date = ? AND teacher_id = ?',
      whereArgs: [data['date'], data['teacher_id']],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'attendance_teachers',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
    return await db.insert('attendance_teachers', data);
  }

  Future<List<Map<String, dynamic>>> getTeacherAttendanceByDate(
      String date) async {
    Database db = await database;
    await _createTeacherAttendanceTable(db);
    return await db
        .query('attendance_teachers', where: 'date = ?', whereArgs: [date]);
  }

  Future<List<Map<String, dynamic>>> getTeacherAttendanceByRange(
      String startDate, String endDate) async {
    Database db = await database;
    await _createTeacherAttendanceTable(db);
    return await db.rawQuery('''
      SELECT at.*, t.name AS teacher_name, t.phone
      FROM attendance_teachers at
      JOIN teachers t ON at.teacher_id = t.id
      WHERE at.date BETWEEN ? AND ?
      ORDER BY at.date ASC, t.name ASC
    ''', [startDate, endDate]);
  }

  Future<int> insertTeacherPeriodAttendance(Map<String, dynamic> row) async {
    Database db = await database;
    await _createTeacherPeriodAttendanceTable(db);
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    final existing = await db.query(
      'teacher_period_attendance',
      where: 'date = ? AND teacher_id = ? AND class_name = ? AND period_no = ?',
      whereArgs: [
        data['date'],
        data['teacher_id'],
        data['class_name'] ?? '',
        data['period_no']
      ],
      limit: 1,
    );
    final result = existing.isNotEmpty
        ? await db.update('teacher_period_attendance', data,
            where: 'id = ?', whereArgs: [existing.first['id']])
        : await db.insert('teacher_period_attendance', data);
    await _syncTeacherDailyAttendanceSummary(
      db,
      data['teacher_id'],
      data['date']?.toString() ?? '',
    );
    return result;
  }

  Future<void> _syncTeacherDailyAttendanceSummary(
      Database db, dynamic teacherIdValue, String date) async {
    await _createTeacherAttendanceTable(db);
    final teacherId = int.tryParse(teacherIdValue?.toString() ?? '') ?? 0;
    if (teacherId == 0 || date.isEmpty) return;
    final rows = await db.query(
      'teacher_period_attendance',
      where:
          'teacher_id = ? AND date = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [teacherId, date],
    );
    if (rows.isEmpty) return;
    var status = 'A';
    var maxLate = 0;
    for (final row in rows) {
      final raw = row['status']?.toString() ?? 'P';
      final normalized = _normalizeTeacherAttendanceStatus(raw);
      if (normalized == 'P') {
        status = 'P';
      } else if (status != 'P' && normalized == 'L') {
        status = 'L';
      }
      final late = int.tryParse(row['late_minutes']?.toString() ?? '0') ?? 0;
      if (late > maxLate) maxLate = late;
    }
    await insertTeacherAttendance({
      'teacher_id': teacherId,
      'date': date,
      'status': status,
      'late_minutes': maxLate,
      'remarks': maxLate.toString(),
    });
  }

  String _normalizeTeacherAttendanceStatus(String status) {
    final clean = status.trim();
    final code = clean.toUpperCase();
    if (clean == '\u062d\u0627\u0636\u0631' || code == 'P') return 'P';
    if (clean == '\u063a\u06cc\u0631 \u062d\u0627\u0636\u0631' || code == 'A') {
      return 'A';
    }
    if (clean ==
            '\u0631\u062e\u0635\u062a \u0627\u062a\u0641\u0627\u0642\u06cc' ||
        code == 'LA') {
      return 'L';
    }
    if (clean == '\u0631\u062e\u0635\u062a' || code == 'L') {
      return 'L';
    }
    if (clean == '\u0628\u06a9\u0627\u0631 \u0645\u062f\u0631\u0633\u06c1' ||
        code == 'OD') {
      return 'P';
    }
    return clean.isEmpty ? 'P' : clean;
  }

  Future<List<Map<String, dynamic>>> getTeacherPeriodAttendanceByDate(
      String date) async {
    Database db = await database;
    await _createTeacherPeriodAttendanceTable(db);
    return db.query('teacher_period_attendance',
        where: 'date = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
        whereArgs: [date]);
  }

  Future<int> insertAttendance(Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;

    // Check for existing record to avoid duplicates
    final existing = await db.query(
      'attendance',
      where: 'date = ? AND student_id = ? AND shift = ?',
      whereArgs: [data['date'], data['student_id'], data['shift']],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'attendance',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      return await db.insert('attendance', data);
    }
  }

  Future<List<Map<String, dynamic>>> getAttendance() async {
    Database db = await database;
    return await db.query('attendance');
  }

  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    Database db = await database;
    return await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<List<Map<String, dynamic>>> getFinance({int? userId, String? userRole}) async {
    Database db = await database;
    final role = (userRole ?? currentUserRole.value)?.toLowerCase() ?? '';
    final targetUserId = userId ?? currentUserId.value;
    // صرف Madrasa کا ڈیٹا دکھائیں (Masjid کا ڈیٹا الگ masjid_finance ٹیبل میں ہے)
    const sysType = 'Madrasa';

    if (role == 'admin') {
      return await db.query(
        'finance',
        where: '(is_deleted = 0 OR is_deleted IS NULL) AND (system_type = ? OR system_type IS NULL)',
        whereArgs: [sysType],
        orderBy: 'user_id ASC, date DESC, id DESC',
      );
    }

    if (targetUserId != null) {
      return await db.query(
        'finance',
        where: 'user_id = ? AND (is_deleted = 0 OR is_deleted IS NULL) AND (system_type = ? OR system_type IS NULL)',
        whereArgs: [targetUserId, sysType],
        orderBy: 'date DESC, id DESC',
      );
    }

    return await db.query(
      'finance',
      where: '(is_deleted = 0 OR is_deleted IS NULL) AND (system_type = ? OR system_type IS NULL)',
      whereArgs: [sysType],
      orderBy: 'date DESC, id DESC',
    );
  }

  // ═══════════════════════════════════════════════════════
  // مسجد فنانس CRUD فنکشنز (الگ masjid_finance ٹیبل)
  // ═══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getMasjidFinance({int? userId, String? userRole}) async {
    Database db = await database;
    final role = (userRole ?? currentUserRole.value)?.toLowerCase() ?? '';
    final targetUserId = userId ?? currentUserId.value;

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS masjid_finance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          date TEXT, type TEXT, amount REAL, description TEXT,
          head_id INTEGER, head_name TEXT,
          manual_receipt_no TEXT, computer_receipt_no INTEGER,
          donor_name TEXT, donor_address TEXT,
          spender_name TEXT, signature_image TEXT, receipt_no TEXT,
          user_id INTEGER DEFAULT 1, user_name TEXT,
          system_type TEXT DEFAULT 'Masjid',
          is_deleted INTEGER DEFAULT 0, is_synced INTEGER DEFAULT 0
        )
      ''');
    } catch (_) {}

    if (role == 'admin') {
      return await db.query(
        'masjid_finance',
        where: '(is_deleted = 0 OR is_deleted IS NULL)',
        orderBy: 'user_id ASC, date DESC, id DESC',
      );
    }

    if (targetUserId != null) {
      return await db.query(
        'masjid_finance',
        where: 'user_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
        whereArgs: [targetUserId],
        orderBy: 'date DESC, id DESC',
      );
    }

    return await db.query(
      'masjid_finance',
      where: '(is_deleted = 0 OR is_deleted IS NULL)',
      orderBy: 'date DESC, id DESC',
    );
  }

  Future<Map<int, Map<String, dynamic>>> getMasjidFinanceGroupedByUser() async {
    final records = await getMasjidFinance(userRole: 'admin');
    final Map<int, Map<String, dynamic>> grouped = {};
    for (var r in records) {
      final uid = (r['user_id'] as int?) ?? 0;
      final uname = (r['user_name'] as String?) ?? 'نامعلوم';
      if (!grouped.containsKey(uid)) {
        grouped[uid] = {
          'name': uname,
          'income': <Map<String, dynamic>>[],
          'expense': <Map<String, dynamic>>[]
        };
      }
      final type = (r['type'] as String? ?? '').toLowerCase();
      if (type == 'income') {
        (grouped[uid]!['income'] as List).add(r);
      } else {
        (grouped[uid]!['expense'] as List).add(r);
      }
    }
    return grouped;
  }

  Future<int> insertMasjidFinance(Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['system_type'] = 'Masjid';
    try {
      return await db.insert('masjid_finance', data,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS masjid_finance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          date TEXT, type TEXT, amount REAL, description TEXT,
          head_id INTEGER, head_name TEXT,
          manual_receipt_no TEXT, computer_receipt_no INTEGER,
          donor_name TEXT, donor_address TEXT,
          spender_name TEXT, signature_image TEXT, receipt_no TEXT,
          user_id INTEGER DEFAULT 1, user_name TEXT,
          system_type TEXT DEFAULT 'Masjid',
          is_deleted INTEGER DEFAULT 0, is_synced INTEGER DEFAULT 0
        )
      ''');
      return await db.insert('masjid_finance', data,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<int> updateMasjidFinance(int id, Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['system_type'] = 'Masjid';
    return await db.update('masjid_finance', data,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMasjidFinance(int id) async {
    Database db = await database;
    return await db.update(
        'masjid_finance', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â  ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢: ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â²ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â± ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â² ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¾ ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ ÃƒÆ’Ã…Â¡Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¹ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§
  Future<Map<int, Map<String, dynamic>>> getFinanceGroupedByUser() async {
    final records = await getFinance(userRole: 'admin');
    final Map<int, Map<String, dynamic>> grouped = {};
    for (var r in records) {
      final uid = (r['user_id'] as int?) ?? 0;
      final uname = (r['user_name'] as String?) ??
          'ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¹ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦';
      if (!grouped.containsKey(uid)) {
        grouped[uid] = {
          'name': uname,
          'income': <Map<String, dynamic>>[],
          'expense': <Map<String, dynamic>>[]
        };
      }
      final type = (r['type'] as String? ?? '').toLowerCase();
      if (type == 'income') {
        (grouped[uid]!['income'] as List).add(r);
      } else {
        (grouped[uid]!['expense'] as List).add(r);
      }
    }
    return grouped;
  }

  Future<int> insertFinance(Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['system_type'] = data['system_type'] ?? 'Madrasa'; // مدرسہ فنانس کے لیے ہمیشہ Madrasa
    final id = await db.insert('finance', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _postSimpleFinanceToAccounts(db, id);
    return id;
  }

  Future<int> updateFinance(int id, Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    final result =
        await db.update('finance', data, where: 'id = ?', whereArgs: [id]);
    await _postSimpleFinanceToAccounts(db, id);
    return result;
  }

  Future<int> deleteFinance(int id) async {
    Database db = await database;
    final result = await db.update('finance', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
    await _deleteSimpleFinanceVoucher(db, id);
    return result;
  }

  Future<void> _ensureDefaultAccountingAccounts(DatabaseExecutor db) async {
    await _ensureAccount(db, '1001', 'Cash in Hand', 'Asset');
    await _ensureAccount(db, '4002', 'Donation / Sadqa', 'Revenue');
    await _ensureAccount(db, '5003', 'Maintenance', 'Expense');
  }

  Future<int> _ensureAccount(
    DatabaseExecutor db,
    String code,
    String name,
    String type,
  ) async {
    final existing = await db.query(
      'acc_chart_of_accounts',
      columns: ['id'],
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return int.tryParse(existing.first['id'].toString()) ?? 0;
    }
    return db.insert('acc_chart_of_accounts', {
      'code': code,
      'name': name,
      'type': type,
      'is_deleted': 0,
      'is_synced': 1,
    });
  }

  String _simpleFinanceReference(int financeId) => 'FIN-$financeId';

  String _simpleFinanceVoucherNo(Map<String, dynamic> finance, int financeId) {
    final type = (finance['type'] ?? '').toString().toLowerCase();
    final prefix = type == 'expense' ? 'SF-PV' : 'SF-RV';
    return '$prefix-${financeId.toString().padLeft(6, '0')}';
  }

  Future<void> _postSimpleFinanceToAccounts(
    Database db,
    int financeId,
  ) async {
    await _createAccountingTables(db);
    await _ensureDefaultAccountingAccounts(db);

    final rows = await db.query(
      'finance',
      where: 'id = ?',
      whereArgs: [financeId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final finance = rows.first;

    if ((int.tryParse(finance['is_deleted']?.toString() ?? '0') ?? 0) == 1) {
      await _deleteSimpleFinanceVoucher(db, financeId);
      return;
    }

    final amount = double.tryParse(finance['amount']?.toString() ?? '0') ?? 0;
    if (amount <= 0) {
      await _deleteSimpleFinanceVoucher(db, financeId);
      return;
    }

    final type = (finance['type'] ?? '').toString().toLowerCase();
    final isExpense = type == 'expense';
    final date = (finance['date'] ?? '').toString();
    final reference = _simpleFinanceReference(financeId);
    final voucherNo = _simpleFinanceVoucherNo(finance, financeId);
    final description = (finance['description'] ?? '').toString().trim();
    final createdBy = int.tryParse(finance['user_id']?.toString() ?? '') ?? 1;
    final cashId = await _ensureAccount(db, '1001', 'Cash in Hand', 'Asset');
    final offsetId = isExpense
        ? await _ensureAccount(db, '5003', 'Maintenance', 'Expense')
        : await _ensureAccount(db, '4002', 'Donation / Sadqa', 'Revenue');

    await db.transaction((txn) async {
      final existing = await txn.query(
        'acc_vouchers',
        columns: ['id'],
        where: 'reference = ?',
        whereArgs: [reference],
        limit: 1,
      );

      int voucherId;
      final voucherData = {
        'voucher_no': voucherNo,
        'date': date,
        'type': isExpense ? 'Payment' : 'Receipt',
        'reference': reference,
        'description': description.isEmpty
            ? (isExpense ? 'Simple finance expense' : 'Simple finance income')
            : description,
        'status': 'Approved',
        'created_by': createdBy,
        'is_deleted': 0,
        'is_synced': 1,
      };

      if (existing.isNotEmpty) {
        voucherId = int.tryParse(existing.first['id'].toString()) ?? 0;
        await txn.update(
          'acc_vouchers',
          voucherData,
          where: 'id = ?',
          whereArgs: [voucherId],
        );
        await txn.delete(
          'acc_ledger_entries',
          where: 'voucher_id = ?',
          whereArgs: [voucherId],
        );
      } else {
        voucherId = await txn.insert('acc_vouchers', voucherData);
      }

      final lines = isExpense
          ? [
              {'account_id': offsetId, 'debit': amount, 'credit': 0.0},
              {'account_id': cashId, 'debit': 0.0, 'credit': amount},
            ]
          : [
              {'account_id': cashId, 'debit': amount, 'credit': 0.0},
              {'account_id': offsetId, 'debit': 0.0, 'credit': amount},
            ];

      for (final line in lines) {
        await txn.insert('acc_ledger_entries', {
          'voucher_id': voucherId,
          'account_id': line['account_id'],
          'debit': line['debit'],
          'credit': line['credit'],
          'is_synced': 1,
        });
      }
    });
  }

  Future<void> _deleteSimpleFinanceVoucher(Database db, int financeId) async {
    await _createAccountingTables(db);
    await db.update(
      'acc_vouchers',
      {'is_deleted': 1, 'is_synced': 1},
      where: 'reference = ?',
      whereArgs: [_simpleFinanceReference(financeId)],
    );
  }

  Future<void> ensureSimpleFinanceAccountingBackfill({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await database;
    await _backfillSimpleFinanceToAccounts(
      db,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  Future<void> _backfillSimpleFinanceToAccounts(
    Database db, {
    String? fromDate,
    String? toDate,
  }) async {
    await _createAccountingTables(db);
    
    // Sync deleted status of finance vouchers
    await db.rawUpdate('''
      UPDATE acc_vouchers
      SET is_deleted = 1
      WHERE reference LIKE 'FIN-%'
      AND CAST(SUBSTR(reference, 5) AS INTEGER) IN (
        SELECT id FROM finance WHERE is_deleted = 1
      )
    ''');
    
    // Clean orphan/unlinked FIN- vouchers whose finance record is deleted or missing
    await db.rawUpdate('''
      UPDATE acc_vouchers
      SET is_deleted = 1
      WHERE reference LIKE 'FIN-%'
      AND CAST(SUBSTR(reference, 5) AS INTEGER) NOT IN (
        SELECT id FROM finance WHERE (is_deleted = 0 OR is_deleted IS NULL)
      )
    ''');

    final where = <String>['(is_deleted = 0 OR is_deleted IS NULL)'];
    final args = <Object?>[];
    if (fromDate != null && fromDate.isNotEmpty) {
      where.add('date >= ?');
      args.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      where.add('date <= ?');
      args.add(toDate);
    }
    final rows = await db.query(
      'finance',
      columns: ['id'],
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'id ASC',
    );
    for (final row in rows) {
      final id = int.tryParse(row['id']?.toString() ?? '') ?? 0;
      if (id > 0) await _postSimpleFinanceToAccounts(db, id);
    }
  }

  Future<int> insertHead(Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    return await db.insert('heads', data);
  }

  Future<int> updateHead(int id, Map<String, dynamic> row) async {
    Database db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.update('heads', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHead(int id) async {
    Database db = await database;
    return await db.update('heads', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getHeads() async {
    Database db = await database;
    await syncLocalHeadsFromChartAndDepartments(db);
    return await db.query('heads',
        where: 'is_deleted = 0 OR is_deleted IS NULL', orderBy: 'name ASC');
  }

  Future<void> syncLocalHeadsFromChartAndDepartments(Database db) async {
    try {
      final chartAccounts = await db.query('acc_chart_of_accounts',
          where: 'is_deleted = 0 OR is_deleted IS NULL');
      for (final ca in chartAccounts) {
        final name = (ca['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final rawType = (ca['type'] ?? '').toString().toLowerCase();
        final type = (rawType == 'income' || rawType.contains('revenue'))
            ? 'Income'
            : 'Expense';
        final existing = await db.query('heads',
            where: 'name = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
            whereArgs: [name]);
        if (existing.isEmpty) {
          await db.insert('heads', {
            'name': name,
            'type': type,
            'is_deleted': 0,
            'is_synced': 0
          });
        }
      }

      final depts = await db.query('departments');
      for (final d in depts) {
        final name = (d['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final existing = await db.query('heads',
            where: 'name = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
            whereArgs: [name]);
        if (existing.isEmpty) {
          await db.insert('heads', {
            'name': name,
            'type': 'Expense',
            'is_deleted': 0,
            'is_synced': 0
          });
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<List<Map<String, dynamic>>> getAccChartAccounts() async {
    Database db = await database;
    await _createAccountingTables(db);
    await _ensureDefaultAccountingAccounts(db);
    final accounts = await db.rawQuery('''
      SELECT c.*, p.name as parent_name, p.code as parent_code
      FROM acc_chart_of_accounts c
      LEFT JOIN acc_chart_of_accounts p ON c.parent_id = p.id
      WHERE (c.is_deleted = 0 OR c.is_deleted IS NULL)
      ORDER BY c.type ASC, c.code ASC, c.name ASC
    ''');
    return accounts;
  }

  Future<int> insertAccChartAccount(Map<String, dynamic> row) async {
    Database db = await database;
    await _createAccountingTables(db);
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return db.insert('acc_chart_of_accounts', data);
  }

  Future<int> updateAccChartAccount(int id, Map<String, dynamic> row) async {
    Database db = await database;
    await _createAccountingTables(db);
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return db.update('acc_chart_of_accounts', data,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAccChartAccount(int id) async {
    Database db = await database;
    await _createAccountingTables(db);
    return db.update(
      'acc_chart_of_accounts',
      {'is_deleted': 1, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAccVouchersWithTotals() async {
    Database db = await database;
    await _createAccountingTables(db);
    await _backfillSimpleFinanceToAccounts(db);
    return db.rawQuery('''
      SELECT v.*,
        COALESCE(SUM(e.debit), 0) AS total_debit,
        COALESCE(SUM(e.credit), 0) AS total_credit
      FROM acc_vouchers v
      LEFT JOIN acc_ledger_entries e ON e.voucher_id = v.id
      WHERE (v.is_deleted = 0 OR v.is_deleted IS NULL)
      GROUP BY v.id
      ORDER BY v.date DESC, v.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAccVoucherEntries(int voucherId) async {
    Database db = await database;
    await _createAccountingTables(db);
    return db.rawQuery('''
      SELECT e.*, a.code, a.name AS account_name
      FROM acc_ledger_entries e
      LEFT JOIN acc_chart_of_accounts a ON a.id = e.account_id
      WHERE e.voucher_id = ?
      ORDER BY e.id ASC
    ''', [voucherId]);
  }

  Future<Map<String, dynamic>> getGeneralLedger({
    required int accountId,
    required String fromDate,
    required String toDate,
  }) async {
    Database db = await database;
    await _createAccountingTables(db);
    await _backfillSimpleFinanceToAccounts(db, toDate: toDate);
    final accounts = await db.query(
      'acc_chart_of_accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (accounts.isEmpty) {
      return {
        'account': null,
        'opening_balance': 0.0,
        'entries': <Map<String, dynamic>>[],
        'total_debit': 0.0,
        'total_credit': 0.0,
        'closing_balance': 0.0,
      };
    }
    final account = accounts.first;
    final type = account['type']?.toString() ?? '';
    final isDebitNormal = type == 'Asset' || type == 'Expense';

    final openingRows = await db.rawQuery('''
      SELECT COALESCE(SUM(e.debit), 0) AS total_dr,
             COALESCE(SUM(e.credit), 0) AS total_cr
      FROM acc_ledger_entries e
      JOIN acc_vouchers v ON e.voucher_id = v.id
      WHERE e.account_id = ?
        AND v.date < ?
        AND v.status != 'Rejected'
        AND (v.is_deleted = 0 OR v.is_deleted IS NULL)
    ''', [accountId, fromDate]);
    final openingDebit =
        double.tryParse(openingRows.first['total_dr']?.toString() ?? '0') ?? 0;
    final openingCredit =
        double.tryParse(openingRows.first['total_cr']?.toString() ?? '0') ?? 0;
    final opening = isDebitNormal
        ? (openingDebit - openingCredit)
        : (openingCredit - openingDebit);

    final rows = await db.rawQuery('''
      SELECT e.*, v.date, v.voucher_no, v.description AS voucher_description,
             v.type AS voucher_type, v.reference
      FROM acc_ledger_entries e
      JOIN acc_vouchers v ON e.voucher_id = v.id
      WHERE e.account_id = ?
        AND v.date BETWEEN ? AND ?
        AND v.status != 'Rejected'
        AND (v.is_deleted = 0 OR v.is_deleted IS NULL)
      ORDER BY v.date ASC, v.id ASC, e.id ASC
    ''', [accountId, fromDate, toDate]);

    var running = opening;
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    final entries = <Map<String, dynamic>>[];
    for (final row in rows) {
      final debit = double.tryParse(row['debit']?.toString() ?? '0') ?? 0;
      final credit = double.tryParse(row['credit']?.toString() ?? '0') ?? 0;
      totalDebit += debit;
      totalCredit += credit;
      running += isDebitNormal ? (debit - credit) : (credit - debit);
      entries.add({
        ...row,
        'running_balance': running,
        'balance_side': running >= 0
            ? (isDebitNormal ? 'Dr' : 'Cr')
            : (isDebitNormal ? 'Cr' : 'Dr'),
      });
    }

    return {
      'account': account,
      'opening_balance': opening,
      'opening_side': opening >= 0
          ? (isDebitNormal ? 'Dr' : 'Cr')
          : (isDebitNormal ? 'Cr' : 'Dr'),
      'entries': entries,
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'closing_balance': running,
      'closing_side': running >= 0
          ? (isDebitNormal ? 'Dr' : 'Cr')
          : (isDebitNormal ? 'Cr' : 'Dr'),
    };
  }

  Future<List<Map<String, dynamic>>> getTrialBalance(String asOfDate) async {
    Database db = await database;
    await _createAccountingTables(db);
    await _backfillSimpleFinanceToAccounts(db, toDate: asOfDate);
    final rows = await db.rawQuery('''
      SELECT a.id, a.code, a.name, a.type,
             COALESCE(SUM(CASE WHEN (v.status IS NULL OR v.status != 'Rejected') AND (v.is_deleted = 0 OR v.is_deleted IS NULL) AND v.date <= ? THEN e.debit ELSE 0 END), 0) AS total_debit,
             COALESCE(SUM(CASE WHEN (v.status IS NULL OR v.status != 'Rejected') AND (v.is_deleted = 0 OR v.is_deleted IS NULL) AND v.date <= ? THEN e.credit ELSE 0 END), 0) AS total_credit
      FROM acc_chart_of_accounts a
      LEFT JOIN acc_ledger_entries e ON a.id = e.account_id
      LEFT JOIN acc_vouchers v ON e.voucher_id = v.id AND (v.is_deleted = 0 OR v.is_deleted IS NULL)
      WHERE (a.is_deleted = 0 OR a.is_deleted IS NULL)
      GROUP BY a.id, a.code, a.name, a.type
      ORDER BY a.type ASC, a.code ASC
    ''', [asOfDate, asOfDate]);

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final debit = double.tryParse(row['total_debit']?.toString() ?? '0') ?? 0;
      final credit =
          double.tryParse(row['total_credit']?.toString() ?? '0') ?? 0;
      final type = row['type']?.toString() ?? '';
      final isDebitNormal = type == 'Asset' || type == 'Expense';
      final balance = isDebitNormal ? debit - credit : credit - debit;
      if (balance.abs() <= 0.01) continue;
      result.add({
        ...row,
        'debit_balance': balance > 0 && isDebitNormal
            ? balance
            : (balance < 0 && !isDebitNormal ? balance.abs() : 0.0),
        'credit_balance': balance > 0 && !isDebitNormal
            ? balance
            : (balance < 0 && isDebitNormal ? balance.abs() : 0.0),
      });
    }
    return result;
  }

  Future<Map<String, dynamic>> getIncomeStatement({
    required String fromDate,
    required String toDate,
    int? departmentId,
  }) async {
    Database db = await database;
    await _createAccountingTables(db);
    await _backfillSimpleFinanceToAccounts(
      db,
      fromDate: fromDate,
      toDate: toDate,
    );
    final params = <Object?>[fromDate, toDate];
    var deptWhere = '';
    if (departmentId != null) {
      deptWhere = ' AND e.department_id = ?';
      params.add(departmentId);
    }
    final rows = await db.rawQuery('''
      SELECT a.id, a.code, a.name, a.type,
             COALESCE(SUM(e.debit), 0) AS total_debit,
             COALESCE(SUM(e.credit), 0) AS total_credit
      FROM acc_chart_of_accounts a
      JOIN acc_ledger_entries e ON a.id = e.account_id
      JOIN acc_vouchers v ON e.voucher_id = v.id AND (v.status IS NULL OR v.status != 'Rejected') AND (v.is_deleted = 0 OR v.is_deleted IS NULL)
      WHERE a.type IN ('Revenue', 'Expense')
        AND v.date BETWEEN ? AND ?
        $deptWhere
      GROUP BY a.id, a.code, a.name, a.type
      ORDER BY a.type DESC, a.code ASC
    ''', params);

    final revenues = <Map<String, dynamic>>[];
    final expenses = <Map<String, dynamic>>[];
    var totalRevenue = 0.0;
    var totalExpense = 0.0;
    for (final row in rows) {
      final debit = double.tryParse(row['total_debit']?.toString() ?? '0') ?? 0;
      final credit =
          double.tryParse(row['total_credit']?.toString() ?? '0') ?? 0;
      final type = row['type']?.toString() ?? '';
      if (type == 'Revenue') {
        final balance = credit - debit;
        if (balance.abs() > 0.01) {
          revenues.add({...row, 'balance': balance});
          totalRevenue += balance;
        }
      } else if (type == 'Expense') {
        final balance = debit - credit;
        if (balance.abs() > 0.01) {
          expenses.add({...row, 'balance': balance});
          totalExpense += balance;
        }
      }
    }
    return {
      'revenues': revenues,
      'expenses': expenses,
      'total_revenue': totalRevenue,
      'total_expense': totalExpense,
      'net_income': totalRevenue - totalExpense,
    };
  }

  Future<String> nextAccVoucherNo(String type) async {
    Database db = await database;
    await _createAccountingTables(db);
    final prefix =
        '${type.isEmpty ? 'J' : type.substring(0, 1).toUpperCase()}V-';
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM acc_vouchers WHERE type = ?',
          [type],
        )) ??
        0;
    return '$prefix${(count + 1).toString().padLeft(5, '0')}';
  }

  Future<int> insertAccVoucherWithEntries({
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> entries,
  }) async {
    Database db = await database;
    await _createAccountingTables(db);
    final validLines = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final debit = double.tryParse(entry['debit']?.toString() ?? '0') ?? 0;
      final credit = double.tryParse(entry['credit']?.toString() ?? '0') ?? 0;
      final accountId =
          int.tryParse(entry['account_id']?.toString() ?? '') ?? 0;
      if (accountId <= 0 && (debit > 0 || credit > 0)) {
        throw Exception('رقم والی ledger line میں اکاؤنٹ منتخب کرنا ضروری ہے۔');
      }
      if (debit > 0 && credit > 0) {
        throw Exception(
            'ایک ledger line میں debit اور credit دونوں نہیں ہو سکتے۔');
      }
      if (accountId > 0 && (debit > 0 || credit > 0)) {
        validLines.add(entry);
      }
    }
    if (validLines.length < 2) {
      throw Exception('کم از کم دو درست ledger lines ضروری ہیں۔');
    }
    final totalDebit = validLines.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse(e['debit']?.toString() ?? '0') ?? 0),
    );
    final totalCredit = validLines.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse(e['credit']?.toString() ?? '0') ?? 0),
    );
    if ((totalDebit - totalCredit).abs() > 0.01 || totalDebit <= 0) {
      throw Exception('Debit اور Credit برابر ہونا ضروری ہے۔');
    }

    final voucherType = voucher['type']?.toString() ?? 'Journal';
    final voucherNo = voucher['voucher_no']?.toString().isNotEmpty == true
        ? voucher['voucher_no'].toString()
        : await nextAccVoucherNo(voucherType);

    return db.transaction<int>((txn) async {
      final data = Map<String, dynamic>.from(voucher);
      data['voucher_no'] = voucherNo;
      data['is_synced'] = 0;
      final voucherId = await txn.insert('acc_vouchers', data);
      for (final entry in validLines) {
        final line = Map<String, dynamic>.from(entry);
        line['voucher_id'] = voucherId;
        line['department_id'] ??= data['department_id'];
        line['is_synced'] = 0;
        await txn.insert('acc_ledger_entries', line);
      }
      return voucherId;
    });
  }

  Future<int> updateAccVoucherWithEntries({
    required int voucherId,
    required Map<String, dynamic> voucher,
    required List<Map<String, dynamic>> entries,
  }) async {
    Database db = await database;
    await _createAccountingTables(db);
    final validLines = <Map<String, dynamic>>[];
    for (final entry in entries) {
      final debit = double.tryParse(entry['debit']?.toString() ?? '0') ?? 0;
      final credit = double.tryParse(entry['credit']?.toString() ?? '0') ?? 0;
      final accountId =
          int.tryParse(entry['account_id']?.toString() ?? '') ?? 0;
      if (accountId <= 0 && (debit > 0 || credit > 0)) {
        throw Exception('رقم والی ledger line میں اکاؤنٹ منتخب کرنا ضروری ہے۔');
      }
      if (debit > 0 && credit > 0) {
        throw Exception(
            'ایک ledger line میں debit اور credit دونوں نہیں ہو سکتے۔');
      }
      if (accountId > 0 && (debit > 0 || credit > 0)) {
        validLines.add(entry);
      }
    }
    if (validLines.length < 2) {
      throw Exception('کم از کم دو درست ledger lines ضروری ہیں۔');
    }
    final totalDebit = validLines.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse(e['debit']?.toString() ?? '0') ?? 0),
    );
    final totalCredit = validLines.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse(e['credit']?.toString() ?? '0') ?? 0),
    );
    if (totalDebit <= 0 || (totalDebit - totalCredit).abs() > 0.01) {
      throw Exception(
          'Debits اور Credits کا برابر ہونا ضروری ہے۔ (Dr: $totalDebit, Cr: $totalCredit)');
    }

    return await db.transaction((txn) async {
      var data = Map<String, dynamic>.from(voucher);
      data['is_synced'] = 0;
      
      await txn.update('acc_vouchers', data, where: 'id = ?', whereArgs: [voucherId]);
      await txn.delete('acc_ledger_entries', where: 'voucher_id = ?', whereArgs: [voucherId]);

      for (final entry in validLines) {
        var line = Map<String, dynamic>.from(entry);
        line['voucher_id'] = voucherId;
        line['department_id'] ??= data['department_id'];
        line['is_synced'] = 0;
        await txn.insert('acc_ledger_entries', line);
      }
      return voucherId;
    });
  }

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    return await db.insert('finance', data);
  }

  Future<int> insertExam(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['total_marks'] = data['total_marks'] ?? 100;
    data['passing_marks'] = data['passing_marks'] ?? 33;
    return await db.insert('exams', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getNotices() async {
    Database db = await database;
    return await db.query('notices',
        where: 'is_deleted = 0 OR is_deleted IS NULL', orderBy: 'date DESC');
  }

  Future<int> insertNotice(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    return await db.insert('notices', data);
  }

  Future<int> insertComplaint(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('complaints', data);
  }

  Future<int> insertParentComplaint(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('parent_complaints', data);
  }

  Future<int> insertLeaveApplication(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('leave_applications', data);
  }

  Future<int> insertFeeSubmission(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('fee_submissions', data);
  }

  Future<void> deleteNotice(int id) async {
    Database db = await database;
    await db.update('notices', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getComplaints() async {
    Database db = await database;
    return await db.query('complaints', orderBy: 'id DESC');
  }

  Future<int> insertAcademicReport(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('academic_reports', data);
  }

  Future<List<Map<String, dynamic>>> getAcademicReports() async {
    Database db = await database;
    return await db.query('academic_reports', orderBy: 'date DESC');
  }

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

  List<String> _decodeIdListText(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return [];
    Iterable<dynamic> items;
    try {
      final decoded = jsonDecode(raw);
      items = decoded is List ? decoded : raw.split(',');
    } catch (_) {
      items = raw.split(',');
    }
    return items
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _encodeIdListText(List<String> ids) {
    final clean = <int>[];
    for (final id in ids) {
      final parsed = int.tryParse(id);
      if (parsed != null && parsed > 0 && !clean.contains(parsed)) {
        clean.add(parsed);
      }
    }
    return jsonEncode(clean);
  }

  Future<void> _updateTeacherReferenceIfTableExists(
    Transaction txn,
    String table,
    int localId,
    int serverId, {
    bool markUnsynced = true,
  }) async {
    final tableExists = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    if (tableExists.isEmpty) return;

    final values = <String, dynamic>{'teacher_id': serverId};
    if (markUnsynced) {
      final cols = await txn.rawQuery("PRAGMA table_info($table)");
      if (cols.any((col) => col['name'] == 'is_synced')) {
        values['is_synced'] = 0;
      }
    }
    await txn
        .update(table, values, where: 'teacher_id = ?', whereArgs: [localId]);
  }

  Future<void> markTeacherAsSynced(int localId, int? serverId) async {
    Database db = await database;
    if (serverId == null || serverId <= 0 || serverId == localId) {
      await db.update('teachers', {'is_synced': 1},
          where: 'id = ?', whereArgs: [localId]);
      return;
    }

    await db.transaction((txn) async {
      final classRows = await txn.query(
        'classes',
        columns: ['id', 'main_teacher_ids'],
        where: "COALESCE(main_teacher_ids, '') <> ''",
      );
      for (final row in classRows) {
        final ids = _decodeIdListText(row['main_teacher_ids']);
        var changed = false;
        final replaced = ids.map((id) {
          if (id == localId.toString()) {
            changed = true;
            return serverId.toString();
          }
          return id;
        }).toList();
        if (!changed) continue;
        await txn.update(
          'classes',
          {
            'main_teacher_ids': _encodeIdListText(replaced),
            'is_synced': 0,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }

      await _updateTeacherReferenceIfTableExists(
          txn, 'attendance_teachers', localId, serverId);
      await _updateTeacherReferenceIfTableExists(
          txn, 'teacher_period_attendance', localId, serverId);
      await _updateTeacherReferenceIfTableExists(
          txn, 'acc_payroll', localId, serverId);

      final source = await txn.query('teachers',
          where: 'id = ?', whereArgs: [localId], limit: 1);
      final target = await txn.query('teachers',
          where: 'id = ?', whereArgs: [serverId], limit: 1);
      if (source.isEmpty) {
        await txn.update('teachers', {'is_synced': 1},
            where: 'id = ?', whereArgs: [serverId]);
        return;
      }

      if (target.isNotEmpty) {
        final merged = Map<String, dynamic>.from(source.first)
          ..remove('id')
          ..['is_synced'] = 1;
        await txn
            .update('teachers', merged, where: 'id = ?', whereArgs: [serverId]);
        await txn.delete('teachers', where: 'id = ?', whereArgs: [localId]);
      } else {
        await txn.update(
          'teachers',
          {'id': serverId, 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    });
  }

  String _normalizeAttendanceStatus(dynamic rawStatus) {
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

  String _normalizeShiftLabel(dynamic shiftRaw) {
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

  List<Map<String, String>> _buildAttendanceRows(dynamic attendanceSource) {
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

      for (int i = 1; i <= 8; i++) {
        final String statusKey = 'status_$i';
        final String lateKey = 'late_$i';
        final dynamic rawStatus = map[statusKey];

        if (rawStatus == null || rawStatus.toString().trim().isEmpty) {
          continue;
        }

        rows.add({
          'date': date,
          'student_id': studentId,
          'shift': shiftMap['$i']!,
          'status': _normalizeAttendanceStatus(rawStatus),
          'delay_minutes': map[lateKey]?.toString() ?? '',
        });
      }
    }

    return rows;
  }

  Future<void> saveServerData(Map<String, dynamic> data) async {
    Database db = await database;
    Batch batch = db.batch();
    final teacherIdRemaps = <List<int>>[];

    if (data['students'] != null) {
      try {
        for (var item in data['students']) {
          String roll =
              (item['roll_number'] ?? item['admission_number'])?.toString() ??
                  '';

          // ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã…Â¡ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â© ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚Â ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¨ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â± ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¯ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ (ÃƒÆ’Ã…Â¡ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â© ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â  ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â )
          var existing = await db
              .query('students', where: 'roll_number = ?', whereArgs: [roll]);

          Map<String, dynamic> row = {
            'id': item['id'],
            'name': item['name']?.toString() ?? '',
            'father_name': item['father_name']?.toString() ?? '',
            'roll_number': roll,
            'class_name':
                (item['class_name'] ?? item['class'])?.toString() ?? '',
            'contact_number':
                (item['contact_number'] ?? item['mobile_no'])?.toString() ?? '',
            'address': item['address']?.toString() ?? '',
            'password': '',
            'status': item['status']?.toString() ?? 'Active',
            'admission_date': item['admission_date']?.toString() ?? '',
            'graduation_date': item['graduation_date']?.toString() ?? '',
            'duration': item['duration']?.toString() ?? '',
            'photo': item['photo']?.toString() ?? '',
            'leaving_reason': item['leaving_reason']?.toString() ?? '',
            'serial_no':
                int.tryParse(item['serial_no']?.toString() ?? '0') ?? 0,
            'hijri_year':
                int.tryParse(item['hijri_year']?.toString() ?? '1447') ?? 1447,
            'is_deleted':
                int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
            'is_synced': 1,
          };

          if (existing.isNotEmpty) {
            // ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â± ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¯ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚ÂªÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â  ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã…Â¡Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¹ ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº (ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚ÂªÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚Â ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ ÃƒÆ’Ã…Â¡Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â± ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ ÃƒÆ’Ã…Â¡Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¨ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢)
            batch.update('students', row,
                where: 'id = ?', whereArgs: [existing.first['id']]);
          } else {
            batch.insert('students', row,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        // ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¨ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â  ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â·ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¨ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¡ ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â  ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¹ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â  ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â± ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â± ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â  ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¨ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â© ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â´ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚Â ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â© ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº
        // (ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚ÂµÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â§ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â  ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â  ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â±ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â± ÃƒÆ’Ã‹Å“Ãƒâ€šÃ‚Â³ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã…Â¡Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â€žÂ¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€¦Ã¢â‚¬â„¢ÃƒÆ’Ã¢â€žÂ¢Ãƒâ€šÃ‚Â¹ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â  ÃƒÆ’Ã…Â¡ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã¢â‚¬ÂºÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ ÃƒÆ’Ã¢â‚¬ÂºÃƒâ€šÃ‚ÂÃƒÆ’Ã¢â€žÂ¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÆ’Ã…Â¡Ãƒâ€šÃ‚Âº)
        List<String> serverRolls = data['students']
            .map<String>((s) =>
                (s['roll_number'] ?? s['admission_number'])?.toString() ?? '')
            .toList();
        if (serverRolls.isNotEmpty) {
          batch.delete('students',
              where:
                  'is_synced = 1 AND roll_number NOT IN (${serverRolls.map((e) => "'$e'").join(',')})');
        }
      } catch (e) {
        debugPrint("Sync Error (students): $e");
      }
    }

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

    final dynamic attendanceSource =
        data['attendance_history'] ?? data['attendance'];
    if (attendanceSource != null) {
      try {
        batch.delete('attendance', where: 'is_synced = ?', whereArgs: [1]);
        final List<Map<String, String>> attendanceRows =
            _buildAttendanceRows(attendanceSource);
        for (final row in attendanceRows) {
          batch.insert('attendance', {
            'date': row['date'] ?? '',
            'shift': row['shift'] ?? '',
            'student_id': row['student_id'] ?? '',
            'status': row['status'] ?? '',
            'delay_minutes': row['delay_minutes'] ?? '',
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (attendance): $e");
      }
    }

    if (data['attendance_teachers'] != null) {
      try {
        await _createTeacherAttendanceTable(db);
        batch.delete('attendance_teachers',
            where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['attendance_teachers']) {
          batch.insert('attendance_teachers', {
            'teacher_id': item['teacher_id'],
            'date': item['date']?.toString() ?? '',
            'status': item['status']?.toString() ?? '',
            'late_minutes':
                int.tryParse(item['late_minutes']?.toString() ?? '0') ?? 0,
            'remarks': item['remarks']?.toString() ?? '',
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (attendance_teachers): $e");
      }
    }

    if (data['teacher_period_attendance'] != null) {
      try {
        await _createTeacherPeriodAttendanceTable(db);
        batch.delete('teacher_period_attendance',
            where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['teacher_period_attendance']) {
          batch.insert(
            'teacher_period_attendance',
            {
              'id': item['id'],
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

    if (data['hifz_history'] != null) {
      try {
        batch.delete('hifz_record', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['hifz_history']) {
          batch.insert('hifz_record', {
            'date': (item['date']?.toString() ?? '').split(' ')[0],
            'student_id': item['student_id']?.toString() ?? '',
            'sabaq_para':
                (item['sabaq_parah'] ?? item['sabaq_para'])?.toString() ?? '',
            'sabaq_lines': item['sabaq_lines']?.toString() ?? '',
            'sabaq_grade':
                (item['sabaq_status'] ?? item['sabaq_grade'])?.toString() ?? '',
            'sabqi_para':
                (item['sabqi_parah'] ?? item['sabqi_para'])?.toString() ?? '',
            'sabqi_qty':
                (item['sabqi_amount'] ?? item['sabqi_qty'])?.toString() ?? '',
            'sabqi_grade':
                (item['sabqi_status'] ?? item['sabqi_grade'])?.toString() ?? '',
            'sabqi_listener': item['sabqi_listener']?.toString() ?? '',
            'manzil_total_qty':
                (item['manzil_amount'] ?? item['manzil_total_qty'])
                        ?.toString() ??
                    '',
            'manzil_details':
                (item['manzil_parah'] ?? item['manzil_details'])?.toString() ??
                    '',
            'manzil_grade':
                (item['manzil_status'] ?? item['manzil_grade'])?.toString() ??
                    '',
            'manzil_listener': item['manzil_listener']?.toString() ?? '',
            'sabaq_time': item['sabaq_time']?.toString() ?? '',
            'sabqi_time': item['sabqi_time']?.toString() ?? '',
            'manzil_time': item['manzil_time']?.toString() ?? '',
            'is_deleted':
                int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (hifz): $e");
      }
    }

    if (data['nazira_history'] != null) {
      try {
        batch.delete('nazira_record', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['nazira_history']) {
          batch.insert('nazira_record', {
            'id': item['id'],
            'student_id': item['student_id'],
            'date': item['date'],
            'morning_sabaq': item['morning_sabaq'],
            'morning_status': item['morning_status'],
            'evening_sabaq': item['evening_sabaq'],
            'evening_status': item['evening_status'],
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (nazira): $e");
      }
    }

    if (data['finance_history'] != null) {
      try {
        batch.delete('finance', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['finance_history']) {
          batch.insert(
              'finance',
              {
                'id': int.tryParse(item['id']?.toString() ?? ''),
                'server_id': int.tryParse(item['id']?.toString() ?? ''),
                'date': item['date']?.toString() ?? '',
                'type': item['type']?.toString() ?? '',
                'amount': (item['amount'] != null)
                    ? double.tryParse(item['amount'].toString()) ?? 0.0
                    : 0.0,
                'description': item['description']?.toString() ?? '',
                'head_id': item['head_id'],
                'manual_receipt_no':
                    item['manual_receipt_no']?.toString() ?? '',
                'donor_name': item['donor_name']?.toString() ?? '',
                'donor_address': item['donor_address']?.toString() ?? '',
                'computer_receipt_no': item['computer_receipt_no'],
                'user_id':
                    int.tryParse(item['user_id']?.toString() ?? '1') ?? 1,
                'user_name': item['user_name']?.toString() ?? 'Admin',
                'system_type': item['system_type']?.toString() ?? 'Madrasa',
                'is_deleted':
                    int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint("Sync Error (finance): $e");
      }
    }

    // مسجد فنانس sync
    if (data['masjid_finance_history'] != null) {
      try {
        batch.delete('masjid_finance', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['masjid_finance_history']) {
          batch.insert(
              'masjid_finance',
              {
                'id': int.tryParse(item['id']?.toString() ?? ''),
                'server_id': int.tryParse(item['id']?.toString() ?? ''),
                'date': item['date']?.toString() ?? '',
                'type': item['type']?.toString() ?? '',
                'amount': (item['amount'] != null)
                    ? double.tryParse(item['amount'].toString()) ?? 0.0
                    : 0.0,
                'description': item['description']?.toString() ?? '',
                'head_id': item['head_id'],
                'head_name': item['head_name']?.toString() ?? '',
                'manual_receipt_no':
                    item['manual_receipt_no']?.toString() ?? '',
                'donor_name': item['donor_name']?.toString() ?? '',
                'donor_address': item['donor_address']?.toString() ?? '',
                'computer_receipt_no': item['computer_receipt_no'],
                'user_id':
                    int.tryParse(item['user_id']?.toString() ?? '1') ?? 1,
                'user_name': item['user_name']?.toString() ?? 'Admin',
                'system_type': 'Masjid',
                'is_deleted':
                    int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint("Sync Error (masjid_finance): $e");
      }
    }

    if (data['exams'] != null) {
      try {
        batch.delete('exams', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['exams']) {
          batch.insert('exams', {
            'exam_name': item['exam_name']?.toString() ?? '',
            'exam_date': item['exam_date']?.toString() ?? '',
            'total_marks':
                double.tryParse(item['total_marks']?.toString() ?? '100') ??
                    100,
            'passing_marks':
                double.tryParse(item['passing_marks']?.toString() ?? '33') ??
                    33,
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (exams): $e");
      }
    }

    if (data['notices'] != null) {
      try {
        batch.delete('notices', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['notices']) {
          batch.insert(
              'notices',
              {
                'id': int.tryParse(item['id']?.toString() ?? ''),
                'title': item['title']?.toString() ?? '',
                'message': item['message']?.toString() ?? '',
                'date': item['date']?.toString() ?? '',
                'is_deleted':
                    int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint("Sync Error (notices): $e");
      }
    }

    if (data['complaints'] != null) {
      try {
        batch.delete('complaints', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['complaints']) {
          batch.insert('complaints', {
            'student_id':
                int.tryParse(item['student_id']?.toString() ?? '') ?? 0,
            'complaint': item['complaint']?.toString() ?? '',
            'date': item['date']?.toString() ?? '',
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (complaints): $e");
      }
    }

    if (data['parent_complaints'] != null) {
      try {
        batch.delete('parent_complaints');
        for (var item in data['parent_complaints']) {
          batch.insert('parent_complaints', {
            'id': item['id'],
            'student_id': item['student_id'],
            'date': item['date'],
            'category': item['category'],
            'description': item['description'],
            'status': item['status'],
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (parent_complaints): $e");
      }
    }

    if (data['leave_applications'] != null) {
      try {
        batch.delete('leave_applications');
        for (var item in data['leave_applications']) {
          batch.insert('leave_applications', {
            'id': item['id'],
            'student_id': item['student_id'],
            'date_from': item['date_from'],
            'date_to': item['date_to'],
            'reason': item['reason'],
            'status': item['status'],
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (leave_applications): $e");
      }
    }

    if (data['fee_submissions'] != null) {
      try {
        batch.delete('fee_submissions');
        for (var item in data['fee_submissions']) {
          batch.insert('fee_submissions', {
            'id': item['id'],
            'student_id': item['student_id'],
            'amount': item['amount'],
            'submission_date': item['submission_date'],
            'screenshot': item['screenshot'] ?? '',
            'status': item['status'],
            'head_id': item['head_id'],
            'description': item['description'],
            'finance_id': item['finance_id'],
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (fee_submissions): $e");
      }
    }

    if (data['exams'] != null) {
      batch.delete('exams');
      for (var item in data['exams']) {
        batch.insert('exams', {
          'id': item['id'],
          'exam_name': item['exam_name']?.toString() ?? '',
          'exam_date': item['exam_date']?.toString() ?? '',
          'total_marks':
              double.tryParse(item['total_marks']?.toString() ?? '100') ?? 100,
          'passing_marks':
              double.tryParse(item['passing_marks']?.toString() ?? '33') ?? 33,
          'is_synced': 1,
        });
      }
    }

    if (data['exam_results'] != null) {
      try {
        batch.delete('exam_results', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['exam_results']) {
          batch.insert(
              'exam_results',
              {
                'id': item['id'],
                'exam_id': item['exam_id'],
                'student_id': item['student_id'],
                'subject': item['subject']?.toString() ?? 'Quran',
                'marks_obtained': item['marks_obtained'],
                'total_marks': item['total_marks'],
                'grade': item['grade']?.toString() ?? '',
                'status': item['status']?.toString() ?? 'Pass',
                'remarks': item['remarks']?.toString() ?? '',
                'pukhtagi':
                    int.tryParse(item['pukhtagi']?.toString() ?? '0') ?? 0,
                'tajweed':
                    int.tryParse(item['tajweed']?.toString() ?? '0') ?? 0,
                'lahja': int.tryParse(item['lahja']?.toString() ?? '0') ?? 0,
                'masail': int.tryParse(item['masail']?.toString() ?? '0') ?? 0,
                'miqdar_khwandgi': item['miqdar_khwandgi']?.toString() ?? '',
                'p1': int.tryParse(item['p1']?.toString() ?? '0') ?? 0,
                'p2': int.tryParse(item['p2']?.toString() ?? '0') ?? 0,
                'p3': int.tryParse(item['p3']?.toString() ?? '0') ?? 0,
                'p4': int.tryParse(item['p4']?.toString() ?? '0') ?? 0,
                'p5': int.tryParse(item['p5']?.toString() ?? '0') ?? 0,
                'p6': int.tryParse(item['p6']?.toString() ?? '0') ?? 0,
                'subjects_marks': item['subjects_marks']?.toString() ?? '',
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint("Sync Error (exam_results): $e");
      }
    }

    if (data['heads'] != null) {
      try {
        batch.delete('heads');
        for (var item in data['heads']) {
          batch.insert(
            'heads',
            {
              'id': item['id'],
              'name': item['name']?.toString() ?? '',
              'type': item['type']?.toString() ?? '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (heads): $e");
      }
    }

    if (data['settings'] != null) {
      try {
        batch.delete('settings');
        var s = data['settings'];
        batch.insert('settings', {
          'id': 1,
          'madrasa_name': s['madrasa_name']?.toString() ?? '',
          'current_hijri_year': s['current_hijri_year']?.toString() ?? '1445',
          'week_start_day':
              int.tryParse(s['week_start_day']?.toString() ?? '6') ?? 6,
          'ai_provider': s['ai_provider']?.toString() ?? 'gemini',
          'gemini_api_key': '',
          'groq_api_key': '',
          'whatsapp_api_key': '',
          'sms_api_key': '',
          'auto_notify_day':
              int.tryParse(s['auto_notify_day']?.toString() ?? '4') ?? 4,
          'auto_notify_time': s['auto_notify_time']?.toString() ?? '18:00',
        });
      } catch (e) {
        debugPrint("Sync Error (settings): $e");
      }
    }

    if (data['classes'] != null) {
      try {
        batch.delete('classes');
        for (var item in data['classes']) {
          batch.insert('classes', {
            'id': item['id'],
            'name': item['name']?.toString() ?? '',
            'section': item['section']?.toString() ?? '',
            'status': item['status']?.toString() ?? 'Active',
            'class_type': item['class_type']?.toString() ?? 'Regular',
            'main_teacher_ids': item['main_teacher_ids']?.toString() ?? '',
            'p1_name': item['p1_name']?.toString() ?? 'Period 1',
            'p2_name': item['p2_name']?.toString() ?? 'Period 2',
            'p3_name': item['p3_name']?.toString() ?? 'Period 3',
            'p4_name': item['p4_name']?.toString() ?? 'Period 4',
            'p5_name': item['p5_name']?.toString() ?? 'Period 5',
            'p6_name': item['p6_name']?.toString() ?? 'Period 6',
            'subjects_list': item['subjects_list']?.toString() ?? '',
            'is_deleted':
                int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (classes): $e");
      }
    }

    if (data['academic_reports'] != null) {
      try {
        batch
            .delete('academic_reports', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['academic_reports']) {
          batch.insert('academic_reports', {
            'id': item['id'],
            'student_id': item['student_id'],
            'date': item['date'],
            'class_name': item['class_name'],
            'subject': item['subject'],
            'lesson_details': item['lesson_details'],
            'grade': item['grade'],
            'remarks': item['remarks'],
            'is_synced': 1,
          });
        }
      } catch (e) {
        debugPrint("Sync Error (academic_reports): $e");
      }
    }

    if (data['qaida_records'] != null) {
      try {
        batch.delete('qaida_records', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['qaida_records']) {
          batch.insert(
            'qaida_records',
            {
              'id': int.tryParse(item['id']?.toString() ?? '') ?? 0,
              'student_id': int.tryParse(item['student_id']?.toString() ?? '') ?? 0,
              'date': item['date']?.toString() ?? '',
              'sabaq_1': item['sabaq_1']?.toString() ?? '',
              'qty_1': item['qty_1']?.toString() ?? '',
              'grade_1': item['grade_1']?.toString() ?? '',
              'sabaq_2': item['sabaq_2']?.toString() ?? '',
              'qty_2': item['qty_2']?.toString() ?? '',
              'grade_2': item['grade_2']?.toString() ?? '',
              'sabaq_3': item['sabaq_3']?.toString() ?? '',
              'qty_3': item['qty_3']?.toString() ?? '',
              'grade_3': item['grade_3']?.toString() ?? '',
              'sabaq_4': item['sabaq_4']?.toString() ?? '',
              'qty_4': item['qty_4']?.toString() ?? '',
              'grade_4': item['grade_4']?.toString() ?? '',
              'lesson_type': item['lesson_type']?.toString() ?? 'نورانی قاعدہ',
              'hearing_time': item['hearing_time']?.toString() ?? '',
              'is_deleted': int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (qaida_records): $e");
      }
    }

    if (data['classes'] != null) {
      try {
        batch.delete('classes');
        for (var item in data['classes']) {
          batch.insert(
              'classes',
              {
                'id': item['id'],
                'name': item['name'],
                'section': item['section'] ?? '',
                'status': item['status'] ?? 'Active',
                'class_type': item['class_type'] ?? 'Regular',
                'main_teacher_ids': item['main_teacher_ids'] ?? '',
                'p1_name': item['p1_name'] ?? 'Period 1',
                'p2_name': item['p2_name'] ?? 'Period 2',
                'p3_name': item['p3_name'] ?? 'Period 3',
                'p4_name': item['p4_name'] ?? 'Period 4',
                'p5_name': item['p5_name'] ?? 'Period 5',
                'p6_name': item['p6_name'] ?? 'Period 6',
                'subjects_list': item['subjects_list'] ?? '',
                'is_deleted':
                    int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint("Sync Error (classes): $e");
      }
    }

    if (data['departments'] != null) {
      try {
        batch.delete('departments');
        for (var item in data['departments']) {
          batch.insert(
            'departments',
            {
              'id': item['id'],
              'name': item['name']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'status': item['status']?.toString() ?? 'Active',
              'is_deleted':
                  int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (departments): $e");
      }
    }

    if (data['acc_chart_of_accounts'] != null) {
      try {
        batch.delete('acc_chart_of_accounts',
            where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['acc_chart_of_accounts']) {
          batch.insert(
            'acc_chart_of_accounts',
            {
              'id': item['id'],
              'code': item['code']?.toString() ?? '',
              'name': item['name']?.toString() ?? '',
              'type': item['type']?.toString() ?? '',
              'is_deleted':
                  int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (acc_chart_of_accounts): $e");
      }
    }

    if (data['acc_vouchers'] != null) {
      try {
        batch.delete('acc_vouchers', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['acc_vouchers']) {
          batch.insert(
            'acc_vouchers',
            {
              'id': item['id'],
              'voucher_no': item['voucher_no']?.toString() ?? '',
              'date': item['date']?.toString() ?? '',
              'type': item['type']?.toString() ?? 'Journal',
              'reference': item['reference']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'department_id':
                  int.tryParse(item['department_id']?.toString() ?? ''),
              'status': item['status']?.toString() ?? 'Pending',
              'created_by': int.tryParse(item['created_by']?.toString() ?? ''),
              'is_deleted':
                  int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (acc_vouchers): $e");
      }
    }

    if (data['acc_ledger_entries'] != null) {
      try {
        batch.delete('acc_ledger_entries',
            where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['acc_ledger_entries']) {
          batch.insert(
            'acc_ledger_entries',
            {
              'id': item['id'],
              'voucher_id': item['voucher_id'],
              'account_id': item['account_id'],
              'debit': double.tryParse(item['debit']?.toString() ?? '0') ?? 0.0,
              'credit':
                  double.tryParse(item['credit']?.toString() ?? '0') ?? 0.0,
              'department_id':
                  int.tryParse(item['department_id']?.toString() ?? ''),
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (acc_ledger_entries): $e");
      }
    }

    if (data['acc_payroll'] != null) {
      try {
        batch.delete('acc_payroll', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['acc_payroll']) {
          final basic =
              double.tryParse(item['basic_salary']?.toString() ?? '0') ?? 0.0;
          final allowances =
              double.tryParse(item['allowances']?.toString() ?? '0') ?? 0.0;
          final deductions =
              double.tryParse(item['deductions']?.toString() ?? '0') ?? 0.0;
          final net = double.tryParse(item['net_salary']?.toString() ?? '') ??
              (basic + allowances - deductions);
          batch.insert(
            'acc_payroll',
            {
              'id': item['id'],
              'teacher_id': item['teacher_id'],
              'month_year': item['month_year']?.toString() ?? '',
              'basic_salary': basic,
              'allowances': allowances,
              'deductions': deductions,
              'net_salary': net,
              'status': item['status']?.toString() ?? 'Unpaid',
              'payment_date': item['payment_date']?.toString() ?? '',
              'is_deleted':
                  int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (acc_payroll): $e");
      }
    }

    if (data['acc_invoices'] != null) {
      try {
        batch.delete('acc_invoices', where: 'is_synced = ?', whereArgs: [1]);
        for (var item in data['acc_invoices']) {
          batch.insert(
            'acc_invoices',
            {
              'id': item['id'],
              'student_id': item['student_id'],
              'invoice_no': item['invoice_no']?.toString() ?? '',
              'month_year': item['month_year']?.toString() ?? '',
              'amount':
                  double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
              'status': item['status']?.toString() ?? 'Unpaid',
              'is_deleted':
                  int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Sync Error (acc_invoices): $e");
      }
    }

    await batch.commit(continueOnError: true, noResult: true);
    for (final remap in teacherIdRemaps) {
      await markTeacherAsSynced(remap[0], remap[1]);
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    Database db = await database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        id INTEGER PRIMARY KEY,
        madrasa_name TEXT,
        phone TEXT,
        current_hijri_year TEXT,
        week_start_day INTEGER DEFAULT 6,
        ai_provider TEXT DEFAULT 'gemini',
        gemini_api_key TEXT,
        groq_api_key TEXT,
        whatsapp_api_key TEXT,
        sms_api_key TEXT,
        auto_notify_day INTEGER DEFAULT 4,
        auto_notify_time TEXT DEFAULT '18:00'
      )
    ''');

    var res = await db.query('settings', where: 'id = 1');
    if (res.isNotEmpty) return res.first;

    await db.insert(
        'settings',
        {
          'id': 1,
          'madrasa_name':
              '\u0645\u062f\u0631\u0633\u06c1 \u0627\u0634\u0631\u0641 \u0627\u0644\u0645\u062f\u0627\u0631\u0633',
          'phone': '',
          'current_hijri_year': '1447',
          'week_start_day': 6,
          'ai_provider': 'gemini',
          'gemini_api_key': '',
          'groq_api_key': '',
          'whatsapp_api_key': '',
          'sms_api_key': '',
          'auto_notify_day': 4,
          'auto_notify_time': '18:00',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    res = await db.query('settings', where: 'id = 1');
    return res.isNotEmpty ? res.first : {};
  }

  Future<List<Map<String, dynamic>>> getCollectiveResults(int examId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT er.*, s.name as student_name, s.father_name, s.roll_number, s.class_name
      FROM exam_results er
      JOIN students s ON er.student_id = s.id
      WHERE er.exam_id = ?
    ''', [examId]);
  }

  Future<List<Map<String, dynamic>>> getExamResults(int examId) async {
    final db = await database;
    return await db
        .query('exam_results', where: 'exam_id = ?', whereArgs: [examId]);
  }

  Future<void> insertExamResult(Map<String, dynamic> row) async {
    final db = await database;
    final existing = await db.query('exam_results',
        where: 'exam_id = ? AND student_id = ?',
        whereArgs: [row['exam_id'], row['student_id']]);

    if (existing.isNotEmpty) {
      await db.update('exam_results', row,
          where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('exam_results', row);
    }
  }

  Future<List<Map<String, dynamic>>> getExams() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*,
        (SELECT COUNT(*) FROM exam_results er WHERE er.exam_id = e.id) AS result_count,
        (SELECT COUNT(*) FROM students s
          WHERE (s.is_deleted = 0 OR s.is_deleted IS NULL)
            AND LOWER(COALESCE(s.status, 'Active')) = 'active') AS total_students
      FROM exams e
      WHERE e.is_deleted = 0 OR e.is_deleted IS NULL
      ORDER BY e.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getStudentResults(int studentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT er.*, e.exam_name, e.exam_date
      FROM exam_results er
      JOIN exams e ON er.exam_id = e.id
      WHERE er.student_id = ?
      ORDER BY e.exam_date DESC
    ''', [studentId]);
  }

  Future<void> _addColumnIfNotExists(Database db, String table, String column, String type) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info($table)");
      bool exists = columns.any((col) => col['name'] == column);
      if (!exists) {
        await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
      }
    } catch (_) {}
  }

  Future<void> _createTeacherPeriodAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_period_attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER,
        class_id INTEGER,
        class_name TEXT,
        date TEXT,
        period_no INTEGER,
        status TEXT,
        late_minutes INTEGER DEFAULT 0,
        remarks TEXT,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    await _addColumnIfNotExists(db, 'teacher_period_attendance', 'class_name', 'TEXT');
    await _addColumnIfNotExists(db, 'teacher_period_attendance', 'is_deleted', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'teacher_period_attendance', 'is_synced', 'INTEGER DEFAULT 0');
  }

  Future<void> forceMigrate(Database db) async {
    try {
      await _createAccountingTables(db);
    } catch (_) {}
    
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS academic_reports(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER,
          date TEXT,
          class_name TEXT,
          subject TEXT,
          lesson_details TEXT,
          grade TEXT,
          remarks TEXT,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''');
    } catch (_) {}

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS qaida_records(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER,
          date TEXT,
          sabaq_1 TEXT, qty_1 TEXT, grade_1 TEXT,
          sabaq_2 TEXT, qty_2 TEXT, grade_2 TEXT,
          sabaq_3 TEXT, qty_3 TEXT, grade_3 TEXT,
          sabaq_4 TEXT, qty_4 TEXT, grade_4 TEXT,
          lesson_type TEXT DEFAULT 'نورانی قاعدہ',
          hearing_time TEXT,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''');
    } catch (_) {}
    await _addColumnIfNotExists(db, 'qaida_records', 'is_deleted', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'qaida_records', 'is_synced', 'INTEGER DEFAULT 0');

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hifz_record(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          date TEXT,
          student_id TEXT,
          sabaq_para TEXT,
          sabaq_lines TEXT,
          sabaq_grade TEXT,
          sabqi_para TEXT,
          sabqi_qty TEXT,
          sabqi_grade TEXT,
          sabqi_listener TEXT,
          manzil_total_qty TEXT,
          manzil_details TEXT,
          manzil_grade TEXT,
          manzil_listener TEXT,
          sabaq_time TEXT,
          sabqi_time TEXT,
          manzil_time TEXT,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS departments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          description TEXT,
          status TEXT DEFAULT 'Active',
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''');
    } catch (_) {}

    await _addColumnIfNotExists(db, 'finance', 'server_id', 'INTEGER');

    await _addColumnIfNotExists(db, 'nazira_record', 'morning_qty', 'TEXT');
    await _addColumnIfNotExists(db, 'nazira_record', 'morning_time', 'TEXT');
    await _addColumnIfNotExists(db, 'nazira_record', 'evening_qty', 'TEXT');
    await _addColumnIfNotExists(db, 'nazira_record', 'evening_time', 'TEXT');

    // Classes columns
    final clsCols = [
      'class_type',
      'section',
      'main_teacher_ids',
      'p1_name',
      'p2_name',
      'p3_name',
      'p4_name',
      'p5_name',
      'p6_name',
      'subjects_list'
    ];
    for (var col in clsCols) {
      String def = col == 'class_type'
          ? '"Regular"'
          : (col == 'section' ||
                  col == 'main_teacher_ids' ||
                  col == 'subjects_list'
              ? '""'
              : '"Period ${col.substring(1, 2)}"');
      await _addColumnIfNotExists(db, 'classes', col, 'TEXT DEFAULT $def');
    }
    // Exam Results columns
      await _addColumnIfNotExists(db, 'exams', 'total_marks', 'REAL DEFAULT 100');
      await _addColumnIfNotExists(db, 'exams', 'passing_marks', 'REAL DEFAULT 33');

    final examCols = [
      'masail',
      'miqdar_khwandgi',
      'p1',
      'p2',
      'p3',
      'p4',
      'p5',
      'p6',
      'subjects_marks'
    ];
    for (var col in examCols) {
      String type = (col == 'miqdar_khwandgi' || col == 'subjects_marks')
          ? 'TEXT DEFAULT ""'
          : 'INTEGER DEFAULT 0';
      await _addColumnIfNotExists(db, 'exam_results', col, type);
    }

    final teacherCols = {
      'house_rent': 'REAL DEFAULT 0',
      'medical_allowance': 'REAL DEFAULT 0',
      'travel_allowance': 'REAL DEFAULT 0',
      'daily_deduction_rate': 'REAL DEFAULT 0',
      'photo': 'TEXT',
      'assigned_classes': 'TEXT',
      'assigned_periods': 'TEXT',
    };
    for (final entry in teacherCols.entries) {
      await _addColumnIfNotExists(db, 'teachers', entry.key, entry.value);
    }
  }

  Future<List<Map<String, dynamic>>> getAccPayroll() async {
    Database db = await database;
    return await db.query('acc_payroll',
        where: 'is_deleted = 0 OR is_deleted IS NULL', orderBy: 'id DESC');
  }

  Future<int> insertAccPayroll(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('acc_payroll', data);
  }

  Future<int> updateAccPayroll(int id, Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db
        .update('acc_payroll', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAccInvoices() async {
    Database db = await database;
    return await db.query('acc_invoices',
        where: 'is_deleted = 0 OR is_deleted IS NULL', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final db = await database;
    return await db.query('departments', orderBy: 'name ASC');
  }

  Future<int> insertDepartment(Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    data['is_deleted'] = data['is_deleted'] ?? 0;
    data['status'] = data['status'] ?? 'Active';
    return db.insert('departments', data);
  }

  Future<int> updateDepartment(int id, Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return db.update('departments', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> inactiveDepartment(int id) async {
    return updateDepartment(id, {'status': 'Inactive'});
  }

  Future<int> insertAccInvoice(Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db.insert('acc_invoices', data);
  }

  Future<int> updateAccInvoice(int id, Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db
        .update('acc_invoices', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteComplaint(int id) async {
    Database db = await database;
    return await db.update('complaints', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateComplaint(int id, Map<String, dynamic> row) async {
    Database db = await database;
    var data = Map<String, dynamic>.from(row);
    data['is_synced'] = 0;
    return await db
        .update('complaints', data, where: 'id = ?', whereArgs: [id]);
  }
}
