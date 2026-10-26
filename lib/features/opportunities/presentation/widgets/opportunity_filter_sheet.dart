import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunity_localization.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity_filter.dart';

class OpportunityFilterSheet extends StatefulWidget {
  const OpportunityFilterSheet({
    required this.initial,
    required this.source,
    this.query = '',
    super.key,
  });
  final OpportunityFilter initial;
  final List<Opportunity> source;
  final String query;
  @override
  State<OpportunityFilterSheet> createState() => _OpportunityFilterSheetState();
}

class _OpportunityFilterSheetState extends State<OpportunityFilterSheet> {
  late Set<String> _kinds = {...widget.initial.kinds};
  late String _region = widget.initial.region;
  late DeadlineWindow _deadline = widget.initial.deadline;
  OpportunityFilter get _filter =>
      OpportunityFilter(kinds: _kinds, region: _region, deadline: _deadline);

  @override
  Widget build(BuildContext context) {
    final regions =
        widget.source
            .map((o) => o.region.isEmpty ? o.market : o.region)
            .where((r) => r.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    'Find your fit.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.tr(context, 'Close filters'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AppText(
              'Opportunity type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  'scholarship': 'Scholarship',
                  'internship': 'Internship',
                  'grant': 'Grant',
                  'job': 'Job',
                }.entries)
                  FilterChip(
                    label: AppText(entry.value),
                    selected: _kinds.contains(entry.key),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _kinds.add(entry.key);
                      } else {
                        _kinds.remove(entry.key);
                      }
                    }),
                  ),
              ],
            ),
            if (regions.isNotEmpty) ...[
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _region,
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(
                  labelText: AppStrings.tr(context, 'Location'),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: AppText('All locations'),
                    ),
                  ),
                  for (final region in regions)
                    DropdownMenuItem(
                      value: region,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(region),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _region = value ?? ''),
              ),
            ],
            const SizedBox(height: 24),
            AppText('Deadline', style: Theme.of(context).textTheme.titleLarge),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  DeadlineWindow.any: 'Any time',
                  DeadlineWindow.thisMonth: 'This month',
                  DeadlineWindow.nextMonth: 'Next month',
                }.entries)
                  ChoiceChip(
                    label: AppText(entry.value),
                    selected: _deadline == entry.key,
                    onSelected: (_) => setState(() => _deadline = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.pop(context, _filter),
              child: AppText(
                'Show ${_filter.apply(widget.source, query: widget.query, additionalTerms: (item) => localizedOpportunitySearchTerms(context, item)).length} opportunities',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _kinds = {};
                _region = '';
                _deadline = DeadlineWindow.any;
              }),
              child: const AppText('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }
}
