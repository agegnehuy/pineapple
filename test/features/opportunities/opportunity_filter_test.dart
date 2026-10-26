import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity_filter.dart';
import 'package:myoccasio/core/network/external_links.dart';

Opportunity item(
  String id, {
  String kind = 'scholarship',
  String deadline = '',
  int match = 90,
  String region = 'ON',
}) => Opportunity.fromJson({
  'id': id,
  'title': id,
  'kind': kind,
  'deadline': deadline,
  'match': match,
  'region': region,
  'org': 'University',
  'tags': ['Science'],
});
void main() {
  test('bilingual search folds accents without changing provider content', () {
    final source = [item('École de génie'), item('Other', kind: 'internship')];
    const filter = OpportunityFilter();
    expect(filter.apply(source, query: 'ecole').single.title, 'École de génie');
    expect(filter.apply(source, query: 'E\u0301COLE').single, source.first);
    expect(
      filter
          .apply(
            source,
            query: 'bourses',
            additionalTerms: (entry) =>
                entry.kind == 'scholarship' ? ['Bourses'] : ['Stages'],
          )
          .single,
      source.first,
    );
    expect(filter.apply(source, query: 'internship').single, source.last);
    expect(source.first.title, 'École de génie');
  });
  test('multi-kind, region, trimmed query and date filters compose', () {
    final list = [
      item('A', deadline: '2026-12-20'),
      item('B', kind: 'internship', deadline: '2026-12-22'),
      item('C', region: 'BC', deadline: '2026-12-23'),
      item('D', deadline: '2026-12-01'),
      item('E'),
    ];
    final result = const OpportunityFilter(
      kinds: {'scholarship', 'internship'},
      region: 'ON',
      deadline: DeadlineWindow.thisMonth,
    ).apply(list, query: ' SCIENCE ', now: DateTime(2026, 12, 15));
    expect(result.map((o) => o.id), ['A', 'B']);
  });
  test('next month crosses year boundary and excludes unknown dates', () {
    final result = const OpportunityFilter(deadline: DeadlineWindow.nextMonth)
        .apply([
          item('January', deadline: '2027-01-02'),
          item('December', deadline: '2026-12-28'),
          item('Rolling'),
        ], now: DateTime(2026, 12, 20));
    expect(result.single.id, 'January');
  });
  test('sort never mutates source and unknown deadlines sort last', () {
    final source = [
      item('B'),
      item('A', deadline: '2026-12-10'),
      item('C', deadline: '2026-11-10'),
    ];
    final result = const OpportunityFilter().apply(
      source,
      sort: OpportunitySort.closingSoon,
    );
    expect(result.map((o) => o.id), ['C', 'A', 'B']);
    expect(source.first.id, 'B');
  });
  test(
    'external links permit web providers and reject executable or credential URLs',
    () {
      expect(safeWebUri('javascript:alert(1)'), isNull);
      expect(safeWebUri('file:///secret'), isNull);
      expect(safeWebUri('https://name:password@example.test'), isNull);
      expect(safeWebUri('/dashboard/applications/abc')?.host, 'myoccasio.ca');
      expect(safeWebUri('https://provider.test/apply')?.host, 'provider.test');
    },
  );
}
