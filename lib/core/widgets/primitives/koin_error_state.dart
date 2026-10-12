import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Friendly failure feedback with an explicit, provider-specific retry.
class KoinErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const KoinErrorState({
    super.key,
    required this.onRetry,
    this.message = 'Could not load this information.',
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textColor(context)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
