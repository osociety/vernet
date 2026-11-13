import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vernet/api/update_checker.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/adaptive_radio.dart';
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
  }) {
    switch (os) {
      case 'android':
        return isStoreBuild
            ? const UpdateGuidance(
                hasBeta: true,
                autoUpdate: 'Play updates Vernet by itself while "Update apps '
                    'automatically" is on in the Play app.',
                betaHowTo: 'Beta builds go to a Play test track first. Joining '
                    'it switches this install over and you keep updating '
                    'through Play.',
                betaLinkLabel: 'Join the beta on Google Play',
                betaLinkUrl: playBetaOptInUrl,
              )
            : const UpdateGuidance(
                hasBeta: true,
                autoUpdate: 'F-Droid refreshes its index and updates Vernet '
                    'with it unless automatic updates are turned off.',
                betaHowTo: 'F-Droid only publishes stable. Pre-release APKs '
                    'are on GitHub and are built to install beside this one.',
                betaLinkLabel: 'Pre-release APKs on GitHub',
                betaLinkUrl: githubReleasesUrl,
              );
      case 'linux':
        return const UpdateGuidance(
          hasBeta: true,
          autoUpdate: 'snapd refreshes a snap on its own, a couple of times a '
              'day, from whichever channel it was installed from.',
          betaHowTo: 'The channel belongs to snapd, not to Vernet, so this '
              'command has to be run once yourself.',
          betaLinkLabel: 'Vernet in the Snap Store',
          betaLinkUrl: snapStoreListingUrl,
          copyCommand: 'sudo snap refresh vernet --channel=beta',
        );
      case 'windows':
        return const UpdateGuidance(
          hasBeta: false,
          autoUpdate: 'The Microsoft Store updates Vernet by itself unless '
              'automatic app updates are off in the Store app.',
          betaHowTo: 'There is no beta track for Windows. The only way to run '
              'a build early is the GitHub pre-release zip or .msixbundle.',
          betaLinkLabel: 'Pre-release builds on GitHub',
          betaLinkUrl: githubReleasesUrl,
        );
      default:
        return const UpdateGuidance(
          hasBeta: false,
          autoUpdate: 'This platform has no store build, so nothing updates '
              'Vernet for you.',
          betaHowTo: 'There is no beta channel here. A pre-release has to be '
              'downloaded and installed by hand.',
          betaLinkLabel: 'Releases on GitHub',
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
    final guidance = UpdatesPage.guidanceFor(
      os: Platform.operatingSystem,
      isStoreBuild: kStoreBuild,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Updates & beta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _versionCard(context),
              if (guidance.hasBeta) ...[
                const SizedBox(height: 16),
                Text('Release channel',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                _channelCard(context),
              ],
              const SizedBox(height: 16),
              Text('How updates reach you',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              _guidanceCard(context, guidance),
              if (guidance.hasBeta) ...[
                const SizedBox(height: 12),
                Text(
                  'Choosing beta makes Vernet report a pre-release as an '
                  'update. Beta builds are tested on real networks by '
                  'volunteers, so a scan can break until it is reported and '
                  'fixed.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _versionCard(BuildContext context) {
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
              'Checking the ${_beta ? 'beta' : 'stable'} releases.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: WidgetKey.checkForUpdatesButton.key,
              onPressed: () => checkForUpdates(context, showIfNoUpdate: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Check for updates'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          AdaptiveListTile(
            key: WidgetKey.updateStableTile.key,
            title: const Text('Stable'),
            subtitle: const Text('Only versions that were promoted by hand'),
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
            title: const Text('Beta'),
            subtitle: const Text('Include the newest pre-release'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Automatic updates',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(guidance.autoUpdate),
            const SizedBox(height: 12),
            Text('Beta testing', style: Theme.of(context).textTheme.titleSmall),
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
              'Vernet cannot change any of that from inside the app.',
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
          tooltip: 'Copy',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: command));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Command copied')),
            );
          },
        ),
      ],
    );
  }
}
