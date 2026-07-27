// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../db_helper.dart';
import 'globals.dart';
import 'network_service.dart';

class SyncService {
  static const List<String> _tables = [
    'students',
    'teachers',
    'hifz_record',
    'nazira_record',
    'qaida_records',
    'attendance',
    'attendance_teachers',
    'teacher_period_attendance',
    'finance',
    'heads',
    'exams',
    'exam_results',
    'notices',
    'complaints',
    'parent_complaints',
    'leave_applications',
    'fee_submissions',
    'academic_reports',
    'classes',
    'departments',
    'acc_chart_of_accounts',
    'acc_vouchers',
    'acc_ledger_entries',
    'acc_payroll',
    'acc_invoices',
  ];

  static const Map<String, String> _apiKeyMap = {
    'finance': 'finance_entries',
    'heads': 'heads',
    'hifz_record': 'hifz_entries',
    'nazira_record': 'nazira_record',
    'qaida_records': 'qaida_records',
    'attendance': 'attendance_entries',
    'attendance_teachers': 'attendance_teachers',
    'teacher_period_attendance': 'teacher_period_attendance',
    'parent_complaints': 'parent_complaints',
    'leave_applications': 'leave_applications',
    'fee_submissions': 'fee_submissions',
    'exam_results': 'exam_results',
    'exams': 'exams',
    'academic_reports': 'academic_reports',
    'acc_chart_of_accounts': 'acc_chart_of_accounts',
    'acc_vouchers': 'acc_vouchers',
    'acc_ledger_entries': 'acc_ledger_entries',
    'acc_payroll': 'acc_payroll',
    'acc_invoices': 'acc_invoices',
  };

  static const Map<String, String> _uploadPermissionMap = {
    'students': 'manage_students',
    'teachers': 'manage_teachers',
    'finance': 'manage_finance',
    'heads': 'manage_finance',
    'fee_submissions': 'manage_finance',
    'hifz_record': 'manage_hifz',
    'nazira_record': 'manage_hifz',
    'qaida_records': 'manage_hifz',
    'attendance': 'manage_attendance',
    'attendance_teachers': 'manage_teacher_attendance',
    'teacher_period_attendance': 'manage_teacher_attendance',
    'academic_reports': 'manage_academics',
    'complaints': 'manage_students',
    'parent_complaints': 'manage_requests',
    'leave_applications': 'manage_requests',
    'notices': 'manage_notices',
    'exams': 'manage_exams',
    'exam_results': 'manage_exams',
    'classes': 'manage_classes',
    'departments': 'manage_erp',
    'acc_chart_of_accounts': 'manage_erp',
    'acc_vouchers': 'manage_erp',
    'acc_ledger_entries': 'manage_erp',
    'acc_payroll': 'manage_finance',
    'acc_invoices': 'manage_erp',
  };

