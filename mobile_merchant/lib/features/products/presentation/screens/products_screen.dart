import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mockProducts = [
      {
        'id': '1',
        'name': 'Savon Dove 100g',
        'category': 'Hygiène',
        'price': '850 F',
        'stock': 45,
        'status': 'ok',
      },
      {
        'id': '2',
        'name': 'Riz Uncle Bens 5kg',
        'category': 'Alimentaire',
        'price': '4 500 F',
        'stock': 8,
        'status': 'low',
      },
      {
        'id': '3',
        'name': 'Huile végétale 1L',
        'category': 'Alimentaire',
        'price': '1 200 F',
        'stock': 0,
        'status': 'out',
      },
      {
        'id': '4',
        'name': 'Piles AA (lot de 4)',
        'category': 'Électronique',
        'price': '950 F',
        'stock': 32,
        'status': 'ok',
      },
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Mes Produits',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        label: 'Filtrer',
                        button: true,
                        child: Material(
                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                          elevation: isDark ? 0 : 2,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: const Icon(Icons.filter_list, size: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 16),
                  Semantics(
                    label: 'Rechercher un produit',
                    textField: true,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: isDark ? AppTheme.surfaceDark : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms).scale(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _CategoryChip(label: 'Tous', count: mockProducts.length, isSelected: true),
                  const SizedBox(width: 8),
                  _CategoryChip(label: 'Stock faible', count: 1, isSelected: false),
                  const SizedBox(width: 8),
                  _CategoryChip(label: 'Rupture', count: 1, isSelected: false),
                ],
              ).animate().fadeIn(delay: 200.ms),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: mockProducts.length,
                itemBuilder: (context, index) {
                  final product = mockProducts[index];
                  return _ProductCard(
                    name: product['name'] as String,
                    category: product['category'] as String,
                    price: product['price'] as String,
                    stock: product['stock'] as int,
                    status: product['status'] as String,
                  )
                      .animate()
                      .fadeIn(delay: (100 * index).ms)
                      .slideX(begin: 0.2, end: 0);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Semantics(
        label: 'Ajouter un produit',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ).animate().fadeIn(delay: 400.ms).scale(),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;

  const _CategoryChip({
    required this.label,
    required this.count,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryBlue : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final int stock;
  final String status;

  const _ProductCard({
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.status,
  });

  Color _getStockColor() {
    switch (status) {
      case 'ok':
        return AppTheme.stockOk;
      case 'low':
        return AppTheme.stockLow;
      case 'out':
        return AppTheme.stockOut;
      default:
        return Colors.grey;
    }
  }

  String _getStockLabel() {
    switch (status) {
      case 'ok':
        return 'En stock';
      case 'low':
        return 'Stock faible';
      case 'out':
        return 'Rupture';
      default:
        return 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: isDark ? 0 : 2,
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_bag,
                  size: 40,
                  color: AppTheme.primaryBlue.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          price,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStockColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 14,
                                color: _getStockColor(),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$stock',
                                style: TextStyle(
                                  color: _getStockColor(),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Semantics(
                    label: 'Modifier',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {},
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Semantics(
                    label: 'Plus d\'options',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
