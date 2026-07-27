import 'package:flutter/material.dart';
import 'dart:convert';
import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/network_service.dart';
import '../widgets/app_drawer.dart';
import 'dashboard.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final Color primaryGreen = const Color(0xFF284D3D);
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color cardColor = const Color(0xFFE8E5D9);

  List<dynamic> users = [];
  List<Map<String, dynamic>> allSystemClasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final classData = await DBHelper().getClasses();
      setState(() => allSystemClasses = classData);
    } catch (_) {}
    await fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final response = await NetworkService.getWithFallbackAction('get_users')
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              users = data['users'];
              isLoading = false;
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch users');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> deleteUser(String id) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isUrduGlobal.value ? 'یوزر حذف کریں' : 'Delete User'),
        content: Text(isUrduGlobal.value
            ? 'کیا آپ واقعی اس یوزر کو حذف کرنا چاہتے ہیں؟'
            : 'Are you sure you want to delete this user?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isUrduGlobal.value ? 'نہیں' : 'No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isUrduGlobal.value ? 'ہاں، حذف کریں' : 'Yes, Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      final response =
          await NetworkService.getWithFallbackAction('delete_user&id=$id');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          fetchUsers();
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(data['message'])));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(data['message'])));
            setState(() => isLoading = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => isLoading = false);
      }
    }
  }

  void openUserDialog({Map<String, dynamic>? user}) {
    final isUrdu = isUrduGlobal.value;
    final nameController = TextEditingController(text: user?['name'] ?? '');
    final usernameController =
        TextEditingController(text: user?['username'] ?? '');
    final passwordController = TextEditingController();
    String role = user?['role'] ?? 'teacher';

    // Parse permissions
    List<String> currentPerms = [];
    if (user != null && user['permissions'] != null) {
      try {
        final p = json.decode(user['permissions']);
        if (p is List) currentPerms = p.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    // Parse allowed classes
    List<dynamic> currentAllowedClasses = [];
    if (user != null && user['allowed_classes'] != null) {
      try {
        final ac = json.decode(user['allowed_classes']);
        if (ac is List) currentAllowedClasses = ac;
      } catch (_) {}
    }

    final Map<String, String> allPerms = {
      'manage_classes': isUrdu ? 'کلاسز کا انتظام' : 'Manage Classes',
      'manage_students': isUrdu ? 'طلباء کا ریکارڈ' : 'Manage Students',
      'manage_teachers': isUrdu ? 'اساتذہ کا ریکارڈ' : 'Manage Teachers',
      'manage_attendance': isUrdu ? 'طالب علموں کی حاضری' : 'Student Attendance',
      'manage_teacher_attendance': isUrdu ? 'اساتذہ کی حاضری' : 'Teacher Attendance',
      'manage_hifz': isUrdu ? 'حفظ (روزانہ اندراج و رپورٹ)' : 'Manage Hifz',
      'manage_hifz_daily': isUrdu ? 'حفظ (روزانہ اندراج)' : 'Hifz Daily Entry',
      'manage_hifz_report': isUrdu ? 'حفظ (تعلیمی رپورٹ)' : 'Hifz Report',
      'manage_academic_dashboard': isUrdu ? 'تعلیمی کارکردگی (اندراج ڈیش بورڈ)' : 'Academic Entry Dashboard',
      'manage_academic_entry': isUrdu ? 'تعلیمی رپورٹ (اندراج)' : 'Academic Entry',
      'manage_academic_view': isUrdu ? 'تعلیمی کارکردگی (رپورٹ دیکھیں)' : 'Academic View',
      'manage_academics': isUrdu ? 'تعلیمی رپورٹ (جنرل)' : 'General Academics',
      'manage_exams': isUrdu ? 'امتحانات و نتائج' : 'Exams & Results',
      'manage_finance': isUrdu ? 'آمدن و خرچ (سادہ فنانس)' : 'Simple Finance',
      'manage_erp': isUrdu ? 'ای آر پی اکاؤنٹس (ERP Accounting)' : 'ERP Accounting',
      'manage_admissions': isUrdu ? 'داخلہ درخواستیں' : 'Admission Requests',
      'manage_notices': isUrdu ? 'نوٹس بورڈ / اعلانات' : 'Notice Board',
      'manage_requests': isUrdu ? 'درخواستیں و شکایات' : 'Requests & Complaints',
      'add_complaint': isUrdu ? 'شکایت اندراج' : 'Add Complaint',
      'manage_complaints': isUrdu ? 'شکایات ریکارڈ' : 'Manage Complaints',
      'manage_users': isUrdu ? 'یوزرز کا انتظام' : 'User Management',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: bgColor,
            title: Text(
                isUrdu
                    ? (user == null ? 'نیا یوزر شامل کریں' : 'یوزر اپڈیٹ کریں')
                    : (user == null ? 'Add New User' : 'Update User'),
                style: TextStyle(
                    color: primaryGreen, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                          labelText: isUrdu ? 'نام' : 'Name',
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                          labelText: isUrdu ? 'یوزر نیم' : 'Username',
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                          labelText: isUrdu ? 'پاسورڈ' : 'Password',
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: InputDecoration(
                          labelText: isUrdu ? 'رول' : 'Role',
                          border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(
                            value: 'admin',
                            child: Text(isUrdu ? 'ایڈمن' : 'Admin')),
                        DropdownMenuItem(
                            value: 'nazim',
                            child: Text(isUrdu ? 'ناظم' : 'Nazim')),
                        DropdownMenuItem(
                            value: 'teacher',
                            child: Text(isUrdu ? 'استاذ' : 'Teacher')),
                      ],
                      onChanged: (val) {
                        setStateDialog(() => role = val!);
                      },
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isUrdu ? 'پرمیشنز' : 'Permissions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: primaryGreen)),
                        TextButton(
                          onPressed: () {
                            setStateDialog(() {
                              if (currentPerms.length == allPerms.length) {
                                currentPerms.clear();
                              } else {
                                currentPerms = allPerms.keys.toList();
                              }
                            });
                          },
                          child: Text(isUrdu ? 'سب منتخب / ختم کریں' : 'Toggle All',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: allPerms.entries.map((e) {
                          return CheckboxListTile(
                            dense: true,
                            title: Text(e.value, style: const TextStyle(fontSize: 13)),
                            value: role == 'admin'
                                ? true
                                : currentPerms.contains(e.key),
                            onChanged: role == 'admin'
                                ? null
                                : (bool? val) {
                                    setStateDialog(() {
                                      if (val == true) {
                                        currentPerms.add(e.key);
                                      } else {
                                        currentPerms.remove(e.key);
                                      }
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isUrdu ? 'متعلقہ کلاسز (Allowed Classes)' : 'Allowed Classes',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: primaryGreen)),
                        TextButton(
                          onPressed: () {
                            setStateDialog(() {
                              if (currentAllowedClasses.length == allSystemClasses.length) {
                                currentAllowedClasses.clear();
                              } else {
                                currentAllowedClasses = allSystemClasses
                                    .map((c) => c['id'])
                                    .where((id) => id != null)
                                    .toList();
                              }
                            });
                          },
                          child: Text(isUrdu ? 'سب منتخب / ختم کریں' : 'Toggle All',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: allSystemClasses.map((cls) {
                          final clsId = cls['id'];
                          final clsName = cls['name'] ?? '';
                          final isChecked = currentAllowedClasses.contains(clsId) || currentAllowedClasses.contains(clsId.toString());
                          return CheckboxListTile(
                            dense: true,
                            title: Text(clsName, style: const TextStyle(fontSize: 13)),
                            value: role == 'admin' ? true : isChecked,
                            onChanged: role == 'admin'
                                ? null
                                : (bool? val) {
                                    setStateDialog(() {
                                      if (val == true) {
                                        if (!currentAllowedClasses.contains(clsId)) {
                                          currentAllowedClasses.add(clsId);
                                        }
                                      } else {
                                        currentAllowedClasses.remove(clsId);
                                        currentAllowedClasses.remove(clsId.toString());
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
                onPressed: () => Navigator.pop(ctx),
                child: Text(isUrdu ? 'منسوخ کریں' : 'Cancel',
                    style: const TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      usernameController.text.isEmpty ||
                      (user == null && passwordController.text.isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUrdu
                            ? 'تمام خانے پر کریں'
                            : 'Fill all required fields')));
                    return;
                  }
                  Navigator.pop(ctx);
                  await saveUser(
                    id: user?['id']?.toString() ?? '',
                    name: nameController.text,
                    username: usernameController.text,
                    password: passwordController.text,
                    role: role,
                    permissions:
                        role == 'admin' ? allPerms.keys.toList() : currentPerms,
                    allowedClasses: role == 'admin'
                        ? allSystemClasses.map((c) => c['id']).toList()
                        : currentAllowedClasses,
                  );
                },
                child: Text(isUrdu ? 'محفوظ کریں' : 'Save',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> saveUser(
      {required String id,
      required String name,
      required String username,
      required String password,
      required String role,
      required List<String> permissions,
      required List<dynamic> allowedClasses}) async {
    setState(() => isLoading = true);
    try {
      final response = await NetworkService.postWithFallbackAction(
        'save_user',
        {
          'id': id,
          'name': name,
          'username': username,
          'password': password,
          'role': role,
          'permissions': permissions,
          'allowed_classes': allowedClasses,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Success')));
        }
        fetchUsers();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save user')));
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => isLoading = false);
      }
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
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (c) => DashboardPage()));
          },
          child: Directionality(
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(isUrdu ? 'یوزرز کا انتظام' : 'Manage Users',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: () {
                      setState(() => isLoading = true);
                      fetchUsers();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => openUserDialog(),
                  )
                ],
              ),
              drawer: const AppDrawer(),
              body: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryGreen))
                  : users.isEmpty
                      ? Center(
                          child: Text(
                              isUrdu ? "کوئی یوزر نہیں ملا" : "No users found"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final u = users[index];
                            return Card(
                              color: Colors.white,
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      primaryGreen.withOpacity(0.1),
                                  child:
                                      Icon(Icons.person, color: primaryGreen),
                                ),
                                title: Text(u['name'] ?? '',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryGreen)),
                                subtitle: Text(
                                    '@${u['username']} - Role: ${u['role']}',
                                    style: TextStyle(color: Colors.grey[700])),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () => openUserDialog(user: u),
                                    ),
                                    if (u['id'].toString() !=
                                        currentUserId.value?.toString())
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            deleteUser(u['id'].toString()),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        );
      },
    );
  }
}
