import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

class KoinEntityNameField extends StatelessWidget {
  const KoinEntityNameField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.hintText,
    this.label = 'Name',
    this.focusNode,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;
  final String label;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final style = KoinTypography.entityNameStyle.copyWith(
      color: AppTheme.textColor(context),
    );
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      onChanged: onChanged,
      textAlign: TextAlign.center,
      textCapitalization: textCapitalization,
      textInputAction: TextInputAction.next,
      style: style,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          color: AppTheme.textLightColor(context),
          fontSize: KoinTypography.caption,
        ),
        hintText: hintText,
        hintMaxLines: 2,
        hintStyle: style.copyWith(color: AppTheme.fieldHintColor(context)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

class KoinNotesField extends StatelessWidget {
  const KoinNotesField({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Notes (Optional)',
    this.focusNode,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    style: Theme.of(context).textTheme.bodyLarge,
    minLines: 1,
    maxLines: 4,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: AppTheme.fieldHintColor(context)),
    ),
  );
}
