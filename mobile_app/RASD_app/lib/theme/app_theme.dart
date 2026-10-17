import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'glass_widgets.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',

      // Pages are see-through: the palm photo is drawn behind every page
      // by PalmPageTransitionsBuilder (see glass_widgets.dart).
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PalmPageTransitionsBuilder(),
          TargetPlatform.iOS: PalmPageTransitionsBuilder(),
          TargetPlatform.windows: PalmPageTransitionsBuilder(),
          TargetPlatform.macOS: PalmPageTransitionsBuilder(),
          TargetPlatform.linux: PalmPageTransitionsBuilder(),
        },
      ),

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.primary,
        centerTitle: false,
        elevation: 0,
      ),

      // Buttons: white glass with green text (more solid on hover/press).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: glassButtonStyle.merge(
          ElevatedButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: glassButtonStyle.merge(
          OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: glassButtonStyle.merge(
          TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // Filter chips (All / Healthy / ...): glass when not selected.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
      ),

      // Round icon buttons on top of the photo.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      // Any Card that was not changed to GlassCard still looks like glass.
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
        ),
      ),

      // Text fields: a little see-through.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.75),
        border: roundedBorder,
        enabledBorder: roundedBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFDCEDE0),

        labelBehavior:
        NavigationDestinationLabelBehavior.alwaysShow,

        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 28,
          );
        }),

        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight:
            selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.primary
                : AppColors.textSecondary,
          );
        }),
      ),
    );
  }
}
