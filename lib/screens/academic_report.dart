// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import '../utils/system_type_global.dart';
import '../utils/performance_helper.dart';
import 'dashboard.dart';

class AcademicReportPage extends StatefulWidget {
  final String? className;
  const AcademicReportPage({super.key, this.className});

  @override
  _AcademicReportPageState createState() => _AcademicReportPageState();
}

class _AcademicReportPageState extends State<AcademicReportPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color textDark = const Color(0xFF2D2D2D);

  final _dateController = TextEditingController();
  final _subjectController = TextEditingController();
  final _batchLessonController = TextEditingController();

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _rawClassesData = [];
  List<String> _classes = [];
  String? _selectedClass;
  List<String> _availableSubjects = [];

  final Map<int, TextEditingController> _lessonDetailsControllers = {};
  final Map<int, String?> _selectedGrades = {};
  final Map<int, TextEditingController> _remarksControllers = {};
  final Map<int, int> _existingRecordIds = {};
  final Map<int, String> _studentAttStatus = {};

  final FocusNode _subjectFocus = FocusNode();

  final List<String> grades = [
    "یاد ہے",
    "یاد نہیں",
    "کچا پکا",
    "غیر حاضر",
    "رخصت",
    "بہترین",
    "بہتر",
    "رعایتی پاس",
    "کچا",
    "سبق نہیں سنایا"
  ];

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.className;
    _dateController.text = _formatDate(DateTime.now());

    _subjectFocus.addListener(() {
      if (!_subjectFocus.hasFocus) {
        _checkExistingRecords();
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _subjectFocus.dispose();
    _dateController.dispose();
    _subjectController.dispose();
    _batchLessonController.dispose();
    for (var c in _lessonDetailsControllers.values) {
      c.dispose();
    }
    for (var c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _normalizeClassName(dynamic value) {
    return (value?.toString() ?? '')
        .trim()
        .replaceAll('ٰ', '')
        .replaceAll('ى', 'ی')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  bool _isActiveStudent(Map<String, dynamic> student) {
    return PerformanceCalculator.isStudentActive(student);
  }

  bool _studentBelongsToSelectedClass(Map<String, dynamic> student) {
    if (_selectedClass == null) return false;
    final selected = _normalizeClassName(_selectedClass);
    final className = _normalizeClassName(student['class_name']);
    final legacyClass = _normalizeClassName(student['class']);
    return className == selected || legacyClass == selected;
  }

  void _loadData() async {
    final data = await DBHelper().getStudentsForUser(includeInactive: true);
    final classesData = await DBHelper().getClassesForUser();

    List<Map<String, dynamic>> filteredClasses = classesData;
    if (currentUserRole.value == 'teacher' && currentUserId.value != null) {
      final tIdStr = currentUserId.value.toString();
      filteredClasses = classesData.where((c) {
        final mainIds = c['main_teacher_ids']?.toString() ?? '';
        final periodIds = c['period_teacher_ids']?.toString() ?? '';
        return mainIds.contains(tIdStr) || periodIds.contains(tIdStr);
      }).toList();
    }

    setState(() {
      _rawClassesData = filteredClasses;
      _classes = filteredClasses.map((c) => c['name'].toString()).toList();
      _allStudents = data.where((s) {
        final cName = _normalizeClassName(
            s['class_name']?.toString().isNotEmpty == true
                ? s['class_name']
                : s['class']);
        final isHifz = cName.contains('حفظ') ||
            cName.contains('حسنصوت') ||
            cName.contains('گردان');
        return _isActiveStudent(s) && !isHifz;
      }).toList();

      for (var student in _allStudents) {
        int sId = student['id'];
        _lessonDetailsControllers.putIfAbsent(
            sId, () => TextEditingController());
        _remarksControllers.putIfAbsent(sId, () => TextEditingController());
      }
    });

    if (_selectedClass != null) {
      _updateAvailableSubjectsForClass(_selectedClass);
      await _checkExistingRecords();
    }
  }

  void _updateAvailableSubjectsForClass(String? className) {
    if (className == null) {
      _availableSubjects = [];
      return;
    }
    final match = _rawClassesData.firstWhere(
      (c) => _normalizeClassName(c['name']) == _normalizeClassName(className),
      orElse: () => {},
    );
    if (match.isEmpty) {
      _availableSubjects = [];
      return;
    }

    final subjectsSet = <String>{};
    final subListStr = match['subjects_list']?.toString() ?? '';
    if (subListStr.isNotEmpty) {
      final parts = subListStr.split(RegExp(r'[,،]'));
      for (final p in parts) {
        final clean = p.split(':').first.trim();
        if (clean.isNotEmpty) subjectsSet.add(clean);
      }
    }

    for (int i = 1; i <= 6; i++) {
      final pName = match['p${i}_name']?.toString().trim() ?? '';
      if (pName.isNotEmpty && !pName.toLowerCase().startsWith('period')) {
        subjectsSet.add(pName);
      }
    }

    if (currentUserRole.value == 'teacher' && currentUserId.value != null) {
      final tIdStr = currentUserId.value.toString();
      try {
        final pTeacherMap =
            jsonDecode(match['period_teacher_ids']?.toString() ?? '{}')
                as Map<String, dynamic>;
        final teacherPeriods = <int>{};
        pTeacherMap.forEach((pStr, ids) {
          if (ids is List && ids.map((e) => e.toString()).contains(tIdStr)) {
            final pInt = int.tryParse(pStr);
            if (pInt != null) teacherPeriods.add(pInt);
          }
        });
        if (teacherPeriods.isNotEmpty) {
          final teacherSubjects = <String>{};
          for (final pNo in teacherPeriods) {
            final pName = match['p${pNo}_name']?.toString().trim() ?? '';
            if (pName.isNotEmpty) teacherSubjects.add(pName);
          }
          if (teacherSubjects.isNotEmpty) {
            subjectsSet.retainAll(teacherSubjects);
          }
        }
      } catch (_) {}
    }

    _availableSubjects = subjectsSet.toList();
    if (_availableSubjects.isNotEmpty &&
        (_subjectController.text.trim().isEmpty ||
            !_availableSubjects.contains(_subjectController.text.trim()))) {
      _subjectController.text = _availableSubjects.first;
    }
  }

  String _normalizeDate(String dateStr) {
    if (dateStr.contains('-')) return dateStr;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        String d = parts[0].padLeft(2, '0');
        String m = parts[1].padLeft(2, '0');
        String y = parts[2];
        return "$y-$m-$d";
      }
    } catch (_) {}
    return dateStr;
  }

  Future<void> _checkExistingRecords() async {
    if (_selectedClass == null) return;
    String d = _dateController.text;
    if (d.isEmpty) return;
    String normalizedD = _normalizeDate(d);

    final db = await DBHelper().database;

    // 1. Fetch attendance for this date & determine auto-status
    final sysType = SystemTypeGlobal.currentSystemType.value;
    final sysCond = sysType == 'Masjid'
        ? "system_type = 'Masjid'"
        : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";

    final attRecords = await db.query(
      'attendance',
      where: '(date = ? OR date = ?) AND $sysCond',
      whereArgs: [d, normalizedD],
    );

    _studentAttStatus.clear();
    for (final att in attRecords) {
      final sId = int.tryParse(att['student_id']?.toString() ?? '');
      if (sId != null) {
        final statusRaw = (att['status'] ?? '').toString().trim();
        final status1 = (att['status_1'] ?? '').toString().trim();
        final statusMerged = ('$statusRaw $status1').toLowerCase();

        if (statusMerged.contains('absent') ||
            statusMerged.contains('غیر حاضر') ||
            statusMerged.contains('غیرحاضر') ||
            statusMerged.contains('غائب') ||
            statusRaw == 'A' ||
            status1 == 'A') {
          _studentAttStatus[sId] = 'غیر حاضر';
        } else if (statusMerged.contains('leave') ||
            statusMerged.contains('رخصت') ||
            statusMerged.contains('چھٹی') ||
            statusRaw == 'L' ||
            status1 == 'L') {
          if (_studentAttStatus[sId] != 'غیر حاضر') {
            _studentAttStatus[sId] = 'رخصت';
          }
        } else if (statusMerged.contains('present') ||
            statusMerged.contains('حاضر') ||
            statusRaw == 'P' ||
            status1 == 'P') {
          if (!_studentAttStatus.containsKey(sId)) {
            _studentAttStatus[sId] = 'حاضر';
          }
        }
      }
    }

    // 2. Fetch existing academic reports for this class, date, and subject
    String subjectQuery = '';
    List<dynamic> args = [_selectedClass, d, normalizedD];
    if (_subjectController.text.trim().isNotEmpty) {
      subjectQuery = ' AND subject = ?';
      args.add(_subjectController.text.trim());
    }

    final existing = await db.query('academic_reports',
        where:
            'class_name = ? AND (date = ? OR date = ?) AND is_deleted = 0$subjectQuery',
        whereArgs: args);

    // Clear current fields for all students & apply attendance-based default
    for (var s in _allStudents) {
      int sId = s['id'];
      _lessonDetailsControllers[sId]?.clear();
      _remarksControllers[sId]?.clear();

      final att = _studentAttStatus[sId] ?? 'حاضر';
      if (att == 'غیر حاضر') {
        _selectedGrades[sId] = 'غیر حاضر';
      } else if (att == 'رخصت') {
        _selectedGrades[sId] = 'رخصت';
      } else {
        _selectedGrades[sId] = 'یاد ہے';
      }
    }
    _existingRecordIds.clear();

    if (existing.isNotEmpty) {
      if (_subjectController.text.trim().isEmpty) {
        _subjectController.text = existing.first['subject']?.toString() ?? '';
      }
      for (var r in existing) {
        int sId = int.tryParse(r['student_id']?.toString() ?? '') ?? -1;
        if (sId != -1 && _lessonDetailsControllers.containsKey(sId)) {
          _existingRecordIds[sId] = r['id'] as int;
          _lessonDetailsControllers[sId]?.text =
              r['lesson_details']?.toString() ?? '';
          final savedGrade = r['grade']?.toString();
          if (savedGrade != null && savedGrade.isNotEmpty) {
            _selectedGrades[sId] = savedGrade;
          }
          _remarksControllers[sId]?.text = r['remarks']?.toString() ?? '';
        }
      }
    }
    setState(() {});
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.red.shade800,
      duration: const Duration(seconds: 4),
    ));
  }

  void _applyBatchNextLesson() {
    final text = _batchLessonController.text.trim();
    if (text.isEmpty) {
      _showError(isUrduGlobal.value
          ? 'براہِ کرم پہلے اگلا سبق درج کریں!'
          : 'Please enter next lesson first!');
      return;
    }

    final filteredStudents =
        _allStudents.where(_studentBelongsToSelectedClass).toList();
    int appliedCount = 0;

    for (var s in filteredStudents) {
      int sId = s['id'];
      final g = _selectedGrades[sId];
      if (g != 'غیر حاضر' && g != 'رخصت') {
        _lessonDetailsControllers[sId]?.text = text;
        appliedCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isUrduGlobal.value
          ? '$appliedCount حاضر طلبہ کے لیے اگلا سبق سیٹ ہو گیا!'
          : 'Next lesson applied to $appliedCount present students!'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _saveAll() async {
    if (_selectedClass == null) {
      _showError(isUrduGlobal.value ? 'کلاس منتخب کریں!' : 'Select Class!');
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      _showError(isUrduGlobal.value ? 'مضمون درج کریں!' : 'Enter subject!');
      return;
    }

    final filteredStudents =
        _allStudents.where(_studentBelongsToSelectedClass).toList();

    if (filteredStudents.isEmpty) {
      _showError(
          isUrduGlobal.value ? 'طالب علم موجود نہیں!' : 'No students found!');
      return;
    }

    final db = await DBHelper().database;
    String d = _dateController.text;

    int savedCount = 0;

    for (var student in filteredStudents) {
      int sId = student['id'];
      final grade = _selectedGrades[sId];
      if (grade != null && grade.isNotEmpty) {
        Map<String, dynamic> data = {
          'date': d,
          'student_id': sId.toString(),
          'class_name': _selectedClass,
          'subject': _subjectController.text.trim(),
          'lesson_details': _lessonDetailsControllers[sId]?.text.trim() ?? '',
          'grade': grade,
          'remarks': _remarksControllers[sId]?.text.trim() ?? '',
          'is_deleted': 0,
          'is_synced': 0,
        };

        if (_existingRecordIds.containsKey(sId)) {
          await db.update('academic_reports', data,
              where: 'id = ?', whereArgs: [_existingRecordIds[sId]]);
        } else {
          final newId = await db.insert('academic_reports', data);
          _existingRecordIds[sId] = newId;
        }
        savedCount++;
      }
    }

    if (savedCount == 0) {
      _showError(isUrduGlobal.value
          ? 'کم از کم ایک طالب علم کا گریڈ منتخب کریں!'
          : 'Select grade for at least one student!');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUrduGlobal.value
            ? '$savedCount طلبہ کا تعلیمی ریکارڈ کامیابی سے محفوظ ہو گیا!'
            : '$savedCount reports saved successfully!'),
        backgroundColor: Colors.green));

    try {
      await SyncService.runTwoWaySync();
    } catch (_) {}
  }

  Color _getGradeColor(String? grade) {
    if (grade == 'غیر حاضر' ||
        grade == 'یاد نہیں' ||
        grade == 'سبق نہیں سنایا') {
      return const Color(0xFFC62828);
    }
    if (grade == 'رخصت' || grade == 'کچا پکا' || grade == 'کچا') {
      return const Color(0xFFE65100);
    }
    if (grade == 'یاد ہے' ||
        grade == 'بہترین' ||
        grade == 'بہتر' ||
        grade == 'حاضر') {
      return primaryGreen;
    }
    return textDark;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (c) => const DashboardPage()));
            }
          },
          child: Directionality(
            textDirection: isUrdu ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Scaffold(
              backgroundColor: bgColor,
              drawer: const AppDrawer(),
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(
                    isUrdu
                        ? 'جنرل تعلیمی رپورٹ اندراج'
                        : 'Academic Report Entry',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isUrdu
                              ? "ڈیٹا سنک ہو رہا ہے..."
                              : "Syncing data...")));
                      try {
                        await SyncService.runTwoWaySync();
                        if (mounted) {
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isUrdu
                                  ? "سنک مکمل ہو گیا!"
                                  : "Sync complete!"),
                              backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  isUrdu ? "سنک میں خرابی آئی" : "Sync failed"),
                              backgroundColor: Colors.red));
                        }
                      }
                    },
                  ),
                ],
              ),
              endDrawer: const AppDrawer(),
              body: Column(
                children: [
                  _buildHeaderFilters(isUrdu),
                  Expanded(
                    child: _buildStudentsList(isUrdu),
                  ),
                ],
              ),
              bottomNavigationBar: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      isUrdu
                          ? "مکمل کلاس کا رزلٹ محفوظ کریں"
                          : "Save All Records",
                      style: const TextStyle(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderFilters(bool isUrdu) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                        labelText: isUrdu ? 'تاریخ' : 'Date',
                        suffixIcon: const Icon(Icons.calendar_today, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12)),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (picked != null) {
                        setState(
                            () => _dateController.text = _formatDate(picked));
                        await _checkExistingRecords();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedClass,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'کلاس' : 'Class',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(isUrdu ? "منتخب کریں" : "Select Class",
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87)),
                      ),
                      ..._classes.map((c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87)))),
                    ],
                    onChanged: (val) async {
                      setState(() {
                        _selectedClass = val;
                        _updateAvailableSubjectsForClass(val);
                      });
                      await _checkExistingRecords();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_availableSubjects.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                value:
                    _availableSubjects.contains(_subjectController.text.trim())
                        ? _subjectController.text.trim()
                        : (_availableSubjects.isNotEmpty
                            ? _availableSubjects.first
                            : null),
                decoration: InputDecoration(
                  labelText: isUrdu ? "مضمون / کتاب" : "Subject / Book",
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                items: _availableSubjects
                    .map((s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) async {
                  if (val != null) {
                    setState(() => _subjectController.text = val);
                    await _checkExistingRecords();
                  }
                },
              )
            else
              TextField(
                controller: _subjectController,
                focusNode: _subjectFocus,
                decoration: InputDecoration(
                    labelText: isUrdu ? "مضمون" : "Subject",
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12)),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  _subjectFocus.unfocus();
                },
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _batchLessonController,
                      decoration: InputDecoration(
                        hintText: isUrdu
                            ? "تمام حاضر طلبہ کے لیے اگلا سبق درج کریں..."
                            : "Enter next lesson for all present...",
                        hintStyle: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _applyBatchNextLesson,
                    icon: const Icon(Icons.bolt, size: 16, color: Colors.white),
                    label: Text(
                      isUrdu ? "سب پر لاگو کریں" : "Apply to All",
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList(bool isUrdu) {
    if (_selectedClass == null) {
      return Center(
        child: Text(
            isUrdu ? "پہلے کلاس منتخب کریں" : "Please select a class first",
            style: const TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    final filteredStudents =
        _allStudents.where(_studentBelongsToSelectedClass).toList();

    if (filteredStudents.isEmpty) {
      return Center(
        child: Text(
            isUrdu
                ? "اس کلاس میں کوئی طالب علم نہیں"
                : "No students in this class",
            style: const TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      itemCount: filteredStudents.length,
      itemBuilder: (context, index) {
        var student = filteredStudents[index];
        int sId = student['id'];
        String sName = student['name'] ?? 'نامعلوم';
        String fName = student['father_name'] ?? 'نامعلوم';
        String sRoll = student['roll_number']?.toString() ??
            student['admission_number']?.toString() ??
            '${index + 1}';
        final attStatus = _studentAttStatus[sId] ?? 'حاضر';
        final currentGrade = _selectedGrades[sId];
        final gradeColor = _getGradeColor(currentGrade);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: currentGrade == 'غیر حاضر'
                  ? Colors.red.shade300
                  : (currentGrade == 'رخصت'
                      ? Colors.orange.shade300
                      : Colors.grey.shade300),
              width: currentGrade == 'غیر حاضر' || currentGrade == 'رخصت'
                  ? 1.5
                  : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(sRoll,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: primaryGreen)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text("$sName - $fName",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: primaryGreen)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: attStatus == 'غیر حاضر'
                            ? Colors.red.shade50
                            : (attStatus == 'رخصت'
                                ? Colors.orange.shade50
                                : Colors.green.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: attStatus == 'غیر حاضر'
                              ? Colors.red.shade400
                              : (attStatus == 'رخصت'
                                  ? Colors.orange.shade400
                                  : Colors.green.shade400),
                        ),
                      ),
                      child: Text(
                        attStatus == 'غیر حاضر'
                            ? (isUrdu ? 'غیر حاضر' : 'Absent')
                            : (attStatus == 'رخصت'
                                ? (isUrdu ? 'رخصت' : 'Leave')
                                : (isUrdu ? 'حاضر' : 'Present')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: attStatus == 'غیر حاضر'
                              ? Colors.red.shade800
                              : (attStatus == 'رخصت'
                                  ? Colors.orange.shade900
                                  : Colors.green.shade800),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: currentGrade == 'غیر حاضر'
                              ? Colors.red.shade50
                              : (currentGrade == 'رخصت'
                                  ? Colors.orange.shade50
                                  : Colors.white),
                          border: Border.all(color: gradeColor, width: 1.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: currentGrade,
                            dropdownColor: Colors.white,
                            style: TextStyle(
                                color: gradeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            hint: Text(
                                isUrdu
                                    ? "پچھلا سبق / کیفیت"
                                    : "Last Lesson / Grade",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            items: grades.map((g) {
                              final c = _getGradeColor(g);
                              return DropdownMenuItem<String>(
                                value: g,
                                child: Text(g,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: c)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedGrades[sId] = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 7,
                      child: TextField(
                        controller: _lessonDetailsControllers[sId],
                        decoration: InputDecoration(
                          hintText: isUrdu
                              ? "اگلا سبق (مقدار / عنوان)"
                              : "Next Lesson",
                          hintStyle: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
