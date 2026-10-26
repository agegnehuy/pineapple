import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/app/app_dependencies.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/widgets/app_brand.dart';
import 'package:myoccasio/features/academics/presentation/academics_screen.dart';
import 'package:myoccasio/features/academics/data/study_plan_preferences_store.dart';
import 'package:myoccasio/features/academics/presentation/study_plan_screen.dart';
import 'package:myoccasio/features/applications/data/application_cache.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';
import 'package:myoccasio/features/coaching/presentation/coach_screen.dart';
import 'package:myoccasio/features/coaching/presentation/story_screen.dart';
import 'package:myoccasio/features/community/presentation/community_screen.dart';
import 'package:myoccasio/features/home/presentation/home_screen.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/features/opportunities/presentation/opportunities_screen.dart';
import 'package:myoccasio/features/profile/presentation/profile_screen.dart';
import 'package:myoccasio/features/profile/presentation/onboarding_screen.dart';
import 'package:myoccasio/features/settings/presentation/settings_screen.dart';
import 'package:myoccasio/features/settings/presentation/support_screen.dart';
import 'dart:async';
import 'package:myoccasio/features/reminders/data/deadline_reminders.dart';
import 'package:myoccasio/features/reminders/presentation/reminder_scope.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.dependencies,
    required this.sessionController,
    super.key,
  });
  final AppDependencies dependencies;
  final AppSessionController sessionController;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _pages = <int, Widget>{};
  bool _signingOut = false;
  String? _profileName;
  ApplicationCache? _applicationCache;
  late StudyPlanPreferencesStore _studyPreferences;
  ReminderSession? _reminders;
  String get _accountId =>
      (widget.sessionController.session?.user?['id'] ?? '').toString();
  @override
  void initState() {
    super.initState();
    final namespace = widget.dependencies.config.apiBaseUri.toString();
    if (_accountId.trim().isNotEmpty) {
      _reminders = widget.dependencies.reminders?.beginSession(_accountId);
    }
    if (_accountId.trim().isNotEmpty) {
      _applicationCache =
          widget.dependencies.applicationCacheFactory?.call(
            _accountId,
            namespace,
          ) ??
          ApplicationCache(accountId: _accountId, namespace: namespace);
    }
    _studyPreferences =
        widget.dependencies.studyPlanPreferencesFactory?.call(namespace) ??
        SecureStudyPlanPreferencesStore(namespace: namespace);
    widget.dependencies.profile.addListener(_refreshIdentity);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerOnboarding());
  }

  Future<void> _refreshIdentity() async {
    try {
      final profile = await widget.dependencies.profile.getCurrentUser();
      if (mounted) setState(() => _profileName = profile.firstName);
    } on Object {
      // Keep the last confirmed identity when a refresh is unavailable.
    }
  }

  @override
  void dispose() {
    widget.dependencies.profile.removeListener(_refreshIdentity);
    _applicationCache?.dispose();
    unawaited(_reminders?.end().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _offerOnboarding() async {
    try {
      final profile = await widget.dependencies.profile.getCurrentUser();
      if (!mounted) return;
      setState(() => _profileName = profile.firstName);
      if (profile.completionPercent == 100) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(
            repository: widget.dependencies.profile,
            profile: profile,
          ),
        ),
      );
      if (changed == true && mounted) setState(_pages.clear);
    } on Object {
      // The dashboard and profile page retain their own retry paths.
    }
  }

  void _select(int index) {
    final navigation = WorkspaceNavigationScope.maybeOf(context);
    if (navigation == null) {
      setState(() => _index = index);
    } else {
      navigation.selectRootTab(index);
    }
  }

  void _open(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  void _show(Widget page) {
    if (!mounted) return;
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  Widget _supportPage() => SupportScreen(
    repository: widget.dependencies.settings,
    email: widget.sessionController.session?.email ?? '',
    name: widget.sessionController.session?.firstName ?? '',
  );

  Widget _settingsPage() => SettingsScreen(
    appearance: widget.dependencies.appearance,
    language: widget.dependencies.language,
    repository: widget.dependencies.settings,
    email: widget.sessionController.session?.email ?? '',
    onSignOut: _signOut,
    onProfile: () => _show(_profilePage()),
  );

  Widget _profilePage() => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('My profile')),
    body: ProfileScreen(
      repository: widget.dependencies.profile,
      onSignOut: _signOut,
      onStory: () =>
          _show(StoryScreen(repository: widget.dependencies.coaching)),
      onSettings: () => _show(_settingsPage()),
      onHelp: () => _show(_supportPage()),
    ),
  );

  Future<void> _signOut() async {
    if (!mounted || _signingOut) return;
    setState(() => _signingOut = true);
    try {
      final accountId = _accountId;
      try {
        await Future.wait([
          if (_applicationCache != null) _applicationCache!.clear(),
          if (accountId.isNotEmpty) _studyPreferences.clear(accountId),
          if (_reminders != null) _reminders!.end(),
        ]).timeout(const Duration(seconds: 3));
      } on Object {
        // Local caches invalidate immediately. Storage failure must not prevent
        // the authenticated session from being cleared.
      }
      await widget.sessionController.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Could not clear your session. Please try signing out again.',
            ),
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Widget _page(int index) => _pages.putIfAbsent(
    index,
    () => switch (index) {
      0 => HomeScreen(
        profile: widget.dependencies.profile,
        coaching: widget.dependencies.coaching,
        firstName: widget.sessionController.session?.firstName ?? '',
        opportunitiesRepository: widget.dependencies.opportunities,
        applicationsRepository: widget.dependencies.applications,
        onExplore: () => _select(1),
        onApplications: () => _select(2),
        onActivity: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ActivityScreen(repository: widget.dependencies.settings),
          ),
        ),
      ),
      1 => OpportunitiesScreen(
        profile: widget.dependencies.profile,
        coaching: widget.dependencies.coaching,
        repository: widget.dependencies.opportunities,
        applicationsRepository: widget.dependencies.applications,
        onEditProfile: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => _profilePage()),
          );
        },
      ),
      2 => ApplicationsScreen(
        repository: widget.dependencies.applications,
        coaching: widget.dependencies.coaching,
        cache: _applicationCache,
        accountId: _accountId,
      ),
      3 => AcademicsScreen(
        repository: widget.dependencies.academics,
        onStory: () =>
            _show(StoryScreen(repository: widget.dependencies.coaching)),
        onStudyPlan: () => _show(
          StudyPlanScreen(
            repository: widget.dependencies.academics,
            accountId: _accountId,
            preferencesStore: _studyPreferences,
          ),
        ),
      ),
      _ => CoachScreen(repository: widget.dependencies.coaching),
    },
  );
  @override
  Widget build(BuildContext context) {
    final index =
        WorkspaceNavigationScope.maybeOf(context)?.selectedIndex ?? _index;
    _page(index);
    final deps = widget.dependencies;
    final profileName =
        _profileName ?? widget.sessionController.session?.firstName ?? '';
    return ReminderLifecycle(
      session: _reminders,
      child: Scaffold(
        appBar: AppBar(
          title: const AppBrand(compact: true),
          actions: [
            IconButton(
              tooltip: AppStrings.tr(context, 'Recent activity'),
              icon: const Icon(Icons.notifications_none),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityScreen(repository: deps.settings),
                ),
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                tooltip: AppStrings.tr(context, 'Open menu'),
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        endDrawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const AppBrand(compact: true),
                  trailing: IconButton(
                    tooltip: AppStrings.tr(context, 'Close menu'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                ListTile(
                  title: profileName.trim().isEmpty
                      ? const AppText('Your workspace')
                      : Text(profileName),
                  subtitle: Text(widget.sessionController.session?.email ?? ''),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const AppText('Saved opportunities'),
                  onTap: () => _open(
                    Scaffold(
                      bottomNavigationBar: const WorkspaceBottomBar(),
                      appBar: AppBar(
                        title: const AppText('Saved opportunities'),
                      ),
                      body: ApplicationsScreen(
                        coaching: deps.coaching,
                        repository: deps.applications,
                        savedOnly: true,
                        cache: _applicationCache,
                        accountId: _accountId,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const AppText('Community'),
                  onTap: () => _open(
                    CommunityScreen(
                      repository: deps.community,
                      supportRepository: deps.settings,
                      email: widget.sessionController.session?.email ?? '',
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.coffee_outlined),
                  title: const AppText('Coffee chats'),
                  onTap: () => _open(
                    CommunityScreen(
                      repository: deps.community,
                      initialTab: 2,
                      supportRepository: deps.settings,
                      email: widget.sessionController.session?.email ?? '',
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const AppText('My story'),
                  onTap: () => _open(StoryScreen(repository: deps.coaching)),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const AppText('My profile'),
                  onTap: () => _open(_profilePage()),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const AppText('Settings'),
                  onTap: () => _open(_settingsPage()),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const AppText('Help & support'),
                  onTap: () => _open(
                    SupportScreen(
                      repository: deps.settings,
                      email: widget.sessionController.session?.email ?? '',
                      name: widget.sessionController.session?.firstName ?? '',
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const AppText('Plan & AI allowance'),
                  onTap: () => _open(PlanScreen(repository: deps.settings)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: AppText(_signingOut ? 'Signing out…' : 'Sign out'),
                  enabled: !_signingOut,
                  onTap: () async {
                    try {
                      await _signOut();
                    } on Object {
                      /* The failure is already shown above. */
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < 5; i++) _pages[i] ?? const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: WorkspaceBottomBar(
          selectedIndex: index,
          onDestinationSelected: _select,
        ),
      ),
    );
  }
}
