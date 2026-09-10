import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:catcheye_studio/models/app_settings.dart';
import 'package:catcheye_studio/services/remote_capture_api_service.dart';

Map<String, dynamic> savedResult() => {
  'cycle_id': '100-100-1',
  'state': 'COMPLETED',
  'status': 'NG',
  'set_id': 'fastener',
  'requested_at_ms': 1789000000000,
  'storage_path': 'bolt_stud/2026-09-09/100-100-1',
  'size_bytes': 1234,
  'inspections': <String, dynamic>{},
};

void main() {
  test(
    'archive requests preserve device date, cursor, storage path and raw/overlay selection',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <Uri>[];
      server.listen((request) async {
        requests.add(request.uri);
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/dates')) {
          request.response.write(
            jsonEncode({
              'storage': {
                'path': '/outputs',
                'total_bytes': 10000,
                'available_bytes': 3000,
                'used_bytes': 7000,
                'used_percent': 70,
                'capture_bytes': 1234,
                'capture_count': 2,
                'result_count': 1,
              },
              'dates': [
                {'date': '2026-09-09', 'count': 1},
              ],
            }),
          );
        } else if (request.uri.path.endsWith('/image')) {
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add([137, 80, 78, 71]);
        } else {
          request.response.write(
            jsonEncode({
              'date': '2026-09-09',
              'results': [savedResult()],
              'next_cursor': null,
            }),
          );
        }
        await request.response.close();
      });
      final api = RemoteCaptureApiService();
      addTearDown(api.close);
      final settings = AppSettings(
        detectorBaseUrl: 'http://127.0.0.1:${server.port}',
      );
      final dates = await api.fetchStationArchiveDates(settings);
      expect(dates.storage.captureBytes, 1234);
      expect(dates.resultCount, 1);
      final page = await api.fetchStationArchive(
        settings,
        date: dates.dates.single.date,
        cursor: '200:200-200-2',
      );
      expect(page.results.single.cycleId, '100-100-1');
      await api.fetchStationImage(
        settings,
        cycleId: '100-100-1',
        inspectionId: 'stud',
        kind: 'raw',
        storagePath: page.results.single.rawJson['storage_path'] as String,
      );
      expect(requests.map((uri) => uri.path), [
        '/api/capture/archive/dates',
        '/api/capture/archive',
        '/api/capture/archive/bolt_stud/2026-09-09/100-100-1/image',
      ]);
      expect(requests[1].queryParameters, {
        'date': '2026-09-09',
        'limit': '100',
        'cursor': '200:200-200-2',
      });
      expect(requests.last.queryParameters, {
        'inspection_id': 'stud',
        'kind': 'raw',
      });
      await expectLater(
        api.fetchStationImage(
          settings,
          cycleId: '100-100-1',
          inspectionId: 'stud',
          kind: 'raw',
          storagePath: '../private',
        ),
        throwsFormatException,
      );
      expect(requests, hasLength(3));
    },
  );

  test(
    'unsupported archive API fails once without using the recent-results API',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final paths = <String>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        request.response.statusCode = 404;
        request.response.write('archive API not installed');
        await request.response.close();
      });
      final api = RemoteCaptureApiService();
      addTearDown(api.close);
      await expectLater(
        api.fetchStationArchiveDates(
          AppSettings(detectorBaseUrl: 'http://127.0.0.1:${server.port}'),
        ),
        throwsA(
          isA<RemoteCaptureApiException>().having(
            (error) => error.statusCode,
            'status',
            404,
          ),
        ),
      );
      expect(paths, ['/api/capture/archive/dates']);
    },
  );

  test('archive page rejects invalid dates and unrelated saved paths', () {
    for (final date in ['2026-02-30', '../outputs']) {
      expect(
        () => StationArchivePage.fromJson({
          'date': date,
          'results': [],
          'next_cursor': null,
        }),
        throwsFormatException,
      );
    }
    for (final change in [
      {'storage_path': 'bolt_stud/2026-09-10/100-100-1'},
      {'storage_path': 'bolt_stud/2026-09-09/100-100-2'},
      {'storage_path': '../private'},
      {'size_bytes': -1},
    ]) {
      expect(
        () => StationArchivePage.fromJson({
          'date': '2026-09-09',
          'results': [
            {...savedResult(), ...change},
          ],
          'next_cursor': null,
        }),
        throwsFormatException,
      );
    }
  });
}
