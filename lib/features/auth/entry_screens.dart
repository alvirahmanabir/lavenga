import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';

/// Restores the stored session, then routes on. The router redirects signed-in
/// users to their home; everyone else goes to onboarding.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final router = GoRouter.of(context);
    final notifier = ref.read(sessionProvider.notifier);
    await Future.wait([
      notifier.restore(),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    if (!mounted) return;
    // Signed-in users are redirected by the router when state changes; this
    // covers the signed-out case where the redirect returns null.
    if (!ref.read(sessionProvider).isSignedIn) router.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Semantics(
          label: 'Lavenga is loading',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lavenga',
                  style: text.displaySmall?.copyWith(color: AppColors.paper)),
              const SizedBox(height: AppSpacing.sm),
              Text('Book studio space, beautifully.',
                  style: text.bodyMedium?.copyWith(color: AppColors.paper)),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paper),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (Icons.search, 'Find the right space',
        'Browse photo, video, podcast and event studios. Filter by price, size, facilities and availability.'),
    (Icons.event_available_outlined, 'Pick your times',
        'Choose a date and exact time slots. Book several spaces in one checkout.'),
    (Icons.verified_outlined, 'Pay with confidence',
        'Your slots are held while you pay. A booking is confirmed only after payment is verified.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final p = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(p.$1, size: 72, color: AppColors.terracotta),
                            const SizedBox(height: AppSpacing.xl),
                            Text(p.$2, style: text.headlineMedium, textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.md),
                            Text(p.$3, style: text.bodyLarge, textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.ink : AppColors.line,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: AppButton(
                    label: last ? 'Get started' : 'Next',
                    onPressed: () {
                      if (last) {
                        context.go('/auth/login');
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral notice for restricted accounts. It never reveals the internal
/// reason (blacklist notes are staff-only).
class RestrictedScreen extends ConsumerWidget {
  const RestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: AppColors.mutedText),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Account unavailable',
                      style: text.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Your account cannot be used for bookings right now. '
                    'Please contact Lavenga support if you think this is a mistake.',
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Sign out',
                    kind: AppButtonKind.secondary,
                    icon: Icons.logout,
                    onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
