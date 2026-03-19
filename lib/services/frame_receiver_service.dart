import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Receives JPEG frames from catcheye-guard via Unix domain socket.
/// Protocol: [4-byte LE uint32 frame_size] [JPEG bytes] per frame.

class FrameReceiverService extends ChangeNotifier {
  Socket? _socket;
  bool _connected = false;
  bool _connecting = false;
  String? _errorMessage;
  Uint8List? _currentFrame;
  int _frameCount = 0;
  int _fps = 0;
  int _framesThisSecond = 0;
  Timer? _fpsTimer;

  // Internal receive buffer
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  int? _pendingFrameSize;

  bool get connected => _connected;
  bool get connecting => _connecting;
  String? get errorMessage => _errorMessage;
  Uint8List? get currentFrame => _currentFrame;
  int get frameCount => _frameCount;
  int get fps => _fps;

  static const String defaultSocketPath = '/tmp/catcheye_guard_preview.sock';

  Future<void> connect([String socketPath = defaultSocketPath]) async {
    if (_connected || _connecting) return;

    _connecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final address = InternetAddress(socketPath, type: InternetAddressType.unix);
      _socket = await Socket.connect(address, 0);
      _connected = true;
      _connecting = false;
      _frameCount = 0;
      _errorMessage = null;

      _startFpsCounter();

      _socket!.listen(
        _onData,
        onError: (error) {
          _errorMessage = 'Connection error: $error';
          _disconnect();
        },
        onDone: () {
          _errorMessage = 'Connection closed by server';
          _disconnect();
        },
        cancelOnError: false,
      );

      notifyListeners();
    } catch (e) {
      _connecting = false;
      _connected = false;
      _errorMessage = 'Connection failed: $e';
      notifyListeners();
    }
  }

  void disconnect() {
    _disconnect();
    _errorMessage = null;
    notifyListeners();
  }

  void _disconnect() {
    _fpsTimer?.cancel();
    _fpsTimer = null;
    _socket?.destroy();
    _socket = null;
    _connected = false;
    _connecting = false;
    _buffer.clear();
    _pendingFrameSize = null;
    notifyListeners();
  }

  void _startFpsCounter() {
    _framesThisSecond = 0;
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fps = _framesThisSecond;
      _framesThisSecond = 0;
      notifyListeners();
    });
  }

  void _onData(Uint8List data) {
    _buffer.add(data);

    while (true) {
      final bytes = _buffer.takeBytes();

      // Need at least 4 bytes for frame size header
      if (_pendingFrameSize == null) {
        if (bytes.length < 4) {
          _buffer.add(bytes);
          break;
        }
        _pendingFrameSize = bytes[0] |
            (bytes[1] << 8) |
            (bytes[2] << 16) |
            (bytes[3] << 24);

        // Sanity check: frame shouldn't be larger than 10MB
        if (_pendingFrameSize! > 10 * 1024 * 1024 || _pendingFrameSize! <= 0) {
          _errorMessage = 'Invalid frame size: $_pendingFrameSize';
          _disconnect();
          return;
        }

        // Put remaining bytes back
        if (bytes.length > 4) {
          _buffer.add(Uint8List.sublistView(bytes, 4));
        }
        continue;
      }

      // Wait for complete frame
      if (bytes.length < _pendingFrameSize!) {
        _buffer.add(bytes);
        break;
      }

      // Extract one complete JPEG frame
      final jpegData = Uint8List.sublistView(bytes, 0, _pendingFrameSize!);
      _currentFrame = jpegData;
      _frameCount++;
      _framesThisSecond++;

      // Put remaining bytes back for next frame
      if (bytes.length > _pendingFrameSize!) {
        _buffer.add(Uint8List.sublistView(bytes, _pendingFrameSize!));
      }
      _pendingFrameSize = null;

      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
