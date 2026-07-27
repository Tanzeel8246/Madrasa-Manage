// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/globals.dart';
import '../utils/network_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/neo_box.dart';
import 'dashboard.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    final oldPass = _oldPasswordController.text.trim();
    final pass = _passwordController.text.trim();
    if (oldPass.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUrduGlobal.value
                ? "براہ کرم موجودہ اور نیا پاسورڈ درج کریں"
                : "Please enter current and new password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await NetworkService.postWithFallbackAction(
        'change_password',
        {
          'old_password': oldPass,
          'new_password': pass,
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isUrduGlobal.value
                    ? "پاسورڈ کامیابی سے تبدیل ہو گیا!"
                    : "Password changed successfully!"),
                backgroundColor: Colors.green),
          );
          _oldPasswordController.clear();
          _passwordController.clear();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(data['message'] ?? 'Error changing password'),
                backgroundColor: Colors.red),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Server error"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Connection error: $e"), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: const Color(0xFFF1EFE7),
              drawer: const AppDrawer(),
              appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...'))
              );
              // Call your sync logic here
              // ApiSync.syncData(); 
            },
          )
        ],
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(isUrdu ? "پاسورڈ تبدیل کریں" : "Change Password",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF284D3D),
                centerTitle: true,
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: NeoBox(
                    padding: 25,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_reset,
                            size: 60, color: Color(0xFF284D3D)),
                        const SizedBox(height: 15),
                        Text(
                          isUrdu ? "نیا پاسورڈ درج کریں" : "Enter New Password",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _oldPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText:
                                isUrdu ? "موجودہ پاسورڈ" : "Current Password",
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: isUrdu ? "نیا پاسورڈ" : "New Password",
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF284D3D),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: _isLoading ? null : _changePassword,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  isUrdu ? "تبدیل کریں" : "Change Password",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                        ),
                      ],
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
}
