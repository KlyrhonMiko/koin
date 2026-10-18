import 'package:flutter/material.dart';

/// Shared entity-editor layout. Forms and save state belong to each feature.
class KoinEntityFormBody extends StatelessWidget {
  const KoinEntityFormBody({
    super.key,
    required this.form,
    required this.action,
  });
  final Widget form;
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: form,
            ),
          ),
        ),
      ),
      SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: action,
          ),
        ),
      ),
    ],
  );
}
