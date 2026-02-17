import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Widget pour afficher une alerte d'appel entrant avec sonnerie
class IncomingCallAlert extends StatelessWidget {
  final String callId;
  final String tripId;
  final String callerName;
  final String callerType;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallAlert({
    super.key,
    required this.callId,
    required this.tripId,
    required this.callerName,
    required this.callerType,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryGreen,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône d'appel animée
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.phone_in_talk,
                size: 60,
                color: AppTheme.primaryGreen,
              ),
            ),

            const SizedBox(height: 24),

            // Texte d'appel entrant
            const Text(
              '📞 Appel entrant',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            // Nom de l'appelant
            Text(
              callerName,
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF8E9AAF),
              ),
            ),

            const SizedBox(height: 8),

            // Type d'appelant
            Text(
              callerType == 'rider' ? 'Votre passager' : 'Votre chauffeur',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E9AAF),
              ),
            ),

            const SizedBox(height: 32),

            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Bouton rejeter
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onReject();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_end),
                        SizedBox(width: 8),
                        Text(
                          'Rejeter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Bouton accepter
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onAccept();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call),
                        SizedBox(width: 8),
                        Text(
                          'Accepter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Afficher le dialogue d'appel entrant
  static void show({
    required BuildContext context,
    required String callId,
    required String tripId,
    required String callerName,
    required String callerType,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallAlert(
        callId: callId,
        tripId: tripId,
        callerName: callerName,
        callerType: callerType,
        onAccept: onAccept,
        onReject: onReject,
      ),
    );
  }
}
