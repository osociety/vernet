import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/l10n/app_localizations_en.dart';
import 'package:vernet/providers/locale_provider.dart';

/// Strings for the layers that have no [BuildContext]: services, blocs,
/// notifications.
///
/// Widgets must keep using `context.l10n`, which rebuilds them when the
/// language changes. This reads the language as it is configured right now, so
/// text that is computed once and then cached — the Wi-Fi diagnostics, the
/// network score advice — only catches up on the next refresh.
AppLocalizations appStrings() => stringsForLocale(currentAppLocale());

/// Picks the bundle for [locale] by language code, so `de_AT` still gets
/// German, and falls back to English for anything the app does not ship.
AppLocalizations stringsForLocale(Locale locale) =>
    AppLocalizations.supportedLocales
            .any((supported) => supported.languageCode == locale.languageCode)
        ? lookupAppLocalizations(Locale(locale.languageCode))
        : AppLocalizationsEn();

/// The locale [MaterialApp] ends up rendering with: the saved choice, else the
/// first system language the app supports, else English.
Locale currentAppLocale() {
  final saved = LocaleProvider.active;
  if (saved != null) return saved;
  // The dispatcher, not the binding: a service can ask for strings before any
  // widget layer exists, and in a plain unit test where none ever will.
  for (final system in ui.PlatformDispatcher.instance.locales) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == system.languageCode) return supported;
    }
  }
  return const Locale('en');
}
