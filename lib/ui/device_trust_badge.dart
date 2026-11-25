import 'package:flutter/material.dart';
import 'package:vernet/utils/localization.dart';

/// Shield that states whether a device is trusted, with the reason on hover or
/// long-press so the plain icon is never the only explanation.
class DeviceTrustBadge extends StatelessWidget {
  const DeviceTrustBadge({
    super.key,
    required this.trusted,
    this.size = 16,
  });

  final bool trusted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: trusted
          ? context.l10n.deviceTrustTrusted
          : context.l10n.deviceTrustUntrusted,
      child: Icon(
        trusted ? Icons.verified_user : Icons.gpp_maybe,
        size: size,
        color: trusted ? colors.primary : colors.error,
        semanticLabel: trusted
            ? context.l10n.deviceTrustTrusted
            : context.l10n.deviceTrustUntrusted,
      ),
    );
  }
}
