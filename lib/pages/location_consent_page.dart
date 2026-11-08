import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vernet/helper/consent_loader.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/main.dart';
import 'package:vernet/ui/semantic_colors.dart';
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

  String get _rationaleTitle {
    if (_isDesktopOnly) return 'Ready to go';
    return 'Why location access?';
  }

  List<String> get _rationaleBullets {
    if (_isDesktopOnly) {
      return [
        'Vernet can scan your network without location access on this platform.',
      ];
    }
    return [
      'Shows your Wi-Fi network name',
      'Enables accurate network scanning on Android',
      'Your location never leaves your device',
    ];
  }

  String get _primaryButtonLabel {
    if (_isDesktopOnly) return 'Get Started';
    if (_permissionStatus.isPermanentlyDenied) return 'Open Settings';
    return 'Allow location access';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                      const Text('Made with \u2764\uFE0F in India'),
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
                        _rationaleTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ..._rationaleBullets.map(
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
                          'Permission was previously denied. '
                          'Open device settings to grant it.',
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
                              : Text(_primaryButtonLabel),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_isDesktopOnly)
                        TextButton(
                          key: WidgetKey.locationConsentSkipButton.key,
                          onPressed: _isLoading ? null : () => _navigate(),
                          child: const Text('Continue without it'),
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
