import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';

class DataField {
  const DataField(
    this.key,
    this.label, {
    this.required = false,
    this.maxLength = 180,
    this.lines = 1,
    this.options,
    this.numeric = false,
    this.validate,
  });
  final String key;
  final String label;
  final bool required;
  final int maxLength;
  final int lines;
  final Map<String, String>? options;
  final bool numeric;
  final String? Function(String)? validate;
}

/// A scrollable editor with draft retention and explicit server confirmation.
class DataFormScreen extends StatefulWidget {
  const DataFormScreen({
    required this.title,
    required this.fields,
    required this.save,
    this.initial = const {},
    this.description,
    this.submitLabel = 'Save',
    super.key,
  });
  final String title;
  final String? description;
  final String submitLabel;
  final List<DataField> fields;
  final Map<String, String> initial;
  final Future<void> Function(Map<String, String>) save;
  @override
  State<DataFormScreen> createState() => _DataFormScreenState();
}

class _DataFormScreenState extends State<DataFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: widget.initial[field.key] ?? ''),
  };
  bool _busy = false;
  bool _allowPop = false;
  String? _error;
  bool get _dirty => _controllers.entries.any(
    (e) => e.value.text != (widget.initial[e.key] ?? ''),
  );
  @override
  void initState() {
    super.initState();
    for (final controller in _controllers.values) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    // ListView may dispose offscreen form fields. Validate their retained
    // controllers as well before sending any data to the backend.
    for (final field in widget.fields) {
      final value = _controllers[field.key]!.text.trim();
      final error = field.required && value.isEmpty
          ? '${field.options == null ? 'Enter' : 'Choose'} ${field.label.toLowerCase()}.'
          : field.validate?.call(value);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save({
        for (final field in widget.fields)
          field.key: field.numeric
              ? _controllers[field.key]!.text.trim().replaceAll(',', '.')
              : _controllers[field.key]!.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Saved successfully.')));
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } on Object catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'Could not save. Your draft is still here. Please try again.';
        setState(() {
          _busy = false;
          _error = message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(message)));
      }
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Discard unsaved changes?'),
        content: const AppText('Your changes have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: AppText(widget.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (widget.description != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: AppText(widget.description!),
                    ),
                  AbsorbPointer(
                    absorbing: _busy,
                    child: Column(
                      children: [
                        for (final field in widget.fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: field.options != null
                                ? DropdownButtonFormField<String>(
                                    initialValue:
                                        field.options!.containsKey(
                                          _controllers[field.key]!.text,
                                        )
                                        ? _controllers[field.key]!.text
                                        : null,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: AppStrings.tr(
                                        context,
                                        field.label,
                                      ),
                                    ),
                                    items: [
                                      for (final e in field.options!.entries)
                                        DropdownMenuItem(
                                          value: e.key,
                                          child: AppText(e.value),
                                        ),
                                    ],
                                    onChanged: (value) =>
                                        _controllers[field.key]!.text =
                                            value ?? '',
                                    validator: (value) =>
                                        field.required &&
                                            (value?.isEmpty ?? true)
                                        ? AppStrings.tr(
                                            context,
                                            'Choose ${field.label.toLowerCase()}.',
                                          )
                                        : null,
                                  )
                                : TextFormField(
                                    controller: _controllers[field.key],
                                    maxLength: field.maxLength,
                                    minLines: field.lines,
                                    maxLines: field.lines == 1
                                        ? 1
                                        : field.lines + 3,
                                    keyboardType: field.numeric
                                        ? const TextInputType.numberWithOptions(
                                            decimal: true,
                                          )
                                        : field.lines > 1
                                        ? TextInputType.multiline
                                        : TextInputType.text,
                                    decoration: InputDecoration(
                                      labelText: AppStrings.tr(
                                        context,
                                        field.label,
                                      ),
                                      alignLabelWithHint: field.lines > 1,
                                    ),
                                    validator: (value) {
                                      final text = (value ?? '').trim();
                                      if (field.required && text.isEmpty) {
                                        return AppStrings.tr(
                                          context,
                                          'Enter ${field.label.toLowerCase()}.',
                                        );
                                      }
                                      return AppStrings.error(
                                        context,
                                        field.validate?.call(text),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: AppText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: AppBusyIndicator(label: 'Saving'),
                          )
                        : AppText(widget.submitLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? validateNumber(
  String value, {
  required double min,
  required double max,
  bool optional = false,
}) {
  if (optional && value.isEmpty) return null;
  final number = double.tryParse(value.trim().replaceAll(',', '.'));
  return number == null || !number.isFinite || number < min || number > max
      ? 'Enter a number from $min to $max.'
      : null;
}

String? validateCalendarDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          parsed.toIso8601String().substring(0, 10) != value
      ? 'Use a valid date in YYYY-MM-DD format.'
      : null;
}
