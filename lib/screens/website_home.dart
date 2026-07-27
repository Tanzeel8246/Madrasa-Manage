// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/globals.dart';
import 'dashboard.dart';

class WebsiteHomePage extends StatefulWidget {
  const WebsiteHomePage({super.key});

  @override
  State<WebsiteHomePage> createState() => _WebsiteHomePageState();
}

class _WebsiteHomePageState extends State<WebsiteHomePage> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://madrasa.mamfss.com/index.php'));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (await controller.canGoBack()) {
              await controller.goBack();
            } else {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (c) => const DashboardPage()),
                );
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF284D3D),
              foregroundColor: Colors.white,
              title: Text(
                isUrdu ? "ویب سائٹ ہوم" : "Website Home",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (await controller.canGoBack()) {
                    await controller.goBack();
                  } else {
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (c) => const DashboardPage()),
                      );
                    }
                  }
                },
              ),
            ),
            body: Stack(
              children: [
                WebViewWidget(controller: controller),
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF284D3D),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
