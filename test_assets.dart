import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final assetKeys = manifestMap.keys.toList();
    print('Available assets:');
    for (var key in assetKeys) {
      if (key.contains('Roboto')) {
        print(' - $key');
      }
    }
  } catch (e) {
    print('Error loading manifest: $e');
  }
}
