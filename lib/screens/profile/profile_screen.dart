import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nomade_client/providers/all_providers.dart';

// Screens
import 'edit_profile_screen.dart';
import 'adresses/add_address_screen.dart';
import 'adresses/my_addresses_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);
    final langState  = ref.watch(languageNotifierProvider);
    final userState  = ref.watch(userNotifierProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeaderSliver(themeState, userState),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildSection(
                  themeState: themeState,
                  title: 'Apparence & Personnalisation',
                  icon: Icons.palette,
                  children: [
                    _buildDarkModeToggle(themeState),
                    _buildLanguageSelector(langState),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  themeState: themeState,
                  title: 'Informations personnelles',
                  icon: Icons.person,
                  children: [
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.edit,
                      title: 'Modifier mon profil',
                      subtitle: 'Nom, téléphone, date de naissance',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.email,
                      title: userState.email ?? 'Email non disponible',
                      subtitle: 'Adresse email',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Vérifié',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  themeState: themeState,
                  title: 'Mes adresses',
                  icon: Icons.location_on,
                  children: [
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.home,
                      title: 'Gérer mes adresses',
                      subtitle: 'Maison, Bureau, Autres',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyAddressesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.add_location_alt,
                      title: 'Ajouter une adresse',
                      subtitle: 'Nouvelle adresse',
                      trailing: const Icon(Icons.chevron_right),
                      color: const Color(0xFFCE1126), // rouge
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddAddressScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  themeState: themeState,
                  title: 'Notifications',
                  icon: Icons.notifications,
                  children: [
                    _buildSwitchTile(
                      themeState: themeState,
                      icon: Icons.notifications_active,
                      title: 'Notifications push',
                      subtitle: 'Recevoir les alertes',
                      value: true,
                      onChanged: (value) {},
                    ),
                    _buildSwitchTile(
                      themeState: themeState,
                      icon: Icons.shopping_bag,
                      title: 'Suivi de commande',
                      subtitle: 'Mises à jour en temps réel',
                      value: true,
                      onChanged: (value) {},
                    ),
                    _buildSwitchTile(
                      themeState: themeState,
                      icon: Icons.local_offer,
                      title: 'Promotions',
                      subtitle: 'Offres et réductions',
                      value: false,
                      onChanged: (value) {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  themeState: themeState,
                  title: 'Historique & Favoris',
                  icon: Icons.history,
                  children: [
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.receipt_long,
                      title: 'Mes commandes',
                      subtitle: 'Historique complet',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.favorite,
                      title: 'Restaurants favoris',
                      subtitle: '5 restaurants',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  themeState: themeState,
                  title: 'Support & Légal',
                  icon: Icons.help_outline,
                  children: [
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.help_center,
                      title: 'Centre d\'aide',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.info,
                      title: 'À propos de Velox',
                      subtitle: 'Version 1.0.0',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  themeState: themeState,
                  title: 'Compte',
                  icon: Icons.security,
                  children: [
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.logout,
                      title: 'Déconnexion',
                      color: Colors.orange,
                      onTap: () => _showLogoutDialog(themeState),
                    ),
                    _buildMenuItem(
                      themeState: themeState,
                      icon: Icons.delete_forever,
                      title: 'Supprimer mon compte',
                      color: const Color(0xFFCE1126), // rouge
                      onTap: () => _showDeleteAccountDialog(themeState),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSliver(ThemeState themeState, UserState userState) {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0E0E0E),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0E0E0E), Color(0xFF1A1919)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF9FFF88),
                          width: 3,
                        ),
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF20201F),
                            backgroundImage: userState.displayPhotoUrl != null
                                ? NetworkImage(userState.displayPhotoUrl!)
                                : null,
                            child: userState.displayPhotoUrl == null
                                ? const Icon(Icons.person, size: 50,
                                    color: Color(0xFF9FFF88))
                                : null,
                          ),
                          if (_isUploading)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF9FFF88),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9FFF88),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9FFF88).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Color(0xFF026400),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  userState.displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userState.email ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFADAAAA),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeState themeState,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF9FFF88), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeState.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: themeState.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required ThemeState themeState,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF9FFF88)).withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color ?? const Color(0xFF9FFF88),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color ?? themeState.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: themeState.textSecondary),
      )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
    );
  }

  Widget _buildDarkModeToggle(ThemeState themeState) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF9FFF88).withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          themeState.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: const Color(0xFF9FFF88),
          size: 22,
        ),
      ),
      title: Text(
        'Mode sombre',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: themeState.textPrimary,
        ),
      ),
      subtitle: Text(
        themeState.isDarkMode ? 'Activé' : 'Désactivé',
        style: TextStyle(fontSize: 13, color: themeState.textSecondary),
      ),
      value: themeState.isDarkMode,
      activeThumbColor: const Color(0xFF9FFF88),
      onChanged: (value) => ref.read(themeNotifierProvider.notifier).toggleTheme(),
    );
  }

  Widget _buildLanguageSelector(LanguageState langState) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF9FFF88).withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.language,
          color: Color(0xFF9FFF88),
          size: 22,
        ),
      ),
      title: const Text(
        'Langue',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        langState.languageName,
        style: const TextStyle(fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showLanguageDialog(langState),
    );
  }

  Widget _buildSwitchTile({
    required ThemeState themeState,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF9FFF88).withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF9FFF88), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: themeState.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: themeState.textSecondary),
      ),
      value: value,
      activeThumbColor: const Color(0xFF9FFF88),
      onChanged: onChanged,
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1919),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF484847),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Changer la photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FFF88).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_camera, color: Color(0xFF9FFF88)),
                ),
                title: const Text('Prendre une photo',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image = await picker.pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (image != null && mounted) await _uploadPhoto(image);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FFF88).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF9FFF88)),
                ),
                title: const Text('Choisir depuis la galerie',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 80);
                  if (image != null && mounted) await _uploadPhoto(image);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(XFile image) async {
    setState(() => _isUploading = true);
    try {
      await ref.read(userNotifierProvider.notifier).uploadProfilePhoto(image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showLanguageDialog(LanguageState langState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir la langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _languageOption(langState, 'FR', 'Français'),
            _languageOption(langState, 'EN', 'English'),
            _languageOption(langState, 'SO', 'Somali'),
            _languageOption(langState, 'AR', 'العربية'),
            _languageOption(langState, 'AF', 'Afar'),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(LanguageState langState, String code, String name) {
    final isSelected = langState.language == code;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9FFF88).withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          code,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF9FFF88) : Colors.grey[600],
          ),
        ),
      ),
      title: Text(name),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF9FFF88))
          : null,
      onTap: () {
        ref.read(languageNotifierProvider.notifier).setLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  void _showLogoutDialog(ThemeState themeState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeState.cardColor,
        title: Text('Déconnexion',
            style: TextStyle(color: themeState.textPrimary)),
        content: Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: themeState.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await ref.read(userNotifierProvider.notifier).logout();
              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil('/', (_) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(ThemeState themeState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeState.cardColor,
        title: Text('Supprimer le compte', style: TextStyle(color: themeState.textPrimary)),
        content: Text(
          'Cette action est irréversible. Toutes vos données seront supprimées définitivement.',
          style: TextStyle(color: themeState.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Show confirmation dialog + delete account
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCE1126),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}