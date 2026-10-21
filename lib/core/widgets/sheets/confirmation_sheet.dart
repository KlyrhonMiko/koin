import 'package:koin/core/utils/motion_policy.dart';
import 'package:flutter/material.dart';

import 'koin_sheet_surface.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/snackbar_utils.dart';

import '../primitives/koin_bottom_sheet_handle.dart';

class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({
    super.key,
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    required this.confirmColor,
    required this.icon,
    this.isDanger = false,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final IconData icon;
  final bool isDanger;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String description,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    required Color confirmColor,
    required IconData icon,
    bool isDanger = false,
  }) {
    KoinSnackBar.dismiss(context);
    HapticService.medium();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmationSheet(
        title: title,
        description: description,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmColor: confirmColor,
        icon: icon,
        isDanger: isDanger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KoinSheetSurface(
      padding: EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        12,
        KoinSpacing.screenInset,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      color: AppTheme.surfaceColor(context),
      shadows: [
        AppTheme.boxShadow(
          context,
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 40,
          offset: const Offset(0, -10),
        ),
      ],
      child: SingleChildScrollView(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Handle
      const KoinBottomSheetHandle(padding: EdgeInsets.only(bottom: 32)),

      // Icon with glow
      Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [
                AppTheme.boxShadow(
                  context,
                  color: confirmColor.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, size: 42, color: confirmColor),
          )
          .koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
          )
          .scale(
            begin: const Offset(0.95, 0.95),
            duration: 250.ms,
            curve: KoinMotion.curve,
          )
          .fadeIn(duration: 300.ms),
      const Gap(24),

      // Text content
      Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: KoinTypography.screenTitle,
              fontWeight: KoinTypography.headingWeight,
              color: AppTheme.textColor(context),
              letterSpacing: KoinTypography.headingTracking,
            ),
          )
          .koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
          )
          .fadeIn(delay: 100.ms, duration: 300.ms)
          .slideY(begin: 0.15, duration: 300.ms, curve: Curves.easeOutCubic),
      const Gap(12),
      Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: KoinTypography.body,
                color: AppTheme.textLightColor(context),
                height: 1.5,
                fontWeight: KoinTypography.supportingWeight,
              ),
            ),
          )
          .koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
          )
          .fadeIn(delay: 180.ms, duration: 300.ms)
          .slideY(begin: 0.15, duration: 300.ms, curve: Curves.easeOutCubic),
      const Gap(40),

      // Actions
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                HapticService.light();
                Navigator.pop(context, false);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                cancelLabel,
                style: TextStyle(
                  fontSize: KoinTypography.itemTitle,
                  fontWeight: KoinTypography.titleWeight,
                  color: AppTheme.textLightColor(context),
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  AppTheme.boxShadow(
                    context,
                    color: confirmColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  HapticService.medium();
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: AppTheme.foregroundFor(confirmColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontSize: KoinTypography.itemTitle,
                    fontWeight: KoinTypography.headingWeight,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
