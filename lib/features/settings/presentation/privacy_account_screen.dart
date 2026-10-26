import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/external_links.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';

class PrivacyAccountScreen extends StatelessWidget {
  const PrivacyAccountScreen({
    required this.repository,
    required this.email,
    required this.onSignOut,
    super.key,
  });
  final SettingsRepository repository;
  final String email;
  final Future<void> Function() onSignOut;

  void _deleteAccount(BuildContext context) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => DataFormScreen(
        title: 'Delete account',
        submitLabel: 'Delete my account',
        description:
            'This permanently deletes your account and owned data, and cancels active billing. Enter your account email and DELETE to confirm. This cannot be undone.',
        fields: [
          DataField(
            'email',
            'Account email',
            required: true,
            validate: (value) =>
                value.trim().toLowerCase() != email.toLowerCase()
                ? 'Enter your current account email.'
                : null,
          ),
          DataField(
            'confirmation',
            'Type DELETE',
            required: true,
            validate: (value) =>
                value != 'DELETE' ? 'Type DELETE exactly.' : null,
          ),
        ],
        save: (values) async {
          await repository.deleteAccount(values['email']!);
          await onSignOut();
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Privacy & account')),
    bottomNavigationBar: const WorkspaceBottomBar(),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AppText(
          'Your information. Your say.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const AppText('Keep control of your MyOccasio account.'),
        const SizedBox(height: 24),
        for (final link in const [
          (
            icon: Icons.shield_outlined,
            title: 'Privacy policy',
            description: 'Understand how your data is used.',
            path: '/privacy',
          ),
          (
            icon: Icons.description_outlined,
            title: 'Terms of service',
            description: 'Read the terms for using MyOccasio.',
            path: '/terms',
          ),
          (
            icon: Icons.accessibility_new,
            title: 'Accessibility',
            description: 'Accessibility support',
            path: '/accessibility',
          ),
        ]) ...[
          Card(
            child: ListTile(
              minTileHeight: 80,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: Icon(link.icon),
              title: AppText(
                link.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(link.description),
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openWebLink(context, link.path),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
        AppText(
          'Account actions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            minTileHeight: 72,
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: AppText(
              'Delete my account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _deleteAccount(context),
          ),
        ),
        const SizedBox(height: 16),
        const AppText('Deletion requires a separate confirmation.'),
      ],
    ),
  );
}
