import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const seed = Color(0xFF4F46E5);
  static const green = Color(0xFF059669);
  static const red = Color(0xFFE11D48);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor:
          b == Brightness.light ? const Color(0xFFF5F6FA) : const Color(0xFF0E1013),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }
}
