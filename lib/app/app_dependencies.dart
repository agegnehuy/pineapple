import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myoccasio/app/state/appearance_controller.dart';
import 'package:myoccasio/app/state/language_controller.dart';
import 'package:myoccasio/app/config/app_config.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/data/application_cache.dart';
import 'package:myoccasio/features/academics/data/study_plan_preferences_store.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/data/native_auth_repository.dart';
import 'package:myoccasio/features/opportunities/data/opportunities_repository.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/community/data/community_repository.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/reminders/data/deadline_reminders.dart';
import 'package:myoccasio/features/reminders/data/reminder_platform.dart';

class AppDependencies {
  AppDependencies({
    required this.config,
    required this.auth,
    required this.profile,
    required this.opportunities,
    required this.applications,
    required this.academics,
    required this.coaching,
    required this.community,
    required this.settings,
    this.applicationCacheFactory,
    this.studyPlanPreferencesFactory,
    this.reminders,
    this.nativeAuth,
    AppearanceController? appearance,
    LanguageController? language,
  }) : appearance = appearance ?? AppearanceController(),
       language = language ?? LanguageController();

  factory AppDependencies.production(AppConfig config) {
    const secureStorage = FlutterSecureStorage();
    final cookieStore = SecureCookieStore(secureStorage);
    final language = LanguageController(
      read: () => secureStorage.read(key: 'myoccasio.language'),
      write: (value) =>
          secureStorage.write(key: 'myoccasio.language', value: value),
    );
    final apiClient = ApiClient(
      baseUri: config.apiBaseUri,
      cookieStore: cookieStore,
      language: () => language.code,
    );

    final auth = AuthRepository(apiClient, cookieStore);
    return AppDependencies(
      config: config,
      auth: auth,
      nativeAuth: NativeAuthRepository(
        api: apiClient,
        auth: auth,
        cookies: cookieStore,
        baseUri: config.apiBaseUri,
      ),
      profile: ProfileRepository(apiClient),
      opportunities: OpportunitiesRepository(apiClient),
      applications: ApplicationsRepository(apiClient),
      academics: AcademicsRepository(apiClient),
      coaching: CoachingRepository(apiClient),
      community: CommunityRepository(apiClient),
      settings: SettingsRepository(apiClient),
      reminders: DeadlineReminders(
        platform: DeviceReminderPlatform(),
        namespace: config.apiBaseUri.toString(),
        language: () => language.code,
      ),
      appearance: AppearanceController(
        read: () => secureStorage.read(key: 'myoccasio.appearance'),
        write: (value) =>
            secureStorage.write(key: 'myoccasio.appearance', value: value),
      ),
      language: language,
    );
  }

  final AppConfig config;
  final AuthRepository auth;
  final NativeAuthRepository? nativeAuth;
  final ProfileRepository profile;
  final OpportunitiesRepository opportunities;
  final ApplicationsRepository applications;
  final AcademicsRepository academics;
  final CoachingRepository coaching;
  final CommunityRepository community;
  final SettingsRepository settings;
  final DeadlineReminders? reminders;
  final ApplicationCache Function(String accountId, String namespace)?
  applicationCacheFactory;
  final StudyPlanPreferencesStore Function(String namespace)?
  studyPlanPreferencesFactory;
  final AppearanceController appearance;
  final LanguageController language;
}
