import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/domain/auth_validation.dart';
import 'package:myoccasio/features/auth/domain/password_reset_link.dart';
import 'package:myoccasio/features/auth/presentation/password_reset_screen.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    required this.repository,
    this.onOpenResetLink,
    super.key,
  });
  final AuthRepository repository;
  final ValueChanged<PasswordResetLink>? onOpenResetLink;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _link = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;
  String? _linkError;

  @override
  void dispose() {
    _email.dispose();
    _link.dispose();
    super.dispose();
  }

  void _openLink() {
    if (_busy) {
      return;
    }
    final link = PasswordResetLink.parse(_link.text);
    if (link == null) {
      setState(
        () => _linkError =
            'Paste the complete reset link from your MyOccasio email.',
      );
      return;
    }
    _link.clear();
    setState(() => _linkError = null);
    FocusScope.of(context).unfocus();
    if (widget.onOpenResetLink case final open?) {
      open(link);
    } else {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (resetContext) => PasswordResetScreen(
            repository: widget.repository,
            link: link,
            onRequestNewLink: () => Navigator.pop(resetContext),
          ),
        ),
      );
    }
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.requestPasswordReset(_email.text);
      if (mounted) {
        setState(() => _sent = true);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not send the reset link. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const AppText('MyOccasio')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AppText(
                  _sent ? 'Check your inbox.' : 'Let’s get you in.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                if (_sent) ...[
                  const EmptyStateCard(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Reset link requested',
                    message:
                        'If an account exists for this email, you’ll receive a secure reset link. Check your inbox and spam folder. The link expires in one hour.',
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => setState(() => _sent = false),
                    child: const AppText('Use another email'),
                  ),
                ] else
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppText(
                          'We’ll send you a secure reset link. Use the email linked to your account.',
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            labelText: AppStrings.tr(context, 'Email address'),
                          ),
                          validator: (value) =>
                              AppStrings.error(context, validateEmail(value)),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: AppText(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _send,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: AppBusyIndicator(
                                    label: 'Requesting reset link',
                                  ),
                                )
                              : const AppText('Send reset link'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const AppText('Already have a reset link?'),
                const SizedBox(height: 12),
                TextField(
                  controller: _link,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _openLink(),
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(context, 'Paste reset link'),
                    errorText: AppStrings.error(context, _linkError),
                    errorMaxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _openLink,
                  child: const AppText('Open reset link'),
                ),
                if (_error != null && _sent)
                  AppText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const AppText('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
