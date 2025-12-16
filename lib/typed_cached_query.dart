// Export our core models and base classes
export 'src/models/query_key.dart';
export 'src/models/mutation_key.dart';
export 'src/models/infinite_query_key.dart';
export 'src/models/serializable.dart';

// Export our typed UI builders and listeners
export 'src/builders/query_builder.dart';
export 'src/builders/infinite_query_builder.dart';
export 'src/builders/mutation_builder.dart';
export 'src/builders/query_listener.dart';
export 'src/builders/mutation_listener.dart';

// Export our custom exceptions
export 'src/errors/query_exception.dart';

// Export initialization utilities
export 'src/config/cached_query_config.dart';

// Export essential types that users need (selectively from cached_query_flutter)
export 'package:cached_query_flutter/cached_query_flutter.dart'
    show
        // Configuration types
        GlobalQueryConfig,
        QueryConfig,
        StorageInterface,
        QueryObserver,
        AppState,
        ConnectionStatus,
        // Query state types
        QueryStatus,
        MutationState,
        // Infinite query types
        InfiniteQuery,
        InfiniteQueryData,
        InfiniteQueryStatus,
        InfiniteQueryInitial,
        InfiniteQueryLoading,
        InfiniteQuerySuccess,
        InfiniteQueryError,
        GetNextArg,
        // Cache instances (but users should prefer our wrapper methods)
        Query,
        CachedQuery,
        MutationCache;
