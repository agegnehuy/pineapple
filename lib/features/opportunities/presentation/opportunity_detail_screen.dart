import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/core/network/external_links.dart';
import 'package:myoccasio/features/applications/presentation/application_workspace_screen.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/features/reminders/presentation/reminder_scope.dart';
import 'package:myoccasio/features/reminders/presentation/deadline_reminder_sheet.dart';

class OpportunityDetailScreen extends StatefulWidget {
  const OpportunityDetailScreen({
    required this.opportunity,
    required this.applicationsRepository,
    this.coaching,
    super.key,
  });

  final Opportunity opportunity;
  final ApplicationsRepository applicationsRepository;
  final CoachingRepository? coaching;

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  bool _saving = false;
  bool _openingReminder = false;

  Future<void> _remind() async {
    final session = ReminderScope.maybeOf(context);
    if (_saving || _openingReminder || session == null || !session.active) {
      return;
    }
    setState(() => _openingReminder = true);
    try {
      final saved = await showDeadlineReminder(
        context,
        session: session,
        opportunityId: widget.opportunity.id,
        title: widget.opportunity.title,
        deadline: widget.opportunity.deadline,
      );
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Reminder saved on this device.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingReminder = false);
    }
  }

  Future<void> _bookmark() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.applicationsRepository.bookmark(widget.opportunity.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('Opportunity saved.')));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Could not save this opportunity. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startApplication() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.applicationsRepository.saveTrackedApplication(
        opportunityId: widget.opportunity.id,
        status: 'drafting',
      );
      if (!mounted) return;
      if (widget.opportunity.id.startsWith('cat:')) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ApplicationWorkspaceScreen(
              coaching: widget.coaching,
              repository: widget.applicationsRepository,
              opportunityId: widget.opportunity.id,
            ),
          ),
        );
        if (mounted) setState(() => _saving = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Added to your applications.')),
      );
      Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Could not save this application. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final opportunity = widget.opportunity;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final deadline = opportunity.deadlineLabel.isNotEmpty
        ? opportunity.deadlineLabel
        : opportunity.deadline.isNotEmpty
        ? opportunity.deadline
        : AppStrings.tr(context, 'See listing');
    return Scaffold(
      bottomNavigationBar: WorkspaceBottomBar(enabled: !_saving),
      appBar: AppBar(title: const Text('MyOccasio')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opportunity.title,
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    if (opportunity.organization.isNotEmpty)
                      Text(
                        opportunity.organization,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusPill(label: opportunity.kindLabel),
                              if (opportunity.match > 0)
                                StatusPill(
                                  label: '${opportunity.match}% match',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: AppStrings.tr(context, 'Save opportunity'),
                          onPressed: _saving ? null : _bookmark,
                          icon: const Icon(Icons.bookmark_border),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (ReminderScope.maybeOf(context) != null) ...[
                      OutlinedButton.icon(
                        onPressed: _saving || _openingReminder ? null : _remind,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const AppText('Remind me'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      key: const ValueKey('opportunity-value-hero'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (opportunity.organization.isNotEmpty)
                            Text(
                              opportunity.organization,
                              style: const TextStyle(
                                color: AppColors.mint,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            opportunity.amount.isEmpty
                                ? AppStrings.tr(context, 'Varies')
                                : opportunity.amount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          if (opportunity.amountSub.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              opportunity.amountSub,
                              style: const TextStyle(color: AppColors.mint),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${AppStrings.tr(context, 'Deadline')} · ',
                                ),
                                TextSpan(text: deadline),
                              ],
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppText(
                      'Why this fits you',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: opportunity.reasons.isEmpty
                          ? const AppText(
                              'Match details are not available. Review the provider’s eligibility criteria before applying.',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var index = 0;
                                  index < opportunity.reasons.length;
                                  index++
                                ) ...[
                                  if (index > 0) const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check,
                                        color: scheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(opportunity.reasons[index]),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 22),
                    AppText(
                      'Make your next chapter count.',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      opportunity.summary.isEmpty
                          ? AppStrings.tr(
                              context,
                              'Review the opportunity details and begin your application when you are ready.',
                            )
                          : opportunity.summary,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (opportunity.applyMode != 'myoccasio' &&
                        opportunity.url != null) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => openWebLink(context, opportunity.url!),
                        icon: const Icon(Icons.open_in_new),
                        label: const AppText('View provider listing'),
                      ),
                    ],
                    if (opportunity.tags.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: opportunity.tags
                            .map((tag) => Chip(label: Text(tag)))
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outline)),
              ),
              child: FilledButton(
                onPressed: _saving ? null : _startApplication,
                child: _saving
                    ? SizedBox.square(
                        dimension: 20,
                        child: AppBusyIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const AppText('Start application'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
