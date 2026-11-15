import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/pages/onboarding/walkthrough_page.dart';
import 'package:vernet/providers/locale_provider.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/adaptive_radio.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

/// First screen of a fresh install, and the step the walkthrough can return to.
///
/// Nothing has to be picked here: the page opens on the system default, so
/// Continue works as a skip and Vernet keeps following the operating system.
/// It renders in that resolved language already — a user who does not read the
/// current text still sees their own language named in its own spelling.
/// Tapping an option previews the whole page in that language; nothing is
/// written until Continue.
class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key, this.selected});

  /// Language to open on. Null is the system default; the walkthrough passes the
  /// applied locale so coming back shows the current choice, not a reset one.
  final Locale? selected;

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  static const double _contentMaxWidth = 480;

  /// Null means follow the system language.
  late Locale? _selected = widget.selected;

  Future<void> _continue() async {
    final picked = _selected;
    final localeProvider = context.read<LocaleProvider>();
    if (localeProvider.locale != picked) {
      // Assigning persists the tag and rebuilds the app in the new locale, so
      // the page the user is leaving is already translated when they arrive back.
      localeProvider.locale = picked;
    }
    await OnboardingService.instance.setLanguageDone();
    if (!mounted) return;
    final showWalkthrough =
        !await OnboardingService.instance.isWalkthroughDone();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => showWalkthrough
            ? WalkthroughPage(
                backBuilder: (_) => LanguagePage(selected: picked))
            : const TabBarPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      // Previewing the pending pick: a null selection inherits the locale the
      // app already resolved, which is what the system default means.
      locale: _selected,
      child: Builder(builder: _scaffold),
    );
  }

  Widget _scaffold(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                Icon(
                  Icons.translate,
                  size: 48,
                  color: colors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.languagePageTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.languagePageDesc,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      _option(
                        key: WidgetKey.languageSystemOption.key,
                        label: l10n.languageSystemDefault,
                        value: null,
                      ),
                      ...AppLocalizations.supportedLocales.map(
                        (locale) => _option(
                          key: null,
                          label: languageName(locale),
                          value: locale,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: WidgetKey.languageContinueButton.key,
                  onPressed: _continue,
                  child: Text(l10n.languageContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option({
    required Key? key,
    required String label,
    required Locale? value,
  }) {
    return AdaptiveListTile(
      key: key,
      title: Text(label),
      leading: AdaptiveRadioButton<Locale?>(
        value: value,
        groupValue: _selected,
        onChanged: (picked) => setState(() => _selected = picked),
      ),
      onTap: () => setState(() => _selected = value),
    );
  }
}
