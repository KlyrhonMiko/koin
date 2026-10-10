import 'package:flutter/material.dart';
import 'koin_empty_state.dart';

/// An activity placeholder using the app's shared empty-state design.
class KoinActivityEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const KoinActivityEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => KoinEmptyState(
    contentKey: const ValueKey('activity_empty_content'),
    icon: Icons.receipt_long_rounded,
    title: title,
    subtitle: subtitle,
  );
}
