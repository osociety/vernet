import 'package:flutter/material.dart';
import 'package:vernet/helper/onboarding_service.dart';
import 'package:vernet/main.dart';
import 'package:vernet/models/onboarding_step.dart';
import 'package:vernet/pages/location_consent_page.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/onboarding_content.dart';

class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key, this.backBuilder});

  /// Route for the back button, supplied when the tour follows the language
  /// step. Null hides the button, which is what a resumed install gets: there
  /// the language choice is already behind it.
  final WidgetBuilder? backBuilder;

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  final _controller = PageController();
  int _currentPage = 0;

  static const double _contentMaxWidth = 480;

  /// The tour is built from the active locale, so its page count comes from the
  /// steps rather than a constant that a future fifth step would silently break.
  List<OnboardingStep> get _steps => onboardingSteps(context.l10n);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await OnboardingService.instance.setWalkthroughDone();
    if (!mounted) return;
    final showConsent = !await OnboardingService.instance.isConsentDone();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            showConsent ? const LocationConsentPage() : const TabBarPage(),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final steps = _steps;
    final isLastStep = _currentPage == steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Only on the first step: backing out of a later one is what
                  // swiping back does, and that stays inside the tour.
                  if (widget.backBuilder != null && _currentPage == 0)
                    TextButton.icon(
                      key: WidgetKey.walkthroughBackButton.key,
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: widget.backBuilder!),
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.commonGoBack),
                    ),
                  const Spacer(),
                  TextButton(
                    key: WidgetKey.walkthroughSkipButton.key,
                    onPressed: _complete,
                    child: Text(l10n.walkthroughSkip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: steps.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return _AnimatedStepPage(
                    controller: _controller,
                    index: index,
                    icon: step.icon,
                    title: step.title,
                    description: step.description,
                    color: colors.primary,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PageIndicator(
                      key: WidgetKey.walkthroughPageIndicator.key,
                      count: steps.length,
                      current: _currentPage,
                      color: colors.primary,
                    ),
                    FilledButton(
                      key: isLastStep
                          ? WidgetKey.walkthroughGetStartedButton.key
                          : WidgetKey.walkthroughNextButton.key,
                      onPressed: _nextPage,
                      child: Text(
                        isLastStep ? l10n.getStarted : l10n.walkthroughNext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AnimatedStepPage extends StatelessWidget {
  const _AnimatedStepPage({
    required this.controller,
    required this.index,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final PageController controller;
  final int index;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double pageOffset = 0;
        if (controller.position.hasContentDimensions) {
          pageOffset = controller.page! - index;
        }
        final opacity = (1 - pageOffset.abs()).clamp(0.0, 1.0);
        final slide = pageOffset * 40;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slide),
            child: child,
          ),
        );
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 56, color: color),
                ),
                const SizedBox(height: 40),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    super.key,
    required this.count,
    required this.current,
    required this.color,
  });

  final int count;
  final int current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
