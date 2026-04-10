import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/roi_config.dart';
import 'roi_config_service.dart';

class RemoteStatus {
  final String rawStatus;
  final String? message;

  const RemoteStatus({
    required this.rawStatus,
    this.message,
  });
}

class RemoteGuardApiService {
  final HttpClient _client = HttpClient();

  Future<AppSettings> fetchSettings(AppSettings connectionSettings) async {
    final json = await _requestJson(
      'GET',
      connectionSettings.buildApiUri('settings'),
    );
    return AppSettings.fromRemoteJson(json);
  }

  Future<void> pushSettings(AppSettings settings) async {
    await _requestJson(
      'PUT',
      settings.buildApiUri('settings'),
      body: settings.toRemoteJson(),
      expectedStatusCodes: const {200, 204},
    );
  }

  Future<CameraRoiConfig> fetchRoi(AppSettings settings) async {
    final json = await _requestJson(
      'GET',
      settings.buildApiUri('roi'),
    );
    return RoiConfigService.fromJsonString(jsonEncode(json));
  }

  Future<void> pushRoi(AppSettings settings, CameraRoiConfig config) async {
    await _requestJson(
      'PUT',
      settings.buildApiUri('roi'),
      body: config.toJson(),
      expectedStatusCodes: const {200, 204},
    );
  }

  Future<RemoteStatus> fetchStatus(AppSettings settings) async {
    final json = await _requestJson(
      'GET',
      settings.buildApiUri('status'),
    );
    final rawStatus = json['status']?.toString() ?? 'unknown';
    return RemoteStatus(
      rawStatus: rawStatus,
      message: json['message']?.toString(),
    );
  }

  Future<void> startDetector(AppSettings settings) async {
    await _requestJson(
      'POST',
      settings.buildApiUri('start'),
      expectedStatusCodes: const {200, 202, 204},
    );
  }

  Future<void> stopDetector(AppSettings settings) async {
    await _requestJson(
      'POST',
      settings.buildApiUri('stop'),
      expectedStatusCodes: const {200, 202, 204},
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Object? body,
    Set<int> expectedStatusCodes = const {200},
  }) async {
    final request = await _client.openUrl(method, uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    if (!expectedStatusCodes.contains(response.statusCode)) {
      final errorBody = responseBody.isEmpty ? response.reasonPhrase : responseBody;
      throw HttpException(
        'Request failed (${response.statusCode}) for $uri: $errorBody',
        uri: uri,
      );
    }

    if (responseBody.isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON object response expected');
    }
    return decoded;
  }
}
