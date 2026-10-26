import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';

class AppBusyIndicator extends StatelessWidget {
  const AppBusyIndicator({
    this.strokeWidth = 4,
    this.color,
    this.label = 'Loading',
    super.key,
  });

  final double strokeWidth;
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Semantics(
        label: AppStrings.tr(context, label),
        liveRegion: true,
        child: ExcludeSemantics(
          child: Icon(Icons.hourglass_empty, color: color),
        ),
      );
    }
    return CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
      semanticsLabel: AppStrings.tr(context, label),
    );
  }
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({this.label = 'Loading…', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppBusyIndicator(strokeWidth: 2.5),
            const SizedBox(height: 16),
            AppText(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.secondaryAction,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            AppText(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            AppText(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const AppText('Try again'),
            ),
            if (secondaryAction != null) ...[
              const SizedBox(height: 12),
              secondaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            AppText(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            AppText(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Expanded(
        child: AppText(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    ];
    final trailingWidget = trailing;
    if (trailingWidget != null) children.add(trailingWidget);
    return Row(children: children);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, this.emphasis = false, super.key});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: emphasis ? AppColors.coral : AppColors.mint,
        shape: const StadiumBorder(),
      ),
      child: AppText(
        label,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
