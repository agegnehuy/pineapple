import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    required this.opportunity,
    required this.onTap,
    this.featured = false,
    this.onSave,
    this.saved = false,
    this.saving = false,
    super.key,
  });

  final Opportunity opportunity;
  final VoidCallback onTap;
  final bool featured;
  final VoidCallback? onSave;
  final bool saved;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = featured ? Colors.white : scheme.onSurface;
    final secondary = featured
        ? Colors.white.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;
    final value = opportunity.amount.isEmpty
        ? AppStrings.tr(context, 'Varies')
        : opportunity.amount;
    final deadline = opportunity.deadlineLabel.isEmpty
        ? AppStrings.tr(context, 'See details')
        : opportunity.deadlineLabel;
    return Card(
      color: featured ? AppColors.forest : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: featured ? BorderSide.none : BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (opportunity.match > 0 || onSave != null || saved || saving)
                Row(
                  children: [
                    if (opportunity.match > 0)
                      Flexible(
                        child: StatusPill(label: '${opportunity.match}% match'),
                      ),
                    const Spacer(),
                    if (onSave != null || saved || saving)
                      IconButton(
                        tooltip: AppStrings.tr(
                          context,
                          saved ? 'Opportunity saved' : 'Save opportunity',
                        ),
                        color: featured ? Colors.white : scheme.primary,
                        disabledColor: featured
                            ? Colors.white.withValues(alpha: 0.78)
                            : scheme.primary,
                        onPressed: saved || saving ? null : onSave,
                        icon: saving
                            ? SizedBox.square(
                                dimension: 20,
                                child: AppBusyIndicator(
                                  color: foreground,
                                  label: 'Saving opportunity',
                                ),
                              )
                            : Icon(
                                saved ? Icons.bookmark : Icons.bookmark_border,
                              ),
                      ),
                  ],
                ),
              Text(
                opportunity.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: foreground,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    if (opportunity.organization.isNotEmpty)
                      TextSpan(text: '${opportunity.organization} · '),
                    TextSpan(
                      text: AppStrings.tr(context, opportunity.kindLabel),
                    ),
                  ],
                ),
                style: TextStyle(color: secondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              Divider(color: secondary.withValues(alpha: 0.22), height: 1),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final amountWidget = Text(
                    value,
                    style: TextStyle(
                      color: featured ? Colors.white : scheme.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                  final deadlineWidget = Text(
                    deadline,
                    style: TextStyle(color: secondary, fontSize: 12),
                  );
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        amountWidget,
                        const SizedBox(height: 6),
                        deadlineWidget,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: amountWidget),
                      const SizedBox(width: 14),
                      Flexible(child: deadlineWidget),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
