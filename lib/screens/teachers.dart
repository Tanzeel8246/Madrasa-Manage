// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  _TeachersPageState createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _foundTeachers = [];

  @override
  void initState() {
    super.initState();
    _refreshTeachers();
  }

  void _refreshTeachers() async {
    final data = await DBHelper().getTeachers();
    setState(() {
      _allTeachers = data;
      _foundTeachers = data;
    });
  }

  void _runFilter(String enteredKeyword) {
    List<Map<String, dynamic>> results = [];
    if (enteredKeyword.isEmpty) {
      results = _allTeachers;
    } else {
      results = _allTeachers
          .where((teacher) =>
              teacher["name"]
                  .toString()
                  .toLowerCase()
                  .contains(enteredKeyword.toLowerCase()) ||
              (teacher["phone"] != null &&
                  teacher["phone"].toString().contains(enteredKeyword)))
          .toList();
    }
    setState(() {
      _foundTeachers = results;
    });
  }

  Future<void> _deleteTeacher(int id) async {
    await DBHelper().updateTeacher(id, {'is_deleted': 1, 'is_synced': 0});
    _refreshTeachers();
  }

  Set<String> _splitTeacherValues(dynamic value) {
    return (value?.toString() ?? '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static const List<Map<String, String>> _periodOptions = [
    {'value': '1', 'labelUr': 'پہلا پیریڈ', 'labelEn': 'Period 1'},
    {'value': '2', 'labelUr': 'دوسرا پیریڈ', 'labelEn': 'Period 2'},
    {'value': '3', 'labelUr': 'تیسرا پیریڈ', 'labelEn': 'Period 3'},
    {'value': '4', 'labelUr': 'چوتھا پیریڈ', 'labelEn': 'Period 4'},
    {'value': '5', 'labelUr': 'پانچواں پیریڈ', 'labelEn': 'Period 5'},
    {'value': '6', 'labelUr': 'چھٹا پیریڈ', 'labelEn': 'Period 6'},
    {'value': '7', 'labelUr': 'ساتواں پیریڈ', 'labelEn': 'Period 7'},
    {'value': '8', 'labelUr': 'آٹھواں پیریڈ', 'labelEn': 'Period 8'},
  ];

  String _normalizePeriodKey(String key) {
    const legacyHifz = {
      'hifz_sabaq': 'hifz_morning',
      'hifz_sabqi': 'hifz_after_breakfast',
      'hifz_manzil': 'hifz_noon',
      'hifz_review': 'hifz_evening',
      'Period 1': '1',
      'Period 2': '2',
      'Period 3': '3',
      'Period 4': '4',
      'Period 5': '5',
      'Period 6': '6',
      'Period 7': '7',
      'Period 8': '8',
    };
    return legacyHifz[key] ?? key;
  }

  Map<String, Set<String>> _decodeAssignedPeriods(
      dynamic value, Set<String> selectedClasses) {
    final raw = value?.toString().trim() ?? '';
    final result = <String, Set<String>>{};
    if (raw.isEmpty) return result;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, val) {
          if (val is List) {
            result[key.toString()] =
                val.map((e) => _normalizePeriodKey(e.toString())).toSet();
          } else if (val != null) {
            result[key.toString()] = val
                .toString()
                .split(',')
                .map((e) => _normalizePeriodKey(e.trim()))
                .where((e) => e.isNotEmpty)
                .toSet();
          }
        });
        return result;
      }
    } catch (_) {}
    final legacy = _splitTeacherValues(raw);
    for (final className in selectedClasses) {
      result[className] = {...legacy};
    }
    return result;
  }

  String _encodeAssignedPeriods(Map<String, Set<String>> map) {
    final clean = <String, List<String>>{};
    map.forEach((className, periods) {
      if (periods.isNotEmpty) {
        final sorted = periods.toList()..sort();
        clean[className] = sorted;
      }
    });
    return jsonEncode(clean);
  }

  bool _classTextContains(Map<String, dynamic> cls, List<String> needles) {
    final text = [cls['name'], cls['class_type'], cls['section']]
        .where((v) => v != null)
        .join(' ')
        .toLowerCase();
    return needles.any((needle) => text.contains(needle.toLowerCase()));
  }

  bool _isHifzClass(Map<String, dynamic> cls) =>
      _classTextContains(cls, ['\u062d\u0641\u0638', 'hifz']);

  bool _isNaziraClass(Map<String, dynamic> cls) =>
      _classTextContains(cls, ['\u0646\u0627\u0638\u0631\u06c1', 'nazira']);

  bool _isQuranicClass(Map<String, dynamic> cls) =>
      _classTextContains(cls, ['\u0642\u0627\u0639\u062f\u06c1', 'qaida', '\u062a\u062c\u0648\u06cc\u062f', 'tajweed', '\u062d\u0633\u0646', 'husn']);

  List<Map<String, String>> _periodOptionsForClass(Map<String, dynamic> cls) {
    if (_isNaziraClass(cls)) {
      return const [
        {'value': '1', 'labelUr': 'صبح کا سیشن (Morning Shift)', 'labelEn': 'Morning Shift'},
        {'value': '2', 'labelUr': 'شام کا سیشن (Evening Shift)', 'labelEn': 'Evening Shift'},
      ];
    }
    if (_isHifzClass(cls) || _isQuranicClass(cls)) {
      return const [
        {'value': '1', 'labelUr': 'صبح کا سیشن (Morning Shift)', 'labelEn': 'Morning Shift'},
        {'value': '2', 'labelUr': 'دوپہر کا سیشن (Noon Shift)', 'labelEn': 'Noon Shift'},
        {'value': '3', 'labelUr': 'عصر / شام کا سیشن (Evening Shift)', 'labelEn': 'Evening Shift'},
        {'value': '4', 'labelUr': 'مغرب / عشاء کا سیشن (Night Shift)', 'labelEn': 'Night Shift'},
      ];
    }
    return _periodOptions;
  }

  String _periodLabel(String value, bool isUrdu) {
    final all = <Map<String, String>>[
      ..._periodOptions,
      {
        'value': 'hifz_morning',
        'labelUr': '\u0635\u0628\u062d',
        'labelEn': 'Morning'
      },
      {
        'value': 'hifz_after_breakfast',
        'labelUr':
            '\u0646\u0627\u0634\u062a\u06c1 \u06a9\u06d2 \u0628\u0639\u062f',
        'labelEn': 'After Breakfast'
      },
      {
        'value': 'hifz_noon',
        'labelUr':
            '\u062f\u0648\u067e\u06c1\u0631 (\u0638\u06c1\u0631 \u06a9\u06d2 \u0628\u0639\u062f)',
        'labelEn': 'Noon (After Zuhr)'
      },
      {
        'value': 'hifz_evening',
        'labelUr':
            '\u0634\u0627\u0645 (\u0645\u063a\u0631\u0628 \u06a9\u06d2 \u0628\u0639\u062f)',
        'labelEn': 'Evening (After Maghrib)'
      },
      {
        'value': 'nazira_morning',
        'labelUr': '\u0635\u0628\u062d',
        'labelEn': 'Morning'
      },
      {
        'value': 'nazira_evening',
        'labelUr': '\u0634\u0627\u0645',
        'labelEn': 'Evening'
      },
    ];
    final key = _normalizePeriodKey(value);
    final found = all.where((p) => p['value'] == key);
    if (found.isEmpty) return value;
    return found.first[isUrdu ? 'labelUr' : 'labelEn'] ?? value;
  }

  String _formatAssignedPeriods(dynamic value, {bool? isUrdu}) {
    final urdu = isUrdu ?? isUrduGlobal.value;
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final parts = <String>[];
        decoded.forEach((className, vals) {
          final labels = vals is List
              ? vals.map((v) => _periodLabel(v.toString(), urdu)).join(', ')
              : vals.toString();
          if (labels.trim().isNotEmpty) parts.add('$className: $labels');
        });
        return parts.join(' | ');
      }
    } catch (_) {}
    return raw
        .split(',')
        .map((v) => _periodLabel(v.trim(), urdu))
        .where((v) => v.isNotEmpty)
        .join(', ');
  }

  // استاد شامل / ایڈٹ کرنے کا ڈائلاگ
  Future<void> _showAddTeacherDialog({Map<String, dynamic>? teacher}) async {
    final classes = await DBHelper().getClasses();
    final selectedClasses = _splitTeacherValues(teacher?['assigned_classes']);
    final selectedPeriodsByClass =
        _decodeAssignedPeriods(teacher?['assigned_periods'], selectedClasses);
    final nameController =
        TextEditingController(text: teacher?['name']?.toString() ?? '');
    final fatherNameController =
        TextEditingController(text: teacher?['father_name']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: teacher?['phone']?.toString() ?? '');
    final cnicController =
        TextEditingController(text: teacher?['cnic']?.toString() ?? '');
    final qualController = TextEditingController(
        text: teacher?['qualification']?.toString() ?? '');
    final salaryController =
        TextEditingController(text: teacher?['salary']?.toString() ?? '');
    final houseRentController =
        TextEditingController(text: teacher?['house_rent']?.toString() ?? '');
    final medicalController = TextEditingController(
        text: teacher?['medical_allowance']?.toString() ?? '');
    final travelController = TextEditingController(
        text: teacher?['travel_allowance']?.toString() ?? '');
    final deductionController = TextEditingController(
        text: teacher?['daily_deduction_rate']?.toString() ?? '');
    final dateController =
        TextEditingController(text: teacher?['joining_date']?.toString() ?? '');
    final addressController =
        TextEditingController(text: teacher?['address']?.toString() ?? '');
    String selectedStatus = teacher?['status']?.toString() ?? 'Active';
    String? localPhotoPath = teacher?['photo']?.toString();
    if (localPhotoPath != null && localPhotoPath.isEmpty) localPhotoPath = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> pickImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(
                source: ImageSource.gallery, imageQuality: 50);
            if (pickedFile != null) {
              setStateDialog(() {
                localPhotoPath = pickedFile.path;
              });
            }
          }

          ImageProvider? avatarImage;
          if (localPhotoPath != null && localPhotoPath!.isNotEmpty) {
            if (localPhotoPath!.startsWith('http') ||
                localPhotoPath!.startsWith('uploads/')) {
              final url = localPhotoPath!.startsWith('http')
                  ? localPhotoPath!
                  : '${apiUrl.endsWith('/') ? apiUrl : '$apiUrl/'}$localPhotoPath';
              avatarImage = NetworkImage(url);
            } else if (File(localPhotoPath!).existsSync()) {
              avatarImage = FileImage(File(localPhotoPath!));
            }
          }

          return AlertDialog(
            title: Text(teacher == null
                ? (isUrduGlobal.value
                    ? "نیا استاد شامل کریں"
                    : "Add New Teacher")
                : (isUrduGlobal.value
                    ? "استاد کی تفصیلات ایڈٹ کریں"
                    : "Edit Teacher")),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: pickImage,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(Icons.camera_alt,
                                size: 40, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value
                            ? "نام استاد *"
                            : "Teacher Name *"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fatherNameController,
                    decoration: InputDecoration(
                        labelText:
                            isUrduGlobal.value ? "ولدیت" : "Father's Name"),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "موبائل نمبر"
                                  : "Mobile No"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cnicController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "شناختی کارڈ (CNIC)"
                                  : "CNIC"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qualController,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "تعلیم"
                                  : "Qualification"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: salaryController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "بنیادی تنخواہ"
                                  : "Basic Salary"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: houseRentController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "ہاؤس رینٹ"
                                  : "House Rent"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: medicalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "میڈیکل الاؤنس"
                                  : "Medical Allow."),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: travelController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "سفری الاؤنس"
                                  : "Travel Allow."),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: deductionController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: isUrduGlobal.value
                                  ? "یومیہ کٹوتی"
                                  : "Daily Deduct."),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: isUrduGlobal.value
                          ? "تقرری کی تاریخ"
                          : "Joining Date",
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          dateController.text =
                              "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value ? "سٹیٹس" : "Status"),
                    items: [
                      DropdownMenuItem(
                          value: "Active",
                          child: Text(isUrduGlobal.value
                              ? "Active (موجود)"
                              : "Active")),
                      DropdownMenuItem(
                          value: "Inactive",
                          child: Text(isUrduGlobal.value
                              ? "Inactive (غیر حاضر)"
                              : "Inactive")),
                    ],
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText:
                            isUrduGlobal.value ? "مکمل پتہ" : "Full Address"),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      isUrduGlobal.value ? "کلاسز الاٹ کریں" : "Assign Classes",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (classes.isEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isUrduGlobal.value
                            ? "ابھی کوئی کلاس موجود نہیں"
                            : "No classes available",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: classes.map((cls) {
                          final className = cls['name']?.toString() ?? '';
                          final selected = selectedClasses.contains(className);
                          return FilterChip(
                            label: Text(className),
                            selected: selected,
                            onSelected: (value) {
                              setStateDialog(() {
                                if (value) {
                                  selectedClasses.add(className);
                                } else {
                                  selectedClasses.remove(className);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      isUrduGlobal.value
                          ? "\u067e\u06cc\u0631\u06cc\u0688\u0632 \u0627\u0644\u0627\u0679 \u06a9\u0631\u06cc\u06ba"
                          : "Assign Periods",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (selectedClasses.isEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isUrduGlobal.value
                            ? "\u067e\u06c1\u0644\u06d2 \u06a9\u0644\u0627\u0633 \u0645\u0646\u062a\u062e\u0628 \u06a9\u0631\u06cc\u06ba"
                            : "Select a class first",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  else
                    ...classes
                        .where((cls) => selectedClasses
                            .contains(cls['name']?.toString() ?? ''))
                        .map((cls) {
                      final className = cls['name']?.toString() ?? '';
                      final options = _periodOptionsForClass(cls);
                      final selectedForClass =
                          selectedPeriodsByClass[className] ?? <String>{};
                      selectedPeriodsByClass[className] = selectedForClass;
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(className,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: options.map((period) {
                                final value = period['value']!;
                                final selected =
                                    selectedForClass.contains(value);
                                return FilterChip(
                                  label: Text(isUrduGlobal.value
                                      ? period['labelUr']!
                                      : period['labelEn']!),
                                  selected: selected,
                                  onSelected: (isSelected) {
                                    setStateDialog(() {
                                      if (isSelected) {
                                        selectedForClass.add(value);
                                      } else {
                                        selectedForClass.remove(value);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isUrduGlobal.value ? "کینسل" : "Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(isUrduGlobal.value
                              ? "نام لکھنا ضروری ہے!"
                              : "Name is required!")),
                    );
                    return;
                  }
                  final data = {
                    'name': nameController.text.trim(),
                    'father_name': fatherNameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'cnic': cnicController.text.trim(),
                    'qualification': qualController.text.trim(),
                    'salary': salaryController.text.trim(),
                    'house_rent': houseRentController.text.trim(),
                    'medical_allowance': medicalController.text.trim(),
                    'travel_allowance': travelController.text.trim(),
                    'daily_deduction_rate': deductionController.text.trim(),
                    'joining_date': dateController.text.trim(),
                    'status': selectedStatus,
                    'address': addressController.text.trim(),
                    'photo': localPhotoPath ?? '',
                    'assigned_classes': selectedClasses.join(','),
                    'assigned_periods':
                        _encodeAssignedPeriods(selectedPeriodsByClass),
                    'is_synced': 0,
                  };
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  if (teacher == null) {
                    await DBHelper().insertTeacher(data);
                  } else {
                    await DBHelper().updateTeacher(teacher['id'], data);
                  }
                  nav.pop();
                  _refreshTeachers();
                  try {
                    await SyncService.runTwoWaySync();
                  } catch (_) {}
                  messenger.showSnackBar(SnackBar(
                    content: Text(isUrduGlobal.value
                        ? "استاد کا ریکارڈ محفوظ ہو گیا!"
                        : "Teacher saved successfully!"),
                    backgroundColor: Colors.green,
                  ));
                },
                child: Text(isUrduGlobal.value ? "محفوظ کریں" : "Save",
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        return Directionality(
          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            drawer: const AppDrawer(),
            appBar: AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: Text(isUrdu ? "اساتذہ کا ریکارڈ" : "Teachers Record"),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
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
                        _refreshTeachers();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                isUrdu ? "سنک مکمل ہو گیا!" : "Sync complete!"),
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
            floatingActionButton: FloatingActionButton(
              backgroundColor: Colors.green.shade700,
              onPressed: _showAddTeacherDialog,
              child: const Icon(Icons.add, color: Colors.white),
            ),
            body: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => _runFilter(value),
                    decoration: InputDecoration(
                      labelText: isUrdu
                          ? 'تلاش کریں (نام یا موبائل نمبر)'
                          : 'Search (Name or Phone)',
                      suffixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _foundTeachers.isNotEmpty
                        ? ListView.builder(
                            itemCount: _foundTeachers.length,
                            itemBuilder: (context, index) {
                              final t = _foundTeachers[index];
                              final teacherName = t['name']?.toString() ?? '?';
                              final firstLetter =
                                  teacherName.isNotEmpty ? teacherName[0] : '?';
                              final phone = t['phone']?.toString() ?? '-';
                              final assignedClasses =
                                  t['assigned_classes']?.toString() ?? '';
                              final assignedPeriods = _formatAssignedPeriods(
                                  t['assigned_periods'],
                                  isUrdu: isUrdu);
                              final subtitleParts = [
                                "${isUrdu ? 'موبائل' : 'Mobile'}: $phone",
                                if (assignedClasses.isNotEmpty)
                                  "${isUrdu ? 'کلاسز' : 'Classes'}: $assignedClasses",
                                if (assignedPeriods.isNotEmpty)
                                  "${isUrdu ? 'پیریڈز' : 'Periods'}: $assignedPeriods",
                              ];
                              final status =
                                  t['status']?.toString() ?? 'Active';
                              final Color statusColor = status == 'Active'
                                  ? Colors.green
                                  : Colors.red;

                              // Build photo avatar
                              Widget leadingWidget;
                              final photo = t['photo']?.toString() ?? '';
                              if (photo.isNotEmpty) {
                                ImageProvider? imgProvider;
                                if (photo.startsWith('http') ||
                                    photo.startsWith('uploads/')) {
                                  final url = photo.startsWith('http')
                                      ? photo
                                      : '${apiUrl.endsWith('/') ? apiUrl : '$apiUrl/'}$photo';
                                  imgProvider = NetworkImage(url);
                                } else if (File(photo).existsSync()) {
                                  imgProvider = FileImage(File(photo));
                                }
                                if (imgProvider != null) {
                                  leadingWidget = CircleAvatar(
                                      backgroundImage: imgProvider);
                                } else {
                                  leadingWidget = CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: Text(firstLetter,
                                        style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold)),
                                  );
                                }
                              } else {
                                leadingWidget = CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: Text(firstLetter,
                                      style: TextStyle(
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.bold)),
                                );
                              }

                              return Card(
                                key: ValueKey(t["id"]),
                                color: Colors.white,
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                child: ListTile(
                                  leading: leadingWidget,
                                  title: Text(teacherName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  subtitle: Text(subtitleParts.join('\n'),
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          status == 'Active'
                                              ? (isUrdu ? 'موجود' : 'Active')
                                              : (isUrdu
                                                  ? 'غیر حاضر'
                                                  : 'Inactive'),
                                          style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue, size: 20),
                                        onPressed: () =>
                                            _showAddTeacherDialog(teacher: t),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        onPressed: () =>
                                            _deleteTeacher(t['id']),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    final fname =
                                        t['father_name']?.toString() ?? '-';
                                    final cnic = t['cnic']?.toString() ?? '-';
                                    final qual =
                                        t['qualification']?.toString() ?? '-';
                                    final sal = t['salary']?.toString() ?? '-';
                                    final join =
                                        t['joining_date']?.toString() ?? '-';
                                    final address =
                                        t['address']?.toString() ?? '-';
                                    final classesText =
                                        t['assigned_classes']?.toString() ??
                                            '-';
                                    final periodsText = _formatAssignedPeriods(
                                        t['assigned_periods'],
                                        isUrdu: isUrdu);

                                    showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                              title: Text(teacherName),
                                              content: SingleChildScrollView(
                                                child: Text(
                                                    "${isUrdu ? 'ولدیت' : 'Father'}: $fname\n"
                                                    "${isUrdu ? 'شناختی کارڈ' : 'CNIC'}: $cnic\n"
                                                    "${isUrdu ? 'تعلیم' : 'Qual.'}: $qual\n"
                                                    "${isUrdu ? 'وظیفہ' : 'Stipend'}: Rs $sal\n"
                                                    "${isUrdu ? 'تقرری کی تاریخ' : 'Joining'}: $join\n"
                                                    "${isUrdu ? 'الاٹ کلاسز' : 'Assigned Classes'}: ${classesText.isEmpty ? '-' : classesText}\n"
                                                    "${isUrdu ? 'الاٹ پیریڈز' : 'Assigned Periods'}: ${periodsText.isEmpty ? '-' : periodsText}\n"
                                                    "${isUrdu ? 'پتہ' : 'Address'}: $address"),
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text("OK"))
                                              ],
                                            ));
                                  },
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              isUrdu
                                  ? 'کوئی استاد نہیں ملا، نیا شامل کریں (+)'
                                  : 'No teachers found, add new (+)',
                              style: const TextStyle(fontSize: 16),
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
}
