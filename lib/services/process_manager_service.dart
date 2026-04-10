import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import 'remote_guard_api_service.dart';

/// catcheye-guard remote detector control service

enum GuardProcessStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

class ProcessManagerService extends ChangeNotifier {
  GuardProcessStatus _status = GuardProcessStatus.stopped;
  final List<String> _logs = [];
  static const int maxLogLines = 5000;
  final RemoteGuardApiService _api = RemoteGuardApiService();
  String? _statusMessage;
  bool _busy = false;

  GuardProcessStatus get status => _status;
  List<String> get logs => List.unmodifiable(_logs);
  String? get statusMessage => _statusMessage;
  bool get busy => _busy;

  bool get isRunning =>
      _status == GuardProcessStatus.running ||
      _status == GuardProcessStatus.starting;

  Future<void> refreshStatus(AppSettings settings) async {
    try {
      final remoteStatus = await _api.fetchStatus(settings);
      _status = _mapStatus(remoteStatus.rawStatus);
      _statusMessage = remoteStatus.message;
      _addLog('[INFO] Status refreshed: ${remoteStatus.rawStatus}');
      notifyListeners();
    } catch (e) {
      _status = GuardProcessStatus.error;
      _statusMessage = e.toString();
      _addLog('[ERROR] Failed to refresh status: $e');
      notifyListeners();
    }
  }

  Future<void> start(AppSettings settings) async {
    if (_busy) return;
    _busy = true;
    _status = GuardProcessStatus.starting;
    _statusMessage = null;
    _addLog('[INFO] Sending remote start request');
    notifyListeners();

    try {
      await _api.startDetector(settings);
      await refreshStatus(settings);
    } catch (e) {
      _status = GuardProcessStatus.error;
      _statusMessage = e.toString();
      _addLog('[ERROR] Failed to start remote detector: $e');
      notifyListeners();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> stop(AppSettings settings) async {
    if (_busy) return;
    _busy = true;
    _status = GuardProcessStatus.stopping;
    _statusMessage = null;
    _addLog('[INFO] Sending remote stop request');
    notifyListeners();

    try {
      await _api.stopDetector(settings);
      await refreshStatus(settings);
    } catch (e) {
      _status = GuardProcessStatus.error;
      _statusMessage = e.toString();
      _addLog('[ERROR] Failed to stop remote detector: $e');
      notifyListeners();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> pushSettings(AppSettings settings) async {
    _busy = true;
    _addLog('[INFO] Uploading detector settings');
    notifyListeners();
    try {
      await _api.pushSettings(settings);
      _addLog('[INFO] Detector settings updated');
    } catch (e) {
      _addLog('[ERROR] Failed to upload settings: $e');
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<AppSettings> pullSettings(AppSettings settings) async {
    _busy = true;
    _addLog('[INFO] Downloading detector settings');
    notifyListeners();
    try {
      final remoteSettings = await _api.fetchSettings(settings);
      _addLog('[INFO] Detector settings downloaded');
      return remoteSettings;
    } catch (e) {
      _addLog('[ERROR] Failed to download settings: $e');
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
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

  GuardProcessStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return GuardProcessStatus.running;
      case 'starting':
        return GuardProcessStatus.starting;
      case 'stopping':
        return GuardProcessStatus.stopping;
      case 'stopped':
        return GuardProcessStatus.stopped;
      default:
        return GuardProcessStatus.error;
    }
  }
}
