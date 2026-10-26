class TrackedApplication {
  const TrackedApplication({
    required this.id,
    required this.opportunityId,
    required this.title,
    required this.organization,
    required this.amount,
    required this.deadlineLabel,
    required this.status,
    required this.match,
    required this.kindLabel,
    this.deadline = '',
    this.removed = false,
  });

  factory TrackedApplication.fromJson(Map<String, dynamic> json) {
    return TrackedApplication(
      id: (json['id'] ?? '').toString(),
      opportunityId: (json['opportunityId'] ?? '').toString(),
      title: (json['title'] ?? 'Opportunity').toString(),
      organization: (json['org'] ?? '').toString(),
      amount: (json['amount'] ?? '').toString(),
      deadlineLabel: (json['deadlineLabel'] ?? '').toString(),
      status: (json['status'] ?? 'saved').toString(),
      match: (json['match'] as num?)?.round() ?? 0,
      kindLabel: (json['kindLabel'] ?? 'Opportunity').toString(),
      deadline: (json['deadline'] ?? '').toString(),
      removed: json['removed'] == true,
    );
  }

  final String id;
  final String opportunityId;
  final String title;
  final String organization;
  final String amount;
  final String deadlineLabel;
  final String status;
  final int match;
  final String kindLabel;
  final String deadline;
  final bool removed;

  bool dueWithinWeek(DateTime now) {
    if (status != 'saved' && status != 'drafting') return false;
    final due = DateTime.tryParse(deadline);
    if (due == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return !due.isBefore(today) &&
        !due.isAfter(DateTime(now.year, now.month, now.day + 7));
  }

  String get statusLabel => switch (status) {
    'drafting' => 'In progress',
    'submitted' => 'Submitted',
    'awarded' => 'Awarded',
    'rejected' => 'Not selected',
    _ => 'Saved',
  };
}

const applicationSubmissionLabels = {
  'submitted': 'Submitted',
  'under_review': 'Under review',
  'shortlisted': 'Shortlisted',
  'awarded': 'Awarded',
  'declined': 'Declined',
  'withdrawn': 'Withdrawn',
};
