import 'category.dart';

/// Represents a chip item in the category budget configuration layout,
/// either an unbudgeted category or the 'Manage' button.
class UnbudgetedChipItem {
  final TransactionCategory? category;
  final bool isManage;
  final double estimatedWidth;
  final int originalIndex;

  const UnbudgetedChipItem({
    this.category,
    required this.isManage,
    required this.estimatedWidth,
    required this.originalIndex,
  });

  /// Estimates the rendered width of a category chip given its [text].
  static double estimateWidth(String text) => 92.0 + (text.length * 7.5);

  /// Optimizes row packing using a greedy best-fit algorithm to minimize ragged line wrapping.
  static List<UnbudgetedChipItem> optimizeRowPacking({
    required List<TransactionCategory> unbudgeted,
    required double maxRowWidth,
    double spacing = 10.0,
  }) {
    final pendingItems = <UnbudgetedChipItem>[];
    for (int i = 0; i < unbudgeted.length; i++) {
      pendingItems.add(
        UnbudgetedChipItem(
          category: unbudgeted[i],
          isManage: false,
          estimatedWidth: estimateWidth(unbudgeted[i].name),
          originalIndex: i,
        ),
      );
    }
    pendingItems.add(
      UnbudgetedChipItem(
        category: null,
        isManage: true,
        estimatedWidth: estimateWidth('Manage'),
        originalIndex: unbudgeted.length,
      ),
    );

    final optimallyOrderedItems = <UnbudgetedChipItem>[];

    while (pendingItems.isNotEmpty) {
      final firstItem = pendingItems.removeAt(0);
      optimallyOrderedItems.add(firstItem);
      double currentX = firstItem.estimatedWidth;

      bool found = true;
      while (found) {
        found = false;
        int bestIndex = -1;
        double bestWidth = -1;

        for (int i = 0; i < pendingItems.length; i++) {
          final w = pendingItems[i].estimatedWidth;
          if (currentX + spacing + w <= maxRowWidth) {
            if (w > bestWidth) {
              bestWidth = w;
              bestIndex = i;
            }
          }
        }

        if (bestIndex != -1) {
          final fitItem = pendingItems.removeAt(bestIndex);
          optimallyOrderedItems.add(fitItem);
          currentX += spacing + bestWidth;
          found = true;
        }
      }
    }

    return optimallyOrderedItems;
  }
}
