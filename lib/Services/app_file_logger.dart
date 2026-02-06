import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Minimal file logger for on-device debugging.
///
/// - Writes to an app-scoped file (no extra permissions required).
/// - Also mirrors logs to debug console in debug mode.
/// - Safe fallback on web (no file IO).
class AppFileLogger {
  AppFileLogger._();

  static final AppFileLogger instance = AppFileLogger._();

  File? _file;
  IOSink? _sink;
  Future<void> _queue = Future<void>.value();

  String? get logFilePath => _file?.path;

  Future<void> init({String fileName = 'dryv_debug.log'}) async {
    if (kIsWeb) return;
    if (_sink != null) return;

    // NOTE:
    // We intentionally avoid depending on plugins (like path_provider) so logging
    // can be enabled without extra setup. This uses the platform temp directory.
    // On Android this typically maps to the app cache directory.
    try {
      final Directory dir = Directory.systemTemp;
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.create(recursive: true);

      _file = file;
      _sink = file.openWrite(mode: FileMode.append);

      await _enqueueWrite(
        '\n===== DRYV SESSION ${DateTime.now().toIso8601String()} =====\n',
      );
    } catch (e, st) {
      // Do not crash the app if file IO fails; keep console logging only.
      _file = null;
      _sink = null;

      if (kDebugMode) {
        // ignore: avoid_print
        print('AppFileLogger.init failed: $e\n$st');
      }
    }
  }

  Future<void> close() async {
    final sink = _sink;
    if (sink == null) return;

    _sink = null;
    await _queue;
    await sink.flush();
    await sink.close();
  }

  void info(String message) => _log('INFO', message);
  void warn(String message) => _log('WARN', message);
  void error(String message, {Object? err, StackTrace? stack}) {
    final suffix = <String>[
      if (err != null) 'error=$err',
      if (stack != null) 'stack=${_formatStack(stack)}',
    ].join(' ');

    _log('ERROR', suffix.isEmpty ? message : '$message $suffix');
  }

  void _log(String level, String message) {
    final line = '${DateTime.now().toIso8601String()} [$level] $message\n';

    if (kDebugMode) {
      // Avoid spamming release logs; debug-only mirror to console.
      // ignore: avoid_print
      print(line.trimRight());
    }

    final sink = _sink;
    if (sink == null) return;

    // Serialize writes so messages don't interleave.
    _queue = _queue.then((_) => _enqueueWrite(line));
  }

  Future<void> _enqueueWrite(String line) async {
    final sink = _sink;
    if (sink == null) return;
    sink.write(line);
    await sink.flush();
  }

  String _formatStack(StackTrace stack) {
    // Keep it compact in logs.
    final lines = stack.toString().split('\n');
    if (lines.length <= 25) return stack.toString();
    return '${lines.take(25).join('\n')}\n...';
  }
}
