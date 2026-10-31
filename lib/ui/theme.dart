import 'package:flutter/material.dart';

/// Farben im Papiertiger-Look.
class PT {
  static const orange = Color(0xFFF28C28);
  static const orangeDunkel = Color(0xFFC9650F);
  static const orangeHell = Color(0xFFFFE6CC);
  static const tinte = Color(0xFF231B16);
  static const grau = Color(0xFF6E625A);
  static const creme = Color(0xFFFFF8F0);
  static const sand = Color(0xFFF1E3D3);
  static const gruen = Color(0xFF2E8B57);
  static const gruenHell = Color(0xFFE1F3E8);
  static const rot = Color(0xFFC93C3C);
  static const rotHell = Color(0xFFFBE4E4);
  static const gelb = Color(0xFFB7791F);
  static const gelbHell = Color(0xFFFDF1D8);
}

ThemeData papiertigerTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PT.orange,
    primary: PT.orangeDunkel,
    onPrimary: Colors.white,
    surface: Colors.white,
  );
  final rund = BorderRadius.circular(14);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PT.creme,
    appBarTheme: const AppBarTheme(
      backgroundColor: PT.creme,
      foregroundColor: PT.tinte,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: PT.tinte,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: rund),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        foregroundColor: PT.tinte,
        side: const BorderSide(color: PT.sand, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: rund),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: PT.orangeHell,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dividerColor: PT.sand,
  );
}
