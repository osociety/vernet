import 'package:flutter/material.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/ui/adaptive/adaptive_dialog.dart';

class NetworkTroubleshootDialog extends StatelessWidget {
  const NetworkTroubleshootDialog({
    super.key,
    required this.status,
  });

  final NetworkConnectionStatus status;

  /// Threshold above which we use a wider desktop layout.
  static const double _desktopBreakpoint = 700;

  /// Max dialog width on desktop/wide screens.
  static const double _desktopMaxWidth = 580;

  /// Max dialog width on mobile/narrow screens.
  static const double _mobileMaxWidth = 420;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isConnected = status.isConnected;
    final statusColor = isConnected ? Colors.green : colors.error;
    final platform = Theme.of(context).platform;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _desktopBreakpoint;

    // On macOS/iOS the CupertinoAlertDialog has a fixed narrow intrinsic
    // width that cannot be overridden with a ConstrainedBox on the content.
    // For wide screens on those platforms we use a Material AlertDialog
    // wrapped in a Dialog (which has no default width cap) so the user gets
    // a comfortably wide layout.
    final useWideDesktopDialog =
        isDesktop &&
        (platform == TargetPlatform.macOS || platform == TargetPlatform.iOS);

    final contentWidget = _buildContent(context, colors, statusColor);

    if (useWideDesktopDialog) {
      return _WideDesktopDialog(
        status: status,
        statusColor: statusColor,
        isConnected: isConnected,
        maxWidth: _desktopMaxWidth,
        content: contentWidget,
      );
    }

    return AdaptiveDialog(
      title: _buildTitle(context, isConnected, statusColor),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? _desktopMaxWidth : _mobileMaxWidth,
        ),
        child: contentWidget,
      ),
      actions: const [],
    );
  }

  Widget _buildTitle(
    BuildContext context,
    bool isConnected,
    Color statusColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isConnected ? Icons.check_circle : Icons.error_outline,
          color: statusColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            status.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colors,
    Color statusColor,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withAlpha(80)),
            ),
            child: Text(
              status.summary,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                ),
          ),
          if (status.details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant.withAlpha(80)),
              ),
              child: Column(
                children: [
                  for (final entry in status.details.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              entry.value,
                              textAlign: TextAlign.end,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (status.troubleshootingSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Troubleshooting Steps',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < status.troubleshootingSteps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                    ),
                    Expanded(
                      child: Text(
                        status.troubleshootingSteps[i],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A Material [Dialog] with an explicit [maxWidth], used on desktop macOS/iOS
/// where [CupertinoAlertDialog] cannot be widened via content constraints.
class _WideDesktopDialog extends StatelessWidget {
  const _WideDesktopDialog({
    required this.status,
    required this.statusColor,
    required this.isConnected,
    required this.maxWidth,
    required this.content,
  });

  final NetworkConnectionStatus status;
  final Color statusColor;
  final bool isConnected;
  final double maxWidth;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.error_outline,
                    color: statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scrollable body
              Flexible(child: content),
              const SizedBox(height: 8),
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(color: colors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
