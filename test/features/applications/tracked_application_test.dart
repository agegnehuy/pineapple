import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';

void main() {
  test(
    'due-soon count uses actual dates and excludes submitted or missing deadlines',
    () {
      final now = DateTime(2026, 12, 28);
      TrackedApplication application(String deadline, String status) =>
          TrackedApplication.fromJson({'deadline': deadline, 'status': status});
      expect(application('2027-01-02', 'drafting').dueWithinWeek(now), isTrue);
      expect(application('2026-12-27', 'saved').dueWithinWeek(now), isFalse);
      expect(
        application('2027-01-02', 'submitted').dueWithinWeek(now),
        isFalse,
      );
      expect(application('', 'saved').dueWithinWeek(now), isFalse);
    },
  );
  test('maps application status labels', () {
    final application = TrackedApplication.fromJson({
      'id': '1',
      'opportunityId': 'future-leaders',
      'title': 'Future Leaders Award',
      'status': 'drafting',
    });

    expect(application.statusLabel, 'In progress');
  });
}
