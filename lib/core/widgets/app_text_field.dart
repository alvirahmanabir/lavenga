import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

/// Standard form field: label above, helper/error below, optional password
/// toggle and read-only (locked) mode for registered email and phone.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.prefixIcon,
    this.hint,
    this.helper,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.inputFormatters,
    this.initialValue,
    this.autofillHints,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final IconData? prefixIcon;
  final String? hint;
  final String? helper;
  final int maxLines;
  final int? maxLength;

  /// Locked fields show a lock icon and cannot be edited (e.g. registered email).
  final bool readOnly;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final String? initialValue;
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget? suffix = widget.suffix;
    if (widget.obscure) {
      suffix = IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _hidden = !_hidden),
      );
    } else if (widget.readOnly) {
      suffix = const Icon(Icons.lock_outline, size: 18, color: AppColors.mutedText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: text.labelLarge),
        const SizedBox(height: AppSpacing.xs + 2),
        TextFormField(
          controller: widget.controller,
          initialValue: widget.controller == null ? widget.initialValue : null,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _hidden,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: text.bodyLarge?.copyWith(
            color: widget.readOnly ? AppColors.mutedText : AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 2,
            prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 20),
            suffixIcon: suffix,
            fillColor: widget.readOnly ? AppColors.paper : AppColors.card,
          ),
        ),
      ],
    );
  }
}

/// Search box with debounced change callback (SRS: debounce keyword input).
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search studios, spaces, codes',
    this.initialValue = '',
    this.debounce = const Duration(milliseconds: 300),
    this.autofocus = false,
    this.onTap,
    this.readOnly = false,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String initialValue;
  final Duration debounce;
  final bool autofocus;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(v.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: widget.hint,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _timer?.cancel();
          widget.onChanged(v.trim());
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty || widget.readOnly
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }
}
