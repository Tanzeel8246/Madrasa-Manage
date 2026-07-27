import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/sync_service.dart';
import '../widgets/app_drawer.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _departments = [];
  int? _editingId;
  String _status = 'Active';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    final rows = await DBHelper().getDepartments();
    if (!mounted) return;
    setState(() {
      _departments = rows;
      _loading = false;
    });
  }

  void _startEdit(Map<String, dynamic> department) {
    setState(() {
      _editingId = department['id'] as int?;
      _nameController.text = department['name']?.toString() ?? '';
      _descriptionController.text = department['description']?.toString() ?? '';
      _status = department['status']?.toString() ?? 'Active';
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _descriptionController.clear();
      _status = 'Active';
    });
  }

  Future<void> _saveDepartment() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrduGlobal.value
              ? 'شعبہ کا نام ضروری ہے'
              : 'Department name is required'),
        ),
      );
      return;
    }

    final data = {
      'name': name,
      'description': _descriptionController.text.trim(),
      'status': _status,
    };

    if (_editingId == null) {
      await DBHelper().insertDepartment(data);
    } else {
      await DBHelper().updateDepartment(_editingId!, data);
    }

    _resetForm();
    await _loadDepartments();
    try {
      await SyncService.runTwoWaySync();
    } catch (_) {}
  }

  Future<void> _inactiveDepartment(int id) async {
    await DBHelper().inactiveDepartment(id);
    await _loadDepartments();
    try {
      await SyncService.runTwoWaySync();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = isUrduGlobal.value;
    return Scaffold(
      appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing data...')));
                try {
                  await SyncService.runTwoWaySync();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync complete')));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: ')));
                }
              },
            )
          ],
        title: Text(isUrdu ? 'شعبہ جات' : 'Departments'),
        backgroundColor: const Color(0xFF284D3D),
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingId == null
                              ? (isUrdu ? 'نیا شعبہ شامل کریں' : 'Add Department')
                              : (isUrdu ? 'شعبہ تبدیل کریں' : 'Edit Department'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF284D3D),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'نام شعبہ *' : 'Department Name *',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'تفصیل' : 'Description',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'اسٹیٹس' : 'Status',
                            border: const OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                          ],
                          onChanged: (value) =>
                              setState(() => _status = value ?? 'Active'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saveDepartment,
                                icon: const Icon(Icons.save),
                                label: Text(isUrdu ? 'محفوظ کریں' : 'Save'),
                              ),
                            ),
                            if (_editingId != null) ...[
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: _resetForm,
                                child: Text(isUrdu ? 'کینسل' : 'Cancel'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isUrdu ? 'شعبہ جات کی فہرست' : 'Departments List',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_departments.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(isUrdu
                            ? 'کوئی شعبہ موجود نہیں'
                            : 'No departments found'),
                      ),
                    ),
                  )
                else
                  ..._departments.map((department) {
                    final active = department['status']?.toString() == 'Active';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              active ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            Icons.business,
                            color: active ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          department['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            department['description']?.toString() ?? '',
                            department['status']?.toString() ?? '',
                          ].where((part) => part.isNotEmpty).join('\n'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _startEdit(department),
                            ),
                            IconButton(
                              icon: const Icon(Icons.block, color: Colors.red),
                              onPressed: active
                                  ? () => _inactiveDepartment(department['id'] as int)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
