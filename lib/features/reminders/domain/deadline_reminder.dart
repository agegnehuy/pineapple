class DeadlineReminder {
  const DeadlineReminder({
    required this.notificationId,
    required this.opportunityId,
    required this.title,
    required this.deadline,
    required this.daysBefore,
    required this.scheduledAt,
  });

  static const choices = [1, 3, 7];
  final int notificationId;
  final String opportunityId;
  final String title;
  final String deadline;
  final int daysBefore;
  final DateTime scheduledAt;

  /// Date-only catalogue deadlines have no provider time zone. Use a disclosed
  /// 9am device-local reminder; timestamps retain their actual instant.
  static DateTime? timeFor(String deadline, int daysBefore) {
    if (!choices.contains(daysBefore)) return null;
    final date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(deadline);
    if (date != null) {
      final year = int.parse(date[1]!);
      final month = int.parse(date[2]!);
      final day = int.parse(date[3]!);
      final parsed = DateTime(year, month, day);
      if (year < 2020 ||
          year > 2200 ||
          parsed.year != year ||
          parsed.month != month ||
          parsed.day != day) {
        return null;
      }
      return DateTime(year, month, day - daysBefore, 9);
    }
    final timestamp = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?(?:Z|([+-])(\d{2}):(\d{2}))$',
    ).firstMatch(deadline);
    if (timestamp == null) {
      return null;
    }
    final year = int.parse(timestamp[1]!);
    final month = int.parse(timestamp[2]!);
    final day = int.parse(timestamp[3]!);
    final calendarDate = DateTime.utc(year, month, day);
    if (year < 2020 ||
        year > 2200 ||
        calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day ||
        int.parse(timestamp[4]!) > 23 ||
        int.parse(timestamp[5]!) > 59 ||
        int.parse(timestamp[6] ?? '0') > 59 ||
        int.parse(timestamp[8] ?? '0') > 23 ||
        int.parse(timestamp[9] ?? '0') > 59) {
      return null;
    }
    final parsed = DateTime.tryParse(deadline);
    return parsed?.subtract(Duration(days: daysBefore));
  }

  bool get isDateOnly => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(deadline);

  Map<String, dynamic> toJson() => {
    'notificationId': notificationId,
    'opportunityId': opportunityId,
    'title': title,
    'deadline': deadline,
    'daysBefore': daysBefore,
    'scheduledAt': scheduledAt.toUtc().toIso8601String(),
  };

  factory DeadlineReminder.fromJson(Map<String, dynamic> data) {
    const keys = {
      'notificationId',
      'opportunityId',
      'title',
      'deadline',
      'daysBefore',
      'scheduledAt',
    };
    if (data.length != keys.length ||
        !data.keys.every(keys.contains) ||
        data['notificationId'] is! int ||
        data['notificationId'] < 1 ||
        data['notificationId'] > 2147483646 ||
        data['daysBefore'] is! int ||
        !choices.contains(data['daysBefore']) ||
        data['opportunityId'] is! String ||
        (data['opportunityId'] as String).trim().isEmpty ||
        (data['opportunityId'] as String).length > 256 ||
        data['title'] is! String ||
        (data['title'] as String).trim().isEmpty ||
        (data['title'] as String).length > 500 ||
        data['deadline'] is! String ||
        (data['deadline'] as String).length > 80 ||
        data['scheduledAt'] is! String ||
        !(data['scheduledAt'] as String).endsWith('Z')) {
      throw const FormatException('Invalid deadline reminder.');
    }
    final time = DateTime.tryParse(data['scheduledAt']);
    if (time == null ||
        time.year < 2020 ||
        time.year > 2200 ||
        timeFor(data['deadline'], data['daysBefore']) == null) {
      throw const FormatException('Invalid deadline reminder time.');
    }
    return DeadlineReminder(
      notificationId: data['notificationId'],
      opportunityId: data['opportunityId'],
      title: data['title'],
      deadline: data['deadline'],
      daysBefore: data['daysBefore'],
      scheduledAt: time.toUtc(),
    );
  }
}
