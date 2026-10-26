import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/auth/presentation/register_screen.dart';
import 'package:myoccasio/features/auth/presentation/sign_in_screen.dart';
import '../../support/deferred_auth_repository.dart';
import '../../support/recording_api.dart';

void main() {
  for (final registering in [false, true]) {
    testWidgets(
      '${registering ? 'registration' : 'sign-in'} blocks Back during submission and allows it after failure',
      (tester) async {
        final api = RecordingApi();
        final auth = DeferredAuthRepository(api);
        final controller = AppSessionController(auth);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => registering
                          ? RegisterScreen(sessionController: controller)
                          : SignInScreen(sessionController: controller),
                    ),
                  ),
                  child: const Text('Open auth'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open auth'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        if (registering) {
          await tester.enterText(fields.at(0), 'One Student');
        }
        await tester.enterText(
          fields.at(registering ? 1 : 0),
          'one@example.test',
        );
        await tester.enterText(fields.at(registering ? 2 : 1), 'fixture-only');
        final submit = find.widgetWithText(
          FilledButton,
          registering ? 'Create account' : 'Sign in',
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(registering ? auth.registrations : auth.signIns, hasLength(1));
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byType(registering ? RegisterScreen : SignInScreen),
          findsOneWidget,
        );
        final operation = registering
            ? auth.registrations.single
            : auth.signIns.single;
        operation.completeError(const ApiException('Please try again.'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Open auth'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        api.close();
      },
    );
  }
}
