import 'package:myoccasio/app/app_dependencies.dart';
import 'package:myoccasio/app/config/app_config.dart';
import 'package:myoccasio/app/state/language_controller.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/data/application_cache.dart';
import 'package:myoccasio/features/academics/data/study_plan_preferences_store.dart';
import 'package:myoccasio/features/academics/domain/study_plan.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'recording_api.dart';

AppDependencies recordingDependencies(
  RecordingApi api, {
  LanguageController? language,
}) => AppDependencies(
  config: AppConfig(
    environment: AppEnvironment.production,
    apiBaseUri: Uri.parse('https://example.test'),
  ),
  auth: AuthRepository(api, MemoryCookieStore()),
  profile: ProfileRepository(api),
  opportunities: OpportunitiesRepository(api),
  applications: ApplicationsRepository(api),
  academics: AcademicsRepository(api),
  coaching: CoachingRepository(api),
  community: CommunityRepository(api),
  settings: SettingsRepository(api),
  language: language,
  applicationCacheFactory: (accountId, namespace) => ApplicationCache(
    accountId: accountId,
    namespace: namespace,
    storage: _MemoryCacheStorage(),
  ),
  studyPlanPreferencesFactory: (_) => _MemoryStudyPreferences(),
);

class _MemoryCacheStorage implements ApplicationCacheStorage {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _MemoryStudyPreferences implements StudyPlanPreferencesStore {
  final _values = <String, StudyPlanPreferences>{};
  @override
  Future<StudyPlanPreferences> read(String accountId) async =>
      _values[accountId] ?? StudyPlanPreferences();
  @override
  Future<void> write(
    String accountId,
    StudyPlanPreferences preferences,
  ) async => _values[accountId] = preferences;
  @override
  Future<void> clear(String accountId) async => _values.remove(accountId);
}
