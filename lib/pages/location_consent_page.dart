import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/helper/consent_loader.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/semantic_colors.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

class LocationConsentPage extends StatefulWidget {
  const LocationConsentPage({super.key});

  @override
  _LocationConsentPageState createState() => _LocationConsentPageState();
}

class _LocationConsentPageState extends State<LocationConsentPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    if (!_isMobileOrWindows) return;
    final status = await Permission.location.status;
    if (mounted) setState(() => _permissionStatus = status);
  }

  bool get _isMobileOrWindows =>
      Platform.isAndroid || Platform.isIOS || Platform.isWindows;

  bool get _isDesktopOnly =>
      !Platform.isAndroid && !Platform.isIOS && !Platform.isWindows;

  String _rationaleTitle(AppLocalizations l10n) =>
      _isDesktopOnly ? l10n.consentReadyTitle : l10n.consentLocationTitle;

  List<String> _rationaleBullets(AppLocalizations l10n) => _isDesktopOnly
      ? [l10n.consentDesktopNote]
      : [
          l10n.consentBulletWifiName,
          l10n.consentBulletAndroidScan,
          l10n.consentBulletPrivacy,
        ];

  String _primaryButtonLabel(AppLocalizations l10n) {
    if (_isDesktopOnly) return l10n.getStarted;
    if (_permissionStatus.isPermanentlyDenied) return l10n.consentOpenSettings;
    return l10n.consentAllowLocation;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Text(l10n.madeInIndia),
                      const SizedBox(height: 15),
                      Text(
                        'Vernet',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(color: colors.primary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _isDesktopOnly
                              ? colors.success.withValues(alpha: 0.12)
                              : colors.info.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isDesktopOnly
                              ? Icons.check_circle
                              : Icons.location_on,
                          size: 48,
                          color: _isDesktopOnly ? colors.success : colors.info,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _rationaleTitle(l10n),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ..._rationaleBullets(l10n).map(
                        (text) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  text,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_permissionStatus.isPermanentlyDenied) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.consentDeniedHint,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.warning,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: _permissionStatus.isPermanentlyDenied
                              ? WidgetKey.locationConsentSettingsButton.key
                              : WidgetKey.locationConsentAllowButton.key,
                          onPressed: _isLoading ? null : _onPrimaryPressed,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_primaryButtonLabel(l10n)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_isDesktopOnly)
                        TextButton(
                          key: WidgetKey.locationConsentSkipButton.key,
                          onPressed: _isLoading ? null : () => _navigate(),
                          child: Text(l10n.consentContinueWithout),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onPrimaryPressed() async {
    if (_isDesktopOnly) {
      _navigate();
      return;
    }
    if (_permissionStatus.isPermanentlyDenied) {
      await openAppSettings();
      final status = await Permission.location.status;
      if (mounted) setState(() => _permissionStatus = status);
      if (status.isGranted) _navigate();
      return;
    }
    setState(() => _isLoading = true);
    final granted = await Permission.location.request().isGranted;
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (granted) _navigate();
  }

  void _navigate() {
    ConsentLoader.setConsentPageShown(true);
    OnboardingService.instance.setConsentDone();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TabBarPage()),
    );
  }
}
