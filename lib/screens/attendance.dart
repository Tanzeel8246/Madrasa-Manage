// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../widgets/neo_box.dart';
import '../db_helper.dart';
import '../utils/sync_service.dart';
import '../utils/teacher_period_utils.dart';
import 'dashboard.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:ui' as ui;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color textDark = const Color(0xFF2D2D2D);

  final _dateController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<String> _classes = [];
  List<Map<String, dynamic>> _classRows = [];
  List<Map<String, dynamic>> _teachers = [];
  List<TeacherPeriodAssignment> _teacherAssignments = [];
  String? _selectedClass;

  late TabController _tabController;
  List<_AttendancePeriod> _periods = const [];

  final Map<String, Map<int, String>> _statusMap = {};
  final Map<String, Map<int, String>> _delayMap = {};
  final Map<String, Map<int, bool>> _isLateMap = {};
  final Map<String, String> _teacherStatusMap = {};
  final Map<String, bool> _teacherLateMap = {};
  final Map<String, TextEditingController> _teacherLateControllers = {};
  bool _isSaving = false;

  final List<String> statusOptions = [
    'حاضر (Present)',
    'غیر حاضر (Absent)',
    'رخصت (Leave)'
  ];

  bool get _canManageTeacherAttendance =>
      currentUserRole.value == 'admin' ||
      currentUserPermissions.value.contains('manage_attendance') ||
      currentUserPermissions.value.contains('manage_teacher_attendance');

  @override
  void initState() {
    super.initState();
    _periods = _buildPeriodsForClass(null);
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _reloadTeacherAssignments();
    });
    _dateController.text = _formatDate(DateTime.now());
    _loadStudents();
  }

  String _formatDate(DateTime date) {
    return intl.DateFormat('yyyy-MM-dd').format(date);
  }

  void _loadStudents() async {
    final data = await DBHelper().getStudents();
    final classesData = await DBHelper().getClassesForUser();
    final teachersData = await DBHelper().getTeachers();
    final teacherPeriodRows =
        await DBHelper().getTeacherPeriodAttendanceByDate(_dateController.text);
    final attendanceRows =
        await DBHelper().getAttendanceByDate(_dateController.text);
    setState(() {
      _classRows = classesData;
      _classes = classesData.map((c) => c['name'].toString()).toList();
      _teachers = teachersData;
      _students = data.where((s) {
        final st = (s['status'] ?? '').toString().trim().toLowerCase();
        final isDel = int.tryParse(s['is_deleted']?.toString() ?? '0') ?? 0;
        return (st == 'active' || st == 'present' || st == '') && isDel == 0;
      }).toList();
      for (var shift in _allPeriodKeys) {
        _statusMap[shift] = {};
        _delayMap[shift] = {};
        _isLateMap[shift] = {};
        for (var student in data) {
          _statusMap[shift]![student['id']] = 'حاضر (Present)';
          _delayMap[shift]![student['id']] = '';
          _isLateMap[shift]![student['id']] = false;
        }
      }
      _refreshTeacherAssignmentsFromCache(teacherPeriodRows);
      _refreshStudentAttendanceFromCache(attendanceRows);
    });
  }

  String _normalizeStudentStatus(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final code = raw.toUpperCase();
    if (raw.contains('حاضر') ||
        raw.toLowerCase().contains('present') ||
        code == 'P') {
      return 'حاضر (Present)';
    }
    if (raw.contains('غیر') ||
        raw.toLowerCase().contains('absent') ||
        code == 'A') {
      return 'غیر حاضر (Absent)';
    }
    if (raw.contains('رخصت') ||
        raw.toLowerCase().contains('leave') ||
        code == 'L') {
      return 'رخصت (Leave)';
    }
    return raw.isEmpty ? 'حاضر (Present)' : raw;
  }

  String _normalizeStudentShift(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final lower = raw.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    const byNumber = {
      '1': 'Morning',
      '2': 'AfterBreakfast',
      '3': 'Noon',
      '4': 'Evening',
      '5': 'Lesson5',
      '6': 'Lesson6',
      '7': 'Study',
      '8': 'Revision',
    };
    if (byNumber.containsKey(lower)) return byNumber[lower]!;
    if (lower == 'afterbreakfast') return 'AfterBreakfast';
    if (lower == 'morning') return 'Morning';
    if (lower == 'noon') return 'Noon';
    if (lower == 'evening') return 'Evening';
    if (lower == 'lesson1') return 'Lesson1';
    if (lower == 'lesson2') return 'Lesson2';
    if (lower == 'lesson3') return 'Lesson3';
    if (lower == 'lesson4') return 'Lesson4';
    if (lower == 'lesson5') return 'Lesson5';
    if (lower == 'lesson6') return 'Lesson6';
    if (lower == 'study') return 'Study';
    if (lower == 'revision') return 'Revision';
    return raw;
  }

  void _refreshStudentAttendanceFromCache(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final shift = _normalizeStudentShift(row['shift']);
      final studentId = int.tryParse(row['student_id']?.toString() ?? '');
      if (studentId == null || !_statusMap.containsKey(shift)) continue;
      final late = int.tryParse(row['delay_minutes']?.toString() ?? '0') ?? 0;
      _statusMap[shift]![studentId] = _normalizeStudentStatus(row['status']);
      _isLateMap[shift]![studentId] = late > 0;
      _delayMap[shift]![studentId] = late > 0 ? late.toString() : '';
    }
  }

  Future<void> _reloadStudentAttendance() async {
    final rows = await DBHelper().getAttendanceByDate(_dateController.text);
    if (!mounted) return;
    setState(() => _refreshStudentAttendanceFromCache(rows));
  }

  int _currentPeriodNo() => _periods[_tabController.index].periodNo;

  List<String> get _allPeriodKeys => const [
        'Morning',
        'AfterBreakfast',
        'Noon',
        'Evening',
        'Lesson1',
        'Lesson2',
        'Lesson3',
        'Lesson4',
        'Lesson5',
        'Lesson6',
        'Study',
        'Revision',
      ];

  Map<String, dynamic>? get _selectedClassRow {
    if (_selectedClass == null) return null;
    for (final row in _classRows) {
      if (row['name']?.toString() == _selectedClass) return row;
    }
    return null;
  }

  bool _classTextHas(Map<String, dynamic>? row, List<String> needles) {
    final text = [
      row?['name'],
      row?['class_type'],
      row?['section'],
      _selectedClass,
    ].whereType<Object>().join(' ').toLowerCase();
    return needles.any((needle) => text.contains(needle.toLowerCase()));
  }

  bool get _isHifzLikeClass => _classTextHas(_selectedClassRow, [
        'حفظ',
        'گردان',
        'حسن صوت',
        'hifz',
        'gardan',
        'husn',
        'Ø­ÙØ¸',
        'Ú¯Ø±Ø¯Ø§Ù†',
        'Ø­Ø³Ù†',
      ]);

  bool get _isNaziraClass => _classTextHas(_selectedClassRow, [
        'ناظرہ',
        'nazira',
        'Ù†Ø§Ø¸Ø±Û',
      ]);

  List<_AttendancePeriod> _buildPeriodsForClass(String? className) {
    final oldSelected = _selectedClass;
    _selectedClass = className;
    final isHifz = _isHifzLikeClass;
    final isNazira = _isNaziraClass;
    _selectedClass = oldSelected;
    if (isHifz || className == null) {
      return const [
        _AttendancePeriod(1, 'Morning', 'صبح', 'Morning'),
        _AttendancePeriod(
            2, 'AfterBreakfast', 'ناشتہ کے بعد', 'After Breakfast'),
        _AttendancePeriod(3, 'Noon', 'دوپہر', 'Noon'),
        _AttendancePeriod(4, 'Evening', 'شام', 'Evening'),
      ];
    }
    if (isNazira) {
      return const [
        _AttendancePeriod(1, 'Morning', 'صبح', 'Morning'),
        _AttendancePeriod(2, 'Evening', 'شام', 'Evening'),
      ];
    }
    return const [
      _AttendancePeriod(1, 'Lesson1', 'سبق1', 'Lesson 1'),
      _AttendancePeriod(2, 'Lesson2', 'سبق2', 'Lesson 2'),
      _AttendancePeriod(3, 'Lesson3', 'سبق3', 'Lesson 3'),
      _AttendancePeriod(4, 'Lesson4', 'سبق4', 'Lesson 4'),
      _AttendancePeriod(5, 'Lesson5', 'سبق5', 'Lesson 5'),
      _AttendancePeriod(6, 'Lesson6', 'سبق6', 'Lesson 6'),
      _AttendancePeriod(7, 'Study', 'مطالعہ', 'Study'),
      _AttendancePeriod(8, 'Revision', 'تکرار', 'Revision'),
    ];
  }

  void _rebuildTabsForClass(String? className) {
    final nextPeriods = _buildPeriodsForClass(className);
    final oldIndex = _tabController.index;
    _tabController.dispose();
    _periods = nextPeriods;
    _tabController = TabController(
      length: _periods.length,
      vsync: this,
      initialIndex: oldIndex.clamp(0, _periods.length - 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _reloadTeacherAssignments();
    });
  }

  String _teacherKey(TeacherPeriodAssignment a) =>
      [a.teacherId, a.className, a.periodNo].join('|');

  String _normalizeTeacherStatus(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final code = raw.toUpperCase();
    if (raw == '\u062d\u0627\u0636\u0631' || code == 'P') return 'P';
    if (raw == '\u063a\u06cc\u0631 \u062d\u0627\u0636\u0631' || code == 'A') {
      return 'A';
    }
    if (raw ==
            '\u0631\u062e\u0635\u062a \u0627\u062a\u0641\u0627\u0642\u06cc' ||
        code == 'LA') {
      return 'LA';
    }
    if (raw == '\u0628\u06a9\u0627\u0631 \u0645\u062f\u0631\u0633\u06c1' ||
        code == 'OD') {
      return 'OD';
    }
    if (raw == '\u0631\u062e\u0635\u062a' || code == 'L') {
      return 'L';
    }
    return raw.isEmpty ? 'P' : raw;
  }

  void _refreshTeacherAssignmentsFromCache(
      List<Map<String, dynamic>> teacherPeriodRows) {
    for (final controller in _teacherLateControllers.values) {
      controller.dispose();
    }
    _teacherStatusMap.clear();
    _teacherLateMap.clear();
    _teacherLateControllers.clear();
    if (!_canManageTeacherAttendance) {
      _teacherAssignments = [];
      return;
    }
    _teacherAssignments = buildTeacherPeriodAssignments(
      teachers: _teachers,
      classes: _classRows,
      className: _selectedClass,
      periodNo: _currentPeriodNo(),
    );
    for (final assignment in _teacherAssignments) {
      final key = _teacherKey(assignment);
      Map<String, dynamic>? existing;
      for (final row in teacherPeriodRows) {
        final rowTeacherId =
            int.tryParse(row['teacher_id']?.toString() ?? '') ?? 0;
        final rowPeriodNo =
            int.tryParse(row['period_no']?.toString() ?? '') ?? 0;
        final rowClassName = row['class_name']?.toString() ?? '';
        if (rowTeacherId == assignment.teacherId &&
            rowPeriodNo == assignment.periodNo &&
            rowClassName == assignment.className) {
          existing = row;
          break;
        }
      }
      final late =
          int.tryParse(existing?['late_minutes']?.toString() ?? '0') ?? 0;
      _teacherStatusMap[key] = _normalizeTeacherStatus(existing?['status']);
      _teacherLateMap[key] = late > 0;
      _teacherLateControllers[key] =
          TextEditingController(text: late > 0 ? late.toString() : '');
    }
  }

  Future<void> _reloadTeacherAssignments() async {
    final rows =
        await DBHelper().getTeacherPeriodAttendanceByDate(_dateController.text);
    if (!mounted) return;
    setState(() => _refreshTeacherAssignmentsFromCache(rows));
  }

  Future<void> _saveTeacherAttendanceForCurrentPeriod() async {
    if (!_canManageTeacherAttendance) return;
    for (final assignment in _teacherAssignments) {
      final key = _teacherKey(assignment);
      final status = _teacherStatusMap[key] ?? 'P';
      final late = status == 'P' && (_teacherLateMap[key] ?? false)
          ? (_teacherLateControllers[key]?.text.trim() ?? '0')
          : '0';
      await DBHelper().insertTeacherPeriodAttendance({
        'teacher_id': assignment.teacherId,
        'class_id': assignment.classId,
        'class_name': assignment.className,
        'date': _dateController.text,
        'period_no': assignment.periodNo,
        'status': status,
        'late_minutes': int.tryParse(late.isEmpty ? '0' : late) ?? 0,
        'remarks': '',
      });
    }
  }

  Future<void> _saveAttendance() async {
    if (_isSaving) return;

    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUrduGlobal.value
                ? 'کوئی طالب علم موجود نہیں!'
                : 'No students found!')),
      );
      return;
    }

    String currentShift = _periods[_tabController.index].key;

    final filteredStudents = _selectedClass == null
        ? _students
        : _students
            .where((s) =>
                (s['class_name'] ?? s['class'])?.toString() == _selectedClass)
            .toList();

    if (filteredStudents.isEmpty && _teacherAssignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUrduGlobal.value
                ? 'اس منتخب کلاس میں محفوظ کرنے کے لیے کوئی حاضری موجود نہیں۔'
                : 'No attendance records to save for the selected class.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _saveTeacherAttendanceForCurrentPeriod();

      for (var student in filteredStudents) {
        int sId = student['id'];
        final status = _statusMap[currentShift]?[sId] ?? 'حاضر (Present)';
        final isPresent = status == 'حاضر (Present)';
        final lateMins = (isPresent && _isLateMap[currentShift]?[sId] == true)
            ? (_delayMap[currentShift]?[sId] ?? '').trim()
            : '0';

        await DBHelper().insertAttendance({
          'date': _dateController.text,
          'shift': currentShift,
          'student_id': sId.toString(),
          'status': status,
          'delay_minutes': lateMins.isEmpty ? '0' : lateMins,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrduGlobal.value
              ? 'اس وقت کی حاضری محفوظ ہو گئی!'
              : 'Attendance saved!'),
          backgroundColor: primaryGreen,
        ),
      );

      SyncService.runTwoWaySync().catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrduGlobal.value
              ? 'حاضری محفوظ نہیں ہو سکی: $e'
              : 'Attendance could not be saved: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _teacherLateControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (didPop) return;
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (c) => const DashboardPage()));
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
                  isUrdu ? "حاضری رجسٹر" : "Attendance Register",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: primaryGreen,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    tooltip: isUrdu ? 'سنک کریں' : 'Sync',
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isUrdu
                              ? "ڈیٹا سنک ہو رہا ہے..."
                              : "Syncing data...")));
                      try {
                        await SyncService.runTwoWaySync();
                        if (mounted) {
                          _loadStudents();
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
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: _periods
                      .map((period) =>
                          Tab(text: isUrdu ? period.labelUr : period.labelEn))
                      .toList(),
                ),
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: NeoBox(
                            padding: 5,
                            child: TextField(
                              controller: _dateController,
                              readOnly: true,
                              style: TextStyle(
                                  color: textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              decoration: InputDecoration(
                                labelText: isUrdu ? 'تاریخ:' : 'Date:',
                                labelStyle: TextStyle(
                                    color: primaryGreen, fontSize: 12),
                                suffixIcon: Icon(Icons.calendar_today,
                                    color: primaryGreen, size: 18),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                              ),
                              onTap: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (pickedDate != null) {
                                  _dateController.text =
                                      intl.DateFormat('yyyy-MM-dd')
                                          .format(pickedDate);
                                  await _reloadTeacherAssignments();
                                  await _reloadStudentAttendance();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NeoBox(
                            padding: 5,
                            child: DropdownButtonFormField<String>(
                              value: _selectedClass,
                              decoration: InputDecoration(
                                labelText: isUrdu
                                    ? 'کلاس منتخب کریں:'
                                    : 'Select Class:',
                                labelStyle: TextStyle(
                                    color: primaryGreen, fontSize: 12),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                        isUrdu ? "تمام کلاسز" : "All Classes",
                                        style: const TextStyle(fontSize: 13))),
                                ..._classes.map((c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c,
                                        style: const TextStyle(fontSize: 13)))),
                              ],
                              onChanged: (val) async {
                                setState(() {
                                  _selectedClass = val;
                                  _rebuildTabsForClass(val);
                                });
                                await _reloadTeacherAssignments();
                                await _reloadStudentAttendance();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _periods
                          .map(
                              (period) => _buildStudentList(period.key, isUrdu))
                          .toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSaving ? null : _saveAttendance,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isSaving
                              ? (isUrdu ? "محفوظ ہو رہا ہے..." : "Saving...")
                              : (isUrdu ? "محفوظ کریں" : "Save"),
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentList(String shift, bool isUrdu) {
    if (_students.isEmpty) {
      return Center(
        child: Text(
          isUrdu ? "کوئی طالب علم موجود نہیں" : "No students found",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      );
    }

    final filteredStudents = _selectedClass == null
        ? _students
        : _students
            .where((s) =>
                (s['class_name'] ?? s['class'])?.toString() == _selectedClass)
            .toList();

    if (filteredStudents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          _buildTeacherAttendanceSection(isUrdu),
          NeoBox(
            padding: 18,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isUrdu
                        ? 'اس منتخب کلاس میں کوئی طالب علم نہیں ملا۔ سنک کریں یا طالب علم کی کلاس چیک کریں۔'
                        : 'No students found in the selected class. Sync or check student class assignment.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: filteredStudents.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildTeacherAttendanceSection(isUrdu);
        var student = filteredStudents[index - 1];
        int sId = student['id'];
        String sName = student['name'];
        String sRoll = student['roll_number'] ?? '-';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: NeoBox(
            padding: 10,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sName,
                            style: TextStyle(
                                color: textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ولد: ${student['father_name'] ?? '-'}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      sRoll,
                      style: TextStyle(
                          color: primaryGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _statusMap[shift]![sId] == 'حاضر (Present)'
                              ? Colors.green.shade700
                              : _statusMap[shift]![sId] == 'غیر حاضر (Absent)'
                                  ? Colors.red.shade700
                                  : _statusMap[shift]![sId] == 'رخصت (Leave)'
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.white),
                            value: _statusMap[shift]![sId],
                            selectedItemBuilder: (BuildContext context) {
                              return statusOptions.map((String value) {
                                return Center(
                                  child: Text(
                                    value,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList();
                            },
                            items: statusOptions.map((String item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item,
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _statusMap[shift]![sId] = newValue!;
                                if (newValue != 'حاضر (Present)') {
                                  _isLateMap[shift]![sId] = false;
                                  _delayMap[shift]![sId] = '';
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_statusMap[shift]![sId] == 'حاضر (Present)') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value:
                              (_isLateMap[shift]![sId] ?? false) ? 'late' : '0',
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'تاخیر' : 'Delay',
                            labelStyle: const TextStyle(fontSize: 13),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: '0',
                                child: Text(isUrdu ? 'بلا تاخیر' : 'On Time',
                                    style: const TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'late',
                                child: Text(isUrdu ? 'تاخیر' : 'Late',
                                    style: const TextStyle(fontSize: 13))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _isLateMap[shift]![sId] = val == 'late';
                              if (val != 'late') {
                                _delayMap[shift]![sId] = '';
                              }
                            });
                          },
                        ),
                      ),
                      if (_isLateMap[shift]![sId] ?? false) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: _delayMap[shift]![sId],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: isUrdu ? 'منع' : 'Min',
                              labelStyle: const TextStyle(fontSize: 12),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 14),
                            onChanged: (val) {
                              _delayMap[shift]![sId] = val;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeacherAttendanceSection(bool isUrdu) {
    if (!_canManageTeacherAttendance) {
      return const SizedBox.shrink();
    }
    if (_teacherAssignments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: NeoBox(
          padding: 12,
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isUrdu
                      ? 'اس کلاس/پیریڈ کے لیے کوئی استاد متعین نہیں۔'
                      : 'No teacher assigned for this class/period',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: _teacherAssignments.map((assignment) {
        final key = _teacherKey(assignment);
        final currentStatus = _teacherStatusMap[key] ?? 'P';
        final isPresent = currentStatus == 'P';
        final isLate = _teacherLateMap[key] ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: NeoBox(
            padding: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_pin, color: primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.teacherName,
                            style: TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${assignment.className} - ${isUrdu ? assignment.periodLabelUr : assignment.periodLabelEn}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    _buildTeacherStatusChip(
                        key, 'P', isUrdu ? 'حاضر' : 'Present', Colors.green),
                    _buildTeacherStatusChip(
                        key, 'L', isUrdu ? 'رخصت' : 'Leave', Colors.orange),
                    _buildTeacherStatusChip(key, 'LA',
                        isUrdu ? 'رخصت اتفاقی' : 'Casual Leave', Colors.blue),
                    _buildTeacherStatusChip(key, 'OD',
                        isUrdu ? 'بکار مدرسہ' : 'Official Duty', Colors.purple),
                  ],
                ),
                if (isPresent) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: isLate ? 'late' : '0',
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'تاخیر' : 'Delay',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: '0',
                                child: Text(isUrdu ? 'بلا تاخیر' : 'On Time')),
                            DropdownMenuItem(
                                value: 'late',
                                child: Text(isUrdu ? 'تاخیر' : 'Late')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _teacherLateMap[key] = val == 'late';
                              if (val != 'late') {
                                _teacherLateControllers[key]?.clear();
                              }
                            });
                          },
                        ),
                      ),
                      if (isLate) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: _teacherLateControllers[key],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: isUrdu ? 'منٹ' : 'Min',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeacherStatusChip(
      String key, String value, String label, Color color) {
    final selected = _teacherStatusMap[key] == value;
    final chipWidth =
        ((MediaQuery.of(context).size.width - 76) / 2).clamp(120.0, 180.0);
    return SizedBox(
      width: chipWidth.toDouble(),
      child: InkWell(
        onTap: () {
          setState(() {
            _teacherStatusMap[key] = value;
            if (value != 'P') {
              _teacherLateMap[key] = false;
              _teacherLateControllers[key]?.clear();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendancePeriod {
  const _AttendancePeriod(this.periodNo, this.key, this.labelUr, this.labelEn);

  final int periodNo;
  final String key;
  final String labelUr;
  final String labelEn;
}
