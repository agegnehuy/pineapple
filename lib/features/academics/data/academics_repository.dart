import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/features/academics/domain/academic_snapshot.dart';
import 'package:myoccasio/features/academics/domain/grading_scale.dart';

class AcademicsRepository {
  AcademicsRepository(this._api);
  final ApiClient _api;
  Future<List<GradingScale>> getGradingScales() async =>
      GradingScale.parseList((await _api.get('/api/grading-scales')).json);
  Future<void> saveCalculation(Map<String, Object?> values) async {
    await _api.postJson('/api/academic/calculations', values);
  }

  Future<void> deleteCalculation(String id) async {
    await _api.deleteJson(
      '/api/academic/calculations/${Uri.encodeComponent(id)}',
    );
  }

  Future<AcademicSnapshot> getSnapshot() async => AcademicSnapshot.fromJson(
    (await _api.get('/api/academic')).json as Map<String, dynamic>,
  );
  Future<void> saveCourse(Map<String, Object?> values, {String? id}) async {
    if (id == null) {
      await _api.postJson('/api/academic/courses', values);
    } else {
      await _api.patchJson(
        '/api/academic/courses/${Uri.encodeComponent(id)}',
        values,
      );
    }
  }

  Future<void> deleteCourse(String id) async {
    await _api.deleteJson('/api/academic/courses/${Uri.encodeComponent(id)}');
  }

  Future<void> saveAssessment(Map<String, Object?> values, {String? id}) async {
    if (id == null) {
      await _api.postJson('/api/academic/assessments', values);
    } else {
      await _api.patchJson(
        '/api/academic/assessments/${Uri.encodeComponent(id)}',
        values,
      );
    }
  }

  Future<void> deleteAssessment(String id) async {
    await _api.deleteJson(
      '/api/academic/assessments/${Uri.encodeComponent(id)}',
    );
  }

  Future<void> updateDeadline(String id, Map<String, Object?> values) async {
    await _api.patchJson(
      '/api/academic/deadlines/${Uri.encodeComponent(id)}',
      values,
    );
  }

  Future<void> deleteDeadline(String id) async {
    await _api.deleteJson('/api/academic/deadlines/${Uri.encodeComponent(id)}');
  }

  Future<void> saveDeadline(Map<String, Object?> values) async {
    await _api.postJson('/api/academic/deadlines', values);
  }

  Future<void> saveDegreePlan(Map<String, Object?> values) async {
    await _api.putJson('/api/academic/degree', values);
  }

  Future<List<Map<String, dynamic>>> getGoals() async =>
      ((await _api.get('/api/academic/goals')).json['goals'] as List)
          .cast<Map<String, dynamic>>();
  Future<void> saveGoal(Map<String, Object?> values, {String? id}) async {
    if (id == null) {
      await _api.postJson('/api/academic/goals', values);
    } else {
      await _api.patchJson(
        '/api/academic/goals/${Uri.encodeComponent(id)}',
        values,
      );
    }
  }

  Future<void> deleteGoal(String id) async {
    await _api.deleteJson('/api/academic/goals/${Uri.encodeComponent(id)}');
  }
}
