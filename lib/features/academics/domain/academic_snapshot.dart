class AcademicCourse {
  AcademicCourse.fromJson(Map<String, dynamic> json)
    : id = json['id'].toString(),
      name = (json['name'] ?? '').toString(),
      code = (json['code'] ?? '').toString(),
      term = (json['term'] ?? '').toString(),
      credits = (json['credits'] as num?)?.toDouble() ?? 0,
      grade = (json['gradePercent'] as num?)?.toDouble(),
      status = (json['status'] ?? 'planned').toString();
  final String id, name, code, term, status;
  final double credits;
  final double? grade;
}

class AcademicSnapshot {
  AcademicSnapshot.fromJson(Map<String, dynamic> json)
    : courses = (json['courses'] as List)
          .cast<Map<String, dynamic>>()
          .map(AcademicCourse.fromJson)
          .toList(),
      deadlines = (json['deadlines'] as List).cast<Map<String, dynamic>>(),
      assessments = (json['assessments'] as List).cast<Map<String, dynamic>>(),
      degreePlan = json['degreePlan'] as Map<String, dynamic>?,
      calculations = (json['calculations'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
  final List<AcademicCourse> courses;
  final List<Map<String, dynamic>> deadlines, assessments, calculations;
  final Map<String, dynamic>? degreePlan;
  double? get gpa {
    final graded = courses.where((c) => c.grade != null && c.credits > 0);
    final credits = graded.fold<double>(0, (sum, c) => sum + c.credits);
    if (credits == 0) return null;
    return graded.fold<double>(
          0,
          (sum, c) => sum + gradeToGpa(c.grade!) * c.credits,
        ) /
        credits;
  }
}

/// The website's default 4.0 scale; institutions can use other scales.
double gradeToGpa(double percent) {
  for (final band in const [
    (85, 4.0),
    (80, 3.7),
    (77, 3.3),
    (73, 3.0),
    (70, 2.7),
    (67, 2.3),
    (63, 2.0),
    (60, 1.7),
    (57, 1.3),
    (53, 1.0),
    (50, 0.7),
  ]) {
    if (percent >= band.$1) return band.$2;
  }
  return 0;
}
