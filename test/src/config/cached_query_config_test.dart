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
    // CachedQuery enforces config-set-once per isolate, so all forwarding assertions
    // run against a single configureFlutter call.
    test('forwards observers and config to CachedQuery.instance', () {
      final observer = _RecordingObserver();
      const customConfig = GlobalQueryConfig(refetchOnResume: false);

      TypedCachedQuery.configureFlutter(
        neverCheckConnection: true,
        config: customConfig,
        observers: [observer],
      );

      expect(CachedQuery.instance.observers, contains(observer));
      expect(CachedQuery.instance.defaultConfig.refetchOnResume, isFalse);
    });
  });
}
