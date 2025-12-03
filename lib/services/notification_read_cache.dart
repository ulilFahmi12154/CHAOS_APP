class NotificationReadCache {
  NotificationReadCache._();
  static final NotificationReadCache instance = NotificationReadCache._();

  final Set<String> _ids = <String>{};

  void add(String id) {
    if (id.isEmpty) return;
    _ids.add(id);
  }

  void addAll(Iterable<String> ids) {
    for (final id in ids) {
      add(id);
    }
  }

  bool contains(String id) => _ids.contains(id);

  void clear() => _ids.clear();
}
