import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/community/presentation/community_conversation_screen.dart';
import 'package:myoccasio/features/community/presentation/community_event_screen.dart';
import 'package:myoccasio/features/community/presentation/community_widgets.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/settings/presentation/support_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    required this.repository,
    this.initialTab = 0,
    this.supportRepository,
    this.email = '',
    super.key,
  });
  final CommunityRepository repository;
  final int initialTab;
  final SettingsRepository? supportRepository;
  final String email;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late int _tab = widget.initialTab;
  final _pending = <String>{};
  final _confirming = <String>{};
  bool _openingComposer = false;
  bool _registeredOnly = false;

  Future<void> _act(
    String id,
    Future<void> Function() action,
    Future<void> Function() refresh,
  ) async {
    if (_pending.contains(id)) return;
    setState(() => _pending.add(id));
    try {
      await action();
      await refresh();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              error is ApiException
                  ? error.message
                  : 'Could not complete that action. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  Future<void> _create(Future<void> Function() refresh) async {
    if (_openingComposer) return;
    final win = _tab == 1;
    setState(() => _openingComposer = true);
    try {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DataFormScreen(
            title: win ? 'Share a win' : 'Start a conversation.',
            description:
                'Your post is visible to the community. Leave out personal contact details.',
            submitLabel: win ? 'Publish' : 'Publish post',
            fields: const [
              DataField(
                'body',
                'What’s on your mind?',
                required: true,
                lines: 8,
                maxLength: 5000,
              ),
            ],
            save: (values) =>
                widget.repository.createPost(values['body']!, win: win),
          ),
        ),
      );
      if (changed == true) await refresh();
    } finally {
      if (mounted) setState(() => _openingComposer = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _pending.isEmpty && _confirming.isEmpty,
    child: Scaffold(
      bottomNavigationBar: WorkspaceBottomBar(
        enabled: _pending.isEmpty && _confirming.isEmpty,
      ),
      appBar: AppBar(title: const AppText('Community')),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(switch (_tab) {
                    1 => 'Good things happen here.',
                    2 => 'A conversation can help.',
                    3 => 'Make room for connection.',
                    _ => 'Find your people.',
                  }, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 12),
                  AppText(switch (_tab) {
                    1 => 'Celebrate a step, big or small.',
                    2 => 'Meet students with a shared direction.',
                    3 => 'Event times below use your device’s local time zone.',
                    _ => 'You don’t have to figure it out alone.',
                  }),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in const {
                          0: 'Feed',
                          1: 'Wins',
                          2: 'People',
                          3: 'Events',
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: AppText(entry.value),
                              selected: _tab == entry.key,
                              showCheckmark: false,
                              onSelected:
                                  _pending.isNotEmpty || _confirming.isNotEmpty
                                  ? null
                                  : (_) => setState(() => _tab = entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: AsyncContent<List<Map<String, dynamic>>>(
          key: ValueKey(_tab),
          load: () => switch (_tab) {
            2 => widget.repository.people(),
            3 => widget.repository.events(),
            _ => widget.repository.posts(wins: _tab == 1),
          },
          builder: (context, items, refresh) {
            final shown = _tab == 3
                ? items
                      .where((event) {
                        if (_registeredOnly) {
                          return event['isRegistered'] == true;
                        }
                        final date = DateTime.tryParse(
                          (event['eventDate'] ?? '').toString(),
                        );
                        return date == null || !date.isBefore(DateTime.now());
                      })
                      .toList(growable: false)
                : items;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                if (_tab == 3) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const AppText('Upcoming'),
                        selected: !_registeredOnly,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _registeredOnly = false),
                      ),
                      ChoiceChip(
                        label: const AppText('Registered'),
                        selected: _registeredOnly,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _registeredOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                if (_tab == 2) ...[
                  const CommunityNote(
                    'Coffee chats begin with a request. Only share contact details when ready.',
                  ),
                  const SizedBox(height: 24),
                ],
                if (_tab == 0) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: const AppText('What’s on your mind?'),
                      trailing: const Icon(Icons.add),
                      onTap: _openingComposer ? null : () => _create(refresh),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (shown.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.people_outline,
                    title: 'Nothing here yet',
                    message: 'Pull down to refresh and check again later.',
                  ),
                for (var index = 0; index < shown.length; index++) ...[
                  Card(
                    color: _tab == 1 && index == 0 ? AppColors.forest : null,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _tab == 2
                          ? _person(shown[index], refresh)
                          : _tab == 3
                          ? _event(shown[index], refresh)
                          : _post(
                              shown[index],
                              refresh,
                              featured: _tab == 1 && index == 0,
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (_tab == 1) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _openingComposer ? null : () => _create(refresh),
                    child: const AppText('Share a win'),
                  ),
                ],
                if (_tab == 0) ...[
                  const SizedBox(height: 8),
                  const CommunityNote(
                    'Be kind. Share experiences, and keep private information private.',
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _post(
    Map<String, dynamic> item,
    Future<void> Function() refresh, {
    bool featured = false,
  }) {
    final win = _tab == 1;
    final id = item['id'].toString();
    final createdAt = DateTime.tryParse((item['createdAt'] ?? '').toString());
    final metadata = [
      (item['authorInstitution'] ?? item['institution'] ?? '').toString(),
      if (createdAt != null) formatDisplayDate(context, createdAt, time: true),
    ].where((text) => text.trim().isNotEmpty).join(' · ');
    final author = CommunityAuthor(
      name: communityAuthorName(item),
      subtitle: metadata,
      featured: featured,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured) ...[
          const AppText(
            'A moment worth sharing',
            style: TextStyle(
              color: AppColors.mint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          author,
          const SizedBox(height: 16),
          if ((item['group'] ?? '').toString().isNotEmpty) ...[
            Chip(label: Text(item['group'].toString())),
            const SizedBox(height: 8),
          ],
        ],
        SelectableText(
          (item['body'] ?? '').toString(),
          style: featured
              ? Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white)
              : Theme.of(context).textTheme.bodyLarge,
        ),
        if (featured) ...[const SizedBox(height: 20), author],
        const SizedBox(height: 16),
        Divider(color: featured ? Colors.white24 : null),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              style: featured
                  ? TextButton.styleFrom(foregroundColor: Colors.white)
                  : null,
              onPressed: _pending.contains(id)
                  ? null
                  : () => _act(
                      id,
                      () => widget.repository.like(
                        id,
                        liked: item['liked'] != true,
                        win: win,
                      ),
                      refresh,
                    ),
              icon: Icon(
                item['liked'] == true ? Icons.favorite : Icons.favorite_border,
              ),
              label: AppText('${item['likeCount'] ?? 0} likes'),
            ),
            TextButton.icon(
              style: featured
                  ? TextButton.styleFrom(foregroundColor: Colors.white)
                  : null,
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityConversationScreen(
                    repository: widget.repository,
                    post: item,
                    win: win,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const AppText('Conversation'),
            ),
            if (widget.supportRepository != null)
              TextButton.icon(
                style: featured
                    ? TextButton.styleFrom(foregroundColor: Colors.white)
                    : null,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportScreen(
                      repository: widget.supportRepository!,
                      email: widget.email,
                      reference: 'Community ${win ? 'win' : 'post'} $id',
                    ),
                  ),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const AppText('Report'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _requestChat(
    Map<String, dynamic> person,
    Future<void> Function() refresh,
  ) async {
    final id = person['id'].toString();
    if (_pending.contains(id) || _confirming.contains(id)) return;
    setState(() => _confirming.add(id));
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const AppText('Request a coffee chat?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(communityAuthorName(person)),
              const SizedBox(height: 12),
              const AppText(
                'Send this student a connection request? Only share personal contact details when you are ready.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Send request'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming.remove(id));
    }
    if (confirmed != true || !mounted) return;
    await _act(id, () async {
      final exists = await widget.repository.requestChat(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              exists
                  ? 'A request already exists between you.'
                  : 'Coffee chat request sent.',
            ),
          ),
        );
      }
    }, refresh);
  }

  Widget _person(Map<String, dynamic> person, Future<void> Function() refresh) {
    final id = person['id'].toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunityAuthor(
          name: communityAuthorName(person),
          subtitle: [
            (person['program'] ?? '').toString(),
            (person['institution'] ?? '').toString(),
          ].where((text) => text.trim().isNotEmpty).join(' · '),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in person['tags'] as List? ?? [])
              Chip(label: Text(tag.toString())),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _pending.contains(id) || _confirming.contains(id)
              ? null
              : () => _requestChat(person, refresh),
          child: const AppText('Request a coffee chat'),
        ),
      ],
    );
  }

  Widget _event(Map<String, dynamic> event, Future<void> Function() refresh) {
    final date = DateTime.tryParse((event['eventDate'] ?? '').toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event['title'].toString(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        date == null
            ? const AppText('Date unavailable')
            : Text(formatDisplayDate(context, date, time: true)),
        Text((event['location'] ?? '').toString()),
        if (event['isRegistered'] == true) ...[
          const SizedBox(height: 12),
          const StatusPill(label: 'Registered'),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => CommunityEventScreen(
                repository: widget.repository,
                event: event,
                onChanged: refresh,
              ),
            ),
          ),
          child: const AppText('View event'),
        ),
      ],
    );
  }
}
