import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/domain/password_reset_link.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    required this.repository,
    required this.link,
    required this.onRequestNewLink,
    this.onFinished,
    this.finishLabel = 'Back to sign in',
    super.key,
  });
  final AuthRepository repository;
  final PasswordResetLink link;
  final VoidCallback onRequestNewLink;
  final VoidCallback? onFinished;
  final String finishLabel;
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false, _complete = false, _allowPop = false;
  bool _confirmingLeave = false, _obscure = true;
  late bool _invalid = !widget.link.isValid;
  String? _error;
  bool get _dirty =>
      !_complete &&
      !_invalid &&
      (_password.text.isNotEmpty || _confirmation.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _password.addListener(_changed);
    _confirmation.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _password.removeListener(_changed);
    _confirmation.removeListener(_changed);
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy ||
        _confirmingLeave ||
        _allowPop ||
        _invalid ||
        _complete ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.resetPassword(
        token: widget.link.token!,
        password: _password.text,
      );
      if (!mounted) {
        return;
      }
      TextInput.finishAutofillContext(shouldSave: true);
      _password.clear();
      _confirmation.clear();
      setState(() {
        _complete = true;
        _busy = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final invalid =
          error is ApiException &&
          error.statusCode == 400 &&
          error.message == 'Reset link is invalid or has expired.';
      if (invalid) {
        _password.clear();
        _confirmation.clear();
      }
      setState(() {
        _busy = false;
        _invalid = invalid;
        _error = error is ApiException
            ? error.message
            : 'Could not update your password. Please try again.';
      });
    }
  }

  Future<void> _leave() async {
    if (_busy || _confirmingLeave || !_dirty) {
      return;
    }
    _confirmingLeave = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const AppText('Discard unsaved changes?'),
          content: const AppText('Your new password has not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Discard'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } finally {
      _confirmingLeave = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_busy && !_dirty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _leave();
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const AppText('MyOccasio')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppText(
                    _complete
                        ? 'Password updated.'
                        : _invalid
                        ? 'This reset link is unavailable.'
                        : 'A fresh start.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  if (_complete) ...[
                    const EmptyStateCard(
                      icon: Icons.check_circle_outline,
                      title: 'Your new password is ready',
                      message:
                          'Your password was updated. Use your new password the next time you sign in.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          widget.onFinished ??
                          () => Navigator.maybePop(context),
                      child: AppText(widget.finishLabel),
                    ),
                  ] else if (_invalid) ...[
                    const EmptyStateCard(
                      icon: Icons.link_off,
                      title: 'Request a new reset link',
                      message:
                          'This link is missing, invalid or expired. Request a new link using the email linked to your account.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: widget.onRequestNewLink,
                      child: const AppText('Request a new reset link'),
                    ),
                  ] else ...[
                    const AppText(
                      'Choose a new password with at least 8 characters. Your current app session will not change automatically.',
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _form,
                      child: AutofillGroup(
                        onDisposeAction: AutofillContextAction.cancel,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                errorMaxLines: 4,
                                labelText: AppStrings.tr(
                                  context,
                                  'New password',
                                ),
                                suffixIcon: IconButton(
                                  tooltip: AppStrings.tr(
                                    context,
                                    _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => (value?.length ?? 0) < 8
                                  ? AppStrings.tr(
                                      context,
                                      'Password must be at least 8 characters.',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmation,
                              enabled: !_busy,
                              obscureText: _obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                errorMaxLines: 4,
                                labelText: AppStrings.tr(
                                  context,
                                  'Confirm password',
                                ),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) => value != _password.text
                                  ? AppStrings.tr(
                                      context,
                                      'Passwords do not match.',
                                    )
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                child: AppText(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: AppBusyIndicator(
                                        label: 'Updating password',
                                      ),
                                    )
                                  : const AppText('Update password'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
