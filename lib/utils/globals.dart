// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';

// پوری ایپ میں زبان کنٹرول کرنے والا ویری ایبل
ValueNotifier<bool> isUrduGlobal = ValueNotifier(true);

// یوزر لاگ ان سٹیٹ
ValueNotifier<String?> currentUserRole =
    ValueNotifier(null); // 'admin', 'nazim', 'teacher', 'student' or 'parent'
ValueNotifier<int?> currentUserId = ValueNotifier(null);
ValueNotifier<String?> currentUserName = ValueNotifier(null);
ValueNotifier<List<String>> currentUserPermissions = ValueNotifier([]);
ValueNotifier<String?> currentUserToken = ValueNotifier(null);
// Teacher کی allowed class names (UI filtering کے لیے) — admin/nazim کے لیے خالی رہتا ہے
ValueNotifier<List<String>> currentUserAssignedClasses = ValueNotifier([]);

// Configure these with --dart-define for release builds.
const String apiUrl = String.fromEnvironment(
  'MADRASA_API_URL',
  defaultValue: 'https://madrasa.mindcraftsai.com/',
);
const String apiSecretKey = String.fromEnvironment('MADRASA_API_SECRET',
    defaultValue: 'u349923428_madrasau349923428_madrasa');
