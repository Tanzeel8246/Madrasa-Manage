// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import '../widgets/neo_box.dart';
import 'dashboard.dart';
import 'dart:ui' as ui;

class PayFeePage extends StatefulWidget {
  const PayFeePage({super.key});

  @override
  State<PayFeePage> createState() => _PayFeePageState();
}

class _PayFeePageState extends State<PayFeePage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _heads = [];
  List<Map<String, dynamic>> _students = [];
  int? _selectedStudentId;
  int? _selectedHeadId;
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
    final res = await data.query('fee_submissions',
        where: 'student_id = ?',
        whereArgs: [targetStudentId],
        orderBy: 'submission_date DESC');
    final headsRes = await data.query('heads',
        where: "LOWER(type) = 'income'", orderBy: 'name ASC');
    setState(() {
      _history = res;
      _heads = headsRes;
      _students = studentsRes;
      _selectedStudentId = targetStudentId;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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
                      maxWidth: 800);
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
                      maxWidth: 800);
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

  Future<void> _submitFee() async {
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

    if (_amountController.text.trim().isEmpty || _selectedHeadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUrduGlobal.value
                ? "مد اور رقم لکھنا ضروری ہے"
                : "Head and Amount are required")),
      );
      return;
    }

    try {
      // تصویر کو base64 میں convert کریں تاکہ سنک کے وقت سرور پر اپلوڈ ہو
      String screenshotData = '';
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        screenshotData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      await DBHelper().insertFeeSubmission({
        'student_id': _selectedStudentId ?? currentUserId.value,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'submission_date': DateTime.now().toIso8601String().split('T')[0],
        'screenshot': screenshotData,
        'head_id': _selectedHeadId,
        'description': _descriptionController.text.trim(),
        'finance_id': null,
        'status': 'Pending',
        'is_synced': 0,
      });

      _amountController.clear();
      _descriptionController.clear();
      setState(() => _selectedImage = null);
      _loadHistory();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrduGlobal.value
                ? 'تعاون کامیابی سے ارسال کر دیا گیا ہے۔'
                : 'Cooperation info submitted successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUrduGlobal.value
              ? 'معلومات کامیابی سے ارسال کر دی گئی ہیں۔'
              : 'Payment info submitted successfully.',
        ),
        backgroundColor: Colors.green,
      ),
    );
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
                title: Text(
                    isUrdu ? 'تعاون(صدقہ/عطیہ) کریں' : 'Donate/Contribute'),
                backgroundColor: Colors.teal.shade800,
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
                    NeoBox(
                      padding: 15,
                      child: Column(
                        children: [
                          Text(
                            isUrdu
                                ? "جاز کیش / ایزی پیسہ"
                                : "JazzCash / EasyPaisa",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "0301-2454595",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal),
                          ),
                          Text(
                            isUrdu ? "محمد اشرف" : "Muhammad Ashraf",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_heads.isEmpty && !_isLoading)
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.orange.shade50,
                        child: Text(
                          isUrdu
                              ? "مد کی لسٹ خالی ہے، براہ کرم سنک کریں"
                              : "Heads list is empty, please sync.",
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedHeadId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText:
                              isUrdu ? 'تعاون کی مد (Category)' : 'Category',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: _heads.map((h) {
                          return DropdownMenuItem<int>(
                            value: h['id'] as int,
                            child: Text(h['name'].toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedHeadId = val;
                          });
                        },
                      ),
                    if (currentUserRole.value == 'parent') ...[
                      const SizedBox(height: 15),
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
                    ],
                    const SizedBox(height: 15),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'رقم (Amount)' : 'Amount',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.money),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText:
                            isUrdu ? 'تفصیل (Description)' : 'Description',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.note),
                      ),
                    ),
                    const SizedBox(height: 15),
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo,
                                      size: 30, color: Colors.grey),
                                  const SizedBox(height: 5),
                                  Text(isUrdu
                                      ? "سکرین شاٹ اپلوڈ کریں"
                                      : "Upload Screenshot"),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(_selectedImage!,
                                    fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        padding: const EdgeInsets.all(15),
                      ),
                      onPressed: _submitFee,
                      child: Text(
                        isUrdu ? 'ارسال کریں' : 'Submit',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      isUrdu ? "سابقہ ریکارڈ (History)" : "Payment History",
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
                                ? "کوئی ریکارڈ نہیں ملا"
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
                              leading: const Icon(Icons.receipt_long,
                                  color: Colors.teal),
                              title: Text(
                                  "Rs. ${h['amount']} ${h['description'] != null && h['description'] != '' ? ' - ${h['description']}' : ''}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(h['submission_date'] ?? ''),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(5)),
                                    child: Text(status,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10)),
                                  ),
                                  if (h['finance_id'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: InkWell(
                                        onTap: () {
                                          showDialog(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                    title: Text(
                                                        isUrduGlobal.value
                                                            ? "رسید"
                                                            : "Receipt"),
                                                    content: Text(isUrduGlobal
                                                            .value
                                                        ? "رسید نمبر: ${h['finance_id']}\nرقم: ${h['amount']}\nیہ تعاون مدرسہ میں وصول پا چکا ہے۔ جزاک اللہ خیر!"
                                                        : "Receipt No: ${h['finance_id']}\nAmount: ${h['amount']}\nThis cooperation has been received by Madrasa. JazakAllah!"),
                                                    actions: [
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child:
                                                              const Text("OK"))
                                                    ],
                                                  ));
                                        },
                                        child: Text(
                                            isUrduGlobal.value
                                                ? "رسید دیکھیں"
                                                : "View Receipt",
                                            style: const TextStyle(
                                                color: Colors.blue,
                                                fontSize: 10,
                                                decoration:
                                                    TextDecoration.underline)),
                                      ),
                                    ),
                                ],
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
