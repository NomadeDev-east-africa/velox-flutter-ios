import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../translations/app_translations.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = AppTranslations.currentLanguage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('choose_language')),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(defaultPadding),
          itemCount: AppTranslations.availableLanguages.length,
          itemBuilder: (context, index) {
            final language = AppTranslations.availableLanguages[index];
            final code = language['code']!;
            final name = language['name']!;
            final nativeName = language['nativeName']!;
            final isSelected = code == _selectedLanguage;

            return InkWell(
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                setState(() {
                  _selectedLanguage = code;
                });
                await AppTranslations.setLanguage(code);

                // Informer l'utilisateur et rafraîchir l'app
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '${tr('language')}: $nativeName',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: primaryColor,
                    duration: const Duration(seconds: 1),
                  ),
                );

                // Attendre un peu puis revenir en arrière pour rafraîchir
                await Future.delayed(const Duration(milliseconds: 500));
                if (!mounted) return;
                navigator.pop(true); // true = langue changée
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: defaultPadding),
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? primaryColor : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Nom de la langue
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nativeName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64)),
                          ),
                        ],
                      ),
                    ),

                    // Checkmark si sélectionné
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: primaryColor,
                        size: 28,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
