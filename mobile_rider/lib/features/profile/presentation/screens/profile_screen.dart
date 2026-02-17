import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryOrange,
                      AppTheme.darkOrange,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Photo de profil',
                      image: true,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ).animate().scale(duration: 400.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Me Amékoudi Koffi Jérôme',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 4),
                    Text(
                      'jerome@example.com',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCard(
                          label: 'Trajets',
                          value: '23',
                        ).animate().fadeIn(delay: 300.ms).scale(),
                        _StatCard(
                          label: 'Points',
                          value: '450',
                        ).animate().fadeIn(delay: 400.ms).scale(),
                        _StatCard(
                          label: 'Économie',
                          value: '12k F',
                        ).animate().fadeIn(delay: 500.ms).scale(),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _ProfileMenuItem(
                      icon: Icons.history,
                      title: 'Historique',
                      subtitle: 'Vos trajets passés',
                      onTap: () {},
                    )
                        .animate()
                        .fadeIn(delay: 600.ms)
                        .slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                    _ProfileMenuItem(
                      icon: Icons.payment,
                      title: 'Moyens de paiement',
                      subtitle: 'Gérer vos cartes',
                      onTap: () {},
                    )
                        .animate()
                        .fadeIn(delay: 700.ms)
                        .slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                    _ProfileMenuItem(
                      icon: Icons.location_on,
                      title: 'Adresses favorites',
                      subtitle: 'Maison, travail...',
                      onTap: () {},
                    )
                        .animate()
                        .fadeIn(delay: 800.ms)
                        .slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                    _ProfileMenuItem(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      subtitle: 'Préférences',
                      onTap: () {},
                    )
                        .animate()
                        .fadeIn(delay: 900.ms)
                        .slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                    _ProfileMenuItem(
                      icon: Icons.help_outline,
                      title: 'Aide & Support',
                      subtitle: 'FAQ et contact',
                      onTap: () {},
                    )
                        .animate()
                        .fadeIn(delay: 1000.ms)
                        .slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                    _ProfileMenuItem(
                      icon: Icons.settings,
                      title: 'Paramètres',
                      subtitle: 'Configuration',
                      onTap: () {},
                    )
                        .animate()
                        .fadeIn(delay: 1100.ms)
                        .slideX(begin: -0.2, end: 0),
                    const SizedBox(height: 24),
                    Semantics(
                      label: 'Se déconnecter',
                      button: true,
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.goNamed('login');
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Se déconnecter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(double.infinity, 56),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 1200.ms)
                        .scale(begin: Offset(0.95, 0.95)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: '$title, $subtitle',
      button: true,
      child: Material(
        elevation: isDark ? 0 : 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: Colors.grey[800]!) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
