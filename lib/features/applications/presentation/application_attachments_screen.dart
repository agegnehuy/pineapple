import 'package:flutter/material.dart';
import 'package:myoccasio/core/files/document_export.dart';
import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/application_attachment.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class ApplicationAttachmentsScreen extends StatefulWidget {
  const ApplicationAttachmentsScreen({
    required this.repository,
    required this.opportunityId,
    required this.limits,
    this.submittedAttachments,
    this.pickDocument = selectResume,
    this.export = exportDocument,
    super.key,
  });
  final ApplicationsRepository repository;
  final String opportunityId;
  final ApplicationAttachmentLimits limits;
  final List<ApplicationAttachment>? submittedAttachments;
  final DocumentPicker pickDocument;
  final DocumentExporter export;
  @override
  State<ApplicationAttachmentsScreen> createState() =>
      _ApplicationAttachmentsScreenState();
}

class _ApplicationAttachmentsScreenState
    extends State<ApplicationAttachmentsScreen> {
  List<ApplicationAttachment> _files = [];
  ({String name, List<int> bytes})? _selected;
  bool _loaded = false,
      _busy = false,
      _blocking = false,
      _confirming = false,
      _uncertain = false;
  String? _error;
  Future<void> Function()? _retry;
  bool get _submitted => widget.submittedAttachments != null;

  @override
  void initState() {
    super.initState();
    if (_submitted) {
      _files = List.of(widget.submittedAttachments!);
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _readFiles() async {
    final files = await widget.repository.getAttachments(widget.opportunityId);
    if (mounted) {
      setState(() {
        _files = files;
        _loaded = true;
        _uncertain = false;
      });
    }
  }

  Future<void> _perform(
    Future<void> Function() action,
    Future<void> Function() retry, {
    bool block = false,
  }) async {
    if (_busy || _confirming) return;
    setState(() {
      _busy = true;
      _blocking = block;
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
              : 'Could not update the supporting documents. Please try again.';
          _retry = _uncertain || _files.length >= widget.limits.maxCount
              ? _load
              : retry;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _blocking = false;
        });
      }
    }
  }

  Future<void> _load() => _perform(_readFiles, _load);

  Future<void> _choose() => _perform(
    () async {
      final selected = await readSelectedDocument(widget.pickDocument);
      if (selected == null || !mounted) return;
      final mime = selected.name.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : applicationDocxMime;
      if (!validApplicationDocument(selected.name, mime)) {
        throw const ApiException('Choose a PDF or DOCX document.');
      }
      setState(() => _selected = selected);
    },
    _choose,
    block: true,
  );

  Future<void> _save({bool profile = false}) async {
    if (_busy ||
        _confirming ||
        _uncertain ||
        _submitted ||
        (!profile && _selected == null)) {
      return;
    }
    if (_files.length >= widget.limits.maxCount) return;
    await _perform(
      () async {
        try {
          final file = profile
              ? await widget.repository.attachProfileResume(
                  widget.opportunityId,
                )
              : await widget.repository.uploadAttachment(
                  widget.opportunityId,
                  _selected!.name,
                  _selected!.bytes,
                );
          if (!mounted) return;
          setState(() {
            _files = [..._files.where((old) => old.id != file.id), file];
            if (!profile) _selected = null;
          });
          _success('Supporting document saved privately.');
        } on Object {
          // A failed response may follow a completed upload. Reconcile with a
          // read before another explicit mutation; never retry an upload itself.
          try {
            await _readFiles();
          } on Object {
            if (mounted) setState(() => _uncertain = true);
          }
          rethrow;
        }
      },
      profile ? _attachResume : _save,
      block: true,
    );
  }

  Future<void> _attachResume() async {
    if (_busy || _confirming) return;
    setState(() => _confirming = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Attach saved résumé?'),
        content: const AppText(
          'Add a private copy of your current profile résumé to this application. It will be shared only after you review and submit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Attach résumé'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (accepted == true) await _save(profile: true);
  }

  Future<void> _remove(ApplicationAttachment file) async {
    if (_busy || _confirming || _uncertain) return;
    setState(() {
      _confirming = true;
      _blocking = true;
    });
    final removed = await confirmAction(
      context,
      title: 'Remove supporting document?',
      message:
          'This removes the private file from this application. Previously submitted copies stay unchanged.',
      actionLabel: 'Remove document',
      action: () =>
          widget.repository.removeAttachment(widget.opportunityId, file.id),
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _blocking = false;
      if (removed) {
        _files = _files.where((old) => old.id != file.id).toList();
        _error = null;
      }
    });
    if (removed) {
      _success('Supporting document removed.');
    } else {
      await _load();
    }
  }

  Future<void> _download(ApplicationAttachment file) => _perform(() async {
    final download = await widget.repository.downloadAttachment(
      widget.opportunityId,
      file.id,
      submitted: _submitted,
    );
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _blocking = true);
    final saved = await widget.export(
      download.name,
      download.mimeType,
      download.bytes,
    );
    if (saved && mounted) _success('Copy saved to your chosen location.');
  }, () => _download(file));

  void _success(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(text)));

  Future<void> _leave() async {
    if (_blocking || _confirming || _selected == null) return;
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Discard selected file?'),
        content: const AppText(
          'This file has not been added to your application.',
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
    canPop: !_blocking && !_confirming && _selected == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: AppText(
          _submitted ? 'Submitted documents' : 'Supporting documents',
        ),
      ),
      bottomNavigationBar: _submitted
          ? WorkspaceBottomBar(enabled: !_blocking && !_confirming)
          : null,
      body: !_loaded && _error == null
          ? const AppLoadingView()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AppText(
                  _submitted
                      ? 'The copies you shared.'
                      : 'A little evidence goes a long way.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                AppText(
                  _submitted
                      ? 'Submitted copies stay unchanged when you edit or remove your private documents.'
                      : 'Up to 3 PDF or DOCX files, 4 MB each. Uploading keeps them private until you review and submit.',
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
                if (_loaded && _files.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.description_outlined,
                    title: 'No supporting documents',
                    message:
                        'Only files you add and review will be included when you submit.',
                  ),
                for (final file in _files)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.fileName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('${(file.byteSize / 1024).ceil()} KB'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy || _confirming || _uncertain
                                    ? null
                                    : () => _download(file),
                                icon: const Icon(Icons.download_outlined),
                                label: const AppText('Save a copy'),
                              ),
                              if (!_submitted)
                                TextButton.icon(
                                  onPressed: _busy || _confirming || _uncertain
                                      ? null
                                      : () => _remove(file),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const AppText('Remove document'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_submitted && _loaded) ...[
                  const SizedBox(height: 16),
                  if (_files.length >= widget.limits.maxCount)
                    const AppText(
                      'You have reached the 3-document limit. Remove a file before adding another.',
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _busy ||
                                _confirming ||
                                _uncertain ||
                                _files.length >= widget.limits.maxCount
                            ? null
                            : _choose,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const AppText('Choose document'),
                      ),
                      OutlinedButton(
                        onPressed:
                            _busy ||
                                _confirming ||
                                _uncertain ||
                                _files.length >= widget.limits.maxCount
                            ? null
                            : _attachResume,
                        child: const AppText('Use saved résumé'),
                      ),
                    ],
                  ),
                ],
                if (_selected != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText('Review selected file'),
                          const SizedBox(height: 12),
                          Text(_selected!.name),
                          Text('${(_selected!.bytes.length / 1024).ceil()} KB'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                onPressed:
                                    _busy ||
                                        _confirming ||
                                        _uncertain ||
                                        _files.length >= widget.limits.maxCount
                                    ? null
                                    : _save,
                                child: const AppText('Upload privately'),
                              ),
                              TextButton(
                                onPressed: _busy || _confirming
                                    ? null
                                    : () => setState(() => _selected = null),
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
                if (!_submitted) ...[
                  const SizedBox(height: 24),
                  const AppText(
                    'Check the provider’s requirements. Attaching a file does not submit an application.',
                  ),
                ],
              ],
            ),
    ),
  );
}
