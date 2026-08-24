// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/globals.dart';
import 'screens/home.dart';
import 'screens/dashboard.dart';
import 'utils/session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auto-login logic
  Widget initialScreen = const HomePage();
  final session = await SessionManager.getSession();
  if (session != null) {
    currentUserRole.value = session['role'];
    currentUserId.value = session['userId'];
    currentUserName.value = session['name'];
    currentUserToken.value = session['token']?.toString();
    if (session['permissions'] != null) {
      currentUserPermissions.value = List<String>.from(session['permissions']);
    }
    if (session['assignedClasses'] != null) {
      currentUserAssignedClasses.value =
          List<String>.from(session['assignedClasses']);
    }
    initialScreen = const DashboardPage();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isUrduGlobal,
      builder: (context, isUrdu, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Madrasa App',
          // 🌟 پوری ایپ کی ڈائریکشن (RTL/LTR) کنٹرول کرنے کے لیے
          builder: (context, child) {
            return Directionality(
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            );
          },
          theme: ThemeData(
            fontFamily: isUrdu
                ? 'JameelNooriNastaleeq'
                : GoogleFonts.poppins().fontFamily,
            textTheme: _buildTextTheme(isUrdu),
            primaryColor: const Color(0xFF284D3D), // Deep Green
            scaffoldBackgroundColor:
                const Color(0xFFF1EFE7), // Beige background
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF1EFE7),
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF284D3D)),
            ),
          ),
          home: initialScreen,
        );
      },
    );
  }

  TextTheme _buildTextTheme(bool isUrdu) {
    TextTheme baseTheme = ThemeData.light().textTheme;

    if (isUrdu) {
      const double urduHeight = 1.8;

      TextStyle? safeStyle(TextStyle? style) {
        if (style == null) return null;
        return style.copyWith(
          fontFamily: 'JameelNooriNastaleeq',
          height: urduHeight,
          fontSize: style.fontSize != null ? style.fontSize! * 1.3 : null,
        );
      }

      return baseTheme.copyWith(
        displayLarge: safeStyle(baseTheme.displayLarge),
        displayMedium: safeStyle(baseTheme.displayMedium),
        displaySmall: safeStyle(baseTheme.displaySmall),
        headlineLarge: safeStyle(baseTheme.headlineLarge),
        headlineMedium: safeStyle(baseTheme.headlineMedium),
        headlineSmall: safeStyle(baseTheme.headlineSmall),
        titleLarge: safeStyle(baseTheme.titleLarge),
        titleMedium: safeStyle(baseTheme.titleMedium),
        titleSmall: safeStyle(baseTheme.titleSmall),
        bodyLarge: safeStyle(baseTheme.bodyLarge),
        bodyMedium: safeStyle(baseTheme.bodyMedium),
        bodySmall: safeStyle(baseTheme.bodySmall),
        labelLarge: safeStyle(baseTheme.labelLarge),
        labelMedium: safeStyle(baseTheme.labelMedium),
        labelSmall: safeStyle(baseTheme.labelSmall),
      );
    }
    return GoogleFonts.poppinsTextTheme(baseTheme);
  }
}
