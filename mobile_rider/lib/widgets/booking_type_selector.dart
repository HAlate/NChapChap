import 'package:flutter/material.dart';
import '../core/constants/booking_types.dart';
import '../core/theme/app_theme.dart';

/// Widget pour sélectionner le type de réservation (immediate vs scheduled)
class BookingTypeSelector extends StatelessWidget {
  final BookingType selectedType;
  final ValueChanged<BookingType> onTypeChanged;

  const BookingTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Type de réservation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...BookingType.values.map(
              (type) => _BookingTypeOption(
                type: type,
                isSelected: selectedType == type,
                onTap: () => onTypeChanged(type),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTypeOption extends StatelessWidget {
  final BookingType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _BookingTypeOption({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isSelected
        ? AppTheme.primaryGreen.withOpacity(0.1)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            // Radio button
            Radio<BookingType>(
              value: type,
              groupValue: isSelected ? type : null,
              onChanged: (_) => onTap(),
              activeColor: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 12),
            // Emoji
            Text(
              type.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryGreen : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Check icon si sélectionné
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
