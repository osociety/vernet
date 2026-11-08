import 'package:flutter/material.dart';
import 'package:vernet/models/onboarding_step.dart';

const List<OnboardingStep> kOnboardingSteps = [
  OnboardingStep(
    icon: Icons.radar,
    title: 'Discover Devices',
    description:
        'Scan your local network to find every connected device and inspect open ports.',
  ),
  OnboardingStep(
    icon: Icons.lock_open,
    title: 'Find Security Gaps',
    description:
        'Identify open ports and potential vulnerabilities on your network.',
  ),
  OnboardingStep(
    icon: Icons.speed,
    title: 'Test Internet Speed',
    description: 'Measure download and upload speeds powered by M-Lab NDT7.',
  ),
  OnboardingStep(
    icon: Icons.dns,
    title: 'DNS & Diagnostics',
    description:
        'Look up DNS records, ping hosts, and diagnose connectivity issues.',
  ),
];
