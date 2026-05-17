import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import 'components/otp_form.dart';

class NumberVerifyScreen extends StatelessWidget {
  final String phoneNumber;
  final String verificationId;

  const NumberVerifyScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Affiche le numéro masqué : +253 77 •• •• 34
    final masked = _maskPhone(phoneNumber);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Icône SMS ─────────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: primaryColor,
                  size: 30,
                ),
              ),

              const SizedBox(height: 20),

              // ── Titre ─────────────────────────────────────────────
              Text(
                'Code de vérification',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                        text: 'Entrez le code à 6 chiffres envoyé au\n'),
                    TextSpan(
                      text: masked,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Formulaire OTP ────────────────────────────────────
              OtpForm(
                verificationId: verificationId,
                phoneNumber: phoneNumber,
              ),

              const SizedBox(height: 24),

              // ── Renvoyer le code ──────────────────────────────────
              Center(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    text: 'Vous n\'avez pas reçu le code ? ',
                    children: [
                      TextSpan(
                        text: 'Renvoyer',
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pop(context);
                          },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Text(
                  'En vous inscrivant, vous acceptez nos\nConditions d\'utilisation et Politique de confidentialité.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: bodyTextColor.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    // +253 77 XX XX → +253 77 •• ••
    final start = phone.substring(0, phone.length - 4);
    return '$start•• ••';
  }
}
