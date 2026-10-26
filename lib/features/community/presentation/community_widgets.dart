import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/theme/app_theme.dart';

String communityAuthorName(Map<String, dynamic> item) =>
    [
          item['authorFirstName'] ?? item['firstName'] ?? '',
          item['authorLastName'] ?? item['lastName'] ?? '',
        ]
        .map((part) => part.toString().trim())
        .where((part) => part.isNotEmpty)
        .join(' ');

class CommunityAuthor extends StatelessWidget {
  const CommunityAuthor({
    required this.name,
    this.subtitle = '',
    this.featured = false,
    super.key,
  });
  final String name;
  final String subtitle;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.forest,
          child: ExcludeSemantics(
            child: initials.isEmpty
                ? const Icon(Icons.person_outline)
                : Text(initials, textScaler: TextScaler.noScaling),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name.trim().isEmpty
                  ? AppText(
                      'Student',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: featured ? Colors.white : null,
                      ),
                    )
                  : Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: featured ? Colors.white : null,
                      ),
                    ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: featured ? AppColors.mint : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class CommunityNote extends StatelessWidget {
  const CommunityNote(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
    ),
    child: AppText(message),
  );
}
