import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:myoccasio/core/localization/app_strings.dart';

String formatCredits(BuildContext context, num value) =>
    '${formatDecimal(context, value, digits: value == value.roundToDouble() ? 0 : 1)} ${AppStrings.tr(context, value == 1 ? 'Credit' : 'Credits').toLowerCase()}';

String formatDisplayDate(
  BuildContext context,
  DateTime value, {
  bool time = false,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final format = DateFormat.yMMMd(locale);
  if (time) {
    if (MediaQuery.alwaysUse24HourFormatOf(context)) {
      format.add_Hm();
    } else {
      format.add_jm();
    }
  }
  return format.format(value.toLocal());
}

String formatDashboardDate(BuildContext context, DateTime value) =>
    DateFormat.MMMMEEEEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value).toUpperCase();

String formatDecimal(BuildContext context, num value, {int digits = 2}) =>
    (NumberFormat.decimalPattern(
            Localizations.localeOf(context).toLanguageTag(),
          )
          ..minimumFractionDigits = digits
          ..maximumFractionDigits = digits)
        .format(value);
