import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/icons.dart';

/// Borderless search input for a header or a search/filter capsule.
class KoinSearchField extends StatefulWidget {
  const KoinSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.inline = false,
    this.autofocus = false,
    this.value,
  });
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool inline;
  final bool autofocus;
  final String? value;

  @override
  State<KoinSearchField> createState() => _KoinSearchFieldState();
}

class _KoinSearchFieldState extends State<KoinSearchField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(KoinSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != null && value != _controller.text) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inline = widget.inline;
    final size = inline ? KoinTypography.itemTitle : KoinTypography.compact;
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: (value) {
        setState(() {});
        widget.onChanged(value);
      },
      style: TextStyle(
        color: AppTheme.textColor(context),
        fontSize: size,
        fontWeight: inline
            ? KoinTypography.supportingWeight
            : KoinTypography.labelWeight,
      ),
      decoration: InputDecoration(
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
                icon: const Icon(KoinIcons.x, size: 18),
              ),
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: AppTheme.textLightColor(context)
              .withValues(alpha: inline ? 1 : 0.4),
          fontSize: size,
          fontWeight: KoinTypography.supportingWeight,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: inline
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
