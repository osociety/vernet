import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/adaptive_radio.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/store_links.dart';

/// How a release actually arrives on this platform, and what switching to the
/// beta track means there.
class UpdateGuidance {
  const UpdateGuidance({
    required this.hasBeta,
    required this.autoUpdate,
    required this.betaHowTo,
    this.betaLinkLabel,
    this.betaLinkUrl,
    this.copyCommand,
  });

  /// Whether this platform has a beta channel at all.
  final bool hasBeta;

  /// What keeps the app current without the user asking each time.
  final String autoUpdate;

  /// The one step that moves this install onto beta.
  final String betaHowTo;

  /// Both are resolved through the language the page renders in, which is why
  /// [guidanceFor] takes the bundle instead of holding const prose.
  final String? betaLinkLabel;
  final String? betaLinkUrl;

  /// A command the user has to run themselves, because no app can run it.
  final String? copyCommand;
}

/// Updates, auto-updating and beta testing, reached from Settings.
///
/// The channel switch below only changes which GitHub release Vernet compares
/// itself against. Which build the store hands out is decided outside the app
/// — by the Play beta opt-in, by the snap channel, or by the Store app's own
/// update setting — so the page says so instead of implying it controls them.
class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});

  /// Only Android and Linux have a beta track today: Play has the test track
  /// and snap has the beta channel. Elsewhere a beta means downloading a
  /// GitHub pre-release by hand, which is not something to promise a switch
  /// for.
  @visibleForTesting
  static UpdateGuidance guidanceFor({
    required String os,
    required bool isStoreBuild,
    required AppLocalizations l10n,
  }) {
    switch (os) {
      case 'android':
        return isStoreBuild
            ? UpdateGuidance(
                hasBeta: true,
                autoUpdate: l10n.updatesPlayAuto,
                betaHowTo: l10n.updatesPlayBetaHow,
                betaLinkLabel: l10n.updatesPlayBetaLink,
                betaLinkUrl: playBetaOptInUrl,
              )
            : UpdateGuidance(
                hasBeta: true,
                autoUpdate: l10n.updatesFdroidAuto,
                betaHowTo: l10n.updatesFdroidBetaHow,
                betaLinkLabel: l10n.updatesFdroidBetaLink,
                betaLinkUrl: githubReleasesUrl,
              );
      case 'linux':
        return UpdateGuidance(
          hasBeta: true,
          autoUpdate: l10n.updatesSnapAuto,
          betaHowTo: l10n.updatesSnapBetaHow,
          betaLinkLabel: l10n.updatesSnapLink,
          betaLinkUrl: snapStoreListingUrl,
          copyCommand: 'sudo snap refresh vernet --channel=beta',
        );
      case 'windows':
        return UpdateGuidance(
          hasBeta: false,
          autoUpdate: l10n.updatesMicrosoftAuto,
          betaHowTo: l10n.updatesMicrosoftBetaHow,
          betaLinkLabel: l10n.updatesPreReleaseLink,
          betaLinkUrl: githubReleasesUrl,
        );
      default:
        return UpdateGuidance(
          hasBeta: false,
          autoUpdate: l10n.updatesNoStoreAuto,
          betaHowTo: l10n.updatesNoBetaHow,
          betaLinkLabel: l10n.updatesReleasesLink,
          betaLinkUrl: githubReleasesUrl,
        );
    }
  }

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  bool _beta = false;
  String? _installedVersion;

  @override
  void initState() {
    super.initState();
    _beta = appSettings.betaUpdates;
    _loadInstalledVersion();
  }

  Future<void> _loadInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _installedVersion = '${info.version}+${info.buildNumber}');
    } catch (packageInfoFailure) {
      // A plugin that answers nothing leaves the plain name on the card; the
      // channel and the check below still work.
      debugPrint('installed version unavailable: $packageInfoFailure');
    }
  }

  Future<void> _select({required bool beta}) async {
    await appSettings.setBetaUpdates(beta);
    if (!mounted) return;
    setState(() => _beta = beta);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final guidance = UpdatesPage.guidanceFor(
      os: Platform.operatingSystem,
      isStoreBuild: kStoreBuild,
      l10n: l10n,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.updatesTitle)),
      body: SafeArea(
          child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _versionCard(context),
              if (guidance.hasBeta) ...[
                const SizedBox(height: 16),
                Text(l10n.updatesReleaseChannel,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                _channelCard(context),
              ],
              const SizedBox(height: 16),
              Text(l10n.updatesHowArrive,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              _guidanceCard(context, guidance),
              if (guidance.hasBeta) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.updatesBetaDisclaimer,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      )),
    );
  }

  Widget _versionCard(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _installedVersion == null
                  ? 'Vernet'
                  : 'Vernet $_installedVersion',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _beta ? l10n.updatesCheckingBeta : l10n.updatesCheckingStable,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: WidgetKey.checkForUpdatesButton.key,
              onPressed: () => checkForUpdates(context, showIfNoUpdate: true),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.updatesCheckButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelCard(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Column(
        children: [
          AdaptiveListTile(
            key: WidgetKey.updateStableTile.key,
            title: Text(l10n.updatesChannelStable),
            subtitle: Text(l10n.updatesChannelStableDesc),
            trailing: AdaptiveRadioButton<bool>(
              value: false,
              groupValue: _beta,
              onChanged: (value) {
                if (value != null) _select(beta: value);
              },
            ),
            onTap: () => _select(beta: false),
          ),
          AdaptiveListTile(
            key: WidgetKey.updateBetaTile.key,
            title: Text(l10n.updatesChannelBeta),
            subtitle: Text(l10n.updatesChannelBetaDesc),
            trailing: AdaptiveRadioButton<bool>(
              value: true,
              groupValue: _beta,
              onChanged: (value) {
                if (value != null) _select(beta: value);
              },
            ),
            onTap: () => _select(beta: true),
          ),
        ],
      ),
    );
  }

  Widget _guidanceCard(BuildContext context, UpdateGuidance guidance) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updatesAutomaticHeading,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(guidance.autoUpdate),
            const SizedBox(height: 12),
            Text(l10n.updatesBetaTestingHeading,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(guidance.betaHowTo),
            if (guidance.copyCommand != null) ...[
              const SizedBox(height: 8),
              _commandRow(context, guidance.copyCommand!),
            ],
            if (guidance.betaLinkUrl != null) ...[
              const SizedBox(height: 4),
              AdaptiveListTile(
                key: WidgetKey.updateBetaOptInTile.key,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.open_in_new),
                title: Text(guidance.betaLinkLabel!),
                onTap: () =>
                    launchURLWithWarning(context, guidance.betaLinkUrl!),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.updatesCannotChangeNote,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commandRow(BuildContext context, String command) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              command,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        IconButton(
          key: WidgetKey.updateCopyCommandButton.key,
          tooltip: l10n.updatesCopyTooltip,
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: command));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.updatesCommandCopied)),
            );
          },
        ),
      ],
    );
  }
}
