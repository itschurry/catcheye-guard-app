import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Receives JPEG frames from catcheye-guard over an HTTP stream.
/// The parser extracts JPEG SOI/EOI markers, so it works with common MJPEG responses.

class FrameReceiverService extends ChangeNotifier {
  final HttpClient _httpClient = HttpClient();
  HttpClientRequest? _request;
  HttpClientResponse? _response;
  StreamSubscription<List<int>>? _streamSubscription;
  bool _connected = false;
  bool _connecting = false;
  String? _errorMessage;
  Uint8List? _currentFrame;
  int _frameCount = 0;
  int _fps = 0;
  int _framesThisSecond = 0;
  Timer? _fpsTimer;

  final List<int> _buffer = <int>[];
  Uri? _connectedUri;

  bool get connected => _connected;
  bool get connecting => _connecting;
  String? get errorMessage => _errorMessage;
  Uint8List? get currentFrame => _currentFrame;
  int get frameCount => _frameCount;
  int get fps => _fps;
  Uri? get connectedUri => _connectedUri;

  static const String defaultStreamUrl = 'http://127.0.0.1:8080/';

  Future<void> connect([String streamUrl = defaultStreamUrl]) async {
    if (_connected || _connecting) return;

    _connecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = _normalizeUri(streamUrl);
      _request = await _httpClient.getUrl(uri);
      _request!.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      _request!.headers.set(HttpHeaders.acceptHeader, 'multipart/x-mixed-replace,image/jpeg,*/*');
      _response = await _request!.close();
      if (_response!.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Unexpected HTTP status ${_response!.statusCode}',
          uri: uri,
        );
      }

      _connected = true;
      _connecting = false;
      _frameCount = 0;
      _errorMessage = null;
      _connectedUri = uri;
      _buffer.clear();

      _startFpsCounter();

      _streamSubscription = _response!.listen(
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
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _request?.abort();
    _request = null;
    _response = null;
    _connected = false;
    _connecting = false;
    _connectedUri = null;
    _buffer.clear();
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

  void _onData(List<int> data) {
    _buffer.addAll(data);

    while (true) {
      final start = _indexOfMarker(_buffer, const [0xFF, 0xD8]);
      if (start < 0) {
        _trimBuffer();
        return;
      }

      final end = _indexOfMarker(_buffer, const [0xFF, 0xD9], start + 2);
      if (end < 0) {
        if (start > 0) {
          _buffer.removeRange(0, start);
        }
        _trimBuffer();
        return;
      }

      final frameEnd = end + 2;
      final jpegData = Uint8List.fromList(_buffer.sublist(start, frameEnd));
      _currentFrame = jpegData;
      _frameCount++;
      _framesThisSecond++;

      _buffer.removeRange(0, frameEnd);
      notifyListeners();
    }
  }

  void _trimBuffer() {
    const maxBufferedBytes = 2 * 1024 * 1024;
    if (_buffer.length > maxBufferedBytes) {
      _buffer.removeRange(0, _buffer.length - maxBufferedBytes);
    }
  }

  int _indexOfMarker(List<int> source, List<int> marker, [int start = 0]) {
    for (var i = start; i <= source.length - marker.length; i++) {
      var matched = true;
      for (var j = 0; j < marker.length; j++) {
        if (source[i + j] != marker[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }

  Uri _normalizeUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    final normalized = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'http://$trimmed';
    return Uri.parse(normalized);
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
