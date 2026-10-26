import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coaching_draft_review_screen.dart';
import 'package:myoccasio/features/coaching/presentation/story_draft_screen.dart';
import 'package:myoccasio/features/coaching/presentation/story_fields.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({required this.repository, super.key});
  final CoachingRepository repository;
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  bool _opening = false;

  Future<void> _edit(
    Map<String, dynamic> story,
    Future<void> Function() refresh,
  ) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DataFormScreen(
            title: 'There’s more to you.',
            description: 'Your story stays editable. Use your own voice.',
            fields: [
              for (final e in storyFields.entries)
                DataField(
                  e.key,
                  e.value,
                  lines: 3,
                  maxLength: e.key.endsWith('Interests') ? 2000 : 3000,
                ),
              const DataField(
                'allowFinancialContextUse',
                'Allow financial context in AI guidance',
                required: true,
                options: {
                  'false': 'Keep private from AI',
                  'true': 'Allow use in AI guidance',
                },
              ),
            ],
            initial: {
              for (final e in story.entries) e.key: e.value?.toString() ?? '',
              'allowFinancialContextUse':
                  (story['allowFinancialContextUse'] == true).toString(),
            },
            save: (v) => widget.repository.saveStory({
              ...v,
              'allowFinancialContextUse':
                  v['allowFinancialContextUse'] == 'true',
            }),
          ),
        ),
      );
      if (changed == true) await refresh();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _draft(
    Map<String, dynamic> story,
    Future<void> Function() refresh,
  ) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              StoryDraftScreen(repository: widget.repository, story: story),
        ),
      );
      if (changed == true) await refresh();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _editStatement(
    String statement,
    Future<void> Function() refresh,
  ) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CoachingDraftReviewScreen(
            title: 'Edit saved statement',
            description: AppStrings.tr(
              context,
              'Your story stays editable. Use your own voice.',
            ),
            draft: statement,
            unsavedInitially: false,
            save: widget.repository.saveDraft,
          ),
        ),
      );
      if (changed == true) await refresh();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: WorkspaceBottomBar(enabled: !_opening),
    appBar: AppBar(title: const AppText('My story')),
    body: AsyncContent<Map<String, dynamic>>(
      load: widget.repository.getStory,
      builder: (context, data, refresh) {
        final story = data['story'] as Map<String, dynamic>? ?? {};
        final hasNotes = storyFields.keys.any(
          (key) => (story[key]?.toString() ?? '').trim().isNotEmpty,
        );
        final statement = (story['personalStatementDraft'] ?? '').toString();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppText(
              'There’s more to you.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const AppText('Your experiences can open doors.'),
            const SizedBox(height: 24),
            if (hasNotes) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(label: 'Saved to your profile'),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const EmptyStateCard(
                icon: Icons.edit_note,
                title: 'Your story starts here.',
                message:
                    'Add a few notes about your background, interests and experiences.',
              ),
              const SizedBox(height: 24),
            ],
            for (final e in storyFields.entries)
              if ((story[e.key]?.toString() ?? '').trim().isNotEmpty) ...[
                AppText(
                  e.value,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(story[e.key].toString()),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            const AppText('Your story stays editable. Use your own voice.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _opening ? null : () => _edit(story, refresh),
              child: const AppText('Edit my story'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _opening || availableStorySources(story).isEmpty
                  ? null
                  : () => _draft(story, refresh),
              child: const AppText('Draft a personal statement'),
            ),
            if (statement.isNotEmpty) ...[
              const SizedBox(height: 24),
              AppText(
                'Saved personal statement',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(statement),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _opening
                    ? null
                    : () => _editStatement(statement, refresh),
                child: const AppText('Edit saved statement'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
