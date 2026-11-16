import 'package:vernet/l10n/app_localizations.dart';

/// The dimension names the score service stores are data: they key the persisted
/// JSON and the switch that picks an icon. So the English token stays in the
/// model and only what the reader sees goes through these helpers.
String scoreDimensionName(AppLocalizations l10n, String name) => switch (name) {
      'Security' => l10n.scoreDimSecurity,
      'Health' => l10n.scoreDimHealth,
      'Reliability' => l10n.scoreDimReliability,
      'Speed' => l10n.scoreDimSpeed,
      'Vulnerabilities' => l10n.scoreDimVulnerabilities,
      _ => name,
    };

/// The card has no room for a whole dimension name, so each one is abbreviated.
/// The abbreviations are separate strings because a three-letter clipping of the
/// translated word is not a useful label (`Zuverlässigkeit` would read `ZU…`).
String scoreDimensionChip(AppLocalizations l10n, String name) => switch (name) {
      'Security' => l10n.scoreChipSecurity,
      'Health' => l10n.scoreChipHealth,
      'Reliability' => l10n.scoreChipReliability,
      'Speed' => l10n.scoreChipSpeed,
      'Vulnerabilities' => l10n.scoreChipVulnerabilities,
      _ => name.substring(0, name.length.clamp(0, 3)).toUpperCase(),
    };
