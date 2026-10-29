import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_sync.dart';

/// Posta unificata list; reads only from the local database through [InboxRepository].
/// Pull-to-refresh asks for a sync; the rows update when it writes the database.
class UnifiedInbox extends StatefulWidget {
  const UnifiedInbox({super.key});

  @override
  State<UnifiedInbox> createState() => _UnifiedInboxState();
}

class _UnifiedInboxState extends State<UnifiedInbox> {
  late final entries = streamSignal(
    () => GetIt.I<InboxRepository>().watchUnifiedInbox(),
  );

  @override
  void dispose() {
    entries.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => RefreshIndicator(
      onRefresh: GetIt.I<MailSync>().syncAll,
      child: ListView(
        // Pullable even when the list is shorter than the screen.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [for (final e in entries.value.value ?? const []) _Row(e)],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.entry);
  final InboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final m = entry.message;
    final unread = !m.isRead;
    final bold = unread ? FontWeight.bold : FontWeight.normal;
    return IntrinsicHeight(
      key: ValueKey('row-${entry.account.id}-${m.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            key: const ValueKey('account-color'),
            color: Color(entry.account.color),
            child: const SizedBox(width: 4),
          ),
          if (unread)
            const Icon(Icons.circle, key: ValueKey('unread'), size: 10),
          Expanded(
            child: ListTile(
              title: Text(m.from, style: TextStyle(fontWeight: bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.subject, style: TextStyle(fontWeight: bold)),
                  Text(m.snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ponytail: fixed ISO date; localized/relative format with the design pass.
                  Text(m.date.toLocal().toIso8601String().substring(0, 10)),
                  if (m.isStarred) const Icon(Icons.star, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
