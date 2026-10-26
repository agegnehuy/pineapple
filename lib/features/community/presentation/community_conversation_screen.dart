import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/community/presentation/community_widgets.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class CommunityConversationScreen extends StatefulWidget {
  const CommunityConversationScreen({
    required this.repository,
    required this.post,
    required this.win,
    super.key,
  });
  final CommunityRepository repository;
  final Map<String, dynamic> post;
  final bool win;

  @override
  State<CommunityConversationScreen> createState() =>
      _CommunityConversationScreenState();
}

class _CommunityConversationScreenState
    extends State<CommunityConversationScreen> {
  final _comment = TextEditingController();
  bool _sending = false;
  bool _confirming = false;
  bool _allowPop = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _comment.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send(Future<void> Function() refresh) async {
    final text = _comment.text.trim();
    if (_sending || _confirming || text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.repository.comment(
        widget.post['id'].toString(),
        text,
        win: widget.win,
      );
      if (!mounted) return;
      _comment.clear();
      // The write is confirmed; a slow read must not trap the student here.
      setState(() => _sending = false);
      await refresh();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not post your comment. Your draft is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leave() async {
    if (_sending || _confirming || _comment.text.isEmpty) return;
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Discard unsaved changes?'),
        content: const AppText('Your comment has not been posted.'),
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
    canPop: _allowPop || (!_sending && !_confirming && _comment.text.isEmpty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: const AppText('Conversation')),
      bottomNavigationBar: WorkspaceBottomBar(
        enabled: !_sending && !_confirming,
      ),
      body: AsyncContent<List<Map<String, dynamic>>>(
        load: () => widget.repository.comments(
          widget.post['id'].toString(),
          win: widget.win,
        ),
        builder: (context, comments, refresh) => LayoutBuilder(
          builder: (context, viewport) => Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    AppText(
                      'A little shared wisdom.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CommunityAuthor(
                              name: communityAuthorName(widget.post),
                            ),
                            const SizedBox(height: 16),
                            SelectableText(widget.post['body'].toString()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${comments.length} ${AppStrings.tr(context, comments.length == 1 ? 'Reply' : 'Replies').toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    for (final comment in comments) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommunityAuthor(
                                name: communityAuthorName(comment),
                              ),
                              const SizedBox(height: 16),
                              SelectableText(
                                (comment['content'] ?? comment['body'] ?? '')
                                    .toString(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (comments.isEmpty)
                      const AppText('Be the first to join the conversation.'),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: viewport.maxHeight * 0.45,
                ),
                child: SingleChildScrollView(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: AppText(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _comment,
                                  enabled: !_sending && !_confirming,
                                  maxLength: 5000,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.tr(
                                      context,
                                      'Your comment',
                                    ),
                                    hintText: AppStrings.tr(
                                      context,
                                      'Add a thoughtful reply…',
                                    ),
                                    counterText: '',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: AppStrings.tr(context, 'Post comment'),
                                onPressed:
                                    _sending ||
                                        _confirming ||
                                        _comment.text.trim().isEmpty
                                    ? null
                                    : () => _send(refresh),
                                icon: _sending
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: AppBusyIndicator(
                                          label: 'Posting comment',
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
