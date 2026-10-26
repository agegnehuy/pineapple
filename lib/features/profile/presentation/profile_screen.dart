import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/features/profile/domain/profile_options.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/profile/presentation/import_profile_screen.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/profile/data/profile_repository.dart';
import 'package:myoccasio/features/profile/domain/user_profile.dart';
import 'package:myoccasio/features/profile/presentation/edit_profile_screen.dart';
import 'package:myoccasio/features/profile/presentation/resume_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.repository,
    required this.onSignOut,
    this.onStory,
    this.onSettings,
    this.onHelp,
    super.key,
  });

  final ProfileRepository repository;
  final Future<void> Function() onSignOut;
  final VoidCallback? onStory;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _future;
  bool _signingOut = false;
  bool _confirmingSignOut = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getCurrentUser();
    widget.repository.addListener(_profileChanged);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_profileChanged);
      widget.repository.addListener(_profileChanged);
      _future = widget.repository.getCurrentUser();
    }
  }

  void _profileChanged() {
    if (mounted) _refresh();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_profileChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.repository.getCurrentUser();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder presents the error and retry action.
    }
  }

  Future<void> _edit(UserProfile profile) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(profile: profile, repository: widget.repository),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    if (_signingOut || _confirmingSignOut) return;
    setState(() => _confirmingSignOut = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Sign out?'),
        content: const AppText('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Sign out'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirmingSignOut = false);
    if (confirmed != true) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Could not clear your session. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<UserProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingView(label: 'Loading your profile…');
          }
          if (snapshot.hasError) {
            return AppErrorView(
              title: 'Profile unavailable',
              message: 'We could not load your profile right now.',
              onRetry: _refresh,
              secondaryAction: TextButton.icon(
                onPressed: _signingOut || _confirmingSignOut
                    ? null
                    : _confirmSignOut,
                icon: Icon(Icons.logout),
                label: const AppText('Sign out'),
              ),
            );
          }
          final profile = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 110),
              children: [
                AppText(
                  'Make it yours.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                const AppText('A profile that grows with you.'),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.mint,
                          foregroundColor: AppColors.forest,
                          child: Text(
                            profile.initials,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.firstName.isEmpty &&
                                        profile.lastName.isEmpty
                                    ? AppStrings.tr(context, 'My profile')
                                    : profile.displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                profile.institution.isEmpty
                                    ? profile.email
                                    : profile.institution,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (profile.program.isNotEmpty)
                                Text(
                                  profile.program,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: AppStrings.tr(context, 'Edit profile'),
                          onPressed: () => _edit(profile),
                          icon: Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Your story is ${profile.completionPercent}% complete.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: profile.completionPercent / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        color: AppColors.coral,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => _edit(profile),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.forest,
                        ),
                        child: AppText(
                          profile.completionPercent == 100
                              ? 'Review profile'
                              : 'Complete profile',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _ProfileSection(
                  icon: Icons.person_outline,
                  title: 'Your basics',
                  detail: profile.citizenship.isEmpty
                      ? AppStrings.tr(context, 'Add your personal details')
                      : citizenshipOptions.containsKey(profile.citizenship)
                      ? AppStrings.tr(
                          context,
                          citizenshipOptions[profile.citizenship]!,
                        )
                      : profile.citizenship,
                  onTap: () => _edit(profile),
                ),
                _ProfileSection(
                  icon: Icons.school_outlined,
                  title: 'Academics',
                  detail: [
                    profile.program,
                    studyYears.contains(profile.year)
                        ? AppStrings.tr(context, profile.year)
                        : profile.year,
                  ].where((value) => value.isNotEmpty).join(' · '),
                  onTap: () => _edit(profile),
                ),
                _ProfileSection(
                  icon: Icons.interests_outlined,
                  title: 'Interests',
                  detail: profile.interests.isEmpty
                      ? AppStrings.tr(context, 'Tell us what matters to you')
                      : profile.interests
                            .take(3)
                            .map(
                              (value) => matchingInterests.contains(value)
                                  ? AppStrings.tr(context, value)
                                  : value,
                            )
                            .join(', '),
                  onTap: () => _edit(profile),
                ),
                _ProfileSection(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Financial context',
                  detail: AppStrings.tr(
                    context,
                    profile.financialNeed.isEmpty ? 'Optional' : 'Saved',
                  ),
                  onTap: () => _edit(profile),
                ),
                const SizedBox(height: 22),
                _ProfileSection(
                  icon: Icons.description_outlined,
                  title: 'Your résumé',
                  detail: AppStrings.tr(
                    context,
                    'Save, replace or download your résumé',
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          ResumeScreen(repository: widget.repository),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ImportProfileScreen(repository: widget.repository),
                      ),
                    );
                  },
                  icon: Icon(Icons.file_upload_outlined),
                  label: const AppText('Import profile'),
                ),
                const SizedBox(height: 12),
                if (widget.onStory != null ||
                    widget.onSettings != null ||
                    widget.onHelp != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onStory != null)
                        TextButton(
                          onPressed: widget.onStory,
                          child: const AppText('My story'),
                        ),
                      if (widget.onSettings != null)
                        TextButton(
                          onPressed: widget.onSettings,
                          child: const AppText('Settings'),
                        ),
                      if (widget.onHelp != null)
                        TextButton(
                          onPressed: widget.onHelp,
                          child: const AppText('Help'),
                        ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: _signingOut || _confirmingSignOut
                      ? null
                      : _confirmSignOut,
                  icon: Icon(Icons.logout),
                  label: const AppText('Sign out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          minTileHeight: 72,
          onTap: onTap,
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: AppText(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: detail.isEmpty
              ? const AppText('Add details')
              : Text(detail),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
