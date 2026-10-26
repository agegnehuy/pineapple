import 'package:flutter/material.dart';
import 'package:myoccasio/core/files/document_export.dart';
import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/profile_resume.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({
    required this.repository,
    this.pickDocument = selectResume,
    this.export = exportDocument,
    super.key,
  });
  final ProfileRepository repository;
  final DocumentPicker pickDocument;
  final DocumentExporter export;

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  ProfileResume? _resume;
  ({String name, List<int> bytes})? _selected;
  bool _loaded = false;
  bool _busy = false;
  bool _blockNavigation = false;
  bool _confirming = false;
  bool _metadataUncertain = false;
  String? _error;
  Future<void> Function()? _retry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _perform(
    Future<void> Function() action,
    Future<void> Function() retry, {
    bool blockNavigation = false,
  }) async {
    if (_busy || _confirming) return;
    setState(() {
      _busy = true;
      _blockNavigation = blockNavigation;
      _error = null;
      _retry = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException
              ? error.message
              : 'Could not update your résumé. Please try again.';
          _retry = _metadataUncertain ? _load : retry;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _blockNavigation = false;
        });
      }
    }
  }

  Future<void> _load() => _perform(() async {
    final resume = await widget.repository.getResume();
    if (mounted) {
      setState(() {
        _resume = resume;
        _loaded = true;
        _metadataUncertain = false;
      });
    }
  }, _load);

  Future<void> _choose() => _perform(() async {
    final selected = await readSelectedDocument(widget.pickDocument);
    if (selected == null || !mounted) return;
    if (!RegExp(
      r'\.(pdf|docx)$',
      caseSensitive: false,
    ).hasMatch(selected.name)) {
      throw const ApiException('Choose a PDF or DOCX résumé.');
    }
    setState(() => _selected = selected);
  }, _choose);

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null || _busy || _confirming || _metadataUncertain) return;
    if (_resume != null) {
      setState(() => _confirming = true);
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const AppText('Replace saved résumé?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Your current résumé will be replaced by this file.',
              ),
              const SizedBox(height: 12),
              Text(selected.name),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Replace résumé'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (replace != true) return;
    }
    await _perform(
      () async {
        final ProfileResume resume;
        try {
          resume = await widget.repository.saveResume(
            selected.name,
            selected.bytes,
          );
        } on Object {
          // A lost response can still mean the backend saved the file.
          // Retain the selected bytes and reconcile metadata before file actions.
          if (mounted) setState(() => _blockNavigation = false);
          try {
            final latest = await widget.repository.getResume();
            if (mounted) setState(() => _resume = latest);
          } on Object {
            if (mounted) setState(() => _metadataUncertain = true);
          }
          rethrow;
        }
        if (!mounted) return;
        setState(() {
          _resume = resume;
          _selected = null;
        });
        _success('Résumé saved');
      },
      _save,
      blockNavigation: true,
    );
  }

  Future<void> _download() => _perform(() async {
    final file = await widget.repository.downloadResumeFile();
    // A popped route can remain mounted during its exit animation.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _blockNavigation = true);
    final saved = await widget.export(file.name, file.mimeType, file.bytes);
    if (saved && mounted) _success('Copy saved to your chosen location.');
  }, _download);

  Future<void> _remove() async {
    if (_busy) return;
    // Lock page navigation too while the confirmation performs its mutation.
    setState(() {
      _busy = true;
      _blockNavigation = true;
    });
    final removed = await confirmAction(
      context,
      title: 'Remove saved résumé?',
      message:
          'This removes the résumé from your profile. Copies you downloaded stay on your device.',
      actionLabel: 'Remove résumé',
      action: widget.repository.removeResume,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _blockNavigation = false;
      if (removed) {
        _resume = null;
        _error = null;
      }
    });
    if (removed) _success('Résumé removed');
  }

  void _success(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(message)));

  Future<void> _leave() async {
    if (_blockNavigation || _confirming || _selected == null) return;
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Discard selected file?'),
        content: const AppText('This file has not been saved to your profile.'),
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
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (discard == true) _selected = null;
    });
    if (discard == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_blockNavigation && !_confirming && _selected == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: const AppText('Your résumé')),
      body: !_loaded && _error == null
          ? const AppLoadingView()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AppText(
                  'Your experience, ready to share.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                const AppText(
                  'Save a PDF or DOCX up to 4 MB to your profile. You choose when to share it.',
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(liveRegion: true, child: AppText(_error!)),
                          TextButton(
                            onPressed: _busy ? null : _retry,
                            child: const AppText('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_loaded)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _resume == null
                                ? Icons.upload_file_outlined
                                : Icons.description_outlined,
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          AppText(
                            _resume == null
                                ? 'No résumé saved yet'
                                : 'Saved résumé',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_resume != null) ...[
                            Text(_resume!.name),
                            Text('${(_resume!.size / 1024).ceil()} KB'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      _busy || _confirming || _metadataUncertain
                                      ? null
                                      : _download,
                                  icon: const Icon(Icons.download_outlined),
                                  label: const AppText('Save a copy'),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      _busy || _confirming || _metadataUncertain
                                      ? null
                                      : _remove,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const AppText('Remove résumé'),
                                ),
                              ],
                            ),
                          ] else
                            const AppText(
                              'Keep your experience close for your next opportunity.',
                            ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed:
                                _busy || _confirming || _metadataUncertain
                                ? null
                                : _choose,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: AppText(
                              _resume == null
                                  ? 'Choose a résumé'
                                  : 'Choose replacement',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_selected != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Review before you save',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(_selected!.name),
                          Text('${(_selected!.bytes.length / 1024).ceil()} KB'),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                onPressed:
                                    _busy || _confirming || _metadataUncertain
                                    ? null
                                    : _save,
                                child: const AppText('Save résumé'),
                              ),
                              TextButton(
                                onPressed: _busy || _confirming
                                    ? null
                                    : () => setState(() {
                                        _selected = null;
                                        if (!_metadataUncertain) _error = null;
                                      }),
                                child: const AppText('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: AppBusyIndicator()),
                  ),
                const SizedBox(height: 24),
                const AppText(
                  'Saving here does not submit an application or send your résumé to a provider.',
                ),
              ],
            ),
    ),
  );
}
