import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:uuid/uuid.dart';

class CategoryDetailScreen extends StatefulWidget {
  final TransactionCategory? category;

  const CategoryDetailScreen({super.key, this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final _nameController = TextEditingController();
  late int _selectedIconCodePoint;
  late String _selectedColorHex;

  final List<int> _availableIcons = [
    Icons.shopping_cart.codePoint,
    Icons.restaurant.codePoint,
    Icons.directions_car.codePoint,
    Icons.attach_money.codePoint,
    Icons.movie.codePoint,
    Icons.local_hospital.codePoint,
    Icons.category.codePoint,
    Icons.home.codePoint,
    Icons.work.codePoint,
    Icons.school.codePoint,
    Icons.fitness_center.codePoint,
    Icons.flight.codePoint,
    Icons.pets.codePoint,
    Icons.payments.codePoint,
    Icons.account_balance.codePoint,
    Icons.savings.codePoint,
    Icons.electrical_services.codePoint,
    Icons.water_drop.codePoint,
    Icons.wifi.codePoint,
    Icons.phone_android.codePoint,
    Icons.celebration.codePoint,
    Icons.card_giftcard.codePoint,
    Icons.coffee.codePoint,
    Icons.fastfood.codePoint,
  ];

  final List<String> _availableColors = [
    '#00D09E', // Teal (Primary)
    '#6366F1', // Indigo
    '#3B82F6', // Blue
    '#EF4444', // Red
    '#F59E0B', // Amber
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#14B8A6', // Teal
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#2196F3', // Light Blue
    '#F44336', // Bright Red
    '#9C27B0', // Deep Purple
    '#673AB7', // Deep Indigo
    '#00BCD4', // Cyan
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedIconCodePoint = widget.category!.iconCodePoint;
      _selectedColorHex = widget.category!.colorHex;
    } else {
      _selectedIconCodePoint = Icons.category.codePoint;
      _selectedColorHex = '#00D09E';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save(WidgetRef ref) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    final category = TransactionCategory(
      id: widget.category?.id ?? 'cat_${const Uuid().v4()}',
      name: _nameController.text.trim(),
      iconCodePoint: _selectedIconCodePoint,
      colorHex: _selectedColorHex,
      budget: widget.category?.budget, // Keep existing budget if editing
    );

    if (widget.category != null) {
      ref.read(categoryProvider.notifier).editCategory(category);
    } else {
      ref.read(categoryProvider.notifier).addCategory(category);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Category "${category.name}" saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF')));

    return Consumer(
      builder: (context, ref, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.category != null ? 'Edit Category' : 'New Category'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconData(_selectedIconCodePoint, fontFamily: 'MaterialIcons'),
                      color: selectedColor,
                      size: 36,
                    ),
                  ),
                ),
                const Gap(24),
                TextField(
                  controller: _nameController,
                  autofocus: widget.category == null,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Groceries',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),

                const Gap(28),
                Text(
                  'Select Icon',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLightColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const Gap(14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _availableIcons.length,
                  itemBuilder: (context, index) {
                    final iconCode = _availableIcons[index];
                    final isSelected = _selectedIconCodePoint == iconCode;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconCodePoint = iconCode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor(context).withValues(alpha: 0.12) : AppTheme.surfaceLightColor(context),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor(context) : AppTheme.dividerColor(context),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          IconData(iconCode, fontFamily: 'MaterialIcons'),
                          color: isSelected ? AppTheme.primaryColor(context) : AppTheme.textLightColor(context),
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
                const Gap(28),
                Text(
                  'Select Color',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLightColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const Gap(14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _availableColors.length,
                  itemBuilder: (context, index) {
                    final colorHex = _availableColors[index];
                    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = _selectedColorHex == colorHex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = colorHex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.45),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  },
                ),
                const Gap(36),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: AppTheme.primaryGradient(context),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _save(ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: Text(
                        widget.category != null ? 'Update Category' : 'Create Category',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
