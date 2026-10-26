import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/api_exception.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Future<void> Function() action,
}) async {
  var busy = false;
  String? error;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              scrollable: true,
              title: AppText(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(message),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: AppText(error!),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: const AppText('Cancel'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          update(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await action();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } on Object catch (failure) {
                            if (dialogContext.mounted) {
                              update(() {
                                busy = false;
                                error = failure is ApiException
                                    ? failure.message
                                    : 'Could not complete this action. Please try again.';
                              });
                            }
                          }
                        },
                  child: AppText(busy ? 'Please wait…' : actionLabel),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}
