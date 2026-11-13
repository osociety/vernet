import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
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
  static String introFor({required bool hasAds}) => hasAds
      ? 'Vernet is free and open source under Apache-2.0, with no paid '
          'features. Donations pay for the devices, testing and development '
          'time behind every release.'
      : 'Vernet is free and open source under Apache-2.0, with no ads and no '
          'paid features. Donations pay for the devices, testing and '
          'development time behind every release.';

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
    final rating = ratingStoreFor(
      os: Platform.operatingSystem,
      isStoreBuild: kStoreBuild,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Support Vernet')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                introFor(hasAds: Platform.isAndroid),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _channel(
                context,
                tileKey: WidgetKey.donateLiberapayTile.key,
                icon: Icons.volunteer_activism,
                title: 'Donate on Liberapay',
                subtitle: 'Recurring or one-time, by card, SEPA or PayPal',
                url: liberapayUrl,
              ),
              _channel(
                context,
                tileKey: WidgetKey.donateKofiTile.key,
                icon: Icons.local_cafe,
                title: 'Buy me a coffee on Ko-fi',
                subtitle: 'One-time payment, no account needed',
                url: koFiUrl,
              ),
              _channel(
                context,
                tileKey: WidgetKey.donateRepositoryTile.key,
                icon: Icons.star,
                title: 'Star Vernet on GitHub',
                subtitle: 'Costs nothing, and it helps others find the app',
                url: repositoryUrl,
              ),
              if (rating == RatingStore.play)
                _channel(
                  context,
                  tileKey: WidgetKey.donatePlayStoreTile.key,
                  icon: Icons.thumb_up,
                  title: 'Rate Vernet on Google Play',
                  subtitle: 'Ratings are how a free app gets discovered',
                  url: playStoreUrl,
                ),
              if (rating == RatingStore.microsoft)
                _channel(
                  context,
                  tileKey: WidgetKey.donateMicrosoftStoreTile.key,
                  icon: Icons.thumb_up,
                  title: 'Review Vernet on the Microsoft Store',
                  subtitle: 'Reviews are how a Store app gets found',
                  url: microsoftStoreUrl,
                ),
              const SizedBox(height: 8),
              Text(
                'Reporting bugs and answering discussions are support too — '
                'the app is maintained by one person who reads them.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
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
