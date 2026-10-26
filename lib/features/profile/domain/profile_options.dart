// Stored values from MyOccasio's matching-options.ts and ApplyWizard.tsx.
const citizenshipOptions = {
  'citizen': 'Canadian citizen',
  'pr': 'Permanent resident',
  'intl': 'International student',
  'refugee': 'Refugee',
  'other': 'Other',
};
const studyYears = [
  'High school',
  '1st year',
  '2nd year',
  '3rd year',
  '4th year',
  '5+ year',
  'Graduate',
];
const opportunityTypeOptions = {
  'scholarship': 'Scholarships',
  'internship': 'Internships',
  'grant': 'Grants',
  'job': 'Jobs',
};

const matchingInterests = [
  'Science & Technology',
  'Engineering',
  'Computer Science',
  'Artificial Intelligence & Data',
  'Business',
  'Finance',
  'Economics',
  'Arts & Design',
  'Humanities',
  'Social Sciences',
  'Health & Medicine',
  'Mental Health & Wellness',
  'Law',
  'Education',
  'Environment & Sustainability',
  'Skilled Trades',
  'Media & Communications',
  'Marketing & Sales',
  'Entrepreneurship',
  'Research',
  'Government & Public Service',
  'International Affairs',
  'Human Rights & Advocacy',
  'Community & Social Impact',
  'Sports & Recreation',
  'Agriculture & Food',
  'Hospitality & Tourism',
  'Architecture & Urban Planning',
  'Transportation & Logistics',
  'Energy & Natural Resources',
];

const importedProfileLabels = {
  'firstName': 'First name',
  'lastName': 'Last name',
  'email': 'Email address',
  'institution': 'Institution',
  'program': 'Program of study',
  'year': 'Year of study',
  'interests': 'Interests',
};
const writableImportFields = {
  'firstName',
  'lastName',
  'institution',
  'program',
  'year',
  'interests',
};

String canonicalOpportunityType(String value) =>
    switch (value.trim().toLowerCase()) {
      'scholarships' || 'scholarship' => 'scholarship',
      'internships' || 'internship' => 'internship',
      'grants' || 'grant' => 'grant',
      'jobs' || 'job' => 'job',
      _ => value.trim(),
    };
