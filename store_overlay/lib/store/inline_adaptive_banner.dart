// The store_overlay copy of this file carries the AdMob implementation; the
// committed version under lib/store/ collapses to nothing. See
// store_overlay/README.md for why the two exist.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:vernet/store/store_ad_slot.dart';

/// Google Play ad unit ids for Vernet, created in the AdMob account that
/// publishes `org.fsociety.vernet.store`.
const Map<StoreAdSlot, String> _adUnitIds = {
  StoreAdSlot.hostScan: 'ca-app-pub-9074226798924140/5975608682',
  StoreAdSlot.dns: 'ca-app-pub-9074226798924140/5288289535',
  StoreAdSlot.ping: 'ca-app-pub-9074226798924140/3376356341',
  StoreAdSlot.portScan: 'ca-app-pub-9074226798924140/3975207869',
};

/// Google's test unit, used for every slot in a debug build.
const String _testAdUnitId = 'ca-app-pub-3940256099942544/9214589741';

/// An AdMob inline adaptive banner that follows the width of its parent.
class InlineAdaptiveBanner extends StatefulWidget {
  const InlineAdaptiveBanner({
    required this.slot,
    this.maxHeight = 100,
    super.key,
  });

  final StoreAdSlot slot;
  final int maxHeight;

  @override
  State<InlineAdaptiveBanner> createState() => _InlineAdaptiveBannerState();
}

class _InlineAdaptiveBannerState extends State<InlineAdaptiveBanner> {
  BannerAd? _ad;
  AdSize? _adSize;
  Orientation? _orientation;
  int? _adWidth;
  int _loadGeneration = 0;

  String get _effectiveAdUnitId =>
      kDebugMode ? _testAdUnitId : _adUnitIds[widget.slot]!;

  bool get _isSupportedPlatform =>
      Theme.of(context).platform == TargetPlatform.android ||
      Theme.of(context).platform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant InlineAdaptiveBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if ((oldWidget.slot != widget.slot ||
            oldWidget.maxHeight != widget.maxHeight) &&
        _adWidth != null) {
      _loadAd(_adWidth!);
    }
  }

  void _ensureAdLoaded(int width, Orientation orientation) {
    if (!_isSupportedPlatform ||
        width <= 0 ||
        (_orientation == orientation && _adWidth == width)) {
      return;
    }

    _orientation = orientation;
    _adWidth = width;
    _loadAd(width);
  }

  Future<void> _loadAd(int width) async {
    final generation = ++_loadGeneration;
    final previousAd = _ad;
    _ad = null;
    _adSize = null;
    await previousAd?.dispose();

    if (!mounted || generation != _loadGeneration || width <= 0) {
      return;
    }

    final ad = BannerAd(
      adUnitId: _effectiveAdUnitId,
      size: AdSize.getInlineAdaptiveBannerAdSize(width, widget.maxHeight),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) async {
          final bannerAd = loadedAd as BannerAd;
          final platformSize = await bannerAd.getPlatformAdSize();
          if (!mounted || generation != _loadGeneration) {
            await bannerAd.dispose();
            return;
          }
          if (platformSize == null) {
            await bannerAd.dispose();
            return;
          }

          setState(() {
            _ad = bannerAd;
            _adSize = platformSize;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('Inline adaptive banner failed to load: $error');
          if (identical(_ad, failedAd)) {
            _ad = null;
            _adSize = null;
          }
          failedAd.dispose();
        },
      ),
    );

    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return const SizedBox.shrink();
        }

        _ensureAdLoaded(
          constraints.maxWidth.truncate(),
          MediaQuery.orientationOf(context),
        );

        final ad = _ad;
        final adSize = _adSize;
        if (ad == null || adSize == null || _adWidth == null) {
          return const SizedBox.shrink();
        }

        return Align(
          child: SizedBox(
            width: _adWidth!.toDouble(),
            height: adSize.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    _ad?.dispose();
    super.dispose();
  }
}
