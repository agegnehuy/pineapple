import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/coaching/presentation/coaching_draft_review_screen.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coach_screen.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class ApplicationCoachScreen extends StatefulWidget {
  const ApplicationCoachScreen({
    required this.applications,
    required this.coaching,
    required this.opportunityId,
    required this.opportunity,
    required this.statement,
    super.key,
  });
  final ApplicationsRepository applications;
  final CoachingRepository coaching;
  final String opportunityId;
  final Map<String, dynamic> opportunity;
  final String statement;
  @override
  State<ApplicationCoachScreen> createState() => _ApplicationCoachScreenState();
}

class _ApplicationCoachScreenState extends State<ApplicationCoachScreen> {
  final _instruction = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  bool _confirming = false;
  bool _allowPop = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _instruction.addListener(_changed);
  }

  void _changed() => setState(() {});

  Future<void> _leave() async {
    if (_busy || _confirming) return;
    setState(() => _confirming = true);
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
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  void _begin(String task) {
    final strings = AppStrings.of(context);
    final prompt = [
      strings.text(task),
      '${strings.text('Opportunity')}: ${widget.opportunity['title']}',
      if (widget.opportunity['description'] != null)
        '${strings.text('Provider description')}: ${widget.opportunity['description']}',
      if (widget.statement.isNotEmpty)
        '${strings.text('My current statement')}: ${widget.statement}',
      strings.text('Use only supplied facts. Ask me for missing information.'),
    ].join('\n\n');
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const AppText('Application coach')),
          bottomNavigationBar: const WorkspaceBottomBar(),
          body: CoachScreen(repository: widget.coaching, initialPrompt: prompt),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (!_consent || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.applications.generateDraft(
        widget.opportunityId,
        _instruction.text.trim(),
      );
      final statement = (result['statement'] ?? '').toString();
      if (statement.trim().isEmpty) {
        throw const ApiException(
          'Drafting is unavailable. Your saved work is unchanged.',
        );
      }
      if (!mounted) return;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CoachingDraftReviewScreen(
            title: 'Review application draft',
            description: [
              AppStrings.tr(
                context,
                'AI-generated draft. Review every fact and keep your own voice. Saving does not submit your application.',
              ),
              if ((result['missingFields'] as List? ?? []).isNotEmpty)
                '${AppStrings.tr(context, 'Missing information')}: ${(result['missingFields'] as List).join('; ')}',
              if ((result['checklist'] as List? ?? []).isNotEmpty)
                '${AppStrings.tr(context, 'Next steps')}: ${(result['checklist'] as List).join('; ')}',
            ].join('\n\n'),
            maxLength: 10000,
            draft: statement,
            save: (statement) => widget.applications.saveStatement(
              widget.opportunityId,
              statement,
              checklist: (result['checklist'] as List? ?? []).cast<String>(),
              missingFields: (result['missingFields'] as List? ?? [])
                  .cast<String>(),
            ),
          ),
        ),
      );
      if (changed == true && mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Drafting is unavailable. Your saved work is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_busy && !_confirming && _instruction.text.isEmpty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      bottomNavigationBar: WorkspaceBottomBar(enabled: !_busy),
      appBar: AppBar(title: const AppText('Application coach')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText(
            'Make your case.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const AppText('A practical plan for a stronger application.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.opportunity['title'].toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (widget.opportunity['provider'] != null)
                    Text(widget.opportunity['provider'].toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppText(
            'Choose where to begin',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          for (final choice in const [
            (
              'Understand the criteria',
              'Turn requirements into a checklist.',
              Icons.check,
              'Help me understand the eligibility criteria and create an application checklist.',
            ),
            (
              'Strengthen my statement',
              'Get feedback on clarity and examples.',
              Icons.description_outlined,
              'Review my statement for clarity, evidence and alignment with the criteria. Ask for my statement if it is missing.',
            ),
            (
              'Prepare for an interview',
              'Practise with prompts and feedback.',
              Icons.chat_bubble_outline,
              'Help me practise for an interview for this opportunity, one question at a time.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  title: AppText(choice.$1),
                  subtitle: AppText(choice.$2),
                  trailing: Icon(choice.$3),
                  onTap: _busy ? null : () => _begin(choice.$4),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const AppText(
            'Questions are reviewed before sending. AI guidance does not guarantee selection or funding.',
          ),
          const Divider(height: 40),
          AppText(
            'Prepare a draft',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const AppText(
            'Uses the existing application guidance service and your account allowance. Availability depends on your plan. You review the result before saving.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instruction,
            enabled: !_busy,
            maxLength: 1000,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: AppStrings.tr(
                context,
                'What should the draft focus on? (optional)',
              ),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            title: const AppText(
              'Allow this draft to use my account profile and saved story. Financial context follows my story privacy choice.',
            ),
            onChanged: _busy
                ? null
                : (v) => setState(() => _consent = v ?? false),
          ),
          if (_error != null)
            Semantics(liveRegion: true, child: AppText(_error!)),
          FilledButton(
            onPressed: _consent && !_busy ? _generate : null,
            child: AppText(
              _busy
                  ? 'Preparing draft…'
                  : _error == null
                  ? 'Generate draft for review'
                  : 'Retry draft generation',
            ),
          ),
        ],
      ),
    ),
  );
}
