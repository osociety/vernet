import 'package:flutter/material.dart';
import 'package:vernet/l10n/app_localizations.dart';
import 'package:vernet/models/onboarding_step.dart';

/// The four feature highlights of the first-run walkthrough, in page order.
///
/// The copy comes from the active locale, so the tour reads in the language the
/// user picked on the screen before this one.
List<OnboardingStep> onboardingSteps(AppLocalizations l10n) => [
      OnboardingStep(
        icon: Icons.radar,
        title: l10n.onboardingDiscoverTitle,
        description: l10n.onboardingDiscoverDesc,
      ),
      OnboardingStep(
        icon: Icons.lock_open,
        title: l10n.onboardingSecurityTitle,
        description: l10n.onboardingSecurityDesc,
      ),
      OnboardingStep(
        icon: Icons.speed,
        title: l10n.onboardingSpeedTitle,
        description: l10n.onboardingSpeedDesc,
      ),
      OnboardingStep(
        icon: Icons.dns,
        title: l10n.onboardingDnsTitle,
        description: l10n.onboardingDnsDesc,
      ),
    ];
