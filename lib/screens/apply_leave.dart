// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import 'dashboard.dart';
import 'dart:ui' as ui;

class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _reasonController = TextEditingController();
  final _dateFromController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0]);
  final _dateToController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0]);
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _students = [];
  int? _selectedStudentId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = DBHelper();
    final data = await db.database;
    final studentsRes = currentUserRole.value == 'parent'
        ? await data.query('students',
            where: 'is_deleted = 0 OR is_deleted IS NULL', orderBy: 'name ASC')
        : <Map<String, dynamic>>[];
    final targetStudentId = currentUserRole.value == 'parent'
        ? (_selectedStudentId ??
            (studentsRes.isNotEmpty
                ? int.tryParse(studentsRes.first['id'].toString())
                : null))
        : currentUserId.value;
    final res = await data.query('leave_applications',
        where: 'student_id = ?',
        whereArgs: [targetStudentId],
        orderBy: 'date_from DESC');
    setState(() {
      _history = res;
      _students = studentsRes;
      _selectedStudentId = targetStudentId;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _runSync() async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Syncing...")));
    try {
      await SyncService.runTwoWaySync();
      _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Synced successfully"), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Sync failed: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _selectDateFrom(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(_dateFromController.text) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateFromController.text = picked.toIso8601String().split('T')[0];
        // Ensure Date To is not before Date From
        if (DateTime.parse(_dateToController.text).isBefore(picked)) {
          _dateToController.text = _dateFromController.text;
        }
      });
    }
  }

  Future<void> _selectDateTo(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateToController.text) ?? DateTime.now(),
      firstDate: DateTime.tryParse(_dateFromController.text) ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateToController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(isUrduGlobal.value
                    ? 'گیلری سے منتخب کریں'
                    : 'Choose from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 50,
                    maxWidth: 800,
                  );
                  if (image != null) {
                    setState(() => _selectedImage = File(image.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(isUrduGlobal.value
                    ? 'کیمرے سے تصویر لیں'
                    : 'Take a Picture'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 50,
                    maxWidth: 800,
                  );
                  if (image != null) {
                    setState(() => _selectedImage = File(image.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitLeave() async {
    if (currentUserRole.value == 'parent' && _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrduGlobal.value
              ? 'براہ کرم طالب علم منتخب کریں'
              : 'Please select a student'),
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUrduGlobal.value
                ? "تمام فیلڈز پر کرنا ضروری ہے"
                : "All fields are required")),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUrduGlobal.value
                ? "پیرنٹس کی ہاتھ سے لکھی درخواست مع دستخط اپلوڈ کریں"
                : "Please upload handwritten application with signature")),
      );
      return;
    }

    try {
      // تصویر کو base64 میں convert کریں تاکہ سنک کے وقت سرور پر اپلوڈ ہو
      String photoData = '';
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        photoData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      await DBHelper().insertLeaveApplication({
        'student_id': _selectedStudentId ?? currentUserId.value,
        'date_from': _dateFromController.text,
        'date_to': _dateToController.text,
        'reason': _reasonController.text.trim(),
        'status': 'Pending',
        'application_photo': photoData,
        'is_synced': 0,
      });

      _reasonController.clear();
      setState(() => _selectedImage = null);
      _loadHistory();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrduGlobal.value
                ? 'درخواست کامیابی سے ارسال کر دی گئی ہے۔'
                : 'Leave request submitted successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUrduGlobal.value
              ? "درخواست بھیجنے میں خرابی: $e"
              : "Error submitting: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              drawer: const AppDrawer(),
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(isUrdu ? 'چھٹی کی درخواست' : 'Apply Leave'),
                backgroundColor: Colors.indigo.shade800,
                foregroundColor: Colors.white,
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: _runSync,
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.event_busy,
                        size: 60, color: Colors.indigo),
                    const SizedBox(height: 15),
                    Text(
                      isUrdu
                          ? 'درخواست کے ساتھ پیرنٹس کی ہاتھ سے لکھی تحریر مع دستخط اپلوڈ کرنا لازمی ہے۔'
                          : 'Uploading handwritten application with parent signature is mandatory.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (currentUserRole.value == 'parent') ...[
                      DropdownButtonFormField<int>(
                        value: _selectedStudentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'طالب علم منتخب کریں' : 'Select Student',
                          border: const OutlineInputBorder(),
                        ),
                        items: _students.map((student) {
                          return DropdownMenuItem<int>(
                            value: int.tryParse(student['id'].toString()),
                            child: Text(student['name']?.toString() ?? ''),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedStudentId = value);
                          _loadHistory();
                        },
                      ),
                      const SizedBox(height: 15),
                    ],
                    TextField(
                      controller: _dateFromController,
                      readOnly: true,
                      onTap: () => _selectDateFrom(context),
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'تاریخ (سے)' : 'Date (From)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _dateToController,
                      readOnly: true,
                      onTap: () => _selectDateTo(context),
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'تاریخ (تک)' : 'Date (To)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.event),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'وجہ' : 'Reason',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.subject),
                      ),
                    ),
                    const SizedBox(height: 15),
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.indigo.shade200),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.indigo.shade50,
                        ),
                        child: _selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.upload_file,
                                      size: 30, color: Colors.indigo),
                                  const SizedBox(height: 5),
                                  Text(isUrdu
                                      ? "ہاتھ سے لکھی درخواست اپلوڈ کریں"
                                      : "Upload Application"),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(_selectedImage!,
                                    fit: BoxFit.contain),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade800,
                        padding: const EdgeInsets.all(15),
                      ),
                      onPressed: _submitLeave,
                      child: Text(
                        isUrdu ? 'درخواست بھیجیں' : 'Submit Request',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      isUrdu ? "سابقہ درخواستیں (History)" : "Leave History",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_history.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                            child: Text(isUrdu
                                ? "کوئی درخواست نہیں ملی"
                                : "No history found.")),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final h = _history[index];
                          final status = h['status'] ?? 'Pending';
                          Color statusColor = Colors.orange;
                          if (status == 'Approved') statusColor = Colors.green;
                          if (status == 'Rejected') statusColor = Colors.red;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(Icons.history_edu,
                                  color: Colors.indigo),
                              title: Text(h['reason'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              subtitle: Text(h['date_from'] ?? ''),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(5)),
                                child: Text(status,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
