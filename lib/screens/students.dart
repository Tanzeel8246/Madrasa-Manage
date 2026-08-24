import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../widgets/app_drawer.dart';
import '../utils/sync_service.dart';
import 'dashboard.dart';
import 'student_report.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_picker/image_picker.dart';

class StudentsPage extends StatefulWidget {
  final String? initialClassFilter;
  const StudentsPage({super.key, this.initialClassFilter});

  @override
  _StudentsPageState createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final ScreenshotController screenshotController = ScreenshotController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _activeStudents = [];
  List<Map<String, dynamic>> _alumniStudents = [];

  List<Map<String, dynamic>> _foundActive = [];
  List<Map<String, dynamic>> _foundAlumni = [];
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClass;
  String? _selectedResidenceStatus;

  // پیجینیشن متغیرات (Pagination)
  static const int _pageSize = 50;
  int _activeOffset = 0;
  int _alumniOffset = 0;
  bool _hasMoreActive = true;
  bool _hasMoreAlumni = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialClassFilter != null) {
      _searchQuery = widget.initialClassFilter!;
      _searchController.text = _searchQuery;
    }
    _refreshStudents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreStudents();
    }
  }

  void _refreshStudents() async {
    setState(() {
      _activeStudents = [];
      _alumniStudents = [];
      _foundActive = [];
      _foundAlumni = [];
      _activeOffset = 0;
      _alumniOffset = 0;
      _hasMoreActive = true;
      _hasMoreAlumni = true;
    });

    // پہلے بیچ
    final activeData = await DBHelper().getPagedStudentsForUser(
        limit: _pageSize,
        offset: 0,
        status: 'Active',
        searchQuery: _searchQuery);
    final alumniData = await DBHelper().getPagedStudentsForUser(
        limit: _pageSize,
        offset: 0,
        status: 'Alumni',
        searchQuery: _searchQuery);

    if (!mounted) return;
    setState(() {
      _activeStudents = activeData;
      _alumniStudents = alumniData;
      _foundActive = activeData;
      _foundAlumni = alumniData;
      _activeOffset = activeData.length;
      _alumniOffset = alumniData.length;
      _hasMoreActive = activeData.length == _pageSize;
      _hasMoreAlumni = alumniData.length == _pageSize;
    });

    final classData = await DBHelper().getClassesForUser();
    if (!mounted) return;
    setState(() => _classes = classData);

    if (widget.initialClassFilter != null &&
        widget.initialClassFilter!.isNotEmpty) {
      _searchController.text = widget.initialClassFilter!;
      _searchQuery = widget.initialClassFilter!;
    }
  }

  Future<void> _loadMoreStudents() async {
    if (_isLoadingMore || (!_hasMoreActive && !_hasMoreAlumni)) return;
    setState(() => _isLoadingMore = true);

    try {
      if (_hasMoreActive) {
        final more = await DBHelper().getPagedStudentsForUser(
            limit: _pageSize,
            offset: _activeOffset,
            status: 'Active',
            searchQuery: _searchQuery);
        setState(() {
          _activeStudents.addAll(more);
          _foundActive = _activeStudents;
          _activeOffset += more.length;
          _hasMoreActive = more.length == _pageSize;
        });
      }

      if (_hasMoreAlumni) {
        final more = await DBHelper().getPagedStudentsForUser(
            limit: _pageSize,
            offset: _alumniOffset,
            status: 'Alumni',
            searchQuery: _searchQuery);
        setState(() {
          _alumniStudents.addAll(more);
          _foundAlumni = _alumniStudents;
          _alumniOffset += more.length;
          _hasMoreAlumni = more.length == _pageSize;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _runFilter(String enteredKeyword) {
    _searchQuery = enteredKeyword.trim();
    _refreshStudents();
  }

  Future<void> _showAddStudentDialog() async {
    final nameController = TextEditingController();
    final fatherNameController = TextEditingController();
    final rollNoController = TextEditingController();
    _selectedClass = null;
      _selectedResidenceStatus = null;
    final contactController = TextEditingController();
    final addressController = TextEditingController();
    final admissionDateController =
        TextEditingController(text: DateTime.now().toString().substring(0, 10));
    final graduationDateController = TextEditingController();
    final durationController = TextEditingController();

    // ویب کی طرح اگلا داخلہ نمبر خودکار تجویز کریں
    final nextRollNo = await DBHelper().getNextStudentRollNumber();
    rollNoController.text = nextRollNo;

    bool isSaving = false;
    String? photoPath;

    Future<void> pickImage(
        void Function(void Function()) setDialogState) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 800,
          maxHeight: 800);
      if (picked != null) {
        setDialogState(() => photoPath = picked.path);
      }
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.person_add, color: Color(0xFF284D3D)),
            const SizedBox(width: 8),
            Text(isUrduGlobal.value
                ? "نیا اندراج (طالب علم)"
                : "New Student Entry"),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => pickImage(setDialogState),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildPhotoAvatar(photoPath, radius: 40),
                      if (photoPath == null)
                        const Icon(Icons.camera_alt,
                            size: 30, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // نام طالب علم *
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: isUrduGlobal.value
                        ? "نام طالب علم *"
                        : "Student Name *",
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // ولدیت *
                TextField(
                  controller: fatherNameController,
                  decoration: InputDecoration(
                    labelText:
                        isUrduGlobal.value ? "ولدیت *" : "Father's Name *",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // داخلہ نمبر اور کلاس (ویب کی طرح)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rollNoController,
                        decoration: InputDecoration(
                          labelText: isUrduGlobal.value
                              ? "داخلہ نمبر *"
                              : "Admission No *",
                          border: const OutlineInputBorder(),
                          hintText: "مثلاً 90001",
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: InputDecoration(
                          labelText:
                              isUrduGlobal.value ? "کلاس / درجہ" : "Class",
                          border: const OutlineInputBorder(),
                        ),
                        items: _classes.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['name'].toString(),
                            child: Text(c['name'].toString()),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            _selectedClass = v;
                          });
                        },
                      ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedResidenceStatus,
                          decoration: InputDecoration(
                            labelText: isUrduGlobal.value ? "?????? ?????" : "Residential Status",
                            border: const OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'residential_aided', child: Text("??????? ??????")),
                            DropdownMenuItem(value: 'non_residential_non_aided', child: Text("??? ??????? ??? ??????")),
                            DropdownMenuItem(value: 'residential_non_aided', child: Text("??????? ??? ??????")),
                            DropdownMenuItem(value: 'non_residential_aided', child: Text("??? ??????? ??????")),
                          ],
                          onChanged: (v) {
                            setDialogState(() {
                              _selectedResidenceStatus = v;
                            });
                          },
                        ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // رابطہ نمبر *
                TextField(
                  controller: contactController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isUrduGlobal.value
                        ? "رابطہ نمبر *"
                        : "Contact Number *",
                    hintText: "0300xxxxxxx",
                    prefixIcon: const Icon(Icons.phone),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // مکمل پتہ
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: isUrduGlobal.value ? "مکمل پتہ" : "Full Address",
                    prefixIcon: const Icon(Icons.home),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // تاریخ داخلہ
                TextField(
                  controller: admissionDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText:
                        isUrduGlobal.value ? "تاریخ داخلہ" : "Admission Date",
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                  ),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) {
                      setDialogState(() => admissionDateController.text =
                          picked.toString().substring(0, 10));
                    }
                  },
                ),
                const SizedBox(height: 10),
                // تعلیمی دورانیہ
                TextField(
                  controller: durationController,
                  decoration: InputDecoration(
                    labelText:
                        isUrduGlobal.value ? "تعلیمی دورانیہ" : "Duration",
                    hintText:
                        isUrduGlobal.value ? "مثلاً 3 سال" : "e.g. 3 years",
                    prefixIcon: const Icon(Icons.timer),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text(isUrduGlobal.value ? "کینسل" : "Cancel"),
            ),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white, size: 18),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF284D3D)),
              onPressed: isSaving
                  ? null
                  : () async {
                      // Validation
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isUrduGlobal.value
                              ? "نام طالب علم لکھنا ضروری ہے!"
                              : "Student name is required!"),
                          backgroundColor: Colors.red,
                        ));
                        return;
                      }
                      if (fatherNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isUrduGlobal.value
                              ? "ولدیت لکھنا ضروری ہے!"
                              : "Father's name is required!"),
                          backgroundColor: Colors.red,
                        ));
                        return;
                      }
                      if (contactController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isUrduGlobal.value
                              ? "رابطہ نمبر لازمی ہے!"
                              : "Contact number is required!"),
                          backgroundColor: Colors.red,
                        ));
                        return;
                      }
                      if (rollNoController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isUrduGlobal.value
                              ? "داخلہ نمبر لازمی ہے!"
                              : "Admission number is required!"),
                          backgroundColor: Colors.red,
                        ));
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        // DB-level duplicate check
                        final result = await DBHelper().insertStudent({
                          'name': nameController.text.trim(),
                          'father_name': fatherNameController.text.trim(),
                          'roll_number': rollNoController.text.trim(),
                          'class_name': _selectedClass ?? '',
          'residence_status': _selectedResidenceStatus ?? '',
                          'contact_number': contactController.text.trim(),
                          'address': addressController.text.trim(),
                          'status': 'Active',
                          'admission_date': admissionDateController.text,
                          'graduation_date': graduationDateController.text,
                          'duration': durationController.text.trim(),
                          'photo': photoPath ?? '',
                        });

                        if (result == -1) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isUrduGlobal.value
                                ? "❌ یہ داخلہ نمبر پہلے سے موجود ہے! نیا نمبر ڈالیں۔"
                                : "❌ This admission number already exists! Enter a new one."),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ));
                          return;
                        }

                        await SyncService.runTwoWaySync();

                        if (mounted) {
                          Navigator.pop(context);
                          _refreshStudents();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isUrduGlobal.value
                                ? "✅ طالب علم کا ریکارڈ محفوظ ہو گیا!"
                                : "✅ Student saved successfully!"),
                            backgroundColor: Colors.green,
                          ));
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Error: $e"),
                          backgroundColor: Colors.red,
                        ));
                      }
                    },
              label: Text(
                  isUrduGlobal.value
                      ? (isSaving ? "محفوظ ہو رہا ہے..." : "محفوظ کریں")
                      : (isSaving ? "Saving..." : "Save"),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showBulkImportDialog() async {
    final importController = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(isUrduGlobal.value
              ? 'طلباء bulk import'
              : 'Bulk Import Students'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isUrduGlobal.value
                      ? 'ہر لائن میں: داخلہ نمبر، نام، ولدیت، رابطہ، کلاس'
                      : 'One row per line: admission no, name, father, contact, class',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: importController,
                  minLines: 8,
                  maxLines: 12,
                  textDirection: isUrduGlobal.value
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: isUrduGlobal.value
                        ? '1001, احمد, محمد, 03000000000, حفظ'
                        : '1001, Ahmad, Muhammad, 03000000000, Hifz',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.pop(context),
              child: Text(isUrduGlobal.value ? 'کینسل' : 'Cancel'),
            ),
            ElevatedButton.icon(
              icon: isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              onPressed: isImporting
                  ? null
                  : () async {
                      setDialogState(() => isImporting = true);
                      final lines = importController.text
                          .split(RegExp(r'\r?\n'))
                          .map((line) => line.trim())
                          .where((line) => line.isNotEmpty)
                          .toList();
                      var imported = 0;
                      var skipped = 0;

                      for (final line in lines) {
                        final cols = line
                            .split(RegExp(r'[\t,]'))
                            .map((part) => part.trim())
                            .toList();
                        if (cols.length < 2) {
                          skipped++;
                          continue;
                        }
                        final name = cols.length > 1 ? cols[1] : '';
                        if (name.isEmpty || name == 'نام الطالب علم') {
                          skipped++;
                          continue;
                        }
                        var admissionNo = cols[0];
                        admissionNo = admissionNo.isEmpty
                            ? await DBHelper().getNextStudentRollNumber()
                            : admissionNo;
                        final result = await DBHelper().insertStudent({
                          'roll_number': admissionNo,
                          'name': name,
                          'father_name': cols.length > 2 ? cols[2] : '',
                          'contact_number': cols.length > 3 ? cols[3] : '',
                          'class_name': cols.length > 4 ? cols[4] : 'حفظ',
                          'status': 'Active',
                          'admission_date':
                              DateTime.now().toString().substring(0, 10),
                        });
                        if (result == -1) {
                          skipped++;
                        } else {
                          imported++;
                        }
                      }

                      try {
                        await SyncService.runTwoWaySync();
                      } catch (_) {}

                      if (!mounted) return;
                      Navigator.pop(context);
                      _refreshStudents();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isUrduGlobal.value
                              ? '$imported طلباء شامل، $skipped چھوڑ دیے گئے'
                              : '$imported students imported, $skipped skipped'),
                          backgroundColor:
                              imported > 0 ? Colors.green : Colors.orange,
                        ),
                      );
                    },
              label: Text(isUrduGlobal.value ? 'امپورٹ' : 'Import'),
            ),
          ],
        );
      }),
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
                  MaterialPageRoute(builder: (_) => const DashboardPage()));
            },
            child: Directionality(
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              child: Scaffold(
                backgroundColor: const Color(0xFFF1EFE7),
                appBar: AppBar(
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  title: Text(isUrdu ? "طلباء کا ریکارڈ" : "Students Record"),
                  backgroundColor: const Color(0xFF284D3D),
                  foregroundColor: Colors.white,
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      tooltip: isUrdu ? 'طلباء امپورٹ کریں' : 'Import Students',
                      onPressed: _showBulkImportDialog,
                    ),
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
                            _refreshStudents();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(isUrdu
                                    ? "سنک مکمل ہو گیا!"
                                    : "Sync complete!"),
                                backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(isUrdu
                                    ? "سنک میں خرابی آئی"
                                    : "Sync failed"),
                                backgroundColor: Colors.red));
                          }
                        }
                      },
                    ),
                  ],
                ),
                drawer: const AppDrawer(),
                floatingActionButton: FloatingActionButton(
                  backgroundColor: const Color(0xFF284D3D),
                  onPressed: _showAddStudentDialog,
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
                              ? 'تلاش کریں (نام، رول نمبر یا کلاس)'
                              : 'Search (Name, Roll No or Class)',
                          suffixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _buildGroupedList(isUrdu),
                      ),
                    ],
                  ),
                ),
              ),
            )); // PopScope کا بند
      },
    );
  }

  Widget _buildPhotoAvatar(String? photoPath, {double radius = 16}) {
    Widget fallback = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.person, size: radius * 1.25, color: Colors.white));
    if (photoPath == null || photoPath.isEmpty) {
      return fallback;
    }

    Widget img;
    if (photoPath.startsWith('http')) {
      img = Image.network(photoPath,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    } else if (File(photoPath).existsSync()) {
      img = Image.file(File(photoPath),
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    } else {
      String baseUrl = apiUrl;
      if (baseUrl.endsWith('api.php')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 7);
      }
      if (!baseUrl.endsWith('/')) baseUrl += '/';

      String fullUrl = baseUrl;
      if (photoPath.startsWith('uploads/')) {
        fullUrl += photoPath;
      } else if (!photoPath.contains('/')) {
        fullUrl += "uploads/students/$photoPath";
      } else {
        fullUrl += photoPath;
      }
      img = Image.network(fullUrl,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(child: img),
    );
  }

  Widget _buildClassDataTable(
      List<Map<String, dynamic>> students, bool isUrdu) {
    int serialNo = 1;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.resolveWith((states) => Colors.grey.shade200),
        dataRowMinHeight: 40,
        dataRowMaxHeight: 55,
        columnSpacing: 20,
        columns: [
          DataColumn(
              label: Text(isUrdu ? 'نمبرشمار' : 'S.No',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text(isUrdu ? 'رول نمبر' : 'Roll No',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text(isUrdu ? 'تصویر' : 'Photo',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text(isUrdu ? 'نام طالب علم' : 'Name',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text(isUrdu ? 'ولدیت' : 'Father',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text(isUrdu ? 'رابطہ' : 'Contact',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text(isUrdu ? 'ایکشن' : 'Action',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: students.map((s) {
          return DataRow(
            cells: [
              DataCell(Text((serialNo++).toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey))),
              DataCell(Text(s['roll_number']?.toString() ?? '-')),
              DataCell(_buildPhotoAvatar(s['photo']?.toString())),
              DataCell(Text(s['name']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(s['father_name']?.toString() ?? '-')),
              DataCell(Text(s['contact_number']?.toString() ?? '-')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility,
                          color: Colors.blue, size: 20),
                      onPressed: () => _showStudentDetails(s, isUrdu),
                    ),
                    if (currentUserRole.value == 'admin')
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.orange, size: 20),
                        onPressed: () => _showEditStudentDialog(s),
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroupedList(bool isUrdu, String filterType) {
    List<Map<String, dynamic>> activeList = [];
    List<Map<String, dynamic>> alumniList = [];

    if (filterType == 'alumni') {
        alumniList = _foundAlumni;
    } else if (filterType == 'all_active') {
        activeList = _foundActive;
    } else {
        activeList = _foundActive.where((s) => (s['residence_status']?.toString() ?? '') == filterType).toList();
    }

    if (activeList.isEmpty && alumniList.isEmpty) {
      return Center(
        child: Text(
          isUrdu ? 'کوئی ریکارڈ نہیں ملا' : 'No record found',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final List<String> predefinedOrder = [
      'حفظ',
      'گردان',
      'تجوید',
      'حسن صوت',
      'اولیٰ',
      'اولیٰ دہم',
      'اولیٰ نہم',
      'مڈل'
    ];

    // Group active students by class
    Map<String, List<Map<String, dynamic>>> classGroups = {};
    for (var student in activeList) {
      String cName = student['class_name']?.toString() ?? 'دیگر';
      if (cName.trim().isEmpty) {
        cName = 'دیگر';
      }
      classGroups.putIfAbsent(cName, () => []).add(student);
    }

    // Determine the sorted order of classes present in groups
    List<String> orderedClasses = [];
    for (String pc in predefinedOrder) {
      if (classGroups.containsKey(pc)) {
        orderedClasses.add(pc);
      }
    }
    // Add remaining classes not in predefined order
    for (var c in classGroups.keys) {
      if (!orderedClasses.contains(c)) {
        orderedClasses.add(c);
      }
    }

    List<Widget> listWidgets = [];

    // Add active classes sections
    for (String cName in orderedClasses) {
      listWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 15, bottom: 5, left: 5, right: 5),
          child: Text(
            "${isUrdu ? 'کلاس' : 'Class'}: $cName",
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF284D3D)),
          ),
        ),
      );
      listWidgets.add(
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildClassDataTable(classGroups[cName]!, isUrdu),
          ),
        ),
      );
    }

    // Add Alumni section at the end if not empty
    if (alumniList.isNotEmpty) {
      listWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 25, bottom: 5, left: 5, right: 5),
          child: Text(
            isUrdu ? 'فارغ التحصیل' : 'Alumni',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
      );
      listWidgets.add(
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildClassDataTable(alumniList, isUrdu),
          ),
        ),
      );
    }

    return ListView(
      children: listWidgets,
    );
  }

  void _showPromoteDialog(Map<String, dynamic> student, bool isUrdu) {
    String? selectedClass;
    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setStateSB) {
            return AlertDialog(
              title:
                  Text(isUrdu ? 'طالب علم کو پروموٹ کریں' : 'Promote Student'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${student['name']} کو اگلی کلاس میں منتقل کریں'),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                        labelText: isUrdu
                            ? 'نئی کلاس منتخب کریں'
                            : 'Select New Class'),
                    value: selectedClass,
                    items: _classes
                        .map((c) => DropdownMenuItem(
                            value: c['name'].toString(),
                            child: Text(c['name'].toString())))
                        .toList(),
                    onChanged: (v) {
                      setStateSB(() {
                        selectedClass = v;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isUrdu ? 'کینسل' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedClass != null) {
                      await DBHelper().updateStudent(
                          student['id'], {'class_name': selectedClass});
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        Navigator.pop(context); // Close details dialog
                        _refreshStudents();
                        try {
                          await SyncService.runTwoWaySync();
                        } catch (_) {}
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isUrdu
                                ? 'طالب علم پروموٹ ہو گیا'
                                : 'Student Promoted')));
                      }
                    }
                  },
                  child: Text(isUrdu ? 'پروموٹ کریں' : 'Promote'),
                )
              ],
            );
          });
        });
  }

  void _showStudentDetails(Map<String, dynamic> student, bool isUrdu) {
    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Row(
              children: [
                Icon(
                    student['status'] == 'Alumni'
                        ? Icons.history_edu
                        : Icons.person,
                    color: const Color(0xFF284D3D)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(student['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailTile(
                      Icons.family_restroom,
                      isUrdu ? 'ولدیت' : 'Father',
                      student['father_name'] ?? '-'),
                  _detailTile(Icons.phone, isUrdu ? 'رابطہ نمبر' : 'Contact',
                      student['contact_number'] ?? '-'),
                  _detailTile(Icons.home, isUrdu ? 'مکمل پتہ' : 'Address',
                      student['address'] ?? '-'),
                  if (student['status'] == 'Alumni') ...[
                    const Divider(),
                    _detailTile(
                        Icons.calendar_today,
                        isUrdu ? 'فراغت کی تاریخ' : 'Graduation Date',
                        student['graduation_date'] ?? '-'),
                    _detailTile(
                        Icons.timer,
                        isUrdu ? 'تعلیمی دورانیہ' : 'Duration',
                        student['duration'] ?? '-'),
                    _detailTile(
                        Icons.info_outline,
                        isUrdu ? 'وجہ فراغت' : 'Reason',
                        student['leaving_reason'] ?? '-'),
                  ],
                ],
              ),
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () => _printIDCard(student, isUrdu),
                icon: const Icon(Icons.assignment_ind,
                    color: Colors.white, size: 18),
                label: Text(isUrdu ? "آئی ڈی کارڈ" : "ID Card",
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              if (currentUserRole.value == 'admin') ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _showEditStudentDialog(student);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: isUrdu ? 'حذف کریں' : 'Delete',
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(isUrdu ? 'طالب علم حذف کریں' : 'Delete Student'),
                        content: Text(isUrdu 
                            ? 'کیا آپ واقعی اس طالب علم کا ریکارڈ حذف کرنا چاہتے ہیں؟'
                            : 'Are you sure you want to delete this student?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(isUrdu ? 'نہیں' : 'No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(isUrdu ? 'ہاں' : 'Yes', style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await DBHelper().deleteStudent(student['id']);
                        await SyncService.runTwoWaySync();
                        if (mounted) {
                          _refreshStudents();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isUrdu ? "✅ طالب علم حذف کر دیا گیا!" : "✅ Student deleted!"),
                            backgroundColor: Colors.green,
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Error: $e"),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    }
                  },
                ),
                if ((student['status']?.toString().toLowerCase() ?? '') !=
                    'alumni')
                  IconButton(
                    icon: const Icon(Icons.upgrade, color: Colors.green),
                    tooltip: isUrdu ? 'پروموٹ کریں' : 'Promote',
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showPromoteDialog(student, isUrdu);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.school, color: Colors.orange),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _showMigrateStudentDialog(student);
                  },
                ),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentReportPage(
                          forceStudentId: student['id']?.toString()),
                    ),
                  );
                },
                icon:
                    const Icon(Icons.analytics, color: Colors.white, size: 18),
                label: Text(isUrdu ? "مکمل رپورٹ دیکھیں" : "View Full Report",
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF284D3D)),
              ),
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(isUrdu ? "بند کریں" : "Close"))
            ],
          );
        });
  }

  Widget _detailTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey, size: 20),
      title:
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    final nameController =
        TextEditingController(text: student['name']?.toString() ?? '');
    final fatherNameController =
        TextEditingController(text: student['father_name']?.toString() ?? '');
    final rollNoController =
        TextEditingController(text: student['roll_number']?.toString() ?? '');
    String? localSelectedClass = student['class_name']?.toString();
      _selectedResidenceStatus = student['residence_status']?.toString();
    final contactController = TextEditingController(
        text: student['contact_number']?.toString() ?? '');
    final addressController =
        TextEditingController(text: student['address']?.toString() ?? '');

    // verify class exists
    if (localSelectedClass != null &&
        !_classes.any((c) => c['name'].toString() == localSelectedClass)) {
      localSelectedClass = null;
    }

    String? photoPath = student['photo']?.toString();
    if (photoPath != null && photoPath.isEmpty) {
      photoPath = null;
    }

    Future<void> pickImage(
        void Function(void Function()) setDialogState) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 800,
          maxHeight: 800);
      if (picked != null) {
        setDialogState(() => photoPath = picked.path);
      }
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.edit, color: Colors.blue),
            const SizedBox(width: 8),
            Text(isUrduGlobal.value ? "طالب علم ترمیم" : "Edit Student"),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => pickImage(setDialogState),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildPhotoAvatar(photoPath, radius: 40),
                      if (photoPath == null)
                        const Icon(Icons.camera_alt,
                            size: 30, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value ? "نام" : "Name",
                        border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: fatherNameController,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value ? "ولدیت" : "Father Name",
                        border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: rollNoController,
                    decoration: InputDecoration(
                        labelText:
                            isUrduGlobal.value ? "داخلہ نمبر" : "Admission No",
                        border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: localSelectedClass,
                  decoration: InputDecoration(
                      labelText: isUrduGlobal.value ? "کلاس" : "Class",
                      border: const OutlineInputBorder()),
                  items: _classes
                      .map((c) => DropdownMenuItem<String>(
                          value: c['name'].toString(),
                          child: Text(c['name'].toString())))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => localSelectedClass = v),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: contactController,
                    decoration: InputDecoration(
                        labelText:
                            isUrduGlobal.value ? "رابطہ نمبر" : "Contact",
                        border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                        labelText: isUrduGlobal.value ? "پتہ" : "Address",
                        border: const OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isUrduGlobal.value ? "کینسل" : "Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  return;
                }
                await DBHelper().updateStudent(student['id'], {
                  'name': nameController.text.trim(),
                  'father_name': fatherNameController.text.trim(),
                  'roll_number': rollNoController.text.trim(),
                  'class_name': localSelectedClass ?? '',
          'residence_status': _selectedResidenceStatus ?? '',
                  'contact_number': contactController.text.trim(),
                  'address': addressController.text.trim(),
                  'photo': photoPath ?? '',
                });
                try {
                  await SyncService.runTwoWaySync();
                } catch (_) {}
                Navigator.pop(context);
                _refreshStudents();
              },
              child: Text(isUrduGlobal.value ? "محفوظ کریں" : "Save"),
            )
          ],
        );
      }),
    );
  }

  void _showMigrateStudentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isUrduGlobal.value
            ? "طالب علم کو فارغ کریں / حذف کریں"
            : "Migrate / Soft Delete"),
        content: Text(isUrduGlobal.value
            ? "کیا آپ اس طالب علم کو فارغ التحصیل (Alumni) کرنا چاہتے ہیں یا مدرسہ سے خارج کرنا چاہتے ہیں؟"
            : "Do you want to make this student an Alumni or remove them?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrduGlobal.value ? "کینسل" : "Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              await DBHelper().updateStudent(student['id'], {
                'status': 'Alumni',
                'graduation_date': DateTime.now().toString().substring(0, 10),
                'leaving_reason': 'Graduated',
              });
              try {
                await SyncService.runTwoWaySync();
              } catch (_) {}
              Navigator.pop(context);
              _refreshStudents();
            },
            child: Text(isUrduGlobal.value ? "فارغ التحصیل" : "Alumni",
                style: const TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DBHelper().updateStudent(student['id'], {
                'status': 'Inactive',
                'leaving_reason': 'Removed',
              });
              try {
                await SyncService.runTwoWaySync();
              } catch (_) {}
              Navigator.pop(context);
              _refreshStudents();
            },
            child: Text(isUrduGlobal.value ? "خارج کریں" : "Remove",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _printIDCard(Map<String, dynamic> student, bool isUrdu) async {
    final ByteData logoData = await rootBundle.load('assets/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();

    Uint8List? photoBytes;
    try {
      final photoPath = student['photo']?.toString() ?? '';
      if (photoPath.isNotEmpty) {
        if (photoPath.startsWith('http')) {
          final response = await http.get(Uri.parse(photoPath));
          if (response.statusCode == 200) photoBytes = response.bodyBytes;
        } else if (File(photoPath).existsSync()) {
          photoBytes = File(photoPath).readAsBytesSync();
        } else {
          String fullUrl = apiUrl;
          if (!fullUrl.endsWith('/')) fullUrl += '/';
          if (photoPath.startsWith('uploads/')) {
            fullUrl += photoPath;
          } else if (!photoPath.contains('/')) {
            fullUrl += "uploads/students/$photoPath";
          } else {
            fullUrl += photoPath;
          }
          final response = await http.get(Uri.parse(fullUrl));
          if (response.statusCode == 200) photoBytes = response.bodyBytes;
        }
      }
    } catch (_) {}

    // Build the ID Card as a Flutter Widget to capture as image
    // This solves the Urdu text breaking issue perfectly.
    final Widget idCardWidget = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'JameelNooriNastaleeq',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          bodyLarge: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
        ),
      ),
      home: Directionality(
        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          width: 337.5, // 3.375 * 100
          height: 212.5, // 2.125 * 100
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF284D3D),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.memory(logoBytes,
                    width: 24,
                    height: 24,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isUrdu
                          ? "مدرسہ اشرف المدارس فروکہ"
                          : "Madrasa Ashraf-ul-Madaris",
                      style: const TextStyle(
                        fontFamily: 'JameelNooriNastaleeq',
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection:
                          isUrdu ? TextDirection.rtl : TextDirection.ltr,
                    ),
                    Text(
                      "شناختی کارڈ - ID Card",
                      style: const TextStyle(
                        fontFamily: 'JameelNooriNastaleeq',
                        fontSize: 12,
                        color: Color(0xFFD4AC0D),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
                Image.memory(logoBytes,
                    width: 24,
                    height: 24,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Main Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo & Signature (Left)
                  Column(
                    children: [
                      Container(
                        width: 70,
                        height: 85,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF284D3D), width: 1.5),
                          color: Colors.grey.shade200,
                        ),
                        child: photoBytes != null
                            ? Image.memory(photoBytes, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  isUrdu ? "تصویر" : "Photo",
                                  style: const TextStyle(
                                      fontFamily: 'JameelNooriNastaleeq',
                                      fontSize: 10),
                                ),
                              ),
                      ),
                      const Spacer(),
                      Container(
                        width: 70,
                        decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Colors.black, width: 0.5)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isUrdu ? "دستخط جاری کنندہ" : "Issuer Signature",
                          style: const TextStyle(
                              fontFamily: 'JameelNooriNastaleeq',
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Details (Right)
                  Expanded(
                    child: Directionality(
                      textDirection:
                          isUrdu ? TextDirection.rtl : TextDirection.ltr,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _idRow(isUrdu ? "نام:" : "Name:",
                              student['name'] ?? '', isUrdu),
                          const SizedBox(height: 3),
                          _idRow(isUrdu ? "ولدیت:" : "Father:",
                              student['father_name'] ?? '', isUrdu),
                          const SizedBox(height: 3),
                          _idRow(isUrdu ? "داخلہ نمبر:" : "Adm No:",
                              student['roll_number'] ?? '', isUrdu),
                          const SizedBox(height: 3),
                          _idRow(isUrdu ? "کلاس:" : "Class:",
                              student['class_name'] ?? '', isUrdu),
                          const SizedBox(height: 3),
                          _idRow(isUrdu ? "رابطہ:" : "Contact:",
                              student['contact_number'] ?? '', isUrdu),
                          const SizedBox(height: 3),
                          _idRow(isUrdu ? "آئی ڈی:" : "ID:",
                              "#${student['id'] ?? ''}", isUrdu),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          // Footer
          Container(
            height: 20,
            color: const Color(0xFFD4AC0D),
            alignment: Alignment.center,
            child: Text(
              isUrdu
                  ? "تعلیم و تربیت کا گہوارہ (مدرسہ اشرف المدارس)"
                  : "Education & Training Center",
              style: const TextStyle(
                fontFamily: 'JameelNooriNastaleeq',
                fontSize: 14,
                color: Color(0xFF284D3D),
                fontWeight: FontWeight.bold,
              ),
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        ],
      ),
    )));

    // Capture the widget as image
    final Uint8List imageBytes = await screenshotController.captureFromWidget(
      idCardWidget,
      delay: const Duration(milliseconds: 100),
      context: context,
    );

    // Create PDF with the captured image
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
            3.375 * PdfPageFormat.inch, 2.125 * PdfPageFormat.inch,
            marginAll: 0),
        build: (pw.Context ctx) {
          return pw.Center(
            child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.fill),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ID_Card_${(student["id"] ?? "student").toString().replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '')}.pdf',
    );
  }

  Widget _idRow(String label, String value, bool isUrdu) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 45,
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'JameelNooriNastaleeq',
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontFamily: 'JameelNooriNastaleeq', fontSize: 10)),
        ),
      ],
    );
  }
}
