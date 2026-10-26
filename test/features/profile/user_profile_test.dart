import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';

void main() {
  test('calculates profile completeness', () {
    final profile = UserProfile.fromJson({
      'user': {
        'firstName': 'Amara',
        'lastName': 'K',
        'institution': 'University of Toronto',
        'program': 'Computer Science',
        'year': '3rd year',
        'citizenship': 'citizen',
        'interests': ['Technology'],
        'opportunityTypes': ['Scholarships'],
      },
    });

    expect(profile.displayName, 'Amara K');
    expect(profile.completionPercent, 100);
  });
}
