import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/profile_options.dart';
import 'package:myoccasio/features/profile/presentation/edit_profile_screen.dart';

class ImportProfileScreen extends StatefulWidget {
  const ImportProfileScreen({
    required this.repository,
    this.pickDocument = selectDocument,
    super.key,
  });
  final ProfileRepository repository;
  final DocumentPicker pickDocument;
  @override
  State<ImportProfileScreen> createState() => _ImportProfileScreenState();
}

class _ImportProfileScreenState extends State<ImportProfileScreen> {
  final _text = TextEditingController();
  final _textFocus = FocusNode();
  final _pasteKey = GlobalKey();
  List<Map<String, dynamic>>? _suggestions;
  final _applied = <String>{};
  bool _busy = false;
  bool _writePending = false;
  bool _confirmingApply = false;
  bool _confirmingLeave = false;
  bool _allowPop = false;
  String? _error;
  bool get _hasDraft =>
      _text.text.trim().isNotEmpty ||
      (_suggestions ?? const []).any(
        (suggestion) =>
            writableImportFields.contains(suggestion['field']) &&
            !_applied.contains(suggestion['field']),
      );
  @override
  void initState() {
    super.initState();
    _text.addListener(_draftChanged);
  }

  void _draftChanged() => setState(() {});

  Future<void> _pasteDetails() async {
    _textFocus.requestFocus();
    final target = _pasteKey.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.15,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
    }
  }

  Future<void> _confirmLeave() async {
    if (_writePending || _confirmingApply || _confirmingLeave) return;
    _confirmingLeave = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Discard this import?'),
        content: const AppText(
          'Applied fields stay saved. Unapplied suggestions and pasted text will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Discard'),
          ),
        ],
      ),
    );
    _confirmingLeave = false;
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _editManually() async {
    if (_busy || _confirmingApply) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.getCurrentUser();
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfileScreen(
            profile: profile,
            repository: widget.repository,
          ),
        ),
      );
      if (mounted && changed == true) {
        setState(() {
          _suggestions = null;
          _applied.clear();
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not load your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await readSelectedDocument(widget.pickDocument);
      if (file == null ||
          !mounted ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final suggestions = await widget.repository.suggestFileImport(
        file.name,
        file.bytes,
      );
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _applied.clear();
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not read this file. Try pasting its text instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.removeListener(_draftChanged);
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final suggestions = await widget.repository.suggestImport(_text.text);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _applied.clear();
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not read your profile text. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(Map<String, dynamic> suggestion) async {
    if (_busy || _confirmingApply) return;
    final field = suggestion['field'].toString();
    if (!writableImportFields.contains(field)) {
      return;
    }
    setState(() => _confirmingApply = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: AppText(
          suggestion['conflict'] == true
              ? 'Replace this profile field?'
              : 'Apply this suggestion?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(importedProfileLabels[field] ?? 'Imported information'),
            const SizedBox(height: 12),
            const AppText('Current value'),
            suggestion['current'] == null
                ? const AppText('Empty')
                : Text(suggestion['current'].toString()),
            const SizedBox(height: 12),
            const AppText('Suggested value'),
            Text(suggestion['value'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Apply'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirmingApply = false);
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _writePending = true;
    });
    try {
      await widget.repository.updateProfile({field: suggestion['value']});
      if (mounted) setState(() => _applied.add(field));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              error is ApiException
                  ? error.message
                  : 'Could not save this field. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _writePending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_writePending && !_confirmingApply && !_hasDraft),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmLeave();
    },
    child: Scaffold(
      appBar: AppBar(title: const AppText('Import profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              'You’ve already done a lot.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            const AppText(
              'Paste text from your résumé or LinkedIn export. Review every suggestion before applying it. Importing does not change your profile automatically.',
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                minTileHeight: 88,
                title: const AppText('Upload a résumé'),
                subtitle: const AppText('Choose a document from your device.'),
                trailing: const Icon(Icons.upload_file_outlined),
                onTap: _busy ? null : _upload,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                minTileHeight: 88,
                title: const AppText('Paste LinkedIn details'),
                subtitle: const AppText(
                  'Use text from your profile or export.',
                ),
                trailing: const Icon(Icons.person_outline),
                onTap: _busy ? null : _pasteDetails,
              ),
            ),
            const SizedBox(height: 20),
            const AppText('Review before you save'),
            const SizedBox(height: 8),
            const AppText(
              'Imported details are suggestions. Confirm each field before updating your profile.',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _upload,
              icon: const Icon(Icons.upload_file),
              label: const AppText('Choose résumé file · up to 4 MB'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: _pasteKey,
              controller: _text,
              focusNode: _textFocus,
              enabled: !_busy,
              minLines: 6,
              maxLines: 14,
              maxLength: 48000,
              decoration: InputDecoration(
                labelText: AppStrings.tr(context, 'Résumé or profile text'),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: AppText(_error!)),
            FilledButton(
              onPressed: _busy ? null : _extract,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: AppBusyIndicator(),
                    )
                  : const AppText('Review suggestions'),
            ),
            if (_suggestions != null) ...[
              const SizedBox(height: 24),
              if (_suggestions!.isEmpty)
                const AppText(
                  'No profile fields were found. Try adding more detail, or edit your profile manually.',
                ),
              for (final suggestion in _suggestions!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            importedProfileLabels[suggestion['field']] ??
                                'Imported information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(suggestion['value'].toString()),
                          if (suggestion['conflict'] == true)
                            AppText('Replaces: ${suggestion['current']}'),
                          if (suggestion['field'] == 'email')
                            const AppText('Email is shown for comparison only.')
                          else if (writableImportFields.contains(
                            suggestion['field'],
                          ))
                            TextButton(
                              onPressed:
                                  _busy ||
                                      _applied.contains(suggestion['field'])
                                  ? null
                                  : () => _apply(suggestion),
                              child: AppText(
                                _applied.contains(suggestion['field'])
                                    ? 'Applied'
                                    : 'Apply this field',
                              ),
                            )
                          else
                            const AppText('Shown for reference only.'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy ? null : _editManually,
              child: const AppText('Enter details myself'),
            ),
          ],
        ),
      ),
    ),
  );
}
