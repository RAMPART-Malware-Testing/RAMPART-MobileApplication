import 'package:flutter/foundation.dart';

class TabCache {
  TabCache._();

  static final TabCache instance = TabCache._();

  static const Duration ttl = Duration(seconds: 4);

  final Map<String, _Entry> _entries = {};

  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);

  T? fresh<T>(String key, {DateTime? now}) {
    final entry = _entries[key];
    if (entry == null) return null;
    if ((now ?? DateTime.now()).difference(entry.savedAt) >= ttl) return null;
    final value = entry.value;
    return value is T ? value : null;
  }

  void store(String key, Object? value, {DateTime? now}) {
    final at = now ?? DateTime.now();
    _entries[key] = _Entry(at, value);
    lastSyncedAt.value = at;
  }

  void noteSync(DateTime at) {
    final current = lastSyncedAt.value;
    if (current == null || at.isAfter(current)) lastSyncedAt.value = at;
  }

  void clear() {
    _entries.clear();
    lastSyncedAt.value = null;
  }
}

class _Entry {
  const _Entry(this.savedAt, this.value);

  final DateTime savedAt;
  final Object? value;
}
