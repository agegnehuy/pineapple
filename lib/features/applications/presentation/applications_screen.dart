import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/data/application_cache.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';
import 'package:myoccasio/features/applications/presentation/application_workspace_screen.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';

const _statusOptions = {
  'saved': 'Saved',
  'drafting': 'In progress',
  'submitted': 'Submitted',
  'awarded': 'Awarded',
  'rejected': 'Not selected',
};

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({
    required this.repository,
    this.savedOnly = false,
    this.coaching,
    this.cache,
    this.accountId,
    super.key,
  });

  final ApplicationsRepository repository;
  final bool savedOnly;
  final CoachingRepository? coaching;
  final ApplicationCache? cache;
  final String? accountId;

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  late Future<_ApplicationsResult> _future;
  int _loadGeneration = 0;
  bool _cacheInvalidated = false;
  bool _accessDenied = false;
  bool _offlineAllowed = true;
  Object? _activeToken;
  String _filter = 'active';
  bool _closingSoon = false;
  final _updating = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.repository.addListener(_refresh);
    widget.cache?.addListener(_cacheChanged);
  }

  @override
  void didUpdateWidget(covariant ApplicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.cache != widget.cache ||
        oldWidget.accountId != widget.accountId) {
      oldWidget.repository.removeListener(_refresh);
      oldWidget.cache?.removeListener(_cacheChanged);
      widget.repository.addListener(_refresh);
      widget.cache?.addListener(_cacheChanged);
      _cacheInvalidated = false;
      _accessDenied = false;
      _offlineAllowed = true;
      _filter = 'active';
      _closingSoon = false;
      _future = _load();
    }
  }

  void _cacheChanged() {
    if (mounted &&
        widget.cache?.accountId == widget.accountId &&
        widget.cache?.isActive == false) {
      setState(() {
        _cacheInvalidated = true;
        _activeToken = null;
        _loadGeneration++;
      });
    } else if (mounted &&
        widget.cache?.accountId == widget.accountId &&
        widget.cache?.allowsOffline == false) {
      setState(() {
        _accessDenied = true;
        _activeToken = null;
        _loadGeneration++;
      });
    }
  }

  Future<_ApplicationsResult> _load() async {
    final generation = ++_loadGeneration;
    _activeToken = null;
    final cache = widget.cache;
    final accountId = widget.accountId;
    final canCache =
        cache != null && cache.accountId == accountId && cache.isActive;
    final accessEpoch = canCache ? cache.accessEpoch : null;
    List<TrackedApplication> applications;
    try {
      applications = await widget.repository.getTrackedApplications();
    } on Object catch (error) {
      if (error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        // Do not let a subsequent connection failure mask an access denial.
        if (generation == _loadGeneration) _offlineAllowed = false;
        if (canCache) cache.denyAccess();
      }
      if (!canCache ||
          !_offlineAllowed ||
          !cache.allowsOffline ||
          !_connectionFailure(error) ||
          generation != _loadGeneration) {
        rethrow;
      }
      final snapshot = await cache.read().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (snapshot == null ||
          !cache.allowsOffline ||
          generation != _loadGeneration) {
        rethrow;
      }
      return _ApplicationsResult(snapshot.applications, cached: snapshot);
    }
    final fetchedAt = DateTime.now().toUtc();
    if (canCache && !cache.confirmAccess(accessEpoch!)) {
      throw const ApiException('Your access changed. Please try again.');
    }
    if (generation == _loadGeneration) _offlineAllowed = true;
    if (canCache && cache.isActive && generation == _loadGeneration) {
      // Secure storage is optional background work; it cannot delay live data.
      unawaited(
        cache
            .write(applications, fetchedAt: fetchedAt)
            .catchError((Object _) {}),
      );
    }
    final result = _ApplicationsResult(applications);
    if (generation == _loadGeneration) _activeToken = result.token;
    return result;
  }

  bool _canAct(Object token) =>
      !_cacheInvalidated &&
      !_accessDenied &&
      (widget.cache?.allowsOffline ?? true) &&
      identical(token, _activeToken);

  static bool _connectionFailure(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      (error is ApiException &&
          error.statusCode == null &&
          const {
            'The request timed out. Please try again.',
            'Could not connect. Check your connection and try again.',
            'The connection was interrupted. Please try again.',
          }.contains(error.message));

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    widget.cache?.removeListener(_cacheChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _cacheInvalidated) return;
    _accessDenied = false;
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder presents the error and retry action.
    }
  }

  Future<void> _changeStatus(
    TrackedApplication application,
    Object token,
  ) async {
    if (!_canAct(token) || _updating.contains(application.opportunityId)) {
      return;
    }
    final status = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _StatusSheet(
        application: application,
        onSave: (status) async {
          if (!_canAct(token)) {
            throw const ApiException('Reconnect to update your saved list.');
          }
          setState(() => _updating.add(application.opportunityId));
          try {
            await widget.repository.saveTrackedApplication(
              opportunityId: application.opportunityId,
              status: status,
            );
          } finally {
            if (mounted) {
              setState(() => _updating.remove(application.opportunityId));
            }
          }
        },
      ),
    );
    if (status != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            'Application marked ${(_statusOptions[status] ?? status).toLowerCase()}.',
          ),
        ),
      );
      await _refresh();
    }
  }

  Future<void> _removeSaved(
    TrackedApplication application,
    Object token,
  ) async {
    if (!_canAct(token)) return;
    final removed = await confirmAction(
      context,
      title: 'Remove from saved?',
      message:
          'This removes the bookmark for ${application.title}. You can save it again from Discover.',
      actionLabel: 'Remove',
      action: () {
        if (!_canAct(token)) {
          throw const ApiException('Reconnect to update your saved list.');
        }
        return widget.repository.removeSaved(application.id);
      },
    );
    if (removed && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_ApplicationsResult>(
        future: _future,
        builder: (context, snapshot) {
          if (_cacheInvalidated) {
            return const Center(
              child: AppText('Your session changed. Please sign in again.'),
            );
          }
          if (!_accessDenied &&
              snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingView(label: 'Loading your applications…');
          }
          if (snapshot.hasError || _accessDenied) {
            return AppErrorView(
              title: 'Applications unavailable',
              message: 'We could not load your saved applications.',
              onRetry: _refresh,
            );
          }
          final result = snapshot.data!;
          if (result.cached != null) {
            return _CachedApplicationsView(
              snapshot: result.cached!,
              onRetry: _refresh,
            );
          }
          final all = result.applications;
          final saved = all.where((item) => item.status == 'saved').toList();
          final drafting = all
              .where((item) => item.status == 'drafting')
              .toList();
          final submitted = all
              .where(
                (item) =>
                    item.status == 'submitted' || item.status == 'awarded',
              )
              .toList();
          final shown = widget.savedOnly
              ? saved
                    .where(
                      (item) =>
                          !_closingSoon || item.dueWithinWeek(DateTime.now()),
                    )
                    .toList()
              : switch (_filter) {
                  'active' =>
                    all
                        .where(
                          (item) =>
                              item.status == 'saved' ||
                              item.status == 'drafting',
                        )
                        .toList(),
                  'saved' => saved,
                  'drafting' => drafting,
                  'submitted' => submitted,
                  _ => all,
                };
          if (widget.savedOnly && _closingSoon) {
            shown.sort((a, b) => a.deadline.compareTo(b.deadline));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
              children: [
                AppText(
                  widget.savedOnly
                      ? 'Keep the good ones.'
                      : 'Your applications.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                AppText(
                  widget.savedOnly
                      ? 'Your shortlist, ready when you are.'
                      : 'A little progress goes a long way.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.savedOnly)
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          '${AppStrings.tr(context, 'All saved')} · ${saved.length}',
                        ),
                        selected: !_closingSoon,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _closingSoon = false),
                      ),
                      ChoiceChip(
                        label: const AppText('Closing soon'),
                        selected: _closingSoon,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _closingSoon = true),
                      ),
                    ],
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth < 280 ||
                              MediaQuery.textScalerOf(context).scale(14) > 20
                          ? 1
                          : 3;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _SummaryCard(
                              value: saved.length.toString(),
                              label: 'Saved',
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _SummaryCard(
                              value: drafting.length.toString(),
                              label: 'In progress',
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _SummaryCard(
                              value: submitted.length.toString(),
                              label: 'Submitted',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const {
                        'active': 'Active',
                        'drafting': 'In progress',
                        'saved': 'Saved',
                        'submitted': 'Submitted',
                        'all': 'All',
                      }.entries)
                        ChoiceChip(
                          label: AppText(entry.value),
                          selected: _filter == entry.key,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _filter = entry.key),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                if (shown.isEmpty)
                  EmptyStateCard(
                    icon: widget.savedOnly
                        ? Icons.bookmark_border
                        : Icons.assignment_outlined,
                    title: widget.savedOnly && _closingSoon
                        ? 'No saved opportunities closing soon'
                        : all.isEmpty
                        ? 'No applications yet'
                        : 'Nothing here yet',
                    message: widget.savedOnly && _closingSoon
                        ? 'Saved opportunities with a deadline in the next seven days will appear here.'
                        : all.isEmpty
                        ? 'Open a match and start an application. It will appear here automatically.'
                        : 'Applications in this stage will appear here.',
                  )
                else
                  for (final application in shown) ...[
                    _ApplicationCard(
                      application: application,
                      savedPresentation: widget.savedOnly,
                      updating: _updating.contains(application.opportunityId),
                      onChangeStatus: () =>
                          _changeStatus(application, result.token),
                      onRemove: application.status == 'saved'
                          ? () => _removeSaved(application, result.token)
                          : null,
                      onOpen: application.opportunityId.startsWith('cat:')
                          ? () async {
                              if (!_canAct(result.token)) return;
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => ApplicationWorkspaceScreen(
                                    coaching: widget.coaching,
                                    repository: widget.repository,
                                    opportunityId: application.opportunityId,
                                  ),
                                ),
                              );
                              if (mounted) await _refresh();
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                if (widget.savedOnly) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const AppText(
                      'Saved here doesn’t mean applied. Your tracker keeps the next steps clear.',
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ApplicationsResult {
  _ApplicationsResult(this.applications, {this.cached});
  final List<TrackedApplication> applications;
  final ApplicationCacheSnapshot? cached;
  final Object token = Object();
}

class _CachedApplicationsView extends StatelessWidget {
  const _CachedApplicationsView({
    required this.snapshot,
    required this.onRetry,
  });
  final ApplicationCacheSnapshot snapshot;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final saved = snapshot.applications
        .where((item) => item.status == 'saved')
        .toList(growable: false);
    final checked = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_jm().format(snapshot.fetchedAt.toLocal());
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          AppText(
            'Keep your place.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const AppText('Saved opportunities are still here.'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Connection unavailable. Showing a read-only saved copy.',
                ),
                const SizedBox(height: 8),
                Text('${AppStrings.tr(context, 'Last checked')}: $checked'),
                if (!snapshot.complete) ...[
                  const SizedBox(height: 8),
                  const AppText(
                    'Only part of this account’s list is available offline.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const AppText('Try connecting again'),
          ),
          const SizedBox(height: 20),
          if (saved.isEmpty)
            const EmptyStateCard(
              icon: Icons.bookmark_border,
              title: 'No saved opportunities in this copy',
              message: 'Reconnect to load your current saved list.',
            ),
          for (final application in saved) ...[
            _ApplicationCard(
              application: application,
              onChangeStatus: null,
              updating: false,
              savedPresentation: true,
              readOnly: true,
            ),
            const SizedBox(height: 16),
          ],
          const AppText(
            'Current deadlines and availability may have changed. Reconnect before continuing.',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontFamily: 'InstrumentSans',
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          AppText(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.onChangeStatus,
    required this.updating,
    required this.savedPresentation,
    this.onOpen,
    this.onRemove,
    this.readOnly = false,
  });

  final TrackedApplication application;
  final VoidCallback? onChangeStatus;
  final bool updating;
  final bool savedPresentation;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusPill(
                        label: readOnly
                            ? 'Saved offline'
                            : savedPresentation && application.match > 0
                            ? '${application.match}% match'
                            : application.statusLabel,
                        emphasis:
                            application.status == 'submitted' ||
                            application.status == 'awarded',
                      ),
                      if (!savedPresentation &&
                          application.dueWithinWeek(DateTime.now()))
                        const StatusPill(label: 'Closing soon', emphasis: true),
                    ],
                  ),
                ),
                if (updating)
                  const SizedBox.square(
                    dimension: 20,
                    child: AppBusyIndicator(
                      strokeWidth: 2,
                      label: 'Updating application',
                    ),
                  ),
                IconButton(
                  tooltip: AppStrings.tr(context, 'Change application status'),
                  onPressed: updating ? null : onChangeStatus,
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              application.title,
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: [
                  if (application.organization.isNotEmpty)
                    TextSpan(text: '${application.organization} · '),
                  TextSpan(text: AppStrings.tr(context, application.kindLabel)),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final amount = application.amount.isEmpty
                    ? AppText(application.kindLabel)
                    : Text(
                        application.amount,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                final deadline = application.deadlineLabel.isEmpty
                    ? const AppText('See listing')
                    : Text(
                        application.deadlineLabel,
                        style: theme.textTheme.bodySmall,
                      );
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [amount, const SizedBox(height: 8), deadline],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: amount),
                    const SizedBox(width: 12),
                    Flexible(child: deadline),
                  ],
                );
              },
            ),
            if (onOpen != null) ...[
              const SizedBox(height: 16),
              if (application.status == 'drafting')
                FilledButton(
                  onPressed: updating ? null : onOpen,
                  child: const AppText('Continue application'),
                )
              else
                OutlinedButton(
                  onPressed: updating ? null : onOpen,
                  child: const AppText('Open application'),
                ),
            ],
            if (onRemove != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: updating ? null : onRemove,
                icon: const Icon(Icons.bookmark_remove_outlined),
                label: const AppText('Remove from saved'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.application, required this.onSave});
  final TrackedApplication application;
  final Future<void> Function(String status) onSave;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late String _selected = widget.application.status;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(_selected);
      if (mounted) Navigator.of(context).pop(_selected);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is ApiException
              ? error.message
              : 'Could not update this application. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppText(
                      'How’s it going?',
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.tr(context, 'Close'),
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.application.title,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              for (final entry in _statusOptions.entries) ...[
                Material(
                  color: _selected == entry.key
                      ? theme.colorScheme.primary.withValues(alpha: 0.06)
                      : theme.scaffoldBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _selected == entry.key
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: InkWell(
                    onTap: _busy
                        ? null
                        : () => setState(() => _selected = entry.key),
                    borderRadius: BorderRadius.circular(14),
                    child: Semantics(
                      checked: _selected == entry.key,
                      inMutuallyExclusiveGroup: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: AppText(entry.value)),
                              if (_selected == entry.key)
                                Icon(
                                  Icons.check,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: AppText(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? SizedBox.square(
                        dimension: 20,
                        child: AppBusyIndicator(
                          color: theme.colorScheme.onPrimary,
                          label: 'Updating application',
                          strokeWidth: 2,
                        ),
                      )
                    : AppText(_error == null ? 'Save status' : 'Retry'),
              ),
              const SizedBox(height: 16),
              AppText(
                'You can change this whenever things move.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
