class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.institution,
    required this.program,
    required this.degree,
    required this.year,
    required this.citizenship,
    required this.gpa,
    required this.interests,
    required this.opportunityTypes,
    required this.financialNeed,
    required this.linkedinUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final data = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    List<String> strings(String key) =>
        (data[key] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false);

    return UserProfile(
      id: (data['id'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      institution: (data['institution'] ?? '').toString(),
      program: (data['program'] ?? '').toString(),
      degree: (data['degree'] ?? '').toString(),
      year: (data['year'] ?? '').toString(),
      citizenship: (data['citizenship'] ?? '').toString(),
      gpa: (data['gpa'] ?? '').toString(),
      interests: strings('interests'),
      opportunityTypes: strings('opportunityTypes'),
      financialNeed: (data['financialNeed'] ?? '').toString(),
      linkedinUrl: (data['linkedinUrl'] ?? '').toString(),
    );
  }

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String institution;
  final String program;
  final String degree;
  final String year;
  final String citizenship;
  final String gpa;
  final List<String> interests;
  final List<String> opportunityTypes;
  final String financialNeed;
  final String linkedinUrl;

  String get displayName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? 'My profile' : value;
  }

  String get initials {
    final letters = [firstName, lastName]
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();
    return letters.isEmpty ? 'MO' : letters;
  }

  int get completionPercent {
    final values = <bool>[
      firstName.isNotEmpty,
      lastName.isNotEmpty,
      institution.isNotEmpty,
      program.isNotEmpty,
      year.isNotEmpty,
      citizenship.isNotEmpty,
      interests.isNotEmpty,
      opportunityTypes.isNotEmpty,
    ];
    return ((values.where((value) => value).length / values.length) * 100)
        .round();
  }
}
