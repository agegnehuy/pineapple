import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/external_links.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/auth/domain/auth_validation.dart';
import 'package:myoccasio/features/settings/data/settings_repository.dart';
import 'package:myoccasio/core/widgets/app_states.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    required this.repository,
    this.email = '',
    this.name = '',
    this.reference,
    super.key,
  });
  final SettingsRepository repository;
  final String email, name;
  final String? reference;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _search = TextEditingController();
  String _query = '';
  SettingsRepository get repository => widget.repository;
  String get email => widget.email;
  String get name => widget.name;
  String? get reference => widget.reference;

  static const _answers = <({String question, String answer})>[
    (
      question: 'How are matches chosen?',
      answer:
          'Matches use the details saved in your profile. Keep your education, interests and preferences up to date, and check each provider’s requirements before applying.',
    ),
    (
      question: 'Where do I submit an application?',
      answer:
          'Open the application workspace. MyOccasio submits directly only when the provider supports it and you confirm. Otherwise, use the official provider website. Saving or tracking an opportunity does not submit an application.',
    ),
    (
      question: 'How does AI allowance work?',
      answer:
          'Your plan and remaining allowance appear in Plan & AI allowance. Drafting and coaching requests may use that allowance. Review generated text before saving or sharing it.',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final shown = _answers.where(
      (entry) => [
        entry.question,
        entry.answer,
        AppStrings.tr(context, entry.question),
        AppStrings.tr(context, entry.answer),
      ].any((value) => value.toLowerCase().contains(query)),
    );
    return _content(context, shown);
  }

  Widget _content(
    BuildContext context,
    Iterable<({String question, String answer})> answers,
  ) => Scaffold(
    appBar: AppBar(title: const AppText('Help & support')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AppText(
          'Let’s work it out.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 20),
        const AppText('Answers and a little human help.'),
        const SizedBox(height: 12),
        const AppText(
          'Get help with your account, matching, or an application. Keep passwords and private documents out of your message.',
        ),
        const SizedBox(height: 24),
        if (reference == null) ...[
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              labelText: AppStrings.tr(context, 'Search help'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: AppStrings.tr(context, 'Clear search'),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          const AppText('Common questions'),
          const SizedBox(height: 12),
          for (final entry in answers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ExpansionTile(
                  key: ValueKey(entry.question),
                  expansionAnimationStyle:
                      MediaQuery.disableAnimationsOf(context)
                      ? AnimationStyle.noAnimation
                      : null,
                  title: AppText(entry.question),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [AppText(entry.answer)],
                ),
              ),
            ),
          if (answers.isEmpty)
            const EmptyStateCard(
              icon: Icons.help_outline,
              title: 'No matching answers',
              message: 'Try another search or contact support below.',
            ),
          const SizedBox(height: 20),
        ],
        FilledButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DataFormScreen(
                title: reference == null
                    ? 'Contact support'
                    : 'Report content to support',
                submitLabel: 'Send message',
                description: reference == null
                    ? 'Your message will be sent to the MyOccasio support team.'
                    : 'Describe the issue with this content. Support will receive its reference along with your message.',
                initial: {'name': name, 'email': email},
                fields: [
                  DataField(
                    'name',
                    'Your name',
                    required: true,
                    maxLength: 120,
                    validate: (v) =>
                        v.length < 2 ? 'Enter at least two characters.' : null,
                  ),
                  const DataField(
                    'email',
                    'Email address',
                    required: true,
                    maxLength: 254,
                    validate: validateEmail,
                  ),
                  DataField(
                    'message',
                    'How can we help?',
                    required: true,
                    lines: 6,
                    maxLength: 4500,
                    validate: (v) => v.length < 10
                        ? 'Please add at least 10 characters.'
                        : null,
                  ),
                ],
                save: (v) => repository.sendSupportMessage(
                  name: v['name']!,
                  email: v['email']!,
                  message: [
                    if (reference != null) 'Content reference: $reference',
                    v['message']!,
                  ].join('\n\n'),
                ),
              ),
            ),
          ),
          child: AppText(
            reference == null ? 'Contact support' : 'Report this content',
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => openWebLink(context, '/privacy'),
          child: const AppText('Privacy policy'),
        ),
        TextButton(
          onPressed: () => openWebLink(context, '/terms'),
          child: const AppText('Terms of service'),
        ),
        TextButton(
          onPressed: () => openWebLink(context, '/accessibility'),
          child: const AppText('Accessibility support'),
        ),
      ],
    ),
  );
}
