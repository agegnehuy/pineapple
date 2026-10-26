const storyFields = {
  'background': 'Your background',
  'motivation': 'What motivates you',
  'achievements': 'What you’re proud of',
  'communityInvolvement': 'Your community involvement',
  'academicInterests': 'Academic interests',
  'careerInterests': 'Career interests',
  'financialContext': 'Financial context (optional)',
};

Set<String> availableStorySources(Map<String, dynamic> story) => storyFields
    .keys
    .where(
      (key) =>
          (story[key]?.toString() ?? '').trim().isNotEmpty &&
          (key != 'financialContext' ||
              story['allowFinancialContextUse'] == true),
    )
    .toSet();
