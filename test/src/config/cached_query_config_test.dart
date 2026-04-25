import 'dart:async';

import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/config/cached_query_config.dart';

class _RecordingObserver extends QueryObserver {
  int onChangeCount = 0;
  @override
  void onChange(dynamic query, dynamic state) {
    onChangeCount += 1;
  }
}

class _StubStorage implements StorageInterface {
  @override
  FutureOr<StoredQuery?> get(String key) => null;
  @override
  void delete(String key) {}
  @override
  void put(StoredQuery query) {}
  @override
  void deleteAll() {}
  @override
  void close() {}
}

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('TypedCachedQuery.createNewInstance', () {
    test('returns an instance distinct from the global singleton', () {
      final isolated = TypedCachedQuery.createNewInstance();
      expect(identical(isolated, CachedQuery.instance), isFalse);
    });

    test('repeated calls return distinct instances', () {
      final a = TypedCachedQuery.createNewInstance();
      final b = TypedCachedQuery.createNewInstance();
      expect(identical(a, b), isFalse);
    });
  });

  group('TypedCachedQuery.createNewMutationCache', () {
    test('returns an instance distinct from the global mutation cache', () {
      final isolated = TypedCachedQuery.createNewMutationCache();
      expect(identical(isolated, MutationCache.instance), isFalse);
    });

    test('repeated calls return distinct instances', () {
      final a = TypedCachedQuery.createNewMutationCache();
      final b = TypedCachedQuery.createNewMutationCache();
      expect(identical(a, b), isFalse);
    });
  });

  group('TypedCachedQuery.configureFlutter', () {
    // CachedQuery enforces config-set-once per isolate, so all forwarding assertions and the
    // observer end-to-end check share a single configureFlutter call.
    test('forwards observers, config, storage and custom streams to CachedQuery.instance', () async {
      final observer = _RecordingObserver();
      final storage = _StubStorage();
      const customConfig = GlobalQueryConfig(refetchOnResume: false);
      final lifecycleController = StreamController<AppState>.broadcast();
      final connectionController = StreamController<ConnectionStatus>.broadcast();
      addTearDown(() async {
        await lifecycleController.close();
        await connectionController.close();
      });

      TypedCachedQuery.configureFlutter(
        neverCheckConnection: true,
        storage: storage,
        config: customConfig,
        observers: [observer],
        lifecycleStream: lifecycleController.stream,
        connectionStream: connectionController.stream,
      );

      expect(CachedQuery.instance.observers, contains(observer));
      expect(CachedQuery.instance.defaultConfig.refetchOnResume, isFalse);
      expect(identical(CachedQuery.instance.storage, storage), isTrue, reason: 'storage must be forwarded by identity to the singleton');

      // Stream-forwarding assertions: configureFlutter must subscribe to the supplied broadcast
      // streams. With Stream.empty() (the previous shape) there was no observable signal that
      // these parameters were actually wired — a regression that dropped them would have stayed
      // green.
      expect(lifecycleController.hasListener, isTrue, reason: 'configureFlutter must subscribe to the forwarded lifecycleStream');
      expect(connectionController.hasListener, isTrue, reason: 'configureFlutter must subscribe to the forwarded connectionStream');

      // Observer end-to-end: drive a real query through the singleton and assert the observer fires.
      final query = Query<String>(
        cache: CachedQuery.instance,
        key: 'cfg-test-q',
        queryFn: () async => 'hi',
        config: const QueryConfig(staleDuration: Duration.zero, ignoreCacheDuration: true),
      );
      await query.fetch();
      expect(observer.onChangeCount, greaterThan(0), reason: 'a registered observer must receive at least one onChange event after a real query fetch');
    });
  });
}
