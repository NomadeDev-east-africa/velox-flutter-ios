import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth-firebase/auth/sign_in_screen.dart';
import 'components/onboard_content.dart';
import 'package:nomade_client/providers/theme_notifier.dart';
import 'package:nomade_client/theme/app_colors.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    final c = isDark ? AppColors.dark : AppColors.light;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Expanded(
              flex: 14,
              child: OnboardContent(
                illustration: "assets/Illustrations/velox1.svg",
                title: "Bienvenue sur Velox",
                text:
                    "Vos repas et vos courses livrés en un éclair à Djibouti-ville. "
                    "Restaurant ou taxi, c'est rapide et simple.",
                c: c,
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'DÉMARRER',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
