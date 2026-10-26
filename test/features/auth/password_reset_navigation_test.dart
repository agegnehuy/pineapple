import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/app.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/auth/data/auth_repository.dart';
import 'package:myoccasio/features/auth/domain/password_reset_link.dart';
import 'package:myoccasio/features/auth/presentation/password_recovery_screen.dart';
import 'package:myoccasio/features/auth/presentation/password_reset_screen.dart';
import 'package:myoccasio/features/navigation/presentation/main_shell.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import '../../support/recording_api.dart';
import '../../support/recording_dependencies.dart';

class _ResetApi extends RecordingApi {
  Future<ApiResponse>? resetResponse, restoreResponse;
  @override
  Future<ApiResponse> request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    List<int>? bodyBytes,
  }) {
    final pending = path == '/api/auth/reset-password'
        ? resetResponse
        : path == '/api/auth/session'
        ? restoreResponse
        : null;
    if (pending != null) {
      calls.add((
        method: method,
        path: path,
        body: body == null ? null : jsonDecode(body),
      ));
      return pending;
    }
    return super.request(
      method,
      path,
      headers: headers,
      body: body,
      bodyBytes: bodyBytes,
    );
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _incoming(
  WidgetTester tester,
  String value, {
  bool legacy = false,
  bool settle = true,
}) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall(
        legacy ? 'pushRoute' : 'pushRouteInformation',
        legacy ? value : {'location': value},
      ),
    ),
    (_) {},
  );
  if (settle) await tester.pumpAndSettle();
}

void _signedIn(_ResetApi api, [String id = 'one']) {
  api.responses['/api/auth/session'] = {
    'user': {'id': id, 'email': '$id@example.test'},
  };
  api.responses['/api/me'] = {
    'user': {
      'id': id,
      'firstName': 'Fixture',
      'lastName': 'Student',
      'institution': 'College',
      'program': 'Science',
      'year': '2nd year',
      'citizenship': 'citizen',
      'interests': ['Science'],
      'opportunityTypes': ['scholarship'],
    },
  };
  api.responses['/api/matches'] = {
    'matches': [],
    'profile': {'status': 'complete', 'firstName': 'Fixture'},
  };
  api.responses['/api/tracking'] = [];
}

