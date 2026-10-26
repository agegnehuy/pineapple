import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/app/state/appearance_controller.dart';
import 'package:myoccasio/app/state/language_controller.dart';
import 'package:myoccasio/features/settings/presentation/appearance_screen.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/network/external_links.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/features/settings/presentation/support_screen.dart';
import 'package:myoccasio/features/settings/presentation/privacy_account_screen.dart';
import 'package:myoccasio/features/reminders/presentation/reminder_scope.dart';
import 'package:myoccasio/features/reminders/presentation/device_reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.repository,
    required this.email,
    required this.onSignOut,
    this.appearance,
    this.language,
    this.onProfile,
    super.key,
  });
  final SettingsRepository repository;
  final String email;
  final Future<void> Function() onSignOut;
  final AppearanceController? appearance;
  final LanguageController? language;
  final VoidCallback? onProfile;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([?appearance, ?language]),
    builder: (context, _) => Scaffold(
      bottomNavigationBar: const WorkspaceBottomBar(),
      appBar: AppBar(title: const AppText('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText(
            'Your space. Your rules.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          const AppText('Account, preferences, and support.'),
          const SizedBox(height: 24),
          ...<Widget>[
            if (ReminderScope.maybeOf(context) case final reminders?)
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const AppText('Device reminders'),
                subtitle: const AppText(
                  'Your deadline reminders on this phone.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceRemindersScreen(session: reminders),
                  ),
                ),
              ),
            if (onProfile != null)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const AppText('Profile & education'),
                subtitle: const AppText('Keep your details up to date.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onProfile,
              ),
            if (appearance != null)
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const AppText('Language and appearance'),
                subtitle: Text(
                  '${AppStrings.tr(context, language?.code == 'fr' ? 'French' : 'English')} · ${AppStrings.tr(context, switch (appearance!.mode) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'Follow device',
                  })}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppearanceScreen(
                      controller: appearance!,
                      language: language,
                    ),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const AppText('Plan & AI allowance'),
              subtitle: const AppText(
                'View your plan and remaining allowance.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanScreen(repository: repository),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const AppText('Help & support'),
              subtitle: const AppText('Find an answer or get in touch.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SupportScreen(repository: repository, email: email),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const AppText('Notification preferences'),
              subtitle: const AppText('Matches, deadlines, and community'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationPreferencesScreen(repository: repository),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const AppText('Recent activity'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityScreen(repository: repository),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const AppText('Privacy & account'),
              subtitle: const AppText(
                'Your data, privacy, and account controls.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PrivacyAccountScreen(
                    repository: repository,
                    email: email,
                    onSignOut: onSignOut,
                  ),
                ),
              ),
            ),
          ].map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTileTheme(
                  data: ListTileThemeData(
                    minTileHeight: 80,
                    titleTextStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: entry,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({required this.repository, super.key});
  final SettingsRepository repository;
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _busy = false;
  bool _refreshing = false;

  Future<void> _savePreference(
    String key,
    bool value,
    Map<String, dynamic> data,
    Future<void> Function() refresh,
  ) async {
    if (_busy || _refreshing) return;
    setState(() => _busy = true);
    try {
      await widget.repository.updateNotifications({key: value});
      if (!mounted) return;
      setState(() {
        // Reflect only a confirmed write, including when the next read fails.
        data[key] = value;
        _busy = false;
        _refreshing = true;
      });
      await refresh();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              error is ApiException
                  ? error.message
                  : 'Could not save your preference. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      bottomNavigationBar: WorkspaceBottomBar(enabled: !_busy),
      appBar: AppBar(title: const AppText('Notification preferences')),
      body: AsyncContent<Map<String, dynamic>>(
        load: widget.repository.notifications,
        builder: (context, data, refresh) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppText(
              'Only the right nudges.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const AppText('Choose what you’d like to hear about.'),
            const SizedBox(height: 24),
            for (final entry in const {
              'matches': ('New matches', 'Opportunities that fit your profile'),
              'deadlines': (
                'Deadline reminders',
                'A heads-up before saved items close',
              ),
              'applications': (
                'Application updates',
                'Progress and next-step reminders',
              ),
              'community': (
                'Community activity',
                'Replies and coffee chat requests',
              ),
              'weeklyRoundup': (
                'Weekly roundup',
                'A little inspiration, once a week',
              ),
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: AppText(
                      entry.value.$1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AppText(entry.value.$2),
                    ),
                    value: data[entry.key] == true,
                    onChanged: _busy || _refreshing
                        ? null
                        : (value) =>
                              _savePreference(entry.key, value, data, refresh),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const AppText(
              'These preferences apply to your MyOccasio account. Device push notifications are separate.',
            ),
          ],
        ),
      ),
    ),
  );
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({required this.repository, super.key});
  final SettingsRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('Recent activity')),
    body: AsyncContent<List<Map<String, dynamic>>>(
      load: repository.activity,
      builder: (context, items, refresh) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          AppText(
            'A little heads-up.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const AppText('Recent activity from your MyOccasio account.'),
          const SizedBox(height: 24),
          if (items.isEmpty)
            const EmptyStateCard(
              icon: Icons.notifications_none,
              title: 'No recent activity',
              message: 'Your account activity will appear here.',
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(item['title'].toString()),
                  subtitle: Text(
                    [
                      item['subtitle'],
                      item['createdAt']?.toString().split('T').first,
                    ].where((s) => s != null && s != '').join('\n'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NotificationPreferencesScreen(repository: repository),
              ),
            ),
            child: const AppText('Manage notification preferences'),
          ),
        ],
      ),
    ),
  );
}

class PlanScreen extends StatelessWidget {
  const PlanScreen({required this.repository, super.key});
  final SettingsRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('Plan & AI allowance')),
    body: AsyncContent<Map<String, dynamic>>(
      load: () async {
        final results = await Future.wait([
          repository.plan(),
          repository.allowance(),
        ]);
        return {'plan': results[0]['plan'], 'allowance': results[1]};
      },
      builder: (context, data, refresh) {
        final plan = data['plan'] as Map<String, dynamic>;
        final allowance = data['allowance'] as Map<String, dynamic>;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppText(
              'Room for your next step.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['label'] == 'Free'
                          ? AppStrings.tr(context, 'Free')
                          : (plan['label'] ?? plan['tier']).toString(),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      '${allowance['messagesRemaining'] ?? 0} AI messages remaining',
                    ),
                    if (allowance['coveredBySubscription'] == true)
                      const AppText(
                        'Included with your subscription. Fair-use limits apply.',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                try {
                  final url = await repository.billingPortal();
                  if (context.mounted) await openWebLink(context, url);
                } on Object catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: AppText(
                          error is ApiException
                              ? error.message
                              : 'Billing is unavailable. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const AppText('Manage existing billing'),
            ),
          ],
        );
      },
    ),
  );
}
