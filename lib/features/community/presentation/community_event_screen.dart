import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class CommunityEventScreen extends StatefulWidget {
  const CommunityEventScreen({
    required this.repository,
    required this.event,
    this.onChanged,
    super.key,
  });
  final CommunityRepository repository;
  final Map<String, dynamic> event;
  final Future<void> Function()? onChanged;

  @override
  State<CommunityEventScreen> createState() => _CommunityEventScreenState();
}

class _CommunityEventScreenState extends State<CommunityEventScreen> {
  late bool _registered = widget.event['isRegistered'] == true;
  bool _busy = false;
  String? _error;

  Future<void> _toggle() async {
    if (_busy) return;
    final cancel = _registered;
    var changed = false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.register(
        widget.event['id'].toString(),
        cancel: cancel,
      );
      if (!mounted) return;
      // Only change the state after the registration endpoint confirms it.
      setState(() => _registered = !cancel);
      changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            cancel
                ? 'Event registration cancelled.'
                : 'Event registration confirmed.',
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not complete that action. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (changed) {
      try {
        await widget.onChanged?.call();
      } on Object {
        // A separate list refresh must not undo confirmed registration state.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(
      (widget.event['eventDate'] ?? '').toString(),
    );
    final location = (widget.event['location'] ?? '').toString();
    final description = (widget.event['description'] ?? '').toString();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const AppText('Events')),
        bottomNavigationBar: WorkspaceBottomBar(enabled: !_busy),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.event['title'].toString(),
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            Container(
              key: const ValueKey('event-date-hero'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  date == null
                      ? const AppText(
                          'Date unavailable',
                          style: TextStyle(color: Colors.white),
                        )
                      : Text(
                          formatDisplayDate(context, date, time: true),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      location,
                      style: const TextStyle(color: AppColors.mint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppText(
              'Event times below use your device’s local time zone.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            AppText(
              'Make room for your next step.',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (description.isNotEmpty) SelectableText(description),
            const SizedBox(height: 24),
            if (_registered) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(label: 'Registered'),
              ),
              const SizedBox(height: 20),
            ],
            if (_error != null) ...[
              Semantics(
                liveRegion: true,
                child: AppText(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _busy ? null : _toggle,
              child: AppText(
                _busy
                    ? 'Please wait…'
                    : _registered
                    ? 'Cancel registration'
                    : 'Register for event',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
