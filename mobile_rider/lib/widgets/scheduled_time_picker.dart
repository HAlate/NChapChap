import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';

/// Widget pour sélectionner la date et l'heure d'une course réservée
class ScheduledTimePicker extends StatelessWidget {
  final DateTime? selectedDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;
  final DateTime? minDateTime;
  final DateTime? maxDateTime;

  const ScheduledTimePicker({
    super.key,
    required this.selectedDateTime,
    required this.onDateTimeChanged,
    this.minDateTime,
    this.maxDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMinDateTime = minDateTime ?? DateTime.now();
    final effectiveMaxDateTime =
        maxDateTime ?? DateTime.now().add(const Duration(days: 7));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showDateTimePicker(
          context,
          effectiveMinDateTime,
          effectiveMaxDateTime,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Heure de départ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedDateTime != null
                                ? _formatDateTime(selectedDateTime!)
                                : 'Sélectionner date et heure',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: selectedDateTime != null
                                  ? Colors.black87
                                  : Colors.grey[600],
                            ),
                          ),
                          if (selectedDateTime != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getRelativeTime(selectedDateTime!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous pouvez réserver jusqu\'à 7 jours à l\'avance',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDateTimePicker(
    BuildContext context,
    DateTime minDateTime,
    DateTime maxDateTime,
  ) async {
    // Première étape: Sélectionner la date
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? minDateTime,
      firstDate: minDateTime,
      lastDate: maxDateTime,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !context.mounted) return;

    // Deuxième étape: Sélectionner l'heure
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: selectedDateTime != null
          ? TimeOfDay.fromDateTime(selectedDateTime!)
          : TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !context.mounted) return;

    // Combiner date et heure
    final combinedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Vérifier que c'est dans le futur
    if (combinedDateTime.isBefore(DateTime.now())) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L\'heure de départ doit être dans le futur'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    onDateTimeChanged(combinedDateTime);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('HH:mm', 'fr_FR');
    final dateFormat = DateFormat('EEEE d MMMM', 'fr_FR');

    String dateStr;
    if (dateToCheck == today) {
      dateStr = 'Aujourd\'hui';
    } else if (dateToCheck == tomorrow) {
      dateStr = 'Demain';
    } else {
      dateStr = dateFormat.format(dateTime);
      // Capitaliser la première lettre
      dateStr = dateStr[0].toUpperCase() + dateStr.substring(1);
    }

    return '$dateStr à ${timeFormat.format(dateTime)}';
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inMinutes < 60) {
      return 'Dans ${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Dans $hours heure${hours > 1 ? 's' : ''}';
    } else {
      final days = difference.inDays;
      return 'Dans $days jour${days > 1 ? 's' : ''}';
    }
  }
}
