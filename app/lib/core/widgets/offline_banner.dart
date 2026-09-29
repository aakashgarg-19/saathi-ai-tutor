import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/doubts/outbox_sync.dart';
import '../../l10n/app_localizations.dart';

/// Shows connectivity and how many offline doubts are waiting to sync.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    final pending = ref.watch(outboxCountProvider).value ?? 0;
    if (online && pending == 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = [
      if (!online) l10n.offline,
      if (pending > 0) l10n.pendingSync(pending),
    ].join(' · ');

    return Material(
      color: online ? scheme.secondaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              online ? Icons.sync_rounded : Icons.cloud_off_rounded,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
            if (online && pending > 0)
              TextButton(
                onPressed: () => ref.read(outboxSyncProvider).flush(),
                child: Text(l10n.retry),
              ),
          ],
        ),
      ),
    );
  }
}
