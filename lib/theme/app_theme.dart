import 'package:flutter/material.dart';

class CustomTheme {
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color buttonColor;
  final Color textColor;
  final Color invoiceHeaderColor;

  const CustomTheme({
    this.primaryColor = const Color(0xFF0818A8), // #0818A8 Deep Royal Blue
    this.secondaryColor = const Color(0xFFCCCCFF), // #CCCCFF Light Periwinkle
    this.backgroundColor = const Color(0xFFF8FAFC), // #F8FAFC Dashboard Bg
    this.buttonColor = const Color(0xFF0818A8), // #0818A8 Button Color
    this.textColor = const Color(0xFF1E293B), // #1E293B Dark Charcoal Text
    this.invoiceHeaderColor = const Color(0xFFFFFFFF), // #FFFFFF Card/Header
  });

  CustomTheme copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? buttonColor,
    Color? textColor,
    Color? invoiceHeaderColor,
  }) {
    return CustomTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      buttonColor: buttonColor ?? this.buttonColor,
      textColor: textColor ?? this.textColor,
      invoiceHeaderColor: invoiceHeaderColor ?? this.invoiceHeaderColor,
    );
  }
}

class AppColors {
  static CustomTheme currentTheme = const CustomTheme();

  // Dynamic colors mapped from current active theme
  static Color get primaryButton => currentTheme.buttonColor;
  static Color get primary => currentTheme.primaryColor;
  static Color get secondary => currentTheme.secondaryColor;
  static Color get accent => currentTheme.secondaryColor;

  static Color get sidebar => currentTheme.primaryColor;
  static Color get dashboardBg => currentTheme.backgroundColor;
  static Color get invoiceCard => currentTheme.invoiceHeaderColor;
  static Color get tableHeader => currentTheme.invoiceHeaderColor.computeLuminance() > 0.5
      ? const Color(0xFFF1F5F9)
      : currentTheme.invoiceHeaderColor.withValues(alpha: 0.15);

  // Status & Financial Amounts Colors
  static const Color paid = Color(0xFF16A34A); // #16A34A
  static const Color pending = Color(0xFFF59E0B); // #F59E0B
  static const Color dueOverdue = Color(0xFFDC2626); // #DC2626

  static const Color profitAmount = Color(0xFF16A34A); // Green
  static const Color expenseAmount = Color(0xFFDC2626); // Red
  static Color get salesAmount => currentTheme.primaryColor;

  // Supporting Neutrals & Accent Colors
  static Color get textPrimary => currentTheme.textColor;
  static Color get textSecondary => currentTheme.textColor.withValues(alpha: 0.7);
  static const Color border = Color(0xFFE2E8F0);
  static Color get sidebarText => Colors.white.withValues(alpha: 0.85);
  static const Color sidebarActiveText = Color(0xFFFFFFFF);
  static Color get sidebarActiveBg => currentTheme.secondaryColor.withValues(alpha: 0.25);
}

class AppTheme {
  static TextStyle timesFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: 'Times New Roman',
      fontFamilyFallback: const ['Tinos', 'Georgia', 'serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  static ThemeData get themeData => getThemeData(AppColors.currentTheme);

  static ThemeData getThemeData(CustomTheme theme) {
    AppColors.currentTheme = theme;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: theme.backgroundColor,
      primaryColor: theme.primaryColor,
      fontFamily: 'Times New Roman',
      fontFamilyFallback: const ['Tinos', 'Georgia', 'serif'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.primaryColor,
        primary: theme.primaryColor,
        secondary: theme.secondaryColor,
        surface: theme.backgroundColor,
        error: AppColors.dueOverdue,
      ),
      textTheme: TextTheme(
        displayLarge: timesFont(fontSize: 32, color: theme.textColor, fontWeight: FontWeight.bold),
        displayMedium: timesFont(fontSize: 28, color: theme.textColor, fontWeight: FontWeight.bold),
        titleLarge: timesFont(fontSize: 20, color: theme.textColor, fontWeight: FontWeight.bold),
        titleMedium: timesFont(fontSize: 16, color: theme.textColor, fontWeight: FontWeight.w600),
        bodyLarge: timesFont(fontSize: 15, color: theme.textColor),
        bodyMedium: timesFont(fontSize: 13, color: theme.textColor.withValues(alpha: 0.7)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.buttonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: timesFont(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.primaryColor,
          side: BorderSide(color: theme.primaryColor, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: timesFont(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: theme.invoiceHeaderColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.8),
        ),
        hintStyle: timesFont(
          color: theme.textColor.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        labelStyle: timesFont(
          color: theme.textColor,
          fontSize: 14,
        ),
      ),
    );
  }
}
