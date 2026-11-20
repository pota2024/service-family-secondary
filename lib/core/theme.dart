import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// هوية بصرية مستخرجة من التصميم المرجعي: أزرق ملكي، سماوي، أبيض، لمسات ذهبية.
class AppColors {
  static const royal = Color(0xFF1746C8);
  static const royalDark = Color(0xFF0A2A8F);
  static const navy = Color(0xFF0A1F5C);
  static const sky = Color(0xFF4DB6FF);
  static const paleSky = Color(0xFFEAF2FF);
  static const gold = Color(0xFFF5B82E);
  static const goldDark = Color(0xFFD99A0B);
  static const ink = Color(0xFF14284B);
  static const success = Color(0xFF22A06B);
  static const danger = Color(0xFFD64545);

  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [royalDark, royal, sky],
  );
  static const buttonGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [royal, royalDark],
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.royal,
    brightness: brightness,
    primary: dark ? AppColors.sky : AppColors.royal,
    secondary: AppColors.gold,
  );
  final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);
  final text = GoogleFonts.cairoTextTheme(base.textTheme).apply(
    bodyColor: dark ? Colors.white : AppColors.ink,
    displayColor: dark ? Colors.white : AppColors.ink,
  );
  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: dark ? const Color(0xFF0B1226) : AppColors.paleSky,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      titleTextStyle: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF16213F) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFD8E3FA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.royal, width: 1.6),
      ),
    ),
  );
}
