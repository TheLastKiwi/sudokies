import 'package:flutter/material.dart';

import '../app.dart';

/// Wraps the app content and shows a slim strip whenever the device is offline.
/// All puzzles work offline, so the copy is reassuring rather than a warning.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final connectivity = AppScope.of(context).connectivity;
    return ListenableBuilder(
      listenable: connectivity,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(child: child),
            if (!connectivity.online) const _OfflineStrip(),
          ],
        );
      },
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Offline — all puzzles still available',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns whether the device is online. When offline, shows a snackbar with
/// [message]. Use to gate actions that need live access:
///
/// ```dart
/// if (!requireConnection(context)) return;
/// ```
///
/// Nothing gates on this today (the app has no live features), but it is here
/// for when online puzzle browsing or sync is enabled.
bool requireConnection(
  BuildContext context, {
  String message = 'This needs an internet connection.',
}) {
  final online = AppScope.of(context).connectivity.online;
  if (!online) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  return online;
}
