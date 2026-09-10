import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catcheye_studio/models/app_settings.dart';
import 'package:catcheye_studio/services/remote_capture_api_service.dart';
import 'package:catcheye_studio/widgets/station_undistortion_control.dart';

StationUndistortion mode(String id, bool enabled, {bool available = true}) =>
    StationUndistortion(
      cameraId: id,
      enabled: enabled,
      calibrationAvailable: available,
      imageGeneration: 1,
      persistent: false,
    );

class FakeApi extends RemoteCaptureApiService {
  bool enabled = false;
  bool available = true;
  bool fail = false;
  int gets = 0;
  int posts = 0;
  String? lastCamera;
  Completer<StationUndistortion>? pending;

  @override
  Future<StationUndistortion> fetchUndistortion(
    AppSettings settings,
    String cameraId,
  ) async {
    gets++;
    return pending == null
        ? mode(cameraId, enabled, available: available)
        : pending!.future;
  }

  @override
  Future<StationUndistortion> setUndistortion(
    AppSettings settings,
    String cameraId,
    bool value,
  ) async {
    posts++;
    lastCamera = cameraId;
    if (fail) throw TimeoutException('state unknown');
    enabled = value;
    return mode(cameraId, enabled);
  }
}

Widget screen(
  FakeApi api, {
  bool blocked = false,
  String id = 'stud_camera',
  bool? observed,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 250,
      child: StationUndistortionControl(
        key: ValueKey(id),
        api: api,
        settings: AppSettings(),
        cameraId: id,
        blocked: blocked,
        observedEnabled: observed,
        onApplyingChanged: (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('loads server state and toggles exactly the selected camera', (
    tester,
  ) async {
    final api = FakeApi();
    addTearDown(api.close);
    await tester.pumpWidget(screen(api));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(api.posts, 1);
    expect(api.lastCamera, 'stud_camera');
    expect(tester.widget<Switch>(find.byType(Switch)).value, true);
    await tester.pumpWidget(screen(api, observed: false));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });

  testWidgets('inspection busy and missing calibration disable the switch', (
    tester,
  ) async {
    final api = FakeApi();
    addTearDown(api.close);
    await tester.pumpWidget(screen(api, blocked: true));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    api.available = false;
    await tester.pumpWidget(screen(api, id: 'nut_camera'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('보정 파일 없음'), findsOneWidget);
    expect(api.posts, 0);
  });

  testWidgets('failed POST requires explicit GET and is never replayed', (
    tester,
  ) async {
    final api = FakeApi()..fail = true;
    addTearDown(api.close);
    await tester.pumpWidget(screen(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('state unknown'), findsOneWidget);
    expect(api.posts, 1);
    api.enabled = true; // The server may have applied a timed-out request.
    await tester.tap(find.byTooltip('보정 상태 다시 조회'));
    await tester.pumpAndSettle();
    expect(api.posts, 1);
    expect(api.gets, 2);
    expect(tester.widget<Switch>(find.byType(Switch)).value, true);
  });

  testWidgets('late response from a previous camera is discarded', (
    tester,
  ) async {
    final api = FakeApi()..pending = Completer<StationUndistortion>();
    addTearDown(api.close);
    final old = api.pending!;
    await tester.pumpWidget(screen(api));
    await tester.pump();
    api.pending = null;
    await tester.pumpWidget(screen(api, id: 'nut_camera'));
    await tester.pumpAndSettle();
    old.complete(mode('stud_camera', true));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });
}