void main() {
  late _ResetApi api;
  late AuthRepository auth;
  setUp(() {
    api = _ResetApi()..responses['/api/auth/reset-password'] = {'ok': true};
    auth = AuthRepository(api, MemoryCookieStore());
  });
  tearDown(() => api.close());
  Future<void> open(
    WidgetTester tester, {
    bool french = false,
    VoidCallback? requestNew,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: Locale(french ? 'fr' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(french ? 2 : 1),
            disableAnimations: french,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PasswordResetScreen(
                    repository: auth,
                    link: PasswordResetLink.parse(
                      'https://myoccasio.ca/reset-password?token=fixture-token',
                    )!,
                    onRequestNewLink: requestNew ?? () {},
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await _tap(tester, 'Open');
  }

  Future<void> fill(
    WidgetTester tester, {
    String password = 'fixture-only',
    String? confirmation,
  }) async {
    await tester.enterText(find.byType(TextFormField).first, password);
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.enterText(
      find.byType(TextFormField).last,
      confirmation ?? password,
    );
  }

  testWidgets(
    'queued IME submit during discard cannot mutate or save an unsubmitted password',
    (tester) async {
      await open(tester);
      await fill(tester);
      final queuedIme = tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(TextFormField).last,
              matching: find.byType(TextField),
            ),
          )
          .onSubmitted!;
      tester.testTextInput.log.clear();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      queuedIme('fixture-only');
      await tester.pump();
      expect(api.calls, isEmpty);
      await _tap(tester, 'Discard');
      expect(find.text('Open'), findsOneWidget);
      expect(api.calls, isEmpty);
      expect(
        tester.testTextInput.log
            .where((call) => call.method == 'TextInput.finishAutofillContext')
            .map((call) => call.arguments),
        [false],
      );
    },
  );

  testWidgets(
    'validation, dirty back and discard do not submit or lose a kept draft',
    (tester) async {
      await open(tester);
      await fill(tester, password: 'short', confirmation: 'different');
      await _tap(tester, 'Update password');
      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(api.calls, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Keep editing');
      expect(find.text('short'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Discard');
      expect(find.text('Open'), findsOneWidget);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets(
    'pending reset blocks back and duplicate submits, then expired link offers recovery',
    (tester) async {
      final pending = Completer<ApiResponse>();
      api.resetResponse = pending.future;
      var requested = false;
      await open(tester, requestNew: () => requested = true);
      await fill(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(api.calls.length, 1);
      await tester.pageBack();
      await tester.pump();
      expect(find.byType(PasswordResetScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      pending.completeError(
        const ApiException(
          'Reset link is invalid or has expired.',
          statusCode: 400,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await _tap(tester, 'Request a new reset link');
      expect(requested, isTrue);
    },
  );

  testWidgets(
    'network error retains password for explicit retry and success clears fields',
    (tester) async {
      api.failure = const ApiException(
        'Could not connect. Check your connection and try again.',
      );
      await open(tester);
      await fill(tester);
      await _tap(tester, 'Update password');
      expect(api.calls.length, 1);
      expect(find.text('fixture-only'), findsNWidgets(2));
      expect(
        tester.testTextInput.log.where(
          (call) =>
              call.method == 'TextInput.finishAutofillContext' &&
              call.arguments == true,
        ),
        isEmpty,
      );
      api.failure = null;
      await _tap(tester, 'Update password');
      expect(api.calls.length, 2);
      expect(find.text('Password updated.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        tester.testTextInput.log.where(
          (call) =>
              call.method == 'TextInput.finishAutofillContext' &&
              call.arguments == true,
        ),
        hasLength(1),
      );
      expect(
        api.calls.every((call) => call.path == '/api/auth/reset-password'),
        isTrue,
      );
    },
  );

  testWidgets(
    'French reset form remains usable at320px200percent and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<ApiResponse>();
      api.resetResponse = pending.future;
      await open(tester, french: true);
      await fill(tester);
      final update = find.text(const AppStrings('fr').text('Update password'));
      await tester.ensureVisible(update);
      await tester.pumpAndSettle();
      await tester.tap(update);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete(const ApiResponse(statusCode: 200, body: '{"ok":true}'));
      await tester.pumpAndSettle();
      expect(
        find.text(const AppStrings('fr').text('Password updated.')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual paste rejects foreign URLs and opens a valid link without sending email',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PasswordRecoveryScreen(repository: auth)),
      );
      final paste = find.widgetWithText(TextField, 'Paste reset link');
      await tester.ensureVisible(paste);
      await tester.enterText(
        paste,
        'https://evil.test/reset-password?token=fixture',
      );
      await _tap(tester, 'Open reset link');
      expect(
        find.text('Paste the complete reset link from your MyOccasio email.'),
        findsOneWidget,
      );
      await tester.enterText(
        paste,
        'https://myoccasio.ca/reset-password?token=fixture',
      );
      await _tap(tester, 'Open reset link');
      expect(find.byType(PasswordResetScreen), findsOneWidget);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets(
    'cold-start reset waits for authenticated restoration and sanitizes route settings',
    (tester) async {
      final restore = Completer<ApiResponse>();
      api.restoreResponse = restore.future;
      _signedIn(api);
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          'ca.occasiotech.myoccasio://reset-password?token=fixture-cold';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        MyOccasioApp(dependencies: recordingDependencies(api)),
      );
      await tester.pump();
      expect(find.byType(PasswordResetScreen), findsNothing);
      api.restoreResponse = null;
      restore.complete(
        ApiResponse(
          statusCode: 200,
          body: jsonEncode(api.responses['/api/auth/session']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PasswordResetScreen), findsOneWidget);
      expect(
        ModalRoute.of(
          tester.element(find.byType(PasswordResetScreen)),
        )!.settings.name,
        '/reset-password',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy and current native links preserve an unsaved private editor and deduplicate',
    (tester) async {
      _signedIn(api);
      await tester.pumpWidget(
        MyOccasioApp(dependencies: recordingDependencies(api)),
      );
      await tester.pumpAndSettle();
      final navigation = WorkspaceNavigationScope.maybeOf(
        tester.element(find.byType(MainShell)),
      )!;
      navigation.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => DataFormScreen(
            title: 'Private editor',
            fields: const [DataField('draft', 'Draft')],
            save: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Private unsaved draft',
      );
      await _incoming(
        tester,
        '/reset-password?token=fixture-running',
        legacy: true,
      );
      expect(find.byType(PasswordResetScreen), findsOneWidget);
      await _incoming(
        tester,
        'https://myoccasio.ca/reset-password?token=fixture-running',
      );
      expect(find.byType(PasswordResetScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Private unsaved draft'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'a reset queued immediately before a later account boundary is discarded',
    (tester) async {
      _signedIn(api);
      await tester.pumpWidget(
        MyOccasioApp(dependencies: recordingDependencies(api)),
      );
      await tester.pumpAndSettle();
      final shell = tester.widget<MainShell>(find.byType(MainShell));
      await _incoming(
        tester,
        'https://myoccasio.ca/reset-password?token=queued-for-one',
        settle: false,
      );
      _signedIn(api, 'two');
      await shell.sessionController.initialize();
      await tester.pumpAndSettle();
      expect(find.byType(PasswordResetScreen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'foreign links are ignored and a later account boundary removes reset drafts',
    (tester) async {
      _signedIn(api);
      await tester.pumpWidget(
        MyOccasioApp(dependencies: recordingDependencies(api)),
      );
      await tester.pumpAndSettle();
      await _incoming(tester, 'https://evil.test/reset-password?token=fixture');
      expect(find.byType(PasswordResetScreen), findsNothing);
      await _incoming(
        tester,
        'ca.occasiotech.myoccasio://reset-password?token=fixture-one',
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Unsaved secret',
      );
      final shell = tester.widget<MainShell>(
        find.byType(MainShell, skipOffstage: false),
      );
      _signedIn(api, 'two');
      await shell.sessionController.initialize();
      await tester.pumpAndSettle();
      expect(find.byType(PasswordResetScreen), findsNothing);
      expect(find.text('Unsaved secret'), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
      expect(
        tester.testTextInput.log.where(
          (call) =>
              call.method == 'TextInput.finishAutofillContext' &&
              call.arguments == true,
        ),
        isEmpty,
      );
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );
}
