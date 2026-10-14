import 'package:koin/core/utils/motion_policy.dart';
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/models.dart';

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
  final Key? fieldKey;
  final FormFieldValidator<String>? validator;
  final Currency? currency;

  const HeroAmountField({
    super.key,
    required this.controller,
    required this.currencySymbol,
    required this.primaryColor,
    this.onChanged,
    this.hintText = '0',
    this.autoFocus = false,
    this.fieldKey,
    this.validator,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isNotEmpty = value.text.isNotEmpty;
        final contentColor = AppTheme.contentColor(context, primaryColor);
        final hintColor = AppTheme.textLightColor(context);
        final amountStyle = KoinTypography.inputAmountStyle.copyWith(
          color: isNotEmpty ? contentColor : hintColor,
        );

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
                    fontSize: KoinTypography.screenTitle,
                    fontWeight: KoinTypography.labelWeight,
                    color: contentColor,
                  ),
                ),
                Flexible(
                  child: IntrinsicWidth(
                    child: TextFormField(
                      key: fieldKey,
                      controller: controller,
                      validator: (text) {
                        if (currency != null &&
                            text != null &&
                            text.trim().isNotEmpty &&
                            currency!.tryParseInput(text) == null) {
                          return currency!.decimalDigits == 0
                              ? 'Enter a whole amount with valid number grouping'
                              : 'Use at most ${currency!.decimalDigits} decimal places and valid number grouping';
                        }
                        return validator?.call(text);
                      },
                      textInputAction: TextInputAction.done,
                      autofocus: autoFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: amountStyle,
                      decoration: InputDecoration(
                        hintText: hintText,
                        errorMaxLines: 3,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        filled: true,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: amountStyle.copyWith(color: hintColor),
                      ),
                      onChanged: (text) {
                        onChanged?.call(text);
                      },
                    ),
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: KoinMotion.duration(
                context,
                const Duration(milliseconds: 200),
              ),
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
