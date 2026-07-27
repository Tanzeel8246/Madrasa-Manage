// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'network_service.dart';

class AIService {
  static Future<String> generateInsight(String prompt) async {
    try {
      final response = await NetworkService.postWithFallbackAction(
        'get_ai_insight',
        {'prompt': prompt},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'success') {
          return (data['insight'] ?? '').toString().trim();
        }
      }
    } catch (e) {
      debugPrint('AI action fallback failed: $e');
    }

    try {
      final response = await NetworkService.postToPathWithFallback(
        'ai_api.php',
        {'prompt': prompt},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'success') {
          return (data['insight'] ?? '').toString().trim();
        }
      }
    } catch (e) {
      debugPrint('AI path fallback failed: $e');
    }

    throw Exception('AI service unavailable');
  }
}
