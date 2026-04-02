import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/widgets/koin_back_button.dart';

class CategoryDetailScreen extends StatefulWidget {
  final TransactionCategory? category;
  final TransactionType? initialType;

  const CategoryDetailScreen({super.key, this.category, this.initialType});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final _nameController = TextEditingController();
  late int _selectedIconCodePoint;
  late String _selectedColorHex;
  late TransactionType _selectedType;

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
      _selectedType = widget.category!.type;
    } else {
      _selectedIconCodePoint = Icons.category.codePoint;
      _selectedColorHex = '#00D09E';
      _selectedType = widget.initialType ?? TransactionType.expense;
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save(WidgetRef ref) {
    if (_nameController.text.trim().isEmpty) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Name Required',
        subtitle: 'Please provide a name for this category',
      );
      return;
    }

    final category = TransactionCategory(
      id: widget.category?.id ?? 'cat_${const Uuid().v4()}',
      name: _nameController.text.trim(),
      iconCodePoint: _selectedIconCodePoint,
      colorHex: _selectedColorHex,
      type: _selectedType,
      budget: _selectedType == TransactionType.expense
          ? widget.category?.budget
          : null,
    );

    if (widget.category != null) {
      ref.read(categoriesProvider.notifier).editCategory(category);
    } else {
      ref.read(categoriesProvider.notifier).addCategory(category);
    }

    HapticService.success();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = Color(
      int.parse(_selectedColorHex.replaceFirst('#', '0xFF')),
    );
    final previewName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Category Name';

    return Consumer(
      builder: (context, ref, _) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor(context),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const KoinBackButton(),
                      const Gap(16),
                      Text(
                        widget.category != null
                            ? 'Edit Category'
                            : 'New Category',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live preview card
                        _buildPreviewCard(
                          context,
                          selectedColor,
                          previewName,
                        ).animate().fade(duration: 400.ms).slideY(begin: 0.05),

                        const Gap(28),

                        // Name field
                        _buildSectionLabel(context, 'Category Name'),
                        const Gap(10),
                        TextField(
                          controller: _nameController,
                          autofocus: widget.category == null,
                          decoration: const InputDecoration(
                            hintText: 'e.g., Groceries',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                        ).animate().fade(delay: 100.ms),

                        const Gap(28),

                        // Type selector
                        _buildSectionLabel(context, 'Category Type'),
                        const Gap(10),
                        _buildTypeSelector(
                          context,
                        ).animate().fade(delay: 120.ms),

                        const Gap(28),

                        // Icon picker
                        _buildSectionLabel(context, 'Icon'),
                        const Gap(12),
                        _buildIconGrid(
                          context,
                          selectedColor,
                        ).animate().fade(delay: 150.ms),

                        const Gap(28),

                        // Color picker
                        _buildSectionLabel(context, 'Color'),
                        const Gap(12),
                        _buildColorGrid(context).animate().fade(delay: 200.ms),

                        const Gap(36),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: AppTheme.primaryGradient(context),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor(
                                    context,
                                  ).withValues(alpha: 0.3),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                              child: Text(
                                widget.category != null
                                    ? 'Update Category'
                                    : 'Create Category',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ).animate().fade(delay: 250.ms),
                      ],
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

  Widget _buildPreviewCard(
    BuildContext context,
    Color selectedColor,
    String previewName,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Row(
        children: [
          // Animated icon preview with glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                IconUtils.getIcon(_selectedIconCodePoint),
                key: ValueKey(_selectedIconCodePoint),
                color: selectedColor,
                size: 28,
              ),
            ),
          ),
          const Gap(16),
          // Name and label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Gap(4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    previewName,
                    key: ValueKey(previewName),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.category?.budget != null &&
                    widget.category!.budget! > 0) ...[
                  const Gap(4),
                  Text(
                    'Has active budget',
                    style: TextStyle(
                      color: AppTheme.primaryColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Color dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selectedColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textLightColor(context),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildIconGrid(BuildContext context, Color selectedColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: GridView.builder(
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
            onTap: () {
              HapticService.light();
              setState(() => _selectedIconCodePoint = iconCode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.12)
                    : AppTheme.surfaceLightColor(context),
                border: Border.all(
                  color: isSelected
                      ? selectedColor
                      : AppTheme.dividerColor(context),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  IconUtils.getIcon(iconCode),
                  color: isSelected
                      ? selectedColor
                      : AppTheme.textLightColor(context),
                  size: 22,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeOption(
              context,
              'Expense',
              TransactionType.expense,
              AppTheme.expenseColor(context),
              Icons.arrow_upward_rounded,
            ),
          ),
          Expanded(
            child: _buildTypeOption(
              context,
              'Income',
              TransactionType.income,
              AppTheme.incomeColor(context),
              Icons.arrow_downward_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
    BuildContext context,
    String label,
    TransactionType type,
    Color color,
    IconData icon,
  ) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() => _selectedType = type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : AppTheme.textLightColor(context),
            ),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppTheme.textLightColor(context),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorGrid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: GridView.builder(
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
            onTap: () {
              HapticService.light();
              setState(() => _selectedColorHex = colorHex);
            },
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
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
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
