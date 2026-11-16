import 'package:flutter/widgets.dart';
import 'package:vernet/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Names each language calls itself, keyed by the BCP 47 tag gen-l10n emits for
/// the ARB file. Endonyms stay untranslated so a user who has the wrong language
/// active can still find their own.
const Map<String, String> kLanguageNames = {'en': 'English', 'de': 'Deutsch'};

String languageName(Locale locale) =>
    kLanguageNames[locale.toLanguageTag()] ?? locale.toLanguageTag();
