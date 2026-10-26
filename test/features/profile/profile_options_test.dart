import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/features/profile/domain/profile_options.dart';

void main() {
  test(
    'legacy plural opportunity labels normalize to actual matching keys',
    () {
      expect(canonicalOpportunityType(' Scholarships '), 'scholarship');
      expect(canonicalOpportunityType('Internships'), 'internship');
      expect(canonicalOpportunityType('grant'), 'grant');
      expect(citizenshipOptions['citizen'], 'Canadian citizen');
    },
  );
}
