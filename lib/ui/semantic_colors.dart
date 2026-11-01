import 'package:flutter/material.dart';

/// Semantic color extension for consistent status indication across the app.
///
/// Color semantics:
/// - [success] (green): Everything is fine, good status, success
/// - [warning] (amber/orange): Caution, moderate issues, needs attention
/// - [critical] (red): Critical failure, security risk, fatal error
/// - [info] (blue): Neutral, informational, active state
extension SemanticColorScheme on ColorScheme {
  /// Green - success, good status, everything is fine
  Color get success => Colors.green;

  /// Amber/Orange - warning, caution, moderate issues
  Color get warning => Colors.amber;

  /// Red - critical failure, security risk, fatal error (alias for error)
  Color get critical => error;

  /// Blue - informational, neutral, active state (alias for primary)
  Color get info => primary;
}

/// Helper to create a theme with proper semantic colors.
ThemeData createSemanticTheme(bool isDark) {
  final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();

  return baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(
      // Only override error color for better visibility
      error: isDark
          ? const Color(0xFFFF6B6B) // Red for critical
          : const Color(0xFFD93025),
      // Keep default Material 3 primary (purple/indigo) - don't override
    ),
  );
}
