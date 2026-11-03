---
version: 1
slug: "budgets-widgets-budget-editor-sheet-dart-eef6571f"
primary_target: "lib/features/budgets/widgets/budget_editor_sheet.dart"
related_targets: ["lib/features/budgets/budgets_screen.dart","lib/features/budgets/widgets/budget_category_picker_sheet.dart","lib/features/dashboard/widgets/budget_progress_card.dart"]
---

# Shared monthly budgets

Mode: Operate. Extend the existing Android budget editor and budget rows.

## Direction contract

THESIS: Food and Drinks remain separate transaction categories while consuming one recurring budget without a prescribed split.

OWN-WORLD: Preserve Koin's Outfit typography, teal controls, themed sheet surface, keypad, and flat budget rows.

STORY: Add budget, choose Food and Drinks as equal categories, then Continue to set one limit. Existing budgets expose a visible Categories field with Apply categories. Both selection actions are staged; budget changes persist only on Save.

FIRST VIEWPORT: Keep Add budget as the primary action and preserve the staggered unbudgeted category chips below it, with their existing wrap packing, icons, and reduced-motion-aware reveal. A chip starts the new picker with its category selected. The searchable multi-select sheet has checkboxes, a selection count and a pinned Continue action. The budget editor shows a neutral header, a visible Categories field with equal selected names, the existing limit controls and keypad. Confirm any moves from existing budgets before committing them together.

FORM: User-confirmed budget-first flow within the incumbent visual system. seed: none (unavailable). The signature interaction is selecting a budget's coverage before its limit; neither Food nor Drinks is presented as an owner. Either category can be removed, and moving categories preserves any remaining budget's limit.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Verification boundary

Widget renders are layout diagnostics. No Android device or emulator is available, so native appearance and device behavior remain unverified. No new production raster assets or design-system changes.
