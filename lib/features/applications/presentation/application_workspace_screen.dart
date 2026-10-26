import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/files/document_export.dart';
import 'package:myoccasio/features/applications/domain/application_attachment.dart';
import 'package:myoccasio/features/applications/presentation/application_attachments_screen.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/network/external_links.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/application_coach_screen.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class ApplicationWorkspaceScreen extends StatefulWidget {
  const ApplicationWorkspaceScreen({
    required this.repository,
    required this.opportunityId,
    this.coaching,
    this.pickDocument = selectResume,
    this.export = exportDocument,
    super.key,
  });
  final ApplicationsRepository repository;
  final String opportunityId;
  final CoachingRepository? coaching;
  final DocumentPicker pickDocument;
  final DocumentExporter export;
  @override
  State<ApplicationWorkspaceScreen> createState() =>
      _ApplicationWorkspaceScreenState();
}

class _ApplicationWorkspaceScreenState
    extends State<ApplicationWorkspaceScreen> {
  bool _busy = false;
  bool _confirmingSubmission = false;
  bool get _blocked => _busy || _confirmingSubmission;
  bool _attachmentsUncertain = false;

  Future<Map<String, dynamic>> _loadWorkspace() async {
    final data = await widget.repository.getWorkspace(widget.opportunityId);
    if (ApplicationAttachmentLimits.supported(data['attachmentLimits']) !=
        null) {
      ApplicationAttachment.parseList(data['attachments']);
      if (data['submission'] != null) {
        ApplicationAttachment.parseList(data['submission']['attachments']);
      }
    }
    if (mounted) setState(() => _attachmentsUncertain = false);
    return data;
  }

  Future<void> _documents(
    ApplicationAttachmentLimits limits,
    Future<void> Function() refresh, {
    List<ApplicationAttachment>? submitted,
  }) async {
    if (_blocked) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicationAttachmentsScreen(
          repository: widget.repository,
          opportunityId: widget.opportunityId,
          limits: limits,
          submittedAttachments: submitted,
          pickDocument: widget.pickDocument,
          export: widget.export,
        ),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> _submit(
    Future<void> Function() refresh, {
    bool withdraw = false,
    List<ApplicationAttachment>? attachments,
  }) async {
    if (_blocked || (!withdraw && _attachmentsUncertain)) return;
    final reviewedIds = attachments
        ?.map((file) => file.id)
        .toList(growable: false);
    var reviewed = withdraw || attachments == null;
    bool? confirmed;
    setState(() => _confirmingSubmission = true);
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            scrollable: true,
            title: AppText(
              withdraw ? 'Withdraw application?' : 'Submit your application?',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  withdraw
                      ? 'The provider will see that you withdrew your application.'
                      : 'Your saved statement and profile snapshot will be sent to the provider. Review them before continuing.',
                ),
                if (!withdraw && attachments != null) ...[
                  const SizedBox(height: 16),
                  const AppText('Supporting documents'),
                  const SizedBox(height: 8),
                  if (attachments.isEmpty)
                    const AppText('No supporting documents will be sent.'),
                  for (final file in attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${file.fileName} (${(file.byteSize / 1024).ceil()} KB)',
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: reviewed,
                    onChanged: (value) =>
                        update(() => reviewed = value == true),
                    title: const AppText(
                      'I reviewed the documents that will be shared.',
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                onPressed: reviewed ? () => Navigator.pop(context, true) : null,
                child: AppText(withdraw ? 'Withdraw' : 'Confirm submission'),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingSubmission = false);
    }
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (withdraw) {
        await widget.repository.withdrawApplication(widget.opportunityId);
      } else {
        await widget.repository.submitApplication(
          widget.opportunityId,
          attachmentIds: reviewedIds,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            withdraw ? 'Application withdrawn.' : 'Application submitted.',
          ),
        ),
      );
      await refresh();
    } on Object catch (error) {
      if (mounted && error is ApiException && error.statusCode == 409) {
        setState(() => _attachmentsUncertain = true);
        await refresh();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              error is ApiException
                  ? error.message
                  : 'Could not update the application. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_blocked,
    child: Scaffold(
      bottomNavigationBar: WorkspaceBottomBar(enabled: !_blocked),
      appBar: AppBar(title: const AppText('Application workspace')),
      body: AsyncContent<Map<String, dynamic>>(
        load: _loadWorkspace,
        builder: (context, data, refresh) {
          final opportunity = data['opportunity'] as Map<String, dynamic>;
          final draft = data['draft'] as Map<String, dynamic>?;
          final submission = data['submission'] as Map<String, dynamic>?;
          final submitted =
              submission != null && submission['status'] != 'withdrawn';
          final internal = data['submissionMode'] == 'internal';
          final statement = (draft?['statement'] ?? '').toString();
          final limits = ApplicationAttachmentLimits.supported(
            data['attachmentLimits'],
          );
          final attachments = limits == null
              ? null
              : ApplicationAttachment.parseList(data['attachments']);
          final submittedFiles = limits == null || submission == null
              ? null
              : ApplicationAttachment.parseList(submission['attachments']);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                opportunity['title'].toString(),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text((opportunity['provider'] ?? '').toString()),
              const SizedBox(height: 20),
              StatusPill(
                label: submitted
                    ? applicationSubmissionLabels[submission['status']] ??
                          submission['status'].toString()
                    : 'Draft · Not submitted',
              ),
              const SizedBox(height: 20),
              if ((opportunity['description'] as String? ?? '').isNotEmpty)
                Text(opportunity['description'].toString()),
              const SizedBox(height: 24),
              AppText(
                'Personal statement',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              statement.isEmpty
                  ? const AppText(
                      'Add a statement to prepare your application.',
                    )
                  : SelectableText(statement),
              const SizedBox(height: 20),
              if (!submitted && widget.coaching != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const AppText('Application coach'),
                  onPressed: _blocked
                      ? null
                      : () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApplicationCoachScreen(
                                applications: widget.repository,
                                coaching: widget.coaching!,
                                opportunityId: widget.opportunityId,
                                opportunity: opportunity,
                                statement: statement,
                              ),
                            ),
                          );
                          if (changed == true) await refresh();
                        },
                ),
              if (!submitted)
                OutlinedButton(
                  onPressed: _blocked
                      ? null
                      : () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DataFormScreen(
                                title: 'Personal statement',
                                description:
                                    'Use your own voice. Save your draft before reviewing or submitting.',
                                fields: const [
                                  DataField(
                                    'statement',
                                    'Statement',
                                    required: true,
                                    lines: 12,
                                    maxLength: 10000,
                                  ),
                                ],
                                initial: {'statement': statement},
                                save: (v) => widget.repository.saveStatement(
                                  widget.opportunityId,
                                  v['statement']!,
                                  checklist:
                                      (draft?['checklist'] as List? ?? [])
                                          .cast<String>(),
                                  missingFields:
                                      (draft?['missingFields'] as List? ?? [])
                                          .cast<String>(),
                                ),
                              ),
                            ),
                          );
                          if (changed == true) await refresh();
                        },
                  child: AppText(
                    statement.isEmpty ? 'Add statement' : 'Edit statement',
                  ),
                ),
              if (limits != null) ...[
                const SizedBox(height: 20),
                AppText(
                  'Supporting documents',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                if (!submitted) ...[
                  if (attachments!.isEmpty)
                    const AppText('No supporting documents'),
                  for (final file in attachments) Text(file.fileName),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _blocked
                        ? null
                        : () => _documents(limits, refresh),
                    icon: const Icon(Icons.attach_file),
                    label: const AppText('Manage supporting documents'),
                  ),
                ],
                if (submittedFiles != null &&
                    (submitted || submittedFiles.isNotEmpty))
                  OutlinedButton.icon(
                    onPressed: _blocked
                        ? null
                        : () => _documents(
                            limits,
                            refresh,
                            submitted: submittedFiles,
                          ),
                    icon: const Icon(Icons.description_outlined),
                    label: const AppText('View submitted documents'),
                  ),
                const AppText(
                  'Files stay private until you review and submit. External provider applications are completed on the provider’s website.',
                ),
                if (_attachmentsUncertain) ...[
                  const AppText(
                    'Refresh the workspace before reviewing documents again.',
                  ),
                  TextButton(
                    onPressed: _blocked ? null : refresh,
                    child: const AppText('Retry'),
                  ),
                ],
              ],
              if (!internal) ...[
                const SizedBox(height: 20),
                const AppText(
                  'This provider accepts applications on its own site. Opening it does not submit or update your application status.',
                ),
                if ((opportunity['applyUrl'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton.icon(
                      onPressed: _blocked
                          ? null
                          : () => openWebLink(
                              context,
                              opportunity['applyUrl'].toString(),
                            ),
                      icon: const Icon(Icons.open_in_new),
                      label: const AppText('Open provider website'),
                    ),
                  ),
              ] else if (!submitted) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed:
                      _blocked || statement.isEmpty || _attachmentsUncertain
                      ? null
                      : () => _submit(refresh, attachments: attachments),
                  child: AppText(_busy ? 'Submitting…' : 'Review & submit'),
                ),
              ],
              if (submitted &&
                  [
                    'submitted',
                    'under_review',
                    'shortlisted',
                  ].contains(submission['status']))
                TextButton(
                  onPressed: _blocked
                      ? null
                      : () => _submit(refresh, withdraw: true),
                  child: const AppText('Withdraw application'),
                ),
              const SizedBox(height: 20),
              if (limits == null)
                const AppText(
                  'Document attachments are not supported by this application endpoint. Check the provider’s requirements before submitting.',
                ),
            ],
          );
        },
      ),
    ),
  );
}
