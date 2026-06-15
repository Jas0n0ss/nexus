import 'package:flutter/foundation.dart';

class LogEntry {
  final DateTime time;
  final String level; // INFO, OK, WARN, ERROR
  final String tag;
  final String message;
  LogEntry(this.level, this.tag, this.message) : time = DateTime.now();

  String get timeStr {
    final t = time;
    return '${t.hour.toString().padLeft(2,'0')}:'
           '${t.minute.toString().padLeft(2,'0')}:'
           '${t.second.toString().padLeft(2,'0')}';
  }
}

class LogsProvider extends ChangeNotifier {
  final List<LogEntry> _entries = [];

  List<LogEntry> get all => _entries;

  List<LogEntry> filtered(String level) =>
      level == 'ALL' ? _entries : _entries.where((e) => e.level == level).toList();

  void add(String level, String tag, String message) {
    _entries.add(LogEntry(level, tag, message));
    notifyListeners();
  }

  void clear() { _entries.clear(); notifyListeners(); }
}
