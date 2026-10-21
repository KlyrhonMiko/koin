import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';

class CategoryDetailScreen extends StatefulWidget {
  final TransactionCategory? category;
  final TransactionType? initialType;

  const CategoryDetailScreen({super.key, this.category, this.initialType});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  late int _selectedIconCodePoint;
  late String _selectedColorHex;
  late TransactionType _selectedType;

  final List<int> _availableIcons = [
    KoinIcons.shoppingCart.codePoint,
    KoinIcons.forkKnife.codePoint,
    KoinIcons.car.codePoint,
    KoinIcons.currencyDollar.codePoint,
    KoinIcons.filmSlate.codePoint,
    KoinIcons.firstAid.codePoint,
    KoinIcons.squaresFour.codePoint,
    KoinIcons.house.codePoint,
    KoinIcons.briefcase.codePoint,
    KoinIcons.graduationCap.codePoint,
    KoinIcons.barbell.codePoint,
    KoinIcons.airplane.codePoint,
    KoinIcons.pawPrint.codePoint,
    KoinIcons.money.codePoint,
    KoinIcons.bank.codePoint,
    KoinIcons.piggyBank.codePoint,
    KoinIcons.plug.codePoint,
    KoinIcons.drop.codePoint,
    KoinIcons.wifiHigh.codePoint,
    KoinIcons.deviceMobile.codePoint,
    KoinIcons.devices.codePoint,
    KoinIcons.confetti.codePoint,
    KoinIcons.gift.codePoint,
    KoinIcons.coffee.codePoint,
    KoinIcons.pintGlass.codePoint,
    KoinIcons.hamburger.codePoint,
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
      _selectedIconCodePoint = KoinIcons.squaresFour.codePoint;
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

  Future<void> _save(WidgetRef ref) async {
    if (_saving) return;
    if (_nameController.text.trim().isEmpty) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Name Required',
        subtitle: 'Please provide a name for this category',
      );
      return;
    }

    var category =
        widget.category?.copyWith(
          name: _nameController.text.trim(),
          iconCodePoint: _selectedIconCodePoint,
          colorHex: _selectedColorHex,
          type: _selectedType,
        ) ??
        TransactionCategory(
          id: widget.category?.id ?? 'cat_${const Uuid().v4()}',
          name: _nameController.text.trim(),
          iconCodePoint: _selectedIconCodePoint,
          colorHex: _selectedColorHex,
          type: _selectedType,
          budget: _selectedType == TransactionType.expense
              ? widget.category?.budget
              : null,
        );

