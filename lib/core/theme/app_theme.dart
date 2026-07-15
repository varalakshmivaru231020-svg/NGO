import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _brand = Color(0xFFFF9933);
  static const _brandDark = Color(0xFFE07C1F);
  static const _secondary = Color(0xFF0052CC);
  static const _secondaryDark = Color(0xFF003D99);
  static const _violet = Color(0xFF7C6CF0);
  static const _amber = Color(0xFFF6A723);
  static const _coral = Color(0xFFF2685E);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
      primary: _brand,
      secondary: _secondary,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF1A2A24)),
      titleTextStyle: TextStyle(
        color: Color(0xFF1A2A24), fontSize: 17, fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4EAE8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE4EAE8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE4EAE8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand, width: 1.5)),
      labelStyle: const TextStyle(color: Color(0xFF5A7068)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _brand, foregroundColor: Colors.white, elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white, selectedItemColor: _brand, unselectedItemColor: Color(0xFF8BA49A),
    ),
    extensions: const [SakshamColors(
      brand: _brand, brandDark: _brandDark, secondary: _secondary, secondaryDark: _secondaryDark,
      violet: _violet, amber: _amber, coral: _coral,
      surface2: Color(0xFFF0F4F2), surface3: Color(0xFFE4EAE8),
      onSurface2: Color(0xFF5A7068), onSurface3: Color(0xFF8BA49A),
    )],
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    colorScheme: ColorScheme.fromSeed(seedColor: _brand, brightness: Brightness.dark, primary: Color(0xFFFFA94D), secondary: Color(0xFF5B9CF6)),
    scaffoldBackgroundColor: const Color(0xFF0D1A16),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D1A16), elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(
      color: const Color(0xFF142620), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1F3A30))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFF142620),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1F3A30))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1F3A30))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA94D), width: 1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFA94D), foregroundColor: Colors.white, elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    extensions: const [SakshamColors(
      brand: Color(0xFFFFA94D), brandDark: Color(0xFFFF9933), secondary: Color(0xFF5B9CF6), secondaryDark: Color(0xFF0052CC),
      violet: Color(0xFF9D91F5),
      amber: Color(0xFFF6B84A), coral: Color(0xFFF47D75),
      surface2: Color(0xFF142620), surface3: Color(0xFF1F3A30),
      onSurface2: Color(0xFF8DBFB0), onSurface3: Color(0xFF4A7A6A),
    )],
  );
}

// ── BuildContext helper — use in any build() to get theme-aware colors ──
extension SakshamThemeX on BuildContext {
  SakshamColors get _sc => Theme.of(this).extension<SakshamColors>()!;
  ThemeData get _t => Theme.of(this);
  bool get isDark => _t.brightness == Brightness.dark;

  Color get scaffoldBg  => _t.scaffoldBackgroundColor;
  Color get cardBg      => _t.cardTheme.color ?? Colors.white;
  Color get headerBg    => isDark ? const Color(0xFF0D1A16) : Colors.white;
  Color get border      => _sc.surface3;
  Color get surface2    => _sc.surface2;
  Color get textPrimary => _t.colorScheme.onSurface;
  Color get textSub     => _sc.onSurface2;
  Color get textHint    => _sc.onSurface3;
  Color get brand       => _sc.brand;
  Color get brandDark   => _sc.brandDark;
  Color get secondary     => _sc.secondary;
  Color get secondaryDark => _sc.secondaryDark;
}

@immutable
class SakshamColors extends ThemeExtension<SakshamColors> {
  const SakshamColors({
    required this.brand, required this.brandDark, required this.secondary, required this.secondaryDark,
    required this.violet, required this.amber, required this.coral, required this.surface2,
    required this.surface3, required this.onSurface2, required this.onSurface3,
  });
  final Color brand, brandDark, secondary, secondaryDark, violet, amber, coral, surface2, surface3, onSurface2, onSurface3;

  @override
  SakshamColors copyWith({Color? brand, Color? brandDark, Color? secondary, Color? secondaryDark, Color? violet, Color? amber, Color? coral, Color? surface2, Color? surface3, Color? onSurface2, Color? onSurface3}) {
    return SakshamColors(
      brand: brand ?? this.brand, brandDark: brandDark ?? this.brandDark,
      secondary: secondary ?? this.secondary, secondaryDark: secondaryDark ?? this.secondaryDark,
      violet: violet ?? this.violet,
      amber: amber ?? this.amber, coral: coral ?? this.coral, surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3, onSurface2: onSurface2 ?? this.onSurface2, onSurface3: onSurface3 ?? this.onSurface3,
    );
  }

  @override
  SakshamColors lerp(SakshamColors? other, double t) {
    if (other == null) return this;
    return SakshamColors(
      brand: Color.lerp(brand, other.brand, t)!, brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!, secondaryDark: Color.lerp(secondaryDark, other.secondaryDark, t)!,
      violet: Color.lerp(violet, other.violet, t)!, amber: Color.lerp(amber, other.amber, t)!,
      coral: Color.lerp(coral, other.coral, t)!, surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!, onSurface2: Color.lerp(onSurface2, other.onSurface2, t)!,
      onSurface3: Color.lerp(onSurface3, other.onSurface3, t)!,
    );
  }
}
