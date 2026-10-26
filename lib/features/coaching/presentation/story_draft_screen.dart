import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/coaching/presentation/coaching_draft_review_screen.dart';
import 'package:myoccasio/features/coaching/presentation/story_fields.dart';

class StoryDraftScreen extends StatefulWidget {
  const StoryDraftScreen({
    required this.repository,
    required this.story,
    super.key,
  });
  final CoachingRepository repository;
  final Map<String, dynamic> story;

  @override
  State<StoryDraftScreen> createState() => _StoryDraftScreenState();
}

class _StoryDraftScreenState extends State<StoryDraftScreen> {
  final _purpose = TextEditingController();
  final _highlight = TextEditingController();
  late final _available = availableStorySources(widget.story);
  late final _sources = {..._available};
  bool _consent = false;
  bool _busy = false;
  bool _confirming = false;
  bool _allowPop = false;
  String? _error;

  bool get _dirty =>
      _purpose.text.isNotEmpty ||
      _highlight.text.isNotEmpty ||
      !setEquals(_sources, _available);

  @override
  void initState() {
    super.initState();
    _purpose.addListener(_changed);
    _highlight.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _purpose.dispose();
    _highlight.dispose();
    super.dispose();
  }

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

  Future<void> _generate() async {
    if (_busy || _confirming || !_consent || _sources.isEmpty) return;
    final instruction = [
      if (_purpose.text.trim().isNotEmpty)
        '${AppStrings.tr(context, 'Writing')}: ${_purpose.text.trim()}',
      if (_highlight.text.trim().isNotEmpty)
        '${AppStrings.tr(context, 'Highlight')}: ${_highlight.text.trim()}',
    ].join('\n');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.draftStory(
        _sources.toList(growable: false),
        instruction,
      );
      final draft = (result['draft'] ?? '').toString();
      if (draft.trim().isEmpty) {
        throw const ApiException(
          'Drafting is unavailable. Your story is unchanged.',
        );
      }
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CoachingDraftReviewScreen(
            title: 'Review your draft',
            description: AppStrings.tr(
              context,
              'AI-generated draft. Check accuracy and keep your own voice. This has not been saved or submitted.',
            ),
            draft: draft,
            save: widget.repository.saveDraft,
          ),
        ),
      );
      if (saved == true && mounted) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Drafting is unavailable. Your story is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_busy && !_confirming && !_dirty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: const AppText('Draft from your story')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppText(
              'Start with your story.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const AppText('A first draft, shaped by your experience.'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const AppText(
                'Drafting support can help you begin. Review every detail and make it yours.',
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _purpose,
              enabled: !_busy,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: AppStrings.tr(context, 'What are you writing?'),
                hintText: AppStrings.tr(
                  context,
                  'Scholarship personal statement',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _highlight,
              enabled: !_busy,
              maxLength: 250,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppStrings.tr(context, 'What should it highlight?'),
                hintText: AppStrings.tr(
                  context,
                  'Leadership & community impact',
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            AppText(
              'Use from my story',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            for (final key in _available) ...[
              Card(
                child: CheckboxListTile(
                  title: AppText(storyFields[key]!),
                  subtitle: Text(
                    widget.story[key].toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: _sources.contains(key),
                  onChanged: _busy
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            _sources.add(key);
                          } else {
                            _sources.remove(key);
                          }
                        }),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_available.isEmpty)
              const AppText('Add notes to My story before creating a draft.'),
            if ((widget.story['financialContext']?.toString() ?? '')
                    .isNotEmpty &&
                widget.story['allowFinancialContextUse'] != true) ...[
              const SizedBox(height: 8),
              const StatusPill(label: 'Financial context stays private'),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _consent = value == true),
              title: const AppText(
                'Allow the selected notes to be sent to the AI service for this draft.',
              ),
            ),
            const AppText('Uses AI allowance · Review before sharing'),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: AppText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || _sources.isEmpty || !_consent
                  ? null
                  : _generate,
              child: AppText(
                _busy
                    ? 'Generating draft…'
                    : _error == null
                    ? 'Create a starting draft'
                    : 'Retry draft generation',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
