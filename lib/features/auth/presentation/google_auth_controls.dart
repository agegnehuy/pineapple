import 'package:flutter/material.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/auth/data/system_auth_browser.dart';

/// Presentation state shared by the email sign-in and registration forms.
/// The session controller remains responsible for authentication and cleanup.
class GoogleAuthController extends ChangeNotifier {
  GoogleAuthController(this.sessionController);

  final AppSessionController sessionController;
  bool checking = false;
  bool available = false;
  bool busy = false;
  bool cancelling = false;
  String? error;
  bool _disposed = false;
  int _probe = 0;
  int _operation = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> checkAvailability() async {
    if (_disposed || checking || busy) return;
    final probe = ++_probe;
    checking = true;
    available = false;
    _notify();
    var result = false;
    try {
      final repository = sessionController.nativeAuth;
      result = repository != null && await repository.googleAvailable();
    } on Object {
      // Capability failures never imply that the browser handoff is supported.
    }
    if (_disposed || probe != _probe) return;
    checking = false;
    available = result;
    _notify();
  }

  void clearError() {
    if (error == null || _disposed) return;
    error = null;
    _notify();
  }

  /// True only for this still-current, confirmed session operation.
  Future<bool> signIn() async {
    if (_disposed || busy || checking || !available) return false;
    final operation = ++_operation;
    busy = true;
    error = null;
    _notify();
    try {
      await sessionController.signInWithGoogle();
      return !_disposed && operation == _operation;
    } on Object catch (failure) {
      if (_disposed || operation != _operation) return false;
      error = failure is NativeAuthCancelled
          ? null
          : failure is ApiException
          ? failure.message
          : 'We could not sign you in. Please try again.';
      // A failed exchange may still need encrypted-cookie cleanup. Keep every
      // form action locked until an explicit cancellation succeeds.
      busy = sessionController.nativeAuth?.pending == true;
      _notify();
      return false;
    }
  }

  Future<void> cancel() async {
    if (_disposed || !busy || cancelling) return;
    ++_operation; // An older completion must never pop a newly unlocked form.
    cancelling = true;
    _notify();
    try {
      await sessionController.cancelNativeSignIn();
      if (_disposed) return;
      busy = false;
      error = null;
    } on Object {
      if (_disposed) return;
      // The session controller may retain its cleanup lock even if the browser
      // has closed. Cancel remains available for an explicit cleanup retry.
      busy = true;
      error = 'Could not cancel sign-in. Please try again.';
    } finally {
      if (!_disposed) {
        cancelling = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _probe++;
    _operation++;
    super.dispose();
  }
}

class GoogleAuthControls extends StatelessWidget {
  const GoogleAuthControls({
    required this.controller,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final GoogleAuthController controller;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed:
              enabled &&
                  !controller.checking &&
                  controller.available &&
                  !controller.busy
              ? onPressed
              : null,
          icon: controller.checking || controller.busy
              ? SizedBox.square(
                  dimension: 22,
                  child: AppBusyIndicator(
                    strokeWidth: 2,
                    label: controller.checking
                        ? 'Checking Google availability…'
                        : 'Waiting for Google sign-in…',
                  ),
                )
              : const Icon(Icons.open_in_browser),
          label: AppText(
            controller.busy ? 'Waiting for Google sign-in…' : label,
          ),
        ),
        if (controller.checking) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: const AppText('Checking Google availability…'),
          ),
        ] else if (!controller.available && !controller.busy) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: const AppText(
              'Google is not available right now. Continue with email or try again.',
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: enabled ? controller.checkAvailability : null,
            child: const AppText('Check Google availability again'),
          ),
        ],
        if (controller.busy) ...[
          const SizedBox(height: 8),
          const AppText(
            'Finish signing in in your system browser, then return here.',
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: controller.cancelling ? null : controller.cancel,
            child: AppText(
              controller.cancelling ? 'Cancelling…' : 'Cancel sign-in',
            ),
          ),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: AppText(
              controller.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    ),
  );
}
