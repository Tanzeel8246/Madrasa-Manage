// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/sync_service.dart';
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
    'Hifz/Gardan/Husn',
    'Nazira',
    'Qaida',
    'Tajweed',
    'Asri Taleem',
    'Darse Nizami',
  ];

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final classes = await DBHelper().getClasses();
    final teachers = await DBHelper().getTeachers();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _teachers = teachers;
      _isLoading = false;
    });
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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(klass == null
              ? (isUrdu ? 'نئی کلاس شامل کریں' : 'Add New Class')
              : (isUrdu ? 'کلاس میں ترمیم' : 'Edit Class')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'کلاس کا نام' : 'Class Name',
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
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment:
                        isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      isUrdu ? 'مرکزی اساتذہ' : 'Main Teachers',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _teachers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(isUrdu
                                  ? 'اساتذہ موجود نہیں'
                                  : 'No teachers found'),
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: _teachers.map((teacher) {
                              final id = teacher['id']?.toString() ?? '';
                              return CheckboxListTile(
                                dense: true,
                                value: selectedTeacherIds.contains(id),
                                title: Text(teacher['name']?.toString() ?? ''),
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedTeacherIds.add(id);
                                    } else {
                                      selectedTeacherIds.remove(id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
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
                final data = {
                  'name': name,
                  'section': sectionController.text.trim(),
                  'class_type': classType,
                  'status': status,
                  'subjects_list': subjectsController.text.trim(),
                  'main_teacher_ids': jsonEncode(selectedTeacherIds.toList()),
                };
                if (klass == null) {
                  await DBHelper().insertClass(data);
                } else {
                  await DBHelper().updateClass(klass['id'] as int, data);
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
        ),
      ),
    );
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
                title: Text(isUrdu ? 'کلاسز مینجمنٹ' : 'Manage Classes',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: primaryGreen,
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
                      : ListView.builder(
                          padding: const EdgeInsets.all(15),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) {
                            final klass = _classes[index];
                            return _buildClassCard(klass, isUrdu);
                          },
                        ),
              floatingActionButton: FloatingActionButton(
                backgroundColor: primaryGreen,
                onPressed: () => _showClassDialog(isUrdu),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
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