    if (_selectedType != TransactionType.expense) {
      category = category.withoutBudget();
    }
    setState(() => _saving = true);
    try {
      if (widget.category != null) {
        await ref.read(categoriesProvider.notifier).editCategory(category);
      } else {
        await ref.read(categoriesProvider.notifier).addCategory(category);
      }
      if (!mounted) return;
      HapticService.success();
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Could not save category',
          subtitle: 'Your changes are kept. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    title: 'Discard category changes?',
    draft: () => (
      _nameController.text,
      _selectedIconCodePoint,
      _selectedColorHex,
      _selectedType,
    ),
    listenables: [_nameController],
    isSaving: () => _saving,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
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
                    horizontal: KoinSpacing.screenInset,
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
                          fontSize: KoinTypography.screenTitle,
                          fontWeight: KoinTypography.headingWeight,
                          letterSpacing: KoinTypography.headingTracking,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      KoinSpacing.screenInset,
                      16,
                      KoinSpacing.screenInset,
                      40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live preview card
                        _buildPreviewCard(context, selectedColor, previewName)
                            .koinAnimate(
                              context,
                              autoPlay: !MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              onInit: KoinMotion.onInit(context),
                            )
                            .fade(duration: 250.ms)
                            .slideY(begin: 0.05),

                        const Gap(KoinSpacing.sectionGap),

                        // Name field
                        _buildSectionLabel(context, 'Category Name'),
                        const Gap(10),
                        TextField(
                              controller: _nameController,
                              autofocus: widget.category == null,
                              decoration: const InputDecoration(
                                hintText: 'e.g., Groceries',
                                prefixIcon: Icon(KoinIcons.tag),
                              ),
                            )
                            .koinAnimate(
                              context,
                              autoPlay: !MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              onInit: KoinMotion.onInit(context),
                            )
                            .fade(delay: 100.ms),

                        const Gap(KoinSpacing.sectionGap),

                        // Type selector
                        _buildSectionLabel(context, 'Category Type'),
                        const Gap(10),
                        _buildTypeSelector(context)
                            .koinAnimate(
                              context,
                              autoPlay: !MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              onInit: KoinMotion.onInit(context),
                            )
                            .fade(delay: 120.ms),

                        const Gap(KoinSpacing.sectionGap),

                        // Icon picker
                        _buildSectionLabel(context, 'Icon'),
                        const Gap(12),
                        _buildIconGrid(context, selectedColor)
                            .koinAnimate(
                              context,
                              autoPlay: !MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              onInit: KoinMotion.onInit(context),
                            )
                            .fade(delay: 150.ms),

                        const Gap(KoinSpacing.sectionGap),

                        // Color picker
                        _buildSectionLabel(context, 'Color'),
                        const Gap(12),
                        _buildColorGrid(context)
                            .koinAnimate(
                              context,
                              autoPlay: !MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              onInit: KoinMotion.onInit(context),
                            )
                            .fade(delay: 200.ms),

                        const Gap(36),

                        KoinPrimaryButton(
                              isLoading: _saving,
                              label: widget.category != null
                                  ? 'Update Category'
                                  : 'Create Category',
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              onPressed: () => _save(ref),
                            )
                            .koinAnimate(
                              context,
                              autoPlay: !MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              onInit: KoinMotion.onInit(context),
                            )
                            .fade(delay: 250.ms),
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
            duration: KoinMotion.duration(
              context,
              const Duration(milliseconds: 300),
            ),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                AppTheme.boxShadow(
                  context,
                  color: selectedColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: KoinMotion.duration(
                context,
                const Duration(milliseconds: 250),
              ),
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
                    fontSize: KoinTypography.overline,
                    fontWeight: KoinTypography.labelWeight,
                    letterSpacing: 0.5,
                  ),
                ),
                const Gap(4),
                Text(
                  previewName,
                  key: ValueKey(previewName),
                  style: const TextStyle(
                    fontWeight: KoinTypography.titleWeight,
                    fontSize: KoinTypography.itemAmount,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.category?.budget != null &&
                    widget.category!.budget! > 0) ...[
                  const Gap(4),
                  Text(
                    'Has active budget',
                    style: TextStyle(
                      color: AppTheme.primaryColor(context),
                      fontSize: KoinTypography.small,
                      fontWeight: KoinTypography.supportingWeight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Color dot
          AnimatedContainer(
            duration: KoinMotion.duration(
              context,
              const Duration(milliseconds: 300),
            ),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selectedColor,
              shape: BoxShape.circle,
              boxShadow: [
                AppTheme.boxShadow(
                  context,
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
      style: TextStyle(
        fontFamily: KoinTypography.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textLightColor(context),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildIconGrid(BuildContext context, Color selectedColor) {
    return IconPaletteGrid(
      iconCodes: _availableIcons,
      selectedCodePoint: _selectedIconCodePoint,
      activeColor: selectedColor,
      onCodePointSelected: (code) =>
          setState(() => _selectedIconCodePoint = code),
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    return TransactionTypeSelector(
      selectedType: _selectedType,
      allowedTypes: const [TransactionType.expense, TransactionType.income],
      activeColor: _selectedType == TransactionType.expense
          ? AppTheme.expenseColor(context)
          : AppTheme.incomeColor(context),
      onChanged: (type) => setState(() => _selectedType = type),
    );
  }

  Widget _buildColorGrid(BuildContext context) {
    return ColorPaletteGrid(
      hexColors: _availableColors,
      selectedHex: _selectedColorHex,
      onHexSelected: (hex) => setState(() => _selectedColorHex = hex),
    );
  }
}
