import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:catcheye_studio/models/app_settings.dart';
import 'package:catcheye_studio/services/remote_capture_api_service.dart';

void main() {
  test(
    'saved PNG endpoint uses cycle, inspection and variant, never a filesystem path',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final api = RemoteCaptureApiService();
      addTearDown(api.close);
      final settings = AppSettings(
        detectorBaseUrl: 'http://127.0.0.1:${server.port}',
      );
      var requests = 0;
      server.listen((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/capture/results/cycle-123/image');
        expect(request.uri.queryParameters, {
          'inspection_id': 'bolt_head',
          'kind': 'overlay',
        });
        expect(request.headers.value(HttpHeaders.acceptHeader), 'image/png');
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add([137, 80, 78, 71, 13, 10, 26, 10]);
        await request.response.close();
      });
      final bytes = await api.fetchStationImage(
        settings,
        cycleId: 'cycle-123',
        inspectionId: 'bolt_head',
        kind: 'overlay',
      );
      expect(bytes, [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(requests, 1);
    },
  );

  test(
    '404 and unexpected content types are explicit; no replacement request',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final api = RemoteCaptureApiService();
      addTearDown(api.close);
      final settings = AppSettings(
        detectorBaseUrl: 'http://127.0.0.1:${server.port}',
      );
      var requests = 0;
      server.listen((request) async {
        requests++;
        request.response.statusCode = requests == 1 ? 404 : 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"error":"saved image missing"}');
        await request.response.close();
      });
      Future<void> read() async {
        await api.fetchStationImage(
          settings,
          cycleId: 'cycle',
          inspectionId: 'stud',
          kind: 'raw',
        );
      }

      await expectLater(
        read(),
        throwsA(
          isA<RemoteCaptureApiException>().having(
            (error) => error.statusCode,
            'HTTP',
            404,
          ),
        ),
      );
      expect(requests, 1);
      await expectLater(read(), throwsFormatException);
      expect(requests, 2);
    },
  );

  test(
    'inspection artifacts are parsed and invalid image identifiers rejected',
    () async {
      final record = StationInspectionResult.fromJson({
        'inspection_id': 'bolt_head',
        'artifacts': {'raw': '1-raw.png', 'overlay': '1-overlay.png'},
        'artifact_error': 'disk error',
      });
      expect(record.artifacts['overlay'], '1-overlay.png');
      expect(record.artifactError, 'disk error');
      expect(
        () => StationInspectionResult.fromJson({
          'inspection_id': 'stud',
          'artifacts': {'raw': 3},
        }),
        throwsFormatException,
      );
      final api = RemoteCaptureApiService();
      addTearDown(api.close);
      await expectLater(
        api.fetchStationImage(
          AppSettings(),
          cycleId: 'cycle',
          inspectionId: '../secret',
          kind: 'raw',
        ),
        throwsFormatException,
      );
      await expectLater(
        api.fetchStationImage(
          AppSettings(),
          cycleId: 'cycle',
          inspectionId: 'stud',
          kind: 'other',
        ),
        throwsFormatException,
      );
    },
  );
}
