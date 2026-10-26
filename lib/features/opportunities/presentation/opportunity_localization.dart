import 'package:flutter/widgets.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/profile/domain/profile_options.dart';

Iterable<String> localizedOpportunitySearchTerms(
  BuildContext context,
  Opportunity item,
) sync* {
  yield AppStrings.tr(context, item.kindLabel);
  final plural = opportunityTypeOptions[item.kind];
  if (plural != null) yield AppStrings.tr(context, plural);
  for (final tag in item.tags) {
    if (matchingInterests.contains(tag)) yield AppStrings.tr(context, tag);
  }
}
