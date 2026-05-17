import 'package:flutter/material.dart';
import '../auth-firebase/auth/sign_in_screen.dart';
import 'components/onboard_content.dart';

// Kinetic Monolith design system
const _bg               = Color(0xFF0E0E0E);
const _primary          = Color(0xFF9FFF88);
const _onPrimary        = Color(0xFF026400);
const _onSurfaceVariant = Color(0xFFADAAAA);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Expanded(
              flex: 14,
              child: PageView.builder(
                itemCount: demoData.length,
                onPageChanged: (value) => setState(() => currentPage = value),
                itemBuilder: (context, index) => OnboardContent(
                  illustration: demoData[index]["illustration"],
                  title: demoData[index]["title"],
                  text: demoData[index]["text"],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                demoData.length,
                (index) => _buildDot(index == currentPage),
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _onPrimary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'COMMENCER',
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

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? _primary : _onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

List<Map<String, dynamic>> demoData = [
  {
    "illustration": "assets/Illustrations/velox1.svg",
    "title": "Bienvenue sur Velox",
    "text":
        " Ici, chaque seconde compte",
  },
  {
    "illustration": "assets/Illustrations/velox2.svg",
    "title": "Livraison et transport rapides",
    "text":
        "Vos repas et courses livrés en un éclair à Djibouti-ville ! Profitez d'un service express, directement à votre porte.",
  },
  {
    "illustration": "assets/Illustrations/velox3.svg",
    "title": "Choisissez votre service",
    "text":
        "Trouvez facilement ce dont vous avez envie : restaurant ou taxi, et bénéficiez d'un service de qualité.",
  },
];