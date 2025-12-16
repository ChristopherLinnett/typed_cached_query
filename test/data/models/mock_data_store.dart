class MockDataStore {
  final Map<String, Map<String, dynamic>> _storage = {};

  Future<void> store(String key, Map<String, dynamic> data) async {
    _storage[key] = Map.from(data);
  }

  Future<Map<String, dynamic>?> retrieve(String key) async {
    return _storage[key] != null ? Map.from(_storage[key]!) : null;
  }

  Future<void> clear(String key) async {
    _storage.remove(key);
  }

  Future<void> clearAll() async {
    _storage.clear();
  }

  List<String> get keys => _storage.keys.toList();

  int get size => _storage.length;

  bool containsKey(String key) => _storage.containsKey(key);
}
