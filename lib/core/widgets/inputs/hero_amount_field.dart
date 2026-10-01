import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Consolidated hero amount input field module for entity creation forms
/// (Savings Goals, Debts, Cashflow Schedules).
/// Encapsulates the currency baseline layout, auto-expanding IntrinsicWidth,
/// 48pt typography, and animated accent underline bar.
class HeroAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final Color primaryColor;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool autoFocus;

  const HeroAmountField({
    super.key,
    required this.controller,
    required this.currencySymbol,
    required this.primaryColor,
    this.onChanged,
    this.hintText = '0',
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isNotEmpty = value.text.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$currencySymbol ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: primaryColor.withValues(alpha: 0.5),
                  ),
                ),
                IntrinsicWidth(
                  child: TextFormField(
                    controller: controller,
                    autofocus: autoFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: !isNotEmpty
                          ? primaryColor.withValues(alpha: 0.35)
                          : primaryColor,
                      letterSpacing: -2,
                      height: 1.1,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(
                        color: primaryColor.withValues(alpha: 0.35),
                      ),
                    ),
                    onChanged: (text) {
                      onChanged?.call(text);
                    },
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isNotEmpty ? 60 : 40,
              height: 3,
              margin: const EdgeInsets.only(top: 8, bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: primaryColor.withValues(alpha: isNotEmpty ? 0.35 : 0.15),
              ),
            ),
          ],
        );
      },
    );
  }
}
