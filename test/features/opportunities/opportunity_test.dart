import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/features/opportunities/domain/opportunity.dart';

void main() {
  test('maps a backend match response', () {
    final opportunity = Opportunity.fromJson({
      'id': 'future-leaders',
      'title': 'Future Leaders Award',
      'org': 'Occasio Foundation',
      'kind': 'scholarship',
      'kindLabel': 'Scholarship',
      'amount': r'$5,000',
      'deadlineLabel': 'Nov 14',
      'match': 94,
      'reasons': ['Matches your field'],
      'tags': ['Leadership'],
      'logo': 'O',
    });

    expect(opportunity.title, 'Future Leaders Award');
    expect(opportunity.match, 94);
    expect(opportunity.reasons, ['Matches your field']);
  });
}
