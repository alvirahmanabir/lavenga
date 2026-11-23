import 'package:material_ui/material_ui.dart';

import '../errors/app_failure.dart';

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Runs [action], showing a snackbar for success or a mapped failure.
/// Returns true on success. Use for every mutation so errors are never silent.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) showAppSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showAppSnack(context, toFailure(e).userMessage, error: true);
    return false;
  }
}

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => Padding(
      // Keyboard-aware sheets.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Asks for a mandatory reason (cancel, reject, blacklist). Returns the text,
/// or null if dismissed.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Confirm',
  bool destructive = true,
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showAppSheet<String>(
    context,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(hintText: hint),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'A reason is required' : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
                  : null,
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
