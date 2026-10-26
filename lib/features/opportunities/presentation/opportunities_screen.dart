import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunity_localization.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity_filter.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_filter_sheet.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunity_detail_screen.dart';
import 'package:myoccasio/features/opportunities/presentation/widgets/opportunity_card.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({
    required this.repository,
    required this.applicationsRepository,
    this.onEditProfile,
    this.coaching,
    this.profile,
    super.key,
  });

  final OpportunitiesRepository repository;
  final ApplicationsRepository applicationsRepository;
  final Future<void> Function()? onEditProfile;
  final CoachingRepository? coaching;
  final ProfileRepository? profile;

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  late Future<OpportunityFeed> _future;
  final _search = TextEditingController();
  String _query = '';
  OpportunityFilter _filterOptions = const OpportunityFilter();
  OpportunitySort _sort = OpportunitySort.bestMatch;
  Set<String>? _saved;
  final _saving = <String>{};

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getMatches();
    _loadSaved();
    widget.applicationsRepository.addListener(_loadSaved);
    widget.profile?.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.applicationsRepository.removeListener(_loadSaved);
    widget.profile?.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final tracked = await widget.applicationsRepository
          .getTrackedApplications();
      if (mounted) {
        setState(() => _saved = tracked.map((a) => a.opportunityId).toSet());
      }
    } on Object {
      /* Matches remain available; do not risk overwriting an unknown tracker status. */
    }
  }

  Future<void> _save(Opportunity opportunity) async {
    if (_saved == null ||
        _saved!.contains(opportunity.id) ||
        _saving.contains(opportunity.id)) {
      return;
    }
    setState(() => _saving.add(opportunity.id));
    try {
      await widget.applicationsRepository.bookmark(opportunity.id);
      if (mounted) {
        setState(() => _saved!.add(opportunity.id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('Opportunity saved.')));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const AppText('Could not save this opportunity.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _save(opportunity),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(opportunity.id));
    }
  }

  Future<void> _refresh() async {
    final future = widget.repository.getMatches();
    _loadSaved();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder presents the error and retry action.
    }
  }

  Future<void> _showFilters(List<Opportunity> source) async {
    final result = await showModalBottomSheet<OpportunityFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      builder: (_) => OpportunityFilterSheet(
        initial: _filterOptions,
        source: source,
        query: _query,
      ),
    );
    if (result != null && mounted) setState(() => _filterOptions = result);
  }

  Future<void> _open(Opportunity opportunity) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OpportunityDetailScreen(
          coaching: widget.coaching,
          opportunity: opportunity,
          applicationsRepository: widget.applicationsRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<OpportunityFeed>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingView(
              label: 'Finding your strongest matches…',
            );
          }
          if (snapshot.hasError) {
            return AppErrorView(
              title: 'Matches are taking a break',
              message: 'We could not load your opportunities right now.',
              onRetry: _refresh,
            );
          }
          final feed = snapshot.data!;
          final opportunities = _filterOptions.apply(
            feed.opportunities,
            query: _query,
            sort: _sort,
            additionalTerms: (item) =>
                localizedOpportunitySearchTerms(context, item),
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                  sliver: SliverList.list(
                    children: [
                      AppText(
                        'Made for you',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        '${feed.totalMatches} opportunities shaped around your profile.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: AppStrings.tr(
                            context,
                            'Search opportunities',
                          ),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showFilters(feed.opportunities),
                            icon: const Icon(Icons.tune),
                            label: AppText(
                              _filterOptions.isActive
                                  ? 'Filters applied'
                                  : 'Filters',
                            ),
                          ),
                          DropdownButton<OpportunitySort>(
                            value: _sort,
                            onChanged: (value) =>
                                setState(() => _sort = value!),
                            items: const [
                              DropdownMenuItem(
                                value: OpportunitySort.bestMatch,
                                child: AppText('Best match'),
                              ),
                              DropdownMenuItem(
                                value: OpportunitySort.closingSoon,
                                child: AppText('Closing soon'),
                              ),
                              DropdownMenuItem(
                                value: OpportunitySort.title,
                                child: AppText('Title'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppText('${opportunities.length} results shown'),
                    ],
                  ),
                ),
                if (feed.opportunities.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(22),
                    sliver: SliverToBoxAdapter(
                      child: EmptyStateCard(
                        icon: Icons.person_search_outlined,
                        title: feed.profileStatus == 'complete'
                            ? 'No matches yet'
                            : 'Complete your profile',
                        message: feed.profileStatus == 'complete'
                            ? 'No opportunities fit your profile right now. Check again later or review your interests.'
                            : feed.profileStatus.isEmpty
                            ? 'Add your academic and interest details to unlock personalized matches.'
                            : 'Your profile needs a little more detail before matching can begin.',
                        action: widget.onEditProfile == null
                            ? null
                            : FilledButton(
                                onPressed: () async {
                                  await widget.onEditProfile!();
                                  if (mounted) await _refresh();
                                },
                                child: const AppText('Review profile'),
                              ),
                      ),
                    ),
                  )
                else if (opportunities.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(22),
                    sliver: SliverToBoxAdapter(
                      child: EmptyStateCard(
                        icon: Icons.search_off,
                        title: 'No results',
                        message: 'Try a different search or opportunity type.',
                        action: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () {
                                _search.clear();
                                setState(() {
                                  _query = '';
                                  _filterOptions = const OpportunityFilter();
                                });
                              },
                              child: const AppText('Reset filters'),
                            ),
                            if (widget.onEditProfile != null)
                              OutlinedButton(
                                onPressed: () async {
                                  await widget.onEditProfile!();
                                  if (mounted) await _refresh();
                                },
                                child: const AppText('Edit my interests'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 110),
                    sliver: SliverList.separated(
                      itemCount: opportunities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final opportunity = opportunities[index];
                        return OpportunityCard(
                          opportunity: opportunity,
                          onTap: () => _open(opportunity),
                          saved: _saved?.contains(opportunity.id) == true,
                          saving: _saving.contains(opportunity.id),
                          onSave:
                              _saved == null || _saving.contains(opportunity.id)
                              ? null
                              : () => _save(opportunity),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
