import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nomade_client/providers/theme_notifier.dart';
import 'package:nomade_client/theme/app_colors.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    final c = isDark ? AppColors.dark : AppColors.light;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        foregroundColor: c.onSurface,
        title: Text(
          'Support & Aide',
          style: TextStyle(
            color: c.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Une question ou un problème ? Contactez-nous directement.',
            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          _sectionTitle(c, 'Support technique'),
          const SizedBox(height: 8),
          _contactCard(
            c: c,
            icon: Icons.bug_report,
            label: 'Signaler un bug',
            value: '77 59 18 23',
            onTap: () => _launch(context, 'tel:77591823'),
          ),
          const SizedBox(height: 12),
          _contactCard(
            c: c,
            icon: Icons.email,
            label: 'Email support',
            value: 'devchirdon@gmail.com',
            onTap: () => _launch(context, 'mailto:devchirdon@gmail.com'),
          ),

          const SizedBox(height: 24),
          _sectionTitle(c, 'Service plateforme'),
          const SizedBox(height: 8),
          _contactCard(
            c: c,
            icon: Icons.phone,
            label: 'Responsable plateforme',
            value: '77 45 38 17',
            onTap: () => _launch(context, 'tel:77453817'),
          ),
          const SizedBox(height: 12),
          _contactCard(
            c: c,
            icon: Icons.email,
            label: 'Email responsable',
            value: 'Ouzeurb@gmail.com',
            onTap: () => _launch(context, 'mailto:Ouzeurb@gmail.com'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: c.onSurface,
      ),
    );
  }

  Widget _contactCard({
    required AppColors c,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      color: c.surfaceLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: c.primary, size: 22),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.onSurface,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, size: 20, color: c.onSurfaceVariant),
      ),
    );
  }

  Future<void> _launch(BuildContext context, String uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = Uri.parse(uri);
    if (!await launchUrl(url)) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'application")),
      );
    }
  }
}
