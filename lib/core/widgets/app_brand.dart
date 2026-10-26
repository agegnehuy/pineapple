import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({this.light = false, this.compact = false, super.key});

  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'MyOccasio',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/branding/myoccasio-key.png',
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: AppText(
              'MyOccasio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 17 : 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
