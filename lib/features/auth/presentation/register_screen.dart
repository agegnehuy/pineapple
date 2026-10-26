import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/network/external_links.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/auth/domain/auth_validation.dart';
import 'package:myoccasio/features/auth/presentation/google_auth_controls.dart';

const _canvas = Color(0xFFFAF8F3);
const _ink = Color(0xFF141D18);
const _green = Color(0xFF0F6E56);
const _muted = Color(0xFF6E7870);
const _outline = Color(0xFFDDE3DC);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.sessionController,
    this.onSignIn,
    super.key,
  });
  final AppSessionController sessionController;
  final VoidCallback? onSignIn;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final GoogleAuthController _google;
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _providerDialog = false;
  String? _error;
  bool get _busy => _submitting || _google.busy;

  @override
  void initState() {
    super.initState();
    _google = GoogleAuthController(widget.sessionController)
      ..addListener(_googleChanged)
      ..checkAvailability();
  }

  void _googleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _providerUnavailable({required bool google}) async {
    if (_busy || _providerDialog || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _providerDialog = true;
    bool? retry;
    try {
      retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: AppText(
            google ? 'Google sign-in unavailable' : 'Apple sign-in unavailable',
          ),
          content: AppText(
            google
                ? 'Google is not available right now. Continue with email or try again.'
                : 'Apple sign-in is not available yet. Please use your email and password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Use email'),
            ),
            if (google)
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const AppText('Try again'),
              ),
          ],
        ),
      );
    } finally {
      _providerDialog = false;
    }
    if (retry != true || !mounted || _busy) return;
    await _google.checkAvailability();
    if (mounted &&
        !_busy &&
        !_google.available &&
        ModalRoute.of(context)?.isCurrent == true) {
      await _providerUnavailable(google: true);
    }
    // A capability retry never starts a browser without a fresh Continue tap.
  }

  Future<void> _showLegal() async {
    if (_busy || _providerDialog || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    FocusScope.of(context).unfocus();
    _providerDialog = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const AppText('Terms and privacy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => openWebLink(dialogContext, '/terms'),
                child: const AppText('Terms of service'),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => openWebLink(dialogContext, '/privacy'),
                child: const AppText('Privacy policy'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Done'),
            ),
          ],
        ),
      );
    } finally {
      _providerDialog = false;
    }
  }

  Future<void> _googleSignIn() async {
    if (_busy || _providerDialog || _google.checking) return;
    FocusScope.of(context).unfocus();
    if (!_google.available) {
      await _providerUnavailable(google: true);
      return;
    }
    setState(() => _error = null);
    final confirmed = await _google.signIn();
    if (confirmed && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _google.removeListener(_googleChanged);
    _google.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _providerDialog || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _google.clearError();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Keep the existing first/last-name API contract. Preserve all remaining
      // name parts, including compound surnames, without inventing a surname.
      final parts = _fullName.text.trim().split(RegExp(r'\s+'));
      await widget.sessionController.register(
        firstName: parts.first,
        lastName: parts.skip(1).join(' '),
        email: _email.text,
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'We could not create your account. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final canvas = dark ? theme.scaffoldBackgroundColor : _canvas;
    final ink = dark ? theme.colorScheme.onSurface : _ink;
    final green = dark ? theme.colorScheme.primary : _green;
    final muted = dark ? theme.colorScheme.onSurfaceVariant : _muted;
    final field = dark ? theme.colorScheme.surface : Colors.white;
    final border = dark ? theme.colorScheme.outline : _outline;
    final textStyle = TextStyle(
      fontFamily: 'InstrumentSans',
      fontSize: 15,
      height: 20 / 15,
      color: ink,
    );
    final linkStyle = TextButton.styleFrom(
      foregroundColor: green,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      textStyle: const TextStyle(
        fontFamily: 'InstrumentSans',
        fontSize: 14,
        height: 20 / 14,
      ),
    );
    final legalStyle = linkStyle.copyWith(
      foregroundColor: WidgetStatePropertyAll(muted),
      textStyle: WidgetStatePropertyAll(textStyle.copyWith(fontSize: 11)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      ),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: border),
    );
    InputDecoration decoration(String hint) => InputDecoration(
      hintText: AppStrings.tr(context, hint),
      hintStyle: textStyle.copyWith(color: ink, fontSize: 14, height: 20 / 14),
      filled: true,
      fillColor: field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: green, width: 2),
      ),
      errorMaxLines: 3,
    );
    Widget provider({
      required String label,
      required Widget icon,
      required VoidCallback? onPressed,
      String? hint,
    }) => Semantics(
      hint: hint == null ? null : AppStrings.tr(context, hint),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: field,
          foregroundColor: ink,
          side: BorderSide(color: border),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textStyle.copyWith(fontWeight: FontWeight.w700),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox.square(dimension: 20, child: icon),
            ),
            const SizedBox(width: 16),
            Expanded(child: AppText(label, textAlign: TextAlign.center)),
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
    Widget label(String value) => ExcludeSemantics(
      child: AppText(
        value,
        style: TextStyle(
          fontFamily: 'InstrumentSans',
          color: dark ? muted : const Color(0xFF5A665D),
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: canvas,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: canvas,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 438,
                      minHeight: viewport.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Transform.translate(
                              offset: const Offset(-10, 0),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: AppStrings.tr(context, 'Back'),
                                    onPressed: _busy
                                        ? null
                                        : () => Navigator.maybePop(context),
                                    icon: Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 16,
                                      color: green,
                                    ),
                                  ),
                                  Flexible(
                                    child: AppText(
                                      'MyOccasio',
                                      style: textStyle.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppText(
                              'A little closer.',
                              key: const ValueKey('register-heading'),
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontSize: 32.5,
                                height: 37 / 32.5,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AppText(
                              'Create your free MyOccasio account.',
                              style: textStyle.copyWith(
                                fontSize: 14,
                                height: 1.5,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 30),
                            provider(
                              label: 'Continue with Apple',
                              icon: const Icon(Icons.apple, size: 20),
                              onPressed: _busy
                                  ? null
                                  : () => _providerUnavailable(google: false),
                              hint:
                                  'Apple sign-in is not available yet. Please use your email and password.',
                            ),
                            const SizedBox(height: 12),
                            provider(
                              label: _google.busy
                                  ? 'Waiting for Google sign-in…'
                                  : 'Continue with Google',
                              icon: _google.checking || _google.busy
                                  ? AppBusyIndicator(
                                      strokeWidth: 2,
                                      label: _google.checking
                                          ? 'Checking Google availability…'
                                          : 'Waiting for Google sign-in…',
                                    )
                                  : const _GoogleMark(),
                              onPressed: _busy || _google.checking
                                  ? null
                                  : _googleSignIn,
                              hint: _google.available
                                  ? null
                                  : 'Google sign-in is unavailable. Use your email and password.',
                            ),
                            if (_google.busy) ...[
                              const SizedBox(height: 8),
                              const AppText(
                                'Finish signing in in your system browser, then return here.',
                              ),
                              TextButton(
                                style: linkStyle,
                                onPressed: _google.cancelling
                                    ? null
                                    : _google.cancel,
                                child: AppText(
                                  _google.cancelling
                                      ? 'Cancelling…'
                                      : 'Cancel sign-in',
                                ),
                              ),
                            ],
                            if (_google.error != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: AppText(
                                  _google.error!,
                                  style: textStyle.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 40),
                            label('FULL NAME'),
                            const SizedBox(height: 8),
                            Semantics(
                              label: AppStrings.tr(context, 'Full name'),
                              child: TextFormField(
                                key: const ValueKey('register-name'),
                                enabled: !_busy,
                                controller: _fullName,
                                style: textStyle.copyWith(
                                  fontSize: 14,
                                  height: 20 / 14,
                                ),
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: decoration('Amara Khan'),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? AppStrings.tr(context, 'Required')
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            label('EMAIL ADDRESS'),
                            const SizedBox(height: 6),
                            Semantics(
                              label: AppStrings.tr(context, 'Email address'),
                              child: TextFormField(
                                key: const ValueKey('register-email'),
                                enabled: !_busy,
                                controller: _email,
                                style: textStyle.copyWith(
                                  fontSize: 14,
                                  height: 20 / 14,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: decoration('amara@university.ca'),
                                validator: (value) => AppStrings.error(
                                  context,
                                  validateEmail(value),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            label('PASSWORD'),
                            const SizedBox(height: 6),
                            Semantics(
                              label: AppStrings.tr(context, 'Password'),
                              child: TextFormField(
                                key: const ValueKey('register-password'),
                                enabled: !_busy,
                                controller: _password,
                                style: textStyle.copyWith(
                                  fontSize: 14,
                                  height: 20 / 14,
                                ),
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                onFieldSubmitted: (_) => _submit(),
                                decoration:
                                    decoration(
                                      'Create a strong password',
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: AppStrings.tr(
                                          context,
                                          _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.lock_outline
                                              : Icons.lock_open_outlined,
                                          size: 18,
                                          color: green,
                                        ),
                                      ),
                                    ),
                                validator: (value) => (value?.length ?? 0) < 8
                                    ? AppStrings.tr(
                                        context,
                                        'Use at least 8 characters.',
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              hint: AppStrings.tr(
                                context,
                                'View Terms of service and Privacy policy',
                              ),
                              child: TextButton(
                                key: const ValueKey('register-consent'),
                                style: legalStyle.copyWith(
                                  alignment: Alignment.centerLeft,
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                  textStyle: WidgetStatePropertyAll(
                                    textStyle.copyWith(
                                      color: muted,
                                      fontSize: 12,
                                      height: 20 / 12,
                                    ),
                                  ),
                                ),
                                onPressed: _busy ? null : _showLegal,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 245,
                                  ),
                                  child: const AppText(
                                    'By continuing, you agree to our Terms of service and Privacy policy.',
                                  ),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: AppText(
                                  _error!,
                                  style: textStyle.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            FilledButton(
                              key: const ValueKey('register-submit'),
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: dark
                                    ? theme.colorScheme.onPrimary
                                    : Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: textStyle.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: _submitting
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: AppBusyIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const AppText('Create account'),
                            ),
                            if (widget.onSignIn != null) ...[
                              const SizedBox(height: 4),
                              TextButton(
                                style: linkStyle,
                                onPressed: _busy ? null : widget.onSignIn,
                                child: const AppText(
                                  'Already a member? Sign in',
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
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => ClipRect(
    child: OverflowBox(
      minWidth: 40,
      maxWidth: 40,
      minHeight: 40,
      maxHeight: 40,
      child: Image.asset(
        'assets/branding/google-signin-icon-button.png',
        width: 40,
        height: 40,
        excludeFromSemantics: true,
      ),
    ),
  );
}