  static Future<void> runTwoWaySync() async {
    final db = DBHelper();
    final uploadErrors = <String>[];

    for (final table in _tables) {
      if (!_canUploadTable(table)) continue;

      final unsynced = await db.getUnsyncedData(table);
      if (unsynced.isEmpty) continue;

      final apiKey = _apiKeyMap[table] ?? table;
      const chunkSize = 50;

      for (var i = 0; i < unsynced.length; i += chunkSize) {
        final end =
            (i + chunkSize < unsynced.length) ? i + chunkSize : unsynced.length;
        var chunk = unsynced.sublist(i, end);

        // Convert file paths to base64 for image columns
        chunk = await _processImagesForSync(chunk, table);
        if (table == 'students') {
          chunk = chunk.map((row) {
            final copy = Map<String, dynamic>.from(row);
            copy.remove('password');
            return copy;
          }).toList();
        }

        try {
          final response = await NetworkService.postWithFallbackAction(
            'sync_up',
            {apiKey: chunk},
          );

          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }

          final body = jsonDecode(response.body);
          if (body['status'] != 'success' &&
              body['status'] != 'partial_success') {
            throw Exception(body['message']?.toString() ?? 'Sync up failed');
          }

          final syncedIds = body['synced_ids']?[apiKey];
          final serverIds = body['server_ids']?[apiKey];
          if (table == 'finance' &&
              (syncedIds is! List || syncedIds.length < chunk.length)) {
            final errors =
                body['errors']?.toString() ?? 'Unknown finance sync error';
            throw Exception(errors);
          }

          if (syncedIds is List) {
            for (final id in syncedIds) {
              final localId = int.tryParse(id.toString()) ?? 0;
              if (localId == 0) continue;
              if (table == 'finance') {
                int? serverId;
                if (serverIds is Map && serverIds[id.toString()] != null) {
                  serverId = int.tryParse(serverIds[id.toString()].toString());
                }
                await db.markFinanceAsSynced(localId, serverId);
              } else if (table == 'teachers') {
                int? serverId;
                if (serverIds is Map && serverIds[id.toString()] != null) {
                  serverId = int.tryParse(serverIds[id.toString()].toString());
                }
                await db.markTeacherAsSynced(localId, serverId);
              } else {
                await db.markAsSynced(table, localId);
              }
            }
          }
        } catch (e) {
          final message = 'Sync up failed for $table: $e';
          debugPrint(message);
          uploadErrors.add(message);
        }
      }
    }

    await _syncDown(db);

    try {
      await db.ensureSimpleFinanceAccountingBackfill();
    } catch (e) {
      debugPrint('Error in accounting backfill after sync: $e');
    }

    if (uploadErrors.isNotEmpty) {
      throw Exception(uploadErrors.join('\n'));
    }
  }

  static bool _canUploadTable(String table) {
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

    if (table == 'academic_reports' &&
        (permissions.contains('manage_academics') ||
            permissions.contains('manage_hifz'))) {
      return true;
    }

    if (table == 'acc_payroll' &&
        (permissions.contains('manage_finance') ||
            permissions.contains('manage_erp'))) {
      return true;
    }

    final permission = _uploadPermissionMap[table];
    return permission != null && permissions.contains(permission);
  }

  static Future<void> _syncDown(DBHelper db) async {
    final pullResponse =
        await NetworkService.getWithFallbackAction('sync_down');
    if (pullResponse.statusCode != 200) {
      throw Exception('Sync down failed: ${pullResponse.statusCode}');
    }

    final pullBody = jsonDecode(pullResponse.body);
    if (pullBody['status'] == 'success' && pullBody['data'] != null) {
      await db.saveServerData(Map<String, dynamic>.from(pullBody['data']));
      return;
    }

    throw Exception((pullBody['message'] ?? 'Sync down failed').toString());
  }

  static Future<List<Map<String, dynamic>>> _processImagesForSync(
      List<Map<String, dynamic>> chunk, String table) async {
    List<Map<String, dynamic>> processed = [];
    for (var row in chunk) {
      var map = Map<String, dynamic>.from(row);
      if (table == 'fee_submissions' && map['screenshot'] != null) {
        map['screenshot'] = await _fileToBase64(map['screenshot']);
      } else if (table == 'leave_applications' &&
          map['application_photo'] != null) {
        map['application_photo'] =
            await _fileToBase64(map['application_photo']);
      } else if (table == 'parent_complaints' && map['evidence'] != null) {
        map['evidence'] = await _fileToBase64(map['evidence']);
      } else if (table == 'students' && map['photo'] != null) {
        map['photo'] = await _fileToBase64(map['photo']);
      } else if (table == 'teachers' && map['photo'] != null) {
        map['photo'] = await _fileToBase64(map['photo']);
      }
      processed.add(map);
    }
    return processed;
  }

  static Future<String?> _fileToBase64(String path) async {
    if (path.isEmpty ||
        path.startsWith('data:image') ||
        path.startsWith('http')) {
      return path;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String ext = path.split('.').last.toLowerCase();
        if (ext != 'png') ext = 'jpeg';
        return "data:image/$ext;base64,${base64Encode(bytes)}";
      }
    } catch (e) {
      debugPrint("File to base64 error: $e");
    }
    return path;
  }
}
