import 'package:cached_query_flutter/cached_query_flutter.dart';

/// Configuration wrapper for CachedQuery initialization in Flutter apps.
/// This provides a clean API to configure the underlying CachedQuery instance
/// without exposing the full CachedQuery API to library users.
class TypedCachedQuery {
  /// Initialize the CachedQuery system for Flutter apps.
  ///
  /// This should be called once during app initialization, typically in your
  /// main() function or in your app's initialization code.
  ///
  /// Parameters:
  /// - [neverCheckConnection]: If true, disables automatic connection checking
  /// - [storage]: Custom storage interface for persistent caching
  /// - [config]: Global configuration for all queries
  /// - [observers]: List of query observers for monitoring
  /// - [lifecycleStream]: Custom app lifecycle stream
  /// - [connectionStream]: Custom connection status stream
  static void configureFlutter({
    bool neverCheckConnection = false,
    StorageInterface? storage,
    GlobalQueryConfig config = const GlobalQueryConfig(),
    List<QueryObserver>? observers,
    Stream<AppState>? lifecycleStream,
    Stream<ConnectionStatus>? connectionStream,
  }) {
    CachedQuery.instance.configFlutter(
      neverCheckConnection: neverCheckConnection,
      storage: storage,
      config: config,
      observers: observers,
      lifecycleStream: lifecycleStream,
      connectionStream: connectionStream,
    );
  }

  /// Create a new isolated CachedQuery instance.
  ///
  /// Useful for testing or when you need completely separate cache instances.
  static CachedQuery createNewInstance() => CachedQuery.asNewInstance();

  /// Create a new isolated MutationCache instance.
  ///
  /// Useful for testing or when you need completely separate mutation cache instances.
  static MutationCache createNewMutationCache() => MutationCache.asNewInstance();
}
