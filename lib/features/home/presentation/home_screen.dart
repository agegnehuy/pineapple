import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_brand.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunity_detail_screen.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.firstName,
    required this.opportunitiesRepository,
    required this.applicationsRepository,
    required this.onExplore,
    required this.onApplications,
    this.onActivity,
    this.coaching,
    this.profile,
    super.key,
  });

  final String firstName;
  final OpportunitiesRepository opportunitiesRepository;
  final ApplicationsRepository applicationsRepository;
  final VoidCallback onExplore;
  final VoidCallback onApplications;
  final VoidCallback? onActivity;
  final CoachingRepository? coaching;
  final ProfileRepository? profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;
  final _saving = <String>{};

  Future<void> _bookmark(Opportunity opportunity) async {
    if (_saving.contains(opportunity.id)) return;
    setState(() => _saving.add(opportunity.id));
    try {
      await widget.applicationsRepository.bookmark(opportunity.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('Opportunity saved.')));
        await _refresh();
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const AppText('Could not save this opportunity.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _bookmark(opportunity),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(opportunity.id));
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.applicationsRepository.addListener(_refresh);
    widget.profile?.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.applicationsRepository.removeListener(_refresh);
    widget.profile?.removeListener(_refresh);
    super.dispose();
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait<dynamic>([
      widget.opportunitiesRepository.getMatches(),
      widget.applicationsRepository.getTrackedApplications(),
    ]);
    return _HomeData(
      feed: results[0] as OpportunityFeed,
      applications: results[1] as List<TrackedApplication>,
    );
  }

  Future<void> _refresh() async {
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

  Future<void> _open(Opportunity opportunity) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OpportunityDetailScreen(
          coaching: widget.coaching,
          opportunity: opportunity,
          applicationsRepository: widget.applicationsRepository,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingView(label: 'Preparing your dashboard…');
          }
          if (snapshot.hasError) {
            return AppErrorView(
              title: 'We could not open your dashboard',
              message: 'Check your connection and try again.',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data!;
          final firstName =
              (data.feed.firstName.isEmpty
                      ? widget.firstName
                      : data.feed.firstName)
                  .trim();
          final activeCount = data.applications
              .where((item) => item.status == 'drafting')
              .length;
          final now = DateTime.now();
          final dueSoon = data.applications
              .where((item) => item.dueWithinWeek(now))
              .length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
              children: [
                if (widget.onActivity == null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppBrand(compact: true),
                      IconButton(
                        tooltip: AppStrings.tr(context, 'Notifications'),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: AppText(
                              'Notifications are not available in this app yet.',
                            ),
                          ),
                        ),
                        icon: Icon(Icons.notifications_none),
                      ),
                    ],
                  ),
                const SizedBox(height: 30),
                AppText(
                  firstName.isEmpty
                      ? 'A little closer.'
                      : 'A little closer, $firstName.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                AppText(
                  formatDashboardDate(context, now),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(label: 'YOUR NEXT BEST STEP'),
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        data.feed.opportunities.isEmpty
                            ? 'Your next chapter\nstarts here.'
                            : 'A strong match.\nA fresh start.',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: widget.onExplore,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.forest,
                        ),
                        child: const AppText('Find my opportunities'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, box) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(14) > 20 ? 1 : 3;
                    final width = (box.maxWidth - (columns - 1) * 8) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: _DashboardMetric(
                            value: data.feed.totalMatches.toString(),
                            label: 'Matches',
                            onTap: widget.onExplore,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _DashboardMetric(
                            value: activeCount.toString(),
                            label: 'In progress',
                            onTap: widget.onApplications,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _DashboardMetric(
                            value: dueSoon.toString(),
                            label: 'Due soon',
                            onTap: widget.onApplications,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                SectionTitle(
                  'Picked for you',
                  trailing: TextButton(
                    onPressed: widget.onExplore,
                    child: const AppText('See all'),
                  ),
                ),
                const SizedBox(height: 14),
                for (final opportunity in data.feed.opportunities.take(3)) ...[
                  OpportunityCard(
                    opportunity: opportunity,
                    onTap: () => _open(opportunity),
                    onSave: () => _bookmark(opportunity),
                    saving: _saving.contains(opportunity.id),
                    saved: data.applications.any(
                      (item) => item.opportunityId == opportunity.id,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              AppText(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeData {
  const _HomeData({required this.feed, required this.applications});

  final OpportunityFeed feed;
  final List<TrackedApplication> applications;
}
