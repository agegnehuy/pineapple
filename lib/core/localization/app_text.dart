import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';

/// Localizes interface copy. User/provider content continues to use plain Text.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.textScaler,
    this.softWrap,
    this.textDirection,
    this.semanticsLabel,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final bool? softWrap;
  final TextDirection? textDirection;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) => Text(
    AppStrings.of(context).text(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    textScaler: textScaler,
    softWrap: softWrap,
    textDirection: textDirection,
    semanticsLabel: semanticsLabel == null
        ? null
        : AppStrings.of(context).text(semanticsLabel!),
  );
}
