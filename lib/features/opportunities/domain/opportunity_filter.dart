import 'package:myoccasio/features/opportunities/domain/opportunity.dart';

enum DeadlineWindow { any, thisMonth, nextMonth }

enum OpportunitySort { bestMatch, closingSoon, title }

class OpportunityFilter {
  const OpportunityFilter({
    this.kinds = const {},
    this.region = '',
    this.deadline = DeadlineWindow.any,
  });
  final Set<String> kinds;
  final String region;
  final DeadlineWindow deadline;
  bool get isActive =>
      kinds.isNotEmpty || region.isNotEmpty || deadline != DeadlineWindow.any;

  List<Opportunity> apply(
    List<Opportunity> source, {
    String query = '',
    OpportunitySort sort = OpportunitySort.bestMatch,
    DateTime? now,
    Iterable<String> Function(Opportunity)? additionalTerms,
  }) {
    final today = now ?? DateTime.now();
    final search = normalizeOpportunitySearch(query.trim());
    final result = source.where((item) {
      if (kinds.isNotEmpty && !kinds.contains(item.kind)) return false;
      if (region.isNotEmpty && item.region != region && item.market != region) {
        return false;
      }
      if (search.isNotEmpty &&
          ![
            item.title,
            item.organization,
            item.kind,
            item.kindLabel,
            ...item.tags,
            if (additionalTerms != null) ...additionalTerms(item),
          ].any((text) => normalizeOpportunitySearch(text).contains(search))) {
        return false;
      }
      if (deadline != DeadlineWindow.any) {
        final due = DateTime.tryParse(item.deadline);
        if (due == null) return false;
        final month = deadline == DeadlineWindow.thisMonth
            ? DateTime(today.year, today.month)
            : DateTime(today.year, today.month + 1);
        if (due.isBefore(DateTime(today.year, today.month, today.day)) ||
            due.year != month.year ||
            due.month != month.month) {
          return false;
        }
      }
      return true;
    }).toList();
    result.sort((a, b) {
      final order = switch (sort) {
        OpportunitySort.bestMatch => b.match.compareTo(a.match),
        OpportunitySort.title => normalizeOpportunitySearch(
          a.title,
        ).compareTo(normalizeOpportunitySearch(b.title)),
        OpportunitySort.closingSoon =>
          (DateTime.tryParse(a.deadline) ?? DateTime(9999)).compareTo(
            DateTime.tryParse(b.deadline) ?? DateTime(9999),
          ),
      };
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return result;
  }
}

String normalizeOpportunitySearch(String value) {
  const accents = {
    'a': 'àáâäãå',
    'c': 'ç',
    'e': 'èéêë',
    'i': 'ìíîï',
    'n': 'ñ',
    'o': 'òóôöõ',
    'u': 'ùúûü',
    'y': 'ýÿ',
    'oe': 'œ',
    'ae': 'æ',
  };
  var result = value.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  for (final entry in accents.entries) {
    for (final character in entry.value.split('')) {
      result = result.replaceAll(character, entry.key);
    }
  }
  return result;
}
