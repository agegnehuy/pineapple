import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/app/app_dependencies.dart';
import 'package:myoccasio/app/state/app_session_controller.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_brand.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/auth/domain/password_reset_link.dart';
import 'package:myoccasio/features/auth/presentation/password_reset_screen.dart';
import 'package:myoccasio/features/auth/presentation/register_screen.dart';
import 'package:myoccasio/features/auth/presentation/password_recovery_screen.dart';
import 'package:myoccasio/features/auth/presentation/sign_in_screen.dart';
import 'package:myoccasio/features/auth/presentation/welcome_screen.dart';
import 'package:myoccasio/features/navigation/presentation/main_shell.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/features/reminders/presentation/reminder_scope.dart';

class MyOccasioApp extends StatefulWidget {
  const MyOccasioApp({required this.dependencies, super.key});
  final AppDependencies dependencies;
  @override
  State<MyOccasioApp> createState() => _MyOccasioAppState();
}

class _MyOccasioAppState extends State<MyOccasioApp>
    with WidgetsBindingObserver {
  late final AppSessionController _sessionController;
  final _navigation = WorkspaceNavigationController();
  PasswordResetLink? _pendingResetLink, _activeResetLink;
  Route<void>? _resetRoute;
  bool _presentationScheduled = false;
  bool _initialRestorationSettled = false;

  @override
  void initState() {
    super.initState();
    // Observe before WidgetsApp so reset URLs never become named routes with
    // sensitive query strings. Initial route generation below is sanitized too.
    WidgetsBinding.instance.addObserver(this);
    _pendingResetLink = PasswordResetLink.parse(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      fromPlatform: true,
    );
    _sessionController = AppSessionController(
      widget.dependencies.auth,
      nativeAuth: widget.dependencies.nativeAuth,
    );
    _sessionController.addListener(_syncNavigationSession);
    _sessionController.initialize();
    widget.dependencies.appearance.initialize();
    widget.dependencies.language.initialize();
    _scheduleResetPresentation();
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final link = PasswordResetLink.parse(
      routeInformation.uri.toString(),
      fromPlatform: true,
    );
    if (link != null) {
      _queueResetLink(link);
    }
    // Unknown/untrusted external URLs do not become arbitrary Navigator routes.
    // The separate OAuth callback is handled by the native auth browser bridge.
    return true;
  }

  void _queueResetLink(PasswordResetLink link) {
    if (_resetRoute?.isActive == true &&
        _activeResetLink?.token == link.token) {
      return;
    }
    setState(() => _pendingResetLink = link);
    if (_resetRoute?.isActive == true) {
      final context = _navigation.navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: AppText(
              'Another reset link is ready. Finish or close this screen to open it.',
            ),
          ),
        );
      }
    }
    _scheduleResetPresentation();
  }

  void _scheduleResetPresentation() {
    if (_presentationScheduled || !mounted) {
      return;
    }
    _presentationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentationScheduled = false;
      if (!mounted ||
          _sessionController.status == AppSessionStatus.loading ||
          _resetRoute?.isActive == true ||
          _pendingResetLink == null) {
        return;
      }
      final navigator = _navigation.navigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      final link = _pendingResetLink!;
      _pendingResetLink = null;
      _activeResetLink = link;
      final authenticated =
          _sessionController.status == AppSessionStatus.authenticated;
      late final MaterialPageRoute<void> route;
      route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/reset-password'),
        builder: (_) => PasswordResetScreen(
          repository: widget.dependencies.auth,
          link: link,
          finishLabel: authenticated ? 'Return to the app' : 'Back to sign in',
          onFinished: () {
            if (!route.isCurrent) {
              return;
            }
            navigator.pop();
            if (!authenticated) {
              _openSignIn(navigator.context);
            }
          },
          onRequestNewLink: () {
            if (!route.isCurrent) {
              return;
            }
            navigator.pop();
            _openRecovery(navigator.context);
          },
        ),
      );
      _resetRoute = route;
      navigator.push<void>(route).whenComplete(() {
        if (!mounted || !identical(_resetRoute, route)) {
          return;
        }
        _resetRoute = null;
        _activeResetLink = null;
        _scheduleResetPresentation();
        WidgetsBinding.instance.scheduleFrame();
      });
    });
  }

  void _syncNavigationSession() {
    final session = _sessionController.session;
    final user = session?.user;
    final Object? identity;
    if (_sessionController.status == AppSessionStatus.authenticated) {
      identity =
          user?['id'] ??
          ((session?.email.isNotEmpty ?? false) ? session!.email : session);
    } else {
      identity = null;
    }
    final generation = _navigation.sessionGeneration;
    _navigation.updateSession(identity);
    if (generation != _navigation.sessionGeneration &&
        _initialRestorationSettled) {
      // Every later account boundary removes private routes and queued reset
      // secrets, including links not yet presented by their post-frame callback.
      _pendingResetLink = null;
      _activeResetLink = null;
      _resetRoute = null;
    }
    if (_sessionController.status != AppSessionStatus.loading) {
      _initialRestorationSettled = true;
    }
    _scheduleResetPresentation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingResetLink = null;
    _activeResetLink = null;
    _sessionController.removeListener(_syncNavigationSession);
    _sessionController.dispose();
    _navigation.dispose();
    super.dispose();
  }

  void _openRecovery(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PasswordRecoveryScreen(
          repository: widget.dependencies.auth,
          onOpenResetLink: _queueResetLink,
        ),
      ),
    );
  }

  void _openSignIn(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => SignInScreen(
        sessionController: _sessionController,
        onCreateAccount: () => _openRegister(context, replace: true),
        onForgotPassword: () => _openRecovery(context),
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement<void, void>(route);
    } else {
      Navigator.of(context).push<void>(route);
    }
  }

  void _openRegister(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => RegisterScreen(
        sessionController: _sessionController,
        onSignIn: () => _openSignIn(context, replace: true),
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement<void, void>(route);
    } else {
      Navigator.of(context).push<void>(route);
    }
  }

  Widget _sessionHome(BuildContext context) => AnimatedBuilder(
    animation: _sessionController,
    builder: (context, _) => switch (_sessionController.status) {
      AppSessionStatus.loading => const _SplashScreen(),
      AppSessionStatus.failed => Scaffold(
        body: SafeArea(
          child: AppErrorView(
            title: 'We couldn’t restore your session',
            message: 'Check your connection and try again.',
            onRetry: _sessionController.initialize,
          ),
        ),
      ),
      AppSessionStatus.unauthenticated => WelcomeScreen(
        onSignIn: () => _openSignIn(context),
        onCreateAccount: () => _openRegister(context),
      ),
      AppSessionStatus.authenticated => MainShell(
        key: ValueKey(_navigation.sessionGeneration),
        dependencies: widget.dependencies,
        sessionController: _sessionController,
      ),
    },
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.dependencies.appearance,
      widget.dependencies.language,
      _navigation,
    ]),
    builder: (context, _) => MaterialApp(
      title: 'MyOccasio',
      navigatorKey: _navigation.navigatorKey,
      navigatorObservers: [_navigation.observer],
      // Never pass a reset token through RouteSettings or framework diagnostics.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: _sessionHome,
        ),
      ],
      builder: (context, child) => ReminderScope(
        controller: widget.dependencies.reminders,
        child: WorkspaceNavigationScope(
          controller: _navigation,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      locale: Locale(widget.dependencies.language.code),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.dependencies.appearance.mode,
      themeAnimationDuration:
          (MediaQuery.maybeDisableAnimationsOf(context) ??
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .accessibilityFeatures
                  .disableAnimations)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      initialRoute: '/',
      onGenerateRoute: (settings) => settings.name == '/'
          ? MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/'),
              builder: _sessionHome,
            )
          : null,
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBrand(),
            SizedBox(height: 24),
            SizedBox.square(
              dimension: 24,
              child: AppBusyIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    ),
  );
}
