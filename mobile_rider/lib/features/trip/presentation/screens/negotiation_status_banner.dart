import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';

/// Un widget de bannière pour afficher l'état actuel de la négociation.
class NegotiationStatusBanner extends StatelessWidget {
  /// Vrai si le passager a fait une offre et attend la réponse du chauffeur.
  final bool isRiderWaiting;

  /// Vrai si le chauffeur a répondu avec une contre-offre.
  final bool hasDriverResponded;

  const NegotiationStatusBanner({
    super.key,
    required this.isRiderWaiting,
    required this.hasDriverResponded,
  });

  @override
  Widget build(BuildContext context) {
    if (isRiderWaiting) {
      return _buildBanner(
        context: context,
        icon: Icons.hourglass_top_rounded,
        text: 'En attente de la réponse du chauffeur...',
        backgroundColor: Colors.blue.withOpacity(0.1),
        iconColor: Colors.blue.shade700,
        textColor: Colors.blue.shade900,
      ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
    }

    if (hasDriverResponded) {
      return _buildBanner(
        context: context,
        icon: Icons.info_outline_rounded,
        text: 'Le chauffeur a fait une nouvelle proposition !',
        backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
        iconColor: AppTheme.primaryGreen,
        textColor: Colors.green.shade900,
      ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
    }

    // Si aucun statut particulier n'est à afficher, on ne retourne rien.
    return const SizedBox.shrink();
  }

  Widget _buildBanner({
    required BuildContext context,
    required IconData icon,
    required String text,
    required Color backgroundColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: textColor, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
