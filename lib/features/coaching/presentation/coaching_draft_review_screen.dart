import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';

/// A generated draft is unsaved even before the student edits its first word.
class CoachingDraftReviewScreen extends StatefulWidget {
  const CoachingDraftReviewScreen({
    required this.title,
    required this.description,
    required this.draft,
    required this.save,
    this.maxLength = 12000,
    this.unsavedInitially = true,
    super.key,
  });
  final String title;
  final String description;
  final String draft;
  final int maxLength;
  final bool unsavedInitially;
  final Future<void> Function(String draft) save;

  @override
  State<CoachingDraftReviewScreen> createState() =>
      _CoachingDraftReviewScreenState();
}

class _CoachingDraftReviewScreenState extends State<CoachingDraftReviewScreen> {
  late final _draft = TextEditingController(text: widget.draft);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _confirming = false;
  bool _allowPop = false;
  String? _error;

  bool get _dirty => widget.unsavedInitially || _draft.text != widget.draft;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _confirming || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(_draft.text.trim());
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _busy = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Saved successfully.')));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is ApiException
              ? error.message
              : 'Could not save. Your draft is still here. Please try again.';
        });
      }
    }
  }

  Future<void> _leave() async {
    if (_busy || _confirming) return;
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Discard unsaved changes?'),
        content: AppText(
          widget.unsavedInitially
              ? 'This draft has not been saved.'
              : 'Your changes have not been saved.',
        ),
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
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _allowPop = discard == true;
    });
    if (_allowPop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: (_allowPop || !_dirty) && !_busy && !_confirming,
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
                  // The description can include original AI/provider text.
                  Text(widget.description),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _draft,
                    enabled: !_busy,
                    minLines: 12,
                    maxLines: null,
                    maxLength: widget.maxLength,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(context, 'Personal statement'),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? AppStrings.tr(context, 'Enter your statement.')
                        : null,
                  ),
                  if (_error != null)
                    Semantics(liveRegion: true, child: AppText(_error!)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || _confirming ? null : _save,
                    child: AppText(_busy ? 'Saving…' : 'Save'),
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
