import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// catcheye-guard process management service

enum GuardProcessStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

class ProcessManagerService extends ChangeNotifier {
  Process? _process;
  GuardProcessStatus _status = GuardProcessStatus.stopped;
  final List<String> _logs = [];
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  static const int maxLogLines = 5000;

  GuardProcessStatus get status => _status;
  List<String> get logs => List.unmodifiable(_logs);

  bool get isRunning =>
      _status == GuardProcessStatus.running ||
      _status == GuardProcessStatus.starting;

  Future<void> start(String executablePath, List<String> args) async {
    if (isRunning) return;

    _status = GuardProcessStatus.starting;
    _logs.clear();
    notifyListeners();

    try {
      _process = await Process.start(executablePath, args);
      _status = GuardProcessStatus.running;
      _addLog('[INFO] Process started (PID: ${_process!.pid})');

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog(line);
      });

      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog('[ERR] $line');
      });

      _process!.exitCode.then((code) {
        _addLog('[INFO] Process exited (exit code: $code)');
        _status = code == 0 ? GuardProcessStatus.stopped : GuardProcessStatus.error;
        _process = null;
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      _status = GuardProcessStatus.error;
      _addLog('[ERROR] Failed to start process: $e');
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (!isRunning || _process == null) return;

    _status = GuardProcessStatus.stopping;
    _addLog('[INFO] Stopping process...');
    notifyListeners();

    _process!.kill(ProcessSignal.sigterm);

    Future.delayed(const Duration(seconds: 5), () {
      if (_process != null) {
        _process!.kill(ProcessSignal.sigkill);
        _addLog('[WARN] SIGKILL sent');
      }
    });
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _logs.add('[$timestamp] $message');
    if (_logs.length > maxLogLines) {
      _logs.removeRange(0, _logs.length - maxLogLines);
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
    }
    super.dispose();
  }
}
