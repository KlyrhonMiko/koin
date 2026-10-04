import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Keeps editor styling local so dashboard cards and light mode stay unchanged.
class KoinFormTheme extends StatelessWidget {
  final WidgetBuilder builder;

  const KoinFormTheme({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness != Brightness.dark) {
      return Builder(builder: builder);
    }
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.65)),
    );
    return Theme(
      data: theme.copyWith(
        extensions: [...theme.extensions.values, const EditorAppearance()],
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          fillColor: theme.colorScheme.surface,
          hintStyle: theme.textTheme.bodyMedium,
          labelStyle: theme.textTheme.bodyMedium,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
        ),
      ),
      child: Builder(builder: builder),
    );
  }
}
