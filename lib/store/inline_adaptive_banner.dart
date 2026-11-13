import 'package:flutter/widgets.dart';
import 'package:vernet/store/store_ad_slot.dart';

/// A banner ad slot.
///
/// The committed build has no ad SDK, so this stub collapses.
/// `store_overlay/lib/store/inline_adaptive_banner.dart` replaces it with the
/// AdMob implementation when `scripts/build_store.dart` assembles the Play
/// build.
class InlineAdaptiveBanner extends StatelessWidget {
  const InlineAdaptiveBanner({
    required this.slot,
    this.maxHeight = 100,
    super.key,
  });

  final StoreAdSlot slot;
  final int maxHeight;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
