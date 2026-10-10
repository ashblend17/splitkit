import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/data/providers.dart';
import '../../core/local/providers.dart';
import '../../core/session/session.dart';

/// Whether a group is kept in sync with a tricount, and how it's going. Read from the server
/// (the sync runs there), so it needs a connection.
final tricountStatusProvider = FutureProvider.autoDispose.family<TricountStatusOut, String>(
  (ref, groupId) => fetch(ref, ref.watch(apiProvider).tricount.getTricountLink(groupId)),
);

/// Entries changed in both apps, in all your groups. Asked again after every device sync
/// (about every 45 s while the app is open), so a new one shows up in the banner.
final tricountConflictsProvider = FutureProvider<List<TricountConflictOut>>((ref) {
  ref.watch(syncStatusProvider.select((s) => s.value?.lastSyncedAt));
  return fetch(ref, ref.watch(apiProvider).tricount.listTricountConflicts());
});

/// "just now", "4 min ago", "2 h ago", "3 Oct".
String agoLabel(DateTime at) {
  final d = appClock.now().difference(at.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = at.toLocal();
  return '${l.day} ${months[l.month - 1]}';
}
