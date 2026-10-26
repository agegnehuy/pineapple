import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';

const _cream = Color(0xFFFAF8F3);
const _ink = Color(0xFF141D18);
const _green = Color(0xFF0F6E56);
const _muted = Color(0xFF6E7870);
const _mint = Color(0xFFDFEDE4);

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onSignIn,
    required this.onCreateAccount,
    super.key,
  });
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? theme.scaffoldBackgroundColor : _cream;
    final foreground = dark ? theme.colorScheme.onSurface : _ink;
    final action = dark ? theme.colorScheme.primary : _green;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: viewport.maxHeight,
                  ),
                  // The flexible gap keeps actions near the bottom on taller
                  // phones. Intrinsic height allows the same content to scroll
                  // naturally with larger text or a short landscape viewport.
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _WelcomeBrand(color: foreground),
                          ),
                          const SizedBox(height: 32),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: dark
                                    ? action.withValues(alpha: 0.15)
                                    : _mint,
                                shape: const StadiumBorder(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: AppText(
                                  'YOUR NEXT CHAPTER',
                                  style: TextStyle(
                                    fontFamily: 'InstrumentSans',
                                    color: foreground,
                                    fontSize: 10,
                                    height: 1.4,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _WelcomeArtwork(),
                          const SizedBox(height: 16),
                          AppText(
                            'More possibility.\nLess searching.',
                            key: const ValueKey('welcome-heading'),
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              color: foreground,
                              fontSize: 34,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 32),
                          AppText(
                            'Find opportunities that fit your story.\nBuild the future you have in mind.',
                            style: TextStyle(
                              fontFamily: 'InstrumentSans',
                              color: dark
                                  ? theme.colorScheme.onSurfaceVariant
                                  : _muted,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                          const Expanded(child: SizedBox(height: 38)),
                          FilledButton(
                            key: const ValueKey('welcome-create-account'),
                            style: FilledButton.styleFrom(
                              backgroundColor: action,
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
                              textStyle: const TextStyle(
                                fontFamily: 'InstrumentSans',
                                fontSize: 15,
                                height: 20 / 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: onCreateAccount,
                            child: const AppText('Get started'),
                          ),
                          TextButton(
                            key: const ValueKey('welcome-sign-in'),
                            style: TextButton.styleFrom(
                              foregroundColor: action,
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'InstrumentSans',
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: onSignIn,
                            child: const AppText('Already a member? Sign in'),
                          ),
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
    );
  }
}

class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MyOccasio',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/myoccasio-key.png',
          width: 36,
          height: 36,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: AppText(
            'MyOccasio',
            style: TextStyle(
              fontFamily: 'InstrumentSans',
              color: color,
              fontSize: 26,
              height: 1.1,
              letterSpacing: -0.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('welcome-art'),
    image: true,
    label: AppStrings.tr(context, 'An open doorway to your next chapter'),
    child: ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 342 / 306,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 342,
            height: 306,
            child: Stack(
              children: [
                SvgPicture.asset('assets/illustrations/welcome-frame.svg'),
                Positioned(
                  left: 46,
                  top: 19,
                  child: SvgPicture.asset(
                    'assets/illustrations/welcome-outer.svg',
                  ),
                ),
                Positioned(
                  left: 82,
                  top: 57,
                  child: SvgPicture.asset(
                    'assets/illustrations/welcome-middle.svg',
                  ),
                ),
                Positioned(
                  left: 119,
                  top: 96,
                  child: SvgPicture.asset(
                    'assets/illustrations/welcome-door.svg',
                  ),
                ),
                Positioned(
                  left: 145,
                  top: 83,
                  child: SvgPicture.asset(
                    'assets/illustrations/welcome-sun.svg',
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 217,
                  child: SvgPicture.asset(
                    'assets/illustrations/welcome-foreground.svg',
                  ),
                ),
                Positioned(
                  left: 24,
                  top: 14,
                  child: AppText(
                    'Open doors.',
                    textScaler: TextScaler.noScaling,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
