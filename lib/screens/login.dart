// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';

import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../utils/globals.dart';
import '../utils/network_service.dart';
import '../utils/session.dart';
import '../widgets/neo_box.dart';
import 'dashboard.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Color bgColor = const Color(0xFFF1EFE7);
  final Color primaryGreen = const Color(0xFF284D3D);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;
  String _errorMessage = '';

  Map<String, dynamic> _decodeResponseBody(String body) {
    final jsonStart = body.indexOf('{');
    final cleanBody = jsonStart >= 0 ? body.substring(jsonStart) : body;
    final decoded = jsonDecode(cleanBody);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  String _networkErrorText(Object? error) {
    if (error is FormatException) {
      return isUrduGlobal.value
          ? 'سرور کا جواب درست نہیں۔ براہ کرم انتظامیہ سے رابطہ کریں۔'
          : 'Server response is invalid. Please contact support.';
    }
    return isUrduGlobal.value
        ? 'سرور سے رابطہ نہیں ہو سکا۔ انٹرنیٹ یا API URL چیک کریں۔'
        : 'Could not reach the server. Check internet or API URL.';
  }

  String _invalidLoginText() {
    return isUrduGlobal.value
        ? 'غلط یوزر نیم یا پاس ورڈ۔'
        : 'Invalid username or password.';
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    String serverMessage = '';

    try {
      final res = await NetworkService.publicPostWithFallbackAction(
        'login_admin',
        {'username': username, 'password': password},
      );
      final body = _decodeResponseBody(res.body);

      if (res.statusCode == 200 && body['status'] == 'success') {
        final role = body['role']?.toString() ?? 'admin';
        currentUserRole.value = role;
        currentUserId.value = int.tryParse(body['admin_id']?.toString() ?? '1');
        currentUserName.value = username;
        currentUserToken.value = body['token']?.toString();
        final perms = body['permissions'] as List<dynamic>?;
        currentUserPermissions.value =
            perms?.map((e) => e.toString()).toList() ?? [];

        // Teacher/Nazim: classes table سے allowed classes load کریں (sync_down پہلے سے filter کر چکا ہے)
        List<String> assignedClasses = [];
        if (role != 'admin') {
          try {
            final classList = await DBHelper().getClasses();
            assignedClasses = classList
                .map((c) => c['name']?.toString() ?? '')
                .where((n) => n.isNotEmpty)
                .toList();
          } catch (_) {}
        }
        currentUserAssignedClasses.value = assignedClasses;

        await SessionManager.saveSession(
          currentUserRole.value!,
          currentUserId.value ?? 1,
          permissions: currentUserPermissions.value,
          token: currentUserToken.value,
          name: currentUserName.value,
          assignedClasses: assignedClasses,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
        return;
      }

      serverMessage = body['message']?.toString() ?? '';
    } catch (e) {
      serverMessage = _networkErrorText(e);
    }

    try {
      final studentRes = await NetworkService.publicPostWithFallbackAction(
        'login_student',
        {'username': username, 'password': password},
      );
      final body = _decodeResponseBody(studentRes.body);

      if (studentRes.statusCode == 200 && body['status'] == 'success') {
        currentUserRole.value = 'student';
        currentUserId.value =
            int.tryParse(body['student_id']?.toString() ?? '1');
        currentUserName.value = username;
        currentUserToken.value = body['token']?.toString();

        await SessionManager.saveSession(
          'student',
          currentUserId.value!,
          token: currentUserToken.value,
          name: currentUserName.value,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
        return;
      }

      // If student login fails, try parent login
      try {
        final parentRes = await NetworkService.publicPostWithFallbackAction(
          'login_parent',
          {'phone': username, 'password': password}, // Parents use phone as username
        );
        final parentBody = _decodeResponseBody(parentRes.body);

        if (parentRes.statusCode == 200 && parentBody['status'] == 'success') {
          currentUserRole.value = 'parent';
          currentUserId.value = int.tryParse(parentBody['parent_id']?.toString() ?? '1');
          currentUserName.value = username;
          currentUserToken.value = parentBody['token']?.toString();

          await SessionManager.saveSession(
            'parent',
            currentUserId.value!,
            token: currentUserToken.value,
            name: currentUserName.value,
          );

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
          return;
        }
      } catch (e) {
        // Ignore parent login network errors and just show the student error
      }

      serverMessage = body['message']?.toString() ?? serverMessage;
      if (!mounted) return;
      setState(() {
        _errorMessage =
            serverMessage.isNotEmpty ? serverMessage : _invalidLoginText();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            serverMessage.isNotEmpty ? serverMessage : _networkErrorText(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    await showDialog(
      context: context,
      builder: (context) {
        final isUrdu = isUrduGlobal.value;
        return AlertDialog(
          title: Text(
            isUrdu ? 'پاس ورڈ ری سیٹ' : 'Reset Password',
            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isUrdu
                ? 'سیکیورٹی کی وجہ سے پاس ورڈ ری سیٹ صرف مدرسہ آفس یا ایڈمن کی منظوری سے ہو گا۔'
                : 'For security, password reset requires madrasa office or admin approval.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              onPressed: () => Navigator.pop(context),
              child: Text(
                isUrdu ? 'ٹھیک ہے' : 'OK',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
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
            backgroundColor: bgColor,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: NeoBox(
                  padding: 30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_person, size: 60, color: primaryGreen),
                      const SizedBox(height: 15),
                      Text(
                        isUrdu
                            ? 'مدرسہ اشرف المدارس'
                            : 'Madrasa Ashraf-ul-Madaris',
                        style: TextStyle(
                          fontSize: 22,
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isUrdu
                            ? 'اپنے اکاؤنٹ میں داخل ہوں'
                            : 'Login to your account',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 25),
                      if (_errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: isUrdu
                              ? 'یوزر نیم / داخلہ نمبر'
                              : 'Username / admission no',
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordController,
                        obscureText: _isObscure,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'پاس ورڈ' : 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isObscure = !_isObscure;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      Align(
                        alignment: isUrdu
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: Text(
                            isUrdu ? 'پاس ورڈ بھول گئے؟' : 'Forgot Password?',
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  isUrdu ? 'لاگ ان کریں' : 'Login',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomePage(),
                            ),
                          );
                        },
                        child: Text(
                          isUrdu ? 'ہوم پر واپس جائیں' : 'Back to Home',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
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
