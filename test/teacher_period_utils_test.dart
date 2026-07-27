import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madrasa_app/utils/teacher_period_utils.dart';

void main() {
  group('buildTeacherPeriodAssignments', () {
    test('uses class main_teacher_ids when teacher profile has no classes', () {
      final assignments = buildTeacherPeriodAssignments(
        teachers: [
          {'id': 1, 'name': 'Teacher A', 'status': 'Active'},
        ],
        classes: [
          {
            'id': 10,
            'name': 'Hifz',
            'class_type': 'Hifz/Gardan/Husn',
            'status': 'Active',
            'main_teacher_ids': jsonEncode([1]),
          },
        ],
        className: 'Hifz',
      );

      expect(assignments.map((a) => a.periodNo), [1, 2, 3, 4]);
      expect(assignments.every((a) => a.teacherId == 1), isTrue);
    });

    test('profile assigned periods limit class-level main teacher periods', () {
      final assignments = buildTeacherPeriodAssignments(
        teachers: [
          {
            'id': 1,
            'name': 'Teacher A',
            'status': 'Active',
            'assigned_periods': jsonEncode({
              'Hifz': ['hifz_evening'],
            }),
          },
        ],
        classes: [
          {
            'id': 10,
            'name': 'Hifz',
            'class_type': 'Hifz/Gardan/Husn',
            'status': 'Active',
            'main_teacher_ids': jsonEncode([1]),
          },
        ],
        className: 'Hifz',
      );

      expect(assignments.length, 1);
      expect(assignments.single.periodNo, 4);
      expect(assignments.single.periodKey, 'hifz_evening');
    });

    test('nazira class defaults to two periods for class-level teacher', () {
      final assignments = buildTeacherPeriodAssignments(
        teachers: [
          {'id': 2, 'name': 'Teacher B', 'status': 'Active'},
        ],
        classes: [
          {
            'id': 20,
            'name': 'Nazira',
            'class_type': 'Nazira',
            'status': 'Active',
            'main_teacher_ids': jsonEncode([2]),
          },
        ],
        className: 'Nazira',
      );

      expect(assignments.map((a) => a.periodNo), [1, 2]);
    });

    test(
        'recognizes Urdu Hifz class name and maps numeric periods to Hifz keys',
        () {
      final assignments = buildTeacherPeriodAssignments(
        teachers: [
          {
            'id': 3,
            'name': 'Teacher C',
            'status': '\u0645\u0648\u062c\u0648\u062f',
            'assigned_periods': jsonEncode({
              '\u062d\u0641\u0638': ['1', '4'],
            }),
          },
        ],
        classes: [
          {
            'id': 30,
            'name': '\u062d\u0641\u0638',
            'class_type': '\u062d\u0641\u0638',
            'status': '\u0645\u0648\u062c\u0648\u062f',
            'main_teacher_ids': jsonEncode([3]),
          },
        ],
        className: '\u062d\u0641\u0638',
      );

      expect(assignments.map((a) => a.periodNo), [1, 4]);
      expect(assignments.map((a) => a.periodKey),
          ['hifz_morning', 'hifz_evening']);
    });

    test('accepts class id based teacher assignments from synced data', () {
      final assignments = buildTeacherPeriodAssignments(
        teachers: [
          {
            'id': 4,
            'name': 'Teacher D',
            'status': 'Active',
            'assigned_classes': jsonEncode(['40']),
            'assigned_periods': jsonEncode({
              '40': ['1', '3'],
            }),
          },
        ],
        classes: [
          {
            'id': 40,
            'name': 'Hifz A',
            'class_type': 'Hifz/Gardan/Husn',
            'status': 'Active',
            'main_teacher_ids': '[]',
          },
        ],
        className: 'Hifz A',
      );

      expect(assignments.map((a) => a.periodNo), [1, 3]);
      expect(
          assignments.map((a) => a.periodKey), ['hifz_morning', 'hifz_noon']);
    });
  });
}
