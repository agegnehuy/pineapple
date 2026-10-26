import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/app/state/appearance_controller.dart';
import 'package:myoccasio/app/state/language_controller.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({required this.controller, this.language, super.key});
  final AppearanceController controller;
  final LanguageController? language;
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _language(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.language!.setLanguage(code);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Could not save your language. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(ThemeMode mode) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.setMode(mode);
    } on Object {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not save your display setting. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: WorkspaceBottomBar(enabled: !_busy),
    appBar: AppBar(
      title: AppText(
        widget.language == null ? 'Appearance' : 'Language and appearance',
      ),
    ),
    body: AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (widget.language != null) widget.language!,
      ]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText(
            'Feel at home here.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          AppText(
            widget.language == null
                ? 'Choose your display settings. Your selection is saved on this device.'
                : 'Choose your language and display settings. Your choices are saved on this device.',
          ),
          const SizedBox(height: 32),
          if (widget.language != null) ...[
            AppText(
              'Language',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            for (final choice in const {
              'en': 'English',
              'fr': 'Français',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    title: AppText(choice.value),
                    selected: widget.language!.code == choice.key,
                    trailing: widget.language!.code == choice.key
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: _busy ? null : () => _language(choice.key),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
          AppText(
            'Appearance',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          for (final choice in const {
            ThemeMode.system: 'Use device setting',
            ThemeMode.light: 'Light',
            ThemeMode.dark: 'Dark',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  title: AppText(choice.value),
                  selected: widget.controller.mode == choice.key,
                  trailing: widget.controller.mode == choice.key
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: _busy ? null : () => _select(choice.key),
                ),
              ),
            ),
          if (_error != null)
            Semantics(liveRegion: true, child: AppText(_error!)),
          if (widget.language != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: AppText(
                'Provider and community content stays in its original language.',
              ),
            ),
          const SizedBox(height: 12),
          const AppText(
            'Large text and reduced motion follow your device accessibility settings.',
          ),
        ],
      ),
    ),
  );
}
