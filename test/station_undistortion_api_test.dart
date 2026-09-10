import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:catcheye_studio/models/app_settings.dart';
import 'package:catcheye_studio/services/remote_capture_api_service.dart';

void main() {
  test(
    'API sends camera-specific GET and boolean POST and propagates 409',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <String>[];
      final subscription = server.listen((request) async {
        requests.add(request.method);
        expect(request.uri.path, '/api/cameras/stud_camera/undistortion');
        if (request.method == 'POST') {
          expect(jsonDecode(await utf8.decoder.bind(request).join()), {
            'enabled': true,
          });
          request.response.statusCode = 409;
          request.response.write('{"error":"CAPTURE_BUSY"}');
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'camera_id': 'stud_camera',
              'enabled': false,
              'calibration_available': true,
              'image_generation': 0,
              'persistent': false,
            }),
          );
        }
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      final api = RemoteCaptureApiService();
      addTearDown(api.close);
      final settings = AppSettings(
        detectorBaseUrl: 'http://127.0.0.1:${server.port}',
      );
      expect(
        (await api.fetchUndistortion(settings, 'stud_camera')).enabled,
        false,
      );
      await expectLater(
        api.setUndistortion(settings, 'stud_camera', true),
        throwsA(
          isA<RemoteCaptureApiException>().having(
            (e) => e.statusCode,
            'status',
            409,
          ),
        ),
      );
      expect(requests, ['GET', 'POST']);
    },
  );

  test('malformed mode responses fail explicitly', () {
    final valid = <String, dynamic>{
      'camera_id': 'stud_camera',
      'enabled': false,
      'calibration_available': true,
      'image_generation': 0,
      'persistent': false,
    };
    for (final key in valid.keys) {
      expect(
        () => StationUndistortion.fromJson(Map.of(valid)..remove(key)),
        throwsFormatException,
      );
    }
    expect(
      () => StationUndistortion.fromJson({...valid, 'enabled': 'false'}),
      throwsFormatException,
    );
    expect(
      () => StationUndistortion.fromJson({...valid, 'image_generation': -1}),
      throwsFormatException,
    );
  });
}
