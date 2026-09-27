import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InlineAdaptiveBanner extends StatefulWidget {
  const InlineAdaptiveBanner({
    required this.adUnitId,
    this.maxHeight = 100,
    super.key,
  });

  final String adUnitId;
  final int maxHeight;

  @override
  State<InlineAdaptiveBanner> createState() => _InlineAdaptiveBannerState();
}

class _InlineAdaptiveBannerState extends State<InlineAdaptiveBanner> {
  static const _testAdUnitId = 'ca-app-pub-3940256099942544/9214589741';

  BannerAd? _ad;
  AdSize? _adSize;
  Orientation? _orientation;
  int? _adWidth;
  int _loadGeneration = 0;

  String get _effectiveAdUnitId => kDebugMode ? _testAdUnitId : widget.adUnitId;

  bool get _isSupportedPlatform =>
      Theme.of(context).platform == TargetPlatform.android ||
      Theme.of(context).platform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant InlineAdaptiveBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if ((oldWidget.adUnitId != widget.adUnitId ||
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
