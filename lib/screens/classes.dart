// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/system_type_global.dart';
import '../utils/sync_service.dart';
import '../utils/teacher_period_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/neo_box.dart';
import 'dashboard.dart';
import 'students.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  _ClassesPageState createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color bgColor = const Color(0xFFF1EFE7);

  final List<String> _classTypes = const [
    'Darse Nizami',
    'Asri Taleem',
    'Hifz/Gardan/Husn',
    'Husn-e-Saut',
    'Nazira',
    'Qaida',
    'Tajweed',
  ];

  static const Map<String, List<String>> courseClassPresets = {
    'اولیٰ (عامہ سال اول)': [
      'نحو میر',
      'صرف میر',
      'تسہیل الادب',
      'زاد الطالبین',
      'نور الایضاح',
    ],
    'اولیٰ عربی': [
      'دروس اللغۃ العربیۃ',
      'القراءۃ الراشدۃ',
      'النحو الواضح',
      'الصرف الواضح',
      'الفقہ المیسر',
      'زاد الطالبین',
    ],
    'اولیٰ نہم (مع میٹرک 9th)': [
      'نحو میر (حصہ اول)',
      'صرف میر (حصہ اول)',
      'تسہیل الادب (حصہ اول)',
      'زاد الطالبین (حصہ اول)',
      'انگریزی (9th)',
      'اردو (9th)',
      'ریاضی (9th)',
      'مطالعہ پاکستان (9th)',
      'جنرل سائنس (9th)',
      'اسلامیات لازمی (9th)',
    ],
    'اولیٰ دہم (مع میٹرک 10th)': [
      'نحو میر (مکمل)',
      'علم الصیغہ',
      'نور الایضاح (فقہ)',
      'زاد الطالبین (مکمل)',
      'انگریزی (10th)',
      'اردو (10th)',
      'ریاضی (10th)',
      'مطالعہ پاکستان (10th)',
      'جنرل سائنس (10th)',
    ],
    'ثانیہ (عامہ سال دوم)': [
      'ہدایۃ النحو',
      'علم الصیغہ',
      'قدوری',
      'نفحة الیمن',
      'قصص النبیین',
    ],
    'ثالثہ (خاصہ سال اول)': [
      'کافیہ',
      'اصول الشاشی',
      'قدوری (مکمل)',
      'مقامات حریری',
    ],
    'رابعہ (خاصہ سال دوم)': [
      'شرح جامی',
      'کنز الدقائق',
      'نور الانوار',
      'شرح التہذیب',
    ],
    'خامسہ (عالیہ سال اول)': [
      'ہدایہ اول',
      'حسامی',
      'دیوان الحماسہ',
      'مختصر المعانی',
    ],
    'سادسہ (عالیہ سال دوم)': [
      'ہدایہ ثالث',
      'توضیح و تلویح',
      'جلالین',
      'مسلم الثبوت',
    ],
    'سابعہ (عالمیہ سال اول)': [
      'مشکوٰۃ المصابیح',
      'ہدایہ رابع',
      'شرح العقائد',
      'بیضاوی',
    ],
    'دورہ حدیث شریف': [
      'صحیح البخاری',
      'صحیح مسلم',
      'جامع الترمذی',
      'سنن ابی داؤد',
      'سنن النسائی',
      'سنن ابن ماجہ',
      'موطا امام مالک',
      'شرح معانی الآثار',
    ],
    'عصری ہفتم (7th)': ['انگریزی', 'ریاضی', 'اردو', 'سائنس', 'اسلامیات', 'مطالعہ پاکستان'],
    'عصری ہشتم (8th)': ['انگریزی', 'ریاضی', 'اردو', 'سائنس', 'اسلامیات', 'مطالعہ پاکستان'],
    'عصری نہم (9th)': ['انگریزی', 'ریاضی', 'اردو', 'فزکس', 'کیمسٹری', 'کمپیوٹر', 'اسلامیات'],
    'عصری دہم (10th)': ['انگریزی', 'ریاضی', 'اردو', 'فزکس', 'کیمسٹری', 'کمپیوٹر', 'مطالعہ پاکستان'],
    'حفظ / گردان': ['صبح کا سیشن (سبق)', 'دوپہر کا سیشن (سبقی)', 'شام کا سیشن (منزل)', 'رات کا سیشن (تکرار)'],
    'ناظرہ قرآن': ['صبح کا سیشن', 'شام کا سیشن'],
    'نورانی قاعدہ': ['صبح کا سیشن', 'شام کا سیشن'],
    'حسنِ صوت': ['صبح کا سیشن', 'دوپہر کا سیشن', 'شام کا سیشن', 'رات کا سیشن'],
    'تجوید و قراءت': ['پیریڈ 1: مخارج و صفات', 'پیریڈ 2: مشق و ترتیل'],
  };

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _courses = [];
  Map<int, List<Map<String, dynamic>>> _courseSubjectsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isMasjid = SystemTypeGlobal.currentSystemType.value == 'Masjid';
    var classes = isMasjid ? await DBHelper().getMaktabClasses() : await DBHelper().getClasses();
    var teachers = isMasjid ? await DBHelper().getMaktabTeachers() : await DBHelper().getTeachers();
    List<Map<String, dynamic>> courses = [];
    Map<int, List<Map<String, dynamic>>> courseSubjectsMap = {};
    try {
      courses = await DBHelper().getCourseStructures();
      for (final c in courses) {
        final cId = c['id'] as int?;
        if (cId != null) {
          final subs = await DBHelper().getCourseSubjects(cId);
          courseSubjectsMap[cId] = subs;
        }
      }
    } catch (e) {
      debugPrint('Error loading courses in classes: $e');
    }

    if (!mounted) return;
    setState(() {
      _classes = classes;
      _teachers = teachers;
      _courses = courses;
      _courseSubjectsMap = courseSubjectsMap;
      _isLoading = false;
    });

    if (classes.isEmpty) {
      SyncService.runTwoWaySync().then((_) async {
        if (!mounted) return;
        final refreshedClasses = isMasjid ? await DBHelper().getMaktabClasses() : await DBHelper().getClasses();
        final refreshedTeachers = isMasjid ? await DBHelper().getMaktabTeachers() : await DBHelper().getTeachers();
        if (mounted && refreshedClasses.isNotEmpty) {
          setState(() {
            _classes = refreshedClasses;
            _teachers = refreshedTeachers;
          });
        }
      }).catchError((_) {});
    }
  }

  Future<void> _syncData(bool isUrdu) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isUrdu ? 'ڈیٹا سنک ہو رہا ہے...' : 'Syncing data...'),
    ));
    try {
      await SyncService.runTwoWaySync();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUrdu ? 'سنک مکمل ہو گیا!' : 'Sync complete!'),
        backgroundColor: Colors.green,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUrdu ? 'سنک میں خرابی آئی' : 'Sync failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  List<String> _decodeTeacherIds(dynamic raw) {
    if (raw == null) return [];
    final text = raw.toString().trim();
    if (text.isEmpty) return [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _teacherNames(dynamic raw) {
    final ids = _decodeTeacherIds(raw).toSet();
    if (ids.isEmpty) return '';
    final names = _teachers
        .where((t) => ids.contains(t['id']?.toString()))
        .map((t) => t['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    return names.join('، ');
  }

  List<Map<String, String>> _getPeriodDefinitionsForClass(
      String classType, String className, bool isUrdu, [String? subjectsList]) {
    // If subjectsList or preset provides subject names, dynamically label the periods with those subjects
    final subjects = subjectsList != null && subjectsList.trim().isNotEmpty
        ? subjectsList
            .split(RegExp(r'[,،\n]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : (courseClassPresets[className] ?? []);

    if (subjects.isNotEmpty) {
      final list = <Map<String, String>>[];
      for (int i = 0; i < subjects.length && i < 8; i++) {
        final pNo = (i + 1).toString();
        final sName = subjects[i];
        list.add({
          'period_no': pNo,
          'label': isUrdu ? 'پیریڈ $pNo: $sName' : 'Period $pNo: $sName',
          'subject_name': sName,
        });
      }
      return list;
    }

    final clean = '${classType.toLowerCase()} ${className.toLowerCase()}';
    if (clean.contains('nazira') || clean.contains('ناظرہ') || clean.contains('qaida') || clean.contains('قاعدہ')) {
      return [
        {'period_no': '1', 'label': isUrdu ? 'پیریڈ 1: صبح کا سیشن' : 'Period 1: Morning Shift', 'subject_name': 'صبح کا سیشن'},
        {'period_no': '2', 'label': isUrdu ? 'پیریڈ 2: شام کا سیشن' : 'Period 2: Evening Shift', 'subject_name': 'شام کا سیشن'},
      ];
    }
    if (clean.contains('husn') || clean.contains('حسن') || clean.contains('صوت')) {
      return [
        {'period_no': '1', 'label': isUrdu ? 'پیریڈ 1: صبح کا سیشن' : 'Period 1: Morning Shift', 'subject_name': 'صبح کا سیشن'},
        {'period_no': '2', 'label': isUrdu ? 'پیریڈ 2: دوپہر کا سیشن' : 'Period 2: Noon Shift', 'subject_name': 'دوپہر کا سیشن'},
        {'period_no': '3', 'label': isUrdu ? 'پیریڈ 3: عصر / شام کا سیشن' : 'Period 3: Evening Shift', 'subject_name': 'عصر / شام کا سیشن'},
        {'period_no': '4', 'label': isUrdu ? 'پیریڈ 4: مغرب / عشاء کا سیشن' : 'Period 4: Night Shift', 'subject_name': 'مغرب / عشاء کا سیشن'},
      ];
    }
    if (clean.contains('hifz') || clean.contains('حفظ') || clean.contains('gardan') || clean.contains('گردان')) {
      return [
        {'period_no': '1', 'label': isUrdu ? 'پیریڈ 1: صبح کا سیشن (سبق)' : 'Period 1: Morning (Sabaq)', 'subject_name': 'سبق'},
        {'period_no': '2', 'label': isUrdu ? 'پیریڈ 2: ناشتہ / دوپہر (سبقی)' : 'Period 2: Noon (Sabqi)', 'subject_name': 'سبقی'},
        {'period_no': '3', 'label': isUrdu ? 'پیریڈ 3: عصر / شام (منزل)' : 'Period 3: Evening (Manzil)', 'subject_name': 'منزل'},
        {'period_no': '4', 'label': isUrdu ? 'پیریڈ 4: مغرب / عشاء (تکرار)' : 'Period 4: Night (Takrar)', 'subject_name': 'تکرار'},
      ];
    }
    return [
      {'period_no': '1', 'label': isUrdu ? 'پہلا پیریڈ (Period 1)' : 'Period 1', 'subject_name': 'پیریڈ 1'},
      {'period_no': '2', 'label': isUrdu ? 'دوسرا پیریڈ (Period 2)' : 'Period 2', 'subject_name': 'پیریڈ 2'},
      {'period_no': '3', 'label': isUrdu ? 'تیسرا پیریڈ (Period 3)' : 'Period 3', 'subject_name': 'پیریڈ 3'},
      {'period_no': '4', 'label': isUrdu ? 'چوتھا پیریڈ (Period 4)' : 'Period 4', 'subject_name': 'پیریڈ 4'},
      {'period_no': '5', 'label': isUrdu ? 'پانچواں پیریڈ (Period 5)' : 'Period 5', 'subject_name': 'پیریڈ 5'},
      {'period_no': '6', 'label': isUrdu ? 'چھٹا پیریڈ (Period 6)' : 'Period 6', 'subject_name': 'پیریڈ 6'},
      {'period_no': '7', 'label': isUrdu ? 'ساتواں پیریڈ (مطالعہ)' : 'Period 7 (Study)', 'subject_name': 'مطالعہ'},
      {'period_no': '8', 'label': isUrdu ? 'آٹھواں پیریڈ (تکرار)' : 'Period 8 (Review)', 'subject_name': 'تکرار'},
    ];
  }

  Future<void> _showClassDialog(bool isUrdu,
      [Map<String, dynamic>? klass]) async {
    final nameController =
        TextEditingController(text: klass?['name']?.toString() ?? '');
    final sectionController =
        TextEditingController(text: klass?['section']?.toString() ?? '');
    final subjectsController =
        TextEditingController(text: klass?['subjects_list']?.toString() ?? '');
    String classType = klass?['class_type']?.toString() ?? 'Darse Nizami';
    if (!_classTypes.contains(classType)) classType = 'Darse Nizami';
    String status = klass?['status']?.toString() ?? 'Active';
    final selectedTeacherIds =
        _decodeTeacherIds(klass?['main_teacher_ids']).toSet();

    final initialClassName = klass?['name']?.toString() ?? '';
    final Map<int, Set<String>> periodTeacherIds = {};
    for (int p = 1; p <= 8; p++) {
      periodTeacherIds[p] = <String>{};
    }
    if (initialClassName.isNotEmpty) {
      for (final t in _teachers) {
        final tId = t['id']?.toString() ?? '';
        final ap = decodeTeacherAssignedPeriods(t['assigned_periods'], {initialClassName});
        final periods = ap[initialClassName] ?? {};
        for (final pStr in periods) {
          final pNo = periodNoFromKey(pStr);
          if (pNo >= 1 && pNo <= 8) {
            periodTeacherIds[pNo]?.add(tId);
          }
        }
      }
    }

    StateSetter? dialogSetState;
    void nameListener() {
      if (dialogSetState != null) {
        dialogSetState!(() {});
      }
    }
    nameController.addListener(nameListener);

    int? selectedCourseId;
    int? selectedCourseYear;

    String getYearLabel(int yearNo, String cType) {
      const Map<int, String> dNames = {
        1: 'سال اول (اولیٰ)',
        2: 'سال دوم (ثانیہ)',
        3: 'سال سوم (ثالثہ)',
        4: 'سال چہارم (رابعہ)',
        5: 'سال پنجم (خامسہ)',
        6: 'سال ششم (سادسہ)',
        7: 'سال ہفتم (سابعہ / موقوف علیہ)',
        8: 'سال ہشتم (دورہ حدیث شریف)',
        9: 'تخصص فی الفقہ سال اول',
        10: 'تخصص فی الفقہ سال دوم',
      };
      const Map<int, String> aNames = {
        1: 'کلاس ہفتم (7th)',
        2: 'کلاس ہشتم (8th)',
        3: 'کلاس نہم (9th)',
        4: 'کلاس دہم (10th)',
        5: 'گیارہویں (11th)',
        6: 'بارہویں (12th)',
      };
      if (cType == 'Asri' || cType == 'School' || cType.contains('عصری')) {
        return aNames[yearNo] ?? 'کلاس $yearNo';
      }
      return dNames[yearNo] ?? 'سال $yearNo';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogSetState = setDialogState;

          // Find active course if selected
          Map<String, dynamic>? currentCourse;
          if (selectedCourseId != null) {
            for (final c in _courses) {
              if (c['id'] == selectedCourseId) {
                currentCourse = c;
                break;
              }
            }
          }

          // Build years available for selected course
          List<int> courseYears = [];
          if (currentCourse != null) {
            final totYears = int.tryParse(currentCourse['total_years']?.toString() ?? '8') ?? 8;
            courseYears = List.generate(totYears, (i) => i + 1);
          }

          return AlertDialog(
            title: Text(klass == null
                ? (isUrdu ? 'نئی کلاس شامل کریں' : 'Add New Class')
                : (isUrdu ? 'کلاس میں ترمیم' : 'Edit Class')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. ڈائنامک کورس سلیکشن باکس
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.school, size: 18, color: primaryGreen),
                              const SizedBox(width: 6),
                              Text(
                                isUrdu ? 'درس نظامی و عصری علوم کورس منتخب کریں:' : 'Select Course / Curriculum:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryGreen),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int?>(
                            value: selectedCourseId,
                            decoration: InputDecoration(
                              labelText: isUrdu ? 'مرتب کردہ کورس' : 'Course',
                              isDense: true,
                              fillColor: Colors.white,
                              filled: true,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(isUrdu ? '-- عام / مروجہ قرآنی کلاس --' : '-- Custom / Quranic Class --'),
                              ),
                              ..._courses.map((c) {
                                final cid = c['id'] as int;
                                final cName = c['name']?.toString() ?? 'کورس #$cid';
                                final cType = c['course_type']?.toString() ?? '';
                                final typeLabel = cType == 'Asri' ? ' (عصری)' : ' (درس نظامی)';
                                return DropdownMenuItem<int?>(
                                  value: cid,
                                  child: Text(
                                    '$cName$typeLabel',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedCourseId = val;
                                selectedCourseYear = null;
                                if (val != null) {
                                  final chosen = _courses.firstWhere((c) => c['id'] == val, orElse: () => {});
                                  final cType = chosen['course_type']?.toString() ?? 'Darse_Nizami';
                                  if (cType == 'Asri' || cType == 'School') {
                                    classType = 'Asri Taleem';
                                  } else {
                                    classType = 'Darse Nizami';
                                  }
                                }
                              });
                            },
                          ),

                          // 2. جب کورس منتخب ہو تو اس کورس کی کلاسز / درجات کا Cascading ڈراپ ڈاؤن
                          if (currentCourse != null && courseYears.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              value: selectedCourseYear,
                              decoration: InputDecoration(
                                labelText: isUrdu ? 'اس کورس کی مطلوبہ کلاس / سال منتخب کریں *' : 'Select Class / Year *',
                                isDense: true,
                                fillColor: Colors.white,
                                filled: true,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.class_, color: Colors.teal),
                              ),
                              items: courseYears.map((yNo) {
                                final cType = currentCourse?['course_type']?.toString() ?? 'Darse_Nizami';
                                final yLabel = getYearLabel(yNo, cType);
                                return DropdownMenuItem<int>(
                                  value: yNo,
                                  child: Text(
                                    yLabel,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                                  ),
                                );
                              }).toList(),
                              onChanged: (yVal) {
                                if (yVal == null) return;
                                setDialogState(() {
                                  selectedCourseYear = yVal;
                                  final cType = currentCourse?['course_type']?.toString() ?? 'Darse_Nizami';
                                  final yLabel = getYearLabel(yVal, cType);
                                  nameController.text = yLabel;

                                  // مضامین لوڈ کریں جو ڈیٹا بیس میں اس کورس اور سال کے تحت محفوظ ہیں
                                  final allCourseSubs = _courseSubjectsMap[currentCourse?['id']] ?? [];
                                  final yearSubs = allCourseSubs
                                      .where((s) => (int.tryParse(s['year_no']?.toString() ?? '1') ?? 1) == yVal)
                                      .map((s) => s['subject_name']?.toString() ?? '')
                                      .where((s) => s.isNotEmpty)
                                      .toList();

                                  if (yearSubs.isNotEmpty) {
                                    subjectsController.text = yearSubs.join('، ');
                                  } else if (courseClassPresets.containsKey(yLabel)) {
                                    subjectsController.text = (courseClassPresets[yLabel] ?? []).join('، ');
                                  }

                                  if (cType == 'Asri' || cType == 'School' || yLabel.contains('عصری')) {
                                    classType = 'Asri Taleem';
                                  } else {
                                    classType = 'Darse Nizami';
                                  }
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    // متبادل فوری سانچہ جات
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'فوری سانچہ (روایتی وفاق المدارس و دیگر)' : 'Preset Template',
                        hintText: isUrdu ? 'کورس سانچہ منتخب کریں' : 'Choose preset',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: const Icon(Icons.auto_stories, color: Color(0xFF284D3D)),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(isUrdu ? '-- کسٹم / اپنی مرضی کی کلاس --' : '-- Custom Class --'),
                        ),
                        ...courseClassPresets.keys.map((cName) => DropdownMenuItem(
                              value: cName,
                              child: Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          if (val != null) {
                            nameController.text = val;
                            final subs = courseClassPresets[val] ?? [];
                            subjectsController.text = subs.join('، ');
                            if (val.contains('عصری') || val.contains('7th') || val.contains('8th') || val.contains('9th') || val.contains('10th')) {
                              classType = 'Asri Taleem';
                            } else if (val.contains('حفظ') || val.contains('گردان')) {
                              classType = 'Hifz/Gardan/Husn';
                            } else if (val.contains('ناظرہ')) {
                              classType = 'Nazira';
                            } else if (val.contains('قاعدہ')) {
                              classType = 'Qaida';
                            } else if (val.contains('صوت')) {
                              classType = 'Husn-e-Saut';
                            } else {
                              classType = 'Darse Nizami';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'کلاس کا نام *' : 'Class Name *',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sectionController,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'سیکشن' : 'Section',
                        hintText: isUrdu ? 'مثلاً A، B' : 'e.g. A, B',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: classType,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'کلاس قسم' : 'Class Type',
                        border: const OutlineInputBorder(),
                      ),
                      items: _classTypes
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => classType = value ?? classType),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'حالت' : 'Status',
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'Inactive', child: Text('Inactive')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? 'Active'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'مضامین/نصاب' : 'Subjects',
                        hintText:
                            isUrdu ? 'مثلاً قرآن:100، ریاضی:50' : 'Quran:100',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment:
                          isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(
                        isUrdu ? 'پیریڈز اور اساتذہ کا تقرر' : 'Periods & Teacher Assignments',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Builder(builder: (context) {
                      final currentPeriods = _getPeriodDefinitionsForClass(
                          classType, nameController.text, isUrdu, subjectsController.text);
                      return Column(
                        children: currentPeriods.map((pDef) {
                          final pNo = int.parse(pDef['period_no']!);
                          final pLabel = pDef['label']!;
                          final assigned = periodTeacherIds[pNo] ?? <String>{};
                          return Container(
                            key: ValueKey('period_container_$pNo'),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pLabel,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryGreen,
                                        fontSize: 13)),
                                const SizedBox(height: 4),
                                if (_teachers.isEmpty)
                                  Text(
                                    isUrdu ? 'کوئی استاد موجود نہیں' : 'No teachers found',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: _teachers.map((teacher) {
                                      final tId = teacher['id']?.toString() ?? '';
                                      final tName = teacher['name']?.toString() ?? '';
                                      final isSelected = assigned.contains(tId);
                                      return FilterChip(
                                        key: ValueKey('period_${pNo}_teacher_$tId'),
                                        label: Text(tName, style: const TextStyle(fontSize: 12)),
                                        selected: isSelected,
                                        selectedColor: primaryGreen.withOpacity(0.2),
                                        checkmarkColor: primaryGreen,
                                        onSelected: (val) {
                                          setDialogState(() {
                                            periodTeacherIds.putIfAbsent(pNo, () => <String>{});
                                            if (val) {
                                              periodTeacherIds[pNo]!.add(tId);
                                              selectedTeacherIds.add(tId);
                                            } else {
                                              periodTeacherIds[pNo]!.remove(tId);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text(
                  isUrdu ? 'محفوظ کریں' : 'Save',
                  style: const TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final currentPeriods = _getPeriodDefinitionsForClass(
                      classType, name, isUrdu, subjectsController.text.trim());
                  final allAssignedTeacherIds = <String>{...selectedTeacherIds};
                  for (final pDef in currentPeriods) {
                    final pNo = int.parse(pDef['period_no']!);
                    if (periodTeacherIds.containsKey(pNo)) {
                      allAssignedTeacherIds.addAll(periodTeacherIds[pNo]!);
                    }
                  }

                  final periodMap = <String, List<String>>{};
                  periodTeacherIds.forEach((k, v) {
                    if (v.isNotEmpty) periodMap[k.toString()] = v.toList();
                  });

                  final data = <String, dynamic>{
                    'name': name,
                    'section': sectionController.text.trim(),
                    'class_type': classType,
                    'status': status,
                    'subjects_list': subjectsController.text.trim(),
                    'main_teacher_ids': jsonEncode(allAssignedTeacherIds.toList()),
                    'period_teacher_ids': jsonEncode(periodMap),
                    'system_type': SystemTypeGlobal.currentSystemType.value,
                    'is_synced': 0,
                  };

                  for (final pDef in currentPeriods) {
                    final pNo = int.tryParse(pDef['period_no'] ?? '') ?? 0;
                    if (pNo >= 1 && pNo <= 6) {
                      data['p${pNo}_name'] = pDef['label'] ?? '';
                    }
                  }

                  if (klass == null) {
                    await DBHelper().insertClass(data);
                  } else {
                    await DBHelper().updateClass(klass['id'] as int, data);
                  }

                  // Sync each teacher's assigned_classes and assigned_periods in SQLite
                  for (final teacher in _teachers) {
                    final tId = teacher['id'];
                    final tIdStr = tId?.toString() ?? '';
                    if (tId == null || tIdStr.isEmpty) continue;

                    var currentAssignedClasses = (teacher['assigned_classes']?.toString() ?? '')
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toSet();

                    var currentAssignedPeriods = decodeTeacherAssignedPeriods(
                        teacher['assigned_periods'], currentAssignedClasses);

                    if (initialClassName.isNotEmpty && initialClassName != name) {
                      currentAssignedClasses.remove(initialClassName);
                      currentAssignedPeriods.remove(initialClassName);
                    }

                    final teacherPeriodsForThisClass = <String>[];
                    for (final pDef in currentPeriods) {
                      final pNo = int.parse(pDef['period_no']!);
                      if (periodTeacherIds[pNo]?.contains(tIdStr) == true) {
                        teacherPeriodsForThisClass.add(pNo.toString());
                      }
                    }

                    if (teacherPeriodsForThisClass.isNotEmpty) {
                      currentAssignedClasses.add(name);
                      currentAssignedPeriods[name] = teacherPeriodsForThisClass.toSet();
                    } else {
                      currentAssignedClasses.remove(name);
                      currentAssignedPeriods.remove(name);
                    }

                    final updatedPeriodsMap = <String, List<String>>{};
                    currentAssignedPeriods.forEach((cName, pSet) {
                      if (pSet.isNotEmpty) updatedPeriodsMap[cName] = pSet.toList()..sort();
                    });

                    await DBHelper().updateTeacher(tId as int, {
                      'assigned_classes': currentAssignedClasses.join(','),
                      'assigned_periods': jsonEncode(updatedPeriodsMap),
                      'is_synced': 0,
                    });
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isUrdu
                        ? 'کلاس محفوظ کر دی گئی'
                        : 'Class saved successfully'),
                    backgroundColor: Colors.green,
                  ));
                },
              ),
            ],
          );
        },
      ),
    );
    nameController.removeListener(nameListener);
  }

  Future<void> _deleteClass(Map<String, dynamic> klass, bool isUrdu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'حذف کی تصدیق' : 'Confirm Delete'),
        content: Text(isUrdu
            ? 'کیا آپ واقعی یہ کلاس حذف کرنا چاہتے ہیں؟'
            : 'Do you really want to delete this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isUrdu ? 'نہیں' : 'No'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: Text(isUrdu ? 'حذف کریں' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DBHelper().deleteClass(klass['id'] as int);
    await _loadData();
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
            child: Builder(builder: (context) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final effectiveBg = theme.scaffoldBackgroundColor;
              final effectiveAppBarBg = isDark ? theme.colorScheme.surface : primaryGreen;

              return Scaffold(
                backgroundColor: effectiveBg,
                drawer: const AppDrawer(),
                appBar: AppBar(
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  title: Text(isUrdu ? 'کلاسز مینجمنٹ' : 'Manage Classes',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  backgroundColor: effectiveAppBarBg,
                  foregroundColor: Colors.white,
                  centerTitle: true,
                actions: [
                  IconButton(
                    tooltip: isUrdu ? 'سنک' : 'Sync',
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: () => _syncData(isUrdu),
                  ),
                ],
              ),
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? _buildEmptyState(isUrdu)
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(15),
                              itemCount: _classes.length,
                              itemBuilder: (context, index) {
                                final klass = _classes[index];
                                return _buildClassCard(klass, isUrdu);
                              },
                            ),
                          ),
                        ),
              floatingActionButton: FloatingActionButton(
                backgroundColor: primaryGreen,
                onPressed: () => _showClassDialog(isUrdu),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            );
          }),
          ),
        );
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> klass, bool isUrdu) {
    final section = klass['section']?.toString() ?? '';
    final teacherNames = _teacherNames(klass['main_teacher_ids']);
    final subjects = klass['subjects_list']?.toString() ?? '';
    final status = klass['status']?.toString() ?? 'Active';
    final active = status == 'Active';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: NeoBox(
        padding: 15,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.class_, color: primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudentsPage(
                                initialClassFilter: klass['name']))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${klass['name'] ?? ''}${section.isNotEmpty ? ' ($section)' : ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(klass['class_type']?.toString() ?? 'Darse Nizami'),
                      ],
                    ),
                  ),
                ),
                Chip(
                  label: Text(active ? 'Active' : 'Inactive'),
                  backgroundColor:
                      active ? Colors.green.shade50 : Colors.grey.shade200,
                ),
              ],
            ),
            if (teacherNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${isUrdu ? 'اساتذہ' : 'Teachers'}: $teacherNames'),
            ],
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${isUrdu ? 'مضامین' : 'Subjects'}: $subjects'),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showClassDialog(isUrdu, klass),
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(isUrdu ? 'ترمیم' : 'Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteClass(klass, isUrdu),
                    icon: const Icon(Icons.delete, size: 18),
                    label: Text(isUrdu ? 'حذف' : 'Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(isUrdu ? 'کوئی کلاس نہیں ملی' : 'No classes found',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
          const SizedBox(height: 10),
          Text(
              isUrdu
                  ? 'نئی کلاس شامل کریں یا ڈیٹا سنک کریں'
                  : 'Add a class or sync data',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }
}
