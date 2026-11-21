import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/shell_chrome.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/build_flavor.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/store_links.dart';

/// The store on this platform where a rating actually reaches other users.
enum RatingStore { play, microsoft, none }

/// Channels that fund Vernet's development, mirroring the repository's
/// README and `.github/FUNDING.yml`.
class DonatePage extends StatelessWidget {
  const DonatePage({super.key});

  static const String liberapayUrl = 'https://liberapay.com/OpenSociety/donate';
  static const String koFiUrl = 'https://ko-fi.com/fs0c13ty';
  static const String repositoryUrl = githubRepositoryUrl;
  static const String playStoreUrl = playStoreListingUrl;
  static const String microsoftStoreUrl = microsoftStoreListingUrl;

  /// The Android build carries ads, so it cannot claim an ad-free app.
  @visibleForTesting
  static String introFor(
          {required bool hasAds, required AppLocalizations l10n}) =>
      hasAds ? l10n.donateIntroAds : l10n.donateIntroNoAds;

  /// A rating ask only works where the platform's listing takes reviews and is
  /// where the user actually installed from.
  ///
  /// The Snap Store has no reviews, there is no Mac App Store build, and an
  /// F-Droid install is not on Play, so those platforms keep the three rows
  /// everyone can act on instead of a link to a store the user is not in.
  @visibleForTesting
  static RatingStore ratingStoreFor({
    required String os,
    required bool isStoreBuild,
  }) {
    if (os == 'android') {
      return isStoreBuild ? RatingStore.play : RatingStore.none;
    }
    if (os == 'windows') return RatingStore.microsoft;
    return RatingStore.none;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final rating = ratingStoreFor(
      os: Platform.operatingSystem,
      isStoreBuild: kStoreBuild,
    );
    return Scaffold(
      appBar: ShellChrome.providesAppBar(context)
          ? null
          : AppBar(title: Text(l10n.navSupport)),
      body: SafeArea(
          child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                introFor(hasAds: Platform.isAndroid, l10n: l10n),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _channel(
                context,
                tileKey: WidgetKey.donateLiberapayTile.key,
                icon: Icons.volunteer_activism,
                title: l10n.donateLiberapayTitle,
                subtitle: l10n.donateLiberapayDesc,
                url: liberapayUrl,
              ),
              _channel(
                context,
                tileKey: WidgetKey.donateKofiTile.key,
                icon: Icons.local_cafe,
                title: l10n.donateKofiTitle,
                subtitle: l10n.donateKofiDesc,
                url: koFiUrl,
              ),
              _channel(
                context,
                tileKey: WidgetKey.donateRepositoryTile.key,
                icon: Icons.star,
                title: l10n.donateStarTitle,
                subtitle: l10n.donateStarDesc,
                url: repositoryUrl,
              ),
              if (rating == RatingStore.play)
                _channel(
                  context,
                  tileKey: WidgetKey.donatePlayStoreTile.key,
                  icon: Icons.thumb_up,
                  title: l10n.donateRatePlayTitle,
                  subtitle: l10n.donateRatePlayDesc,
                  url: playStoreUrl,
                ),
              if (rating == RatingStore.microsoft)
                _channel(
                  context,
                  tileKey: WidgetKey.donateMicrosoftStoreTile.key,
                  icon: Icons.thumb_up,
                  title: l10n.donateRateStoreTitle,
                  subtitle: l10n.donateRateStoreDesc,
                  url: microsoftStoreUrl,
                ),
              const SizedBox(height: 8),
              Text(
                l10n.donateCommunityNote,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _channel(
    BuildContext context, {
    required Key tileKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: AdaptiveListTile(
        key: tileKey,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.open_in_new,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () => launchURLWithWarning(context, url),
      ),
    );
  }
}
