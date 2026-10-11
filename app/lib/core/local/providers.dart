import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast_memory.dart';

import '../session/session.dart';
import 'db_factory.dart';
import 'ledger.dart';
import 'outbox.dart';
import 'store.dart';
import 'sync_engine.dart';

/// sembast's file/IndexedDB factory; tests use `databaseFactoryMemory`.
final localDatabaseFactoryProvider = Provider<DatabaseFactory>((_) => platformDatabaseFactory);

final localDatabasePathProvider = Provider<Future<String> Function(String userId)>((_) => localDatabasePath);

/// How often to sync while the app is open (besides on start, on resume and after writes);
/// a third of that while offline. Null turns the timer off (tests).
final syncIntervalProvider = Provider<Duration?>((_) => const Duration(seconds: 45));

/// Sync when the app comes back to the foreground. Off only where there is no Flutter binding
/// (the live tests against a real server).
final syncOnResumeProvider = Provider<bool>((_) => true);

/// The signed-in user's local database.
final localStoreProvider = FutureProvider<LocalStore>((ref) async {
  final (userId, viewAs) = ref.watch(sessionProvider.select((s) => (s.value?.user.id, s.value?.viewAsSessionId)));
  if (userId == null) throw const LocalNotFound('Session');
  if (viewAs != null) {
    // View-as: someone else's data never touches this device's disk, and is gone on exit.
    final path = 'view-as-$viewAs';
    final store = await LocalStore.open(databaseFactoryMemory, path);
    ref.onDispose(() => LocalStore.delete(databaseFactoryMemory, path));
    return store;
  }
  final path = await ref.watch(localDatabasePathProvider)(userId);
  final store = await LocalStore.open(ref.watch(localDatabaseFactoryProvider), path);
  ref.onDispose(store.close);
  return store;
});

final syncEngineProvider = FutureProvider<SyncEngine>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  final engine = SyncEngine(
    api: ref.watch(apiProvider).sync,
    store: store,
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
  );
  final interval = ref.watch(syncIntervalProvider);
  // Every interval, and three times as often while offline, so the app notices it's back
  // (and sends what's waiting) sooner.
  var ticks = 0;
  final timer = interval == null
      ? null
      : Timer.periodic(interval ~/ 3, (_) {
          ticks++;
          if (engine.status.offline || ticks % 3 == 0) engine.pull().ignore();
        });
  final lifecycle = ref.watch(syncOnResumeProvider) ? AppLifecycleListener(onResume: () => engine.pull().ignore()) : null;
  ref.onDispose(() {
    timer?.cancel();
    lifecycle?.dispose();
    engine.dispose();
  });
  return engine;
});

/// Everything on this device, recomputed after every sync. The first launch after sign-in
/// waits for the first sync; after that screens open instantly from the device and a sync
/// runs in the background. Invalidate it (`refreshLedger`) to sync now.
final ledgerProvider = StreamProvider<Ledger>((ref) async* {
  final store = await ref.watch(localStoreProvider.future);
  final engine = await ref.watch(syncEngineProvider.future);
  final sync = engine.pull();
  if (store.hasData) {
    sync.ignore();
  } else {
    await sync;
  }
  yield* store.watch();
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final engine = await ref.watch(syncEngineProvider.future);
  yield engine.status;
  yield* engine.statusChanges;
});

/// Deletes a user's local database (explicit logout).
Future<void> deleteLocalData(Ref ref, String userId) async {
  final path = await ref.read(localDatabasePathProvider)(userId);
  await LocalStore.delete(ref.read(localDatabaseFactoryProvider), path);
}

/// Writes made on this device that the server hasn't confirmed or has refused, oldest first.
final outboxProvider = Provider<List<OutboxOp>>((ref) {
  ref.watch(ledgerProvider);
  return ref.watch(localStoreProvider).value?.outbox ?? const [];
});
