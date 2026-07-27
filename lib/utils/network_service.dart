// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'globals.dart';

class NetworkService {
  static List<String> baseUrls() {
    final Set<String> urls = {apiUrl.trim()};
    final Uri? parsed = Uri.tryParse(apiUrl.trim());

    if (parsed != null && parsed.host.isNotEmpty) {
      if (parsed.host.startsWith('www.')) {
        urls.add(parsed
            .replace(host: parsed.host.replaceFirst('www.', ''))
            .toString());
      } else {
        urls.add(parsed.replace(host: 'www.${parsed.host}').toString());
      }
    }

    return urls.toList();
  }

  static Map<String, String> authHeaders({bool json = false}) {
    final token = currentUserToken.value;
    if (apiSecretKey.isEmpty && (token == null || token.isEmpty)) {
      throw StateError('Login required.');
    }

    return {
      if (json) 'Content-Type': 'application/json',
      if (apiSecretKey.isNotEmpty) 'Authorization': 'Bearer $apiSecretKey',
      if (apiSecretKey.isNotEmpty) 'X-API-KEY': apiSecretKey,
      if (token?.isNotEmpty == true) 'X-USER-TOKEN': token!,
    };
  }

  static Map<String, String> publicHeaders({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (apiSecretKey.isNotEmpty) 'X-API-KEY': apiSecretKey,
    };
  }

  static Uri buildActionUri(String baseUrl, String action) {
    String fullUrl = baseUrl;
    if (!fullUrl.endsWith('/')) fullUrl += '/';
    if (!fullUrl.contains('api.php')) fullUrl += 'api.php';
    return Uri.parse('$fullUrl?action=$action');
  }

  static Uri buildPathUri(String baseUrl, String path) {
    String fullUrl = baseUrl;
    if (!fullUrl.endsWith('/')) fullUrl += '/';
    return Uri.parse('$fullUrl$path');
  }

  static Future<http.Response> getWithFallbackAction(String action) async {
    Object? lastError;
    for (final baseUrl in baseUrls()) {
      try {
        return await http
            .get(
              buildActionUri(baseUrl, action),
              headers: authHeaders(),
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('No working endpoint');
  }

  static Future<http.Response> publicGetWithFallbackAction(
      String action) async {
    Object? lastError;
    for (final baseUrl in baseUrls()) {
      try {
        return await http
            .get(
              buildActionUri(baseUrl, action),
              headers: publicHeaders(),
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('No working endpoint');
  }

  static Future<http.Response> postWithFallbackAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    Object? lastError;
    for (final baseUrl in baseUrls()) {
      try {
        return await http
            .post(
              buildActionUri(baseUrl, action),
              headers: authHeaders(json: true),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('No working endpoint');
  }

  static Future<http.Response> publicPostWithFallbackAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    Object? lastError;
    for (final baseUrl in baseUrls()) {
      try {
        return await http
            .post(
              buildActionUri(baseUrl, action),
              headers: publicHeaders(json: true),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('No working endpoint');
  }

  static Future<http.Response> postToPathWithFallback(
    String path,
    Map<String, dynamic> payload,
  ) async {
    Object? lastError;
    for (final baseUrl in baseUrls()) {
      try {
        return await http
            .post(
              buildPathUri(baseUrl, path),
              headers: authHeaders(json: true),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('No working endpoint');
  }
}
