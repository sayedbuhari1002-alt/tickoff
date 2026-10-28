import 'package:flutter/material.dart';

/// Runs [action]; if it throws, shows the problem in a SnackBar instead of
/// crashing. Returns true when the action succeeded.
Future<bool> guarded(
  BuildContext context,
  Future<void> Function() action, {
  String message = 'Could not save',
}) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      final String detail =
          e is ArgumentError ? '${e.message}' : e.toString();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$message: $detail')));
    }
    return false;
  }
}

/// Shows a short confirmation message.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
