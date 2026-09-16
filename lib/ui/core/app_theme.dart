import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const ink = Color(0xff373544);
  static const blue = Color(0xff398de4);
  static ThemeData light() => ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    primaryColor: blue,
    colorScheme: const ColorScheme.light(
      primary: blue,
      secondary: blue,
      onSurface: ink,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      shape: Border(bottom: BorderSide(color: Color(0xffeeeeef))),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, color: ink, height: 1.2),
      bodyMedium: TextStyle(fontSize: 14, color: ink),
      titleMedium: TextStyle(
        fontSize: 16,
        color: ink,
        fontWeight: FontWeight.w400,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? ink : Colors.transparent,
      ),
      side: const BorderSide(color: ink, width: 1.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
    ),
    dividerColor: const Color(0xffeeeeef),
    listTileTheme: const ListTileThemeData(
      iconColor: ink,
      textColor: ink,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xfffcfcfd),
      selectedItemColor: blue,
      unselectedItemColor: Color(0xffb8bcc8),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 10),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
  );
  static ThemeData dark() => light();
}
