import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF6F3EA);
  static const surface = Color(0xFFFFFDF7);
  static const evergreen = Color(0xFF0B5D45);
  static const forest = Color(0xFF063D31);
  static const mint = Color(0xFFDDEFE5);
  static const coral = Color(0xFFF2B49C);
  static const ink = Color(0xFF183A31);
  static const muted = Color(0xFF64766F);
  static const border = Color(0xFFD8DED8);
  static const danger = Color(0xFFB4433B);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppTheme {
  static ThemeData get dark {
    final source = light;
    const scheme = ColorScheme.dark(
      primary: Color(0xFF79C9A3),
      onPrimary: Color(0xFF092D20),
      secondary: AppColors.coral,
      onSecondary: AppColors.forest,
      surface: Color(0xFF121D14),
      onSurface: Color(0xFFF2F5F0),
      onSurfaceVariant: Color(0xFF9BA89E),
      outline: Color(0xFF29382D),
      error: Color(0xFFFFA69E),
    );
    final darkBase = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'InstrumentSans',
    );
    return source.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF09120C),
      textTheme: source.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      appBarTheme: source.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF09120C),
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: source.cardTheme.copyWith(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      inputDecorationTheme: darkBase.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: source.inputDecorationTheme.contentPadding,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: source.filledButtonTheme.style?.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.outline
                : scheme.primary,
          ),
          foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: source.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.primary)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      navigationBarTheme: source.navigationBarTheme.copyWith(
        backgroundColor: scheme.surface,
        indicatorColor: const Color(0xFF244A36),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),
      dividerTheme: DividerThemeData(color: scheme.outline),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface),
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.evergreen,
      onPrimary: Colors.white,
      secondary: AppColors.coral,
      onSecondary: AppColors.forest,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      error: AppColors.danger,
      outline: AppColors.border,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      visualDensity: VisualDensity.standard,
      fontFamily: 'InstrumentSans',
    );

    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AccessiblePageTransition(
            ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.iOS: _AccessiblePageTransition(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.macOS: _AccessiblePageTransition(
            CupertinoPageTransitionsBuilder(),
          ),
        },
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 38,
          height: 1.05,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        headlineLarge: const TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 32,
          height: 1.08,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 26,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: AppColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AppColors.ink,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: AppColors.muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.evergreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.evergreen,
          side: const BorderSide(color: AppColors.evergreen),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.evergreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.mint,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        height: 72,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.forest,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}

class _AccessiblePageTransition extends PageTransitionsBuilder {
  const _AccessiblePageTransition(this.delegate);
  final PageTransitionsBuilder delegate;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return delegate.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
