import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:catcheye_studio/models/app_settings.dart';
import 'package:catcheye_studio/providers/settings_provider.dart';
import 'package:catcheye_studio/providers/reference_credential_provider.dart';
import 'package:catcheye_studio/services/reference_credential_store.dart';
import 'package:catcheye_studio/services/remote_reference_api_service.dart';
import 'package:catcheye_studio/widgets/model_validation_review.dart';
import 'package:catcheye_studio/widgets/zoomable_viewport.dart';

const _detection = ModelValidationDetection(
  className: 'bolt_head',
  confidence: 0.9,
  box: [10, 20, 30, 40],
);
const _prompt = ModelValidationResult(
  source: 'prompt',
  className: 'bolt_head',
  status: 'PRESENT',
  reason: 'TARGET_CONFIRMED',
  latencyMs: 500,
  detections: [_detection],
);
const _baseline = ModelValidationResult(
  source: 'baseline',
  className: 'bolt_head',
  status: 'ABSENT',
  reason: 'NO_CANDIDATE',
  latencyMs: 510,
  detections: [],
);

ReferenceModel _model(List<ModelValidationResult> results) => ReferenceModel(
  modelId: 'model_candidate',
  referenceRevisionId: 'refrev_candidate',
  createdAtMs: 1,
  engineSha256: 'engine',
  metadataSha256: 'metadata',
  technicalPassed: true,
  reviewRequired: true,
  buildId: 'build_candidate',
  validation: ModelValidation(
    technicalPassed: true,
    productionApproved: false,
    results: results,
  ),
  weightsSha256: null,
  exportConfigSha256: null,
  onnxSha256: null,
);

Future<void> _mount(
  WidgetTester tester,
  _Api api, {
  List<ModelValidationResult> results = const [_prompt, _baseline],
  double width = 1000,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final settings = AppSettings(
    detectorBaseUrl: 'http://station.test:8090',
    remoteDeviceKind: RemoteDeviceKind.inspection,
  );
  final store = ReferenceCredentialStore(backend: _Credentials());
  await store.writeToken(
    settings,
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(initialSettings: settings),
        ),
        ChangeNotifierProvider(
          create: (_) => ReferenceCredentialProvider(store: store),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ModelValidationReview(model: _model(results), api: api),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!api.corruptImage && find.byType(Image).evaluate().isNotEmpty) {
    final image = tester.widget<Image>(find.byType(Image));
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(Image))),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  test('image coordinate mapping uses xywh at different viewport sizes', () {
    const painter = ValidationDetectionsPainter(
      detections: [_detection],
      imageWidth: 100,
      imageHeight: 80,
    );
    expect(
      painter.rectFor(_detection, const Size(200, 160)),
      const Rect.fromLTWH(20, 40, 60, 80),
    );
    expect(
      painter.rectFor(_detection, const Size(50, 40)),
      const Rect.fromLTWH(5, 10, 15, 20),
    );
  });

  test('record distinguishes unrecorded positions from zero detections', () {
    final record = <String, dynamic>{
      'source': 'prompt',
      'class_name': 'bolt_head',
      'status': 'ABSENT',
      'reason': 'NO_CANDIDATE',
    };
    expect(ModelValidationResult.fromJson(record).detections, isNull);
    expect(
      ModelValidationResult.fromJson({...record, 'detections': []}).detections,
      isEmpty,
    );
    final parsed = ModelValidationResult.fromJson({
      ...record,
      'detections': [
        {
          'class_name': 'bolt_head',
          'confidence': 0.9,
          'box': [10, 20, 30, 40],
        },
      ],
    });
    expect(parsed.detections!.single.box, [10, 20, 30, 40]);
    expect(
      () => ModelValidationResult.fromJson({
        ...record,
        'detections': [
          {
            'class_name': 'bolt_head',
            'confidence': 0.9,
            'box': [10, 20, -30, 40],
          },
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => ModelValidationResult.fromJson({...record, 'detections': {}}),
      throwsFormatException,
    );
  });

  for (final width in [1000.0, 390.0]) {
    testWidgets(
      'saved image and overlay are correlated to the selected sample at $width px',
      (tester) async {
        final api = _Api();
        await _mount(tester, api, width: width);
        expect(api.revisions, ['refrev_candidate']);
        expect(api.images, [
          '/api/reference/images/refrev_candidate-bolt_head',
        ]);
        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(ZoomableViewport), findsOneWidget);
        expect(find.text('볼트 헤드 · 검출'), findsWidgets);
        expect(find.textContaining('검출 점수 90.0%'), findsOneWidget);
        expect(
          tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .where((w) => w.painter is ValidationDetectionsPainter),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('초기 기준 이미지'));
        await tester.pumpAndSettle();
        expect(api.revisions.last, 'refrev_initial');
        expect(
          api.images.last,
          '/api/reference/images/refrev_initial-bolt_head',
        );
        expect(find.text('볼트 헤드 · 미검출'), findsWidgets);
        expect(find.text('이 이미지에서 검출된 후보가 없어.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'old records display their actual input without invented detections',
    (tester) async {
      await _mount(
        tester,
        _Api(),
        results: const [
          ModelValidationResult(
            source: 'prompt',
            className: 'bolt_head',
            status: 'PRESENT',
            reason: 'TARGET_CONFIRMED',
            latencyMs: 1,
          ),
        ],
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('이 기록에는 검출 위치가 저장되지 않았어.'), findsOneWidget);
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).onSelected,
        isNull,
      );
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((w) => w.painter is ValidationDetectionsPainter),
        isEmpty,
      );
    },
  );

  testWidgets('image failure clears earlier evidence and remains explicit', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    api.failImage = true;
    await tester.tap(find.text('초기 기준 이미지'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('이미지를 불러오지 못했어.'), findsOneWidget);
    expect(find.textContaining('sample image missing'), findsOneWidget);
    expect(api.images, hasLength(2));
  });

  testWidgets('mismatched revision never fetches unrelated image evidence', (
    tester,
  ) async {
    final api = _Api()..wrongRevision = true;
    await _mount(tester, api);
    expect(api.images, isEmpty);
    expect(find.textContaining('요청한 검증 리비전과 서버 응답이 일치하지 않아.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('corrupt image does not display detection boxes', (tester) async {
    final api = _Api()..corruptImage = true;
    await _mount(tester, api);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('이미지 파일을 해석할 수 없어.'), findsOneWidget);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is ValidationDetectionsPainter),
      isEmpty,
    );
  });

  testWidgets('late image response cannot overwrite newly selected evidence', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    final delayed = Completer<Uint8List>();
    api.delayedImage = delayed;
    await tester.tap(find.text('초기 기준 이미지'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byType(Image), findsNothing);
    api.delayedImage = null;
    await tester.tap(find.text('이번 리비전'));
    await tester.pumpAndSettle();
    delayed.completeError(StateError('stale image failure'));
    await tester.pumpAndSettle();
    expect(find.text('볼트 헤드 · 검출'), findsWidgets);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('stale image failure'), findsNothing);
  });

  testWidgets('failed shape metric shows measured value and configured limit', (
    tester,
  ) async {
    await _mount(
      tester,
      _Api(),
      results: const [
        ModelValidationResult(
          source: 'prompt',
          className: 'nut_hole',
          status: 'NG',
          reason: 'SHAPE_QUALITY_FAILED',
          latencyMs: 1,
          detections: [],
          measurements: {
            'quality_metrics': {'circularity': 0.6},
            'quality_limits': {'min_circularity': 0.8},
            'failed_metrics': ['circularity'],
          },
        ),
      ],
    );
    expect(find.text('너트 홀 · NG'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('원형도: 0.600'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('원형도: 0.600 / ≥ 0.800 · 기준 미달'), findsOneWidget);
  });
}

class _Api extends RemoteReferenceApiService {
  final revisions = <String>[];
  final images = <String>[];
  bool failImage = false;
  bool wrongRevision = false;
  bool corruptImage = false;
  Completer<Uint8List>? delayedImage;

  @override
  Future<ReferenceRevision> fetchRevision(
    AppSettings settings,
    String revisionId, {
    required String bearerToken,
  }) async {
    revisions.add(revisionId);
    return ReferenceRevision(
      revisionId: wrongRevision ? 'refrev_wrong' : revisionId,
      baseRevisionId: null,
      createdAtMs: 1,
      entries: [
        for (final part in ['bolt_head', 'nut_hole'])
          ReferenceRevisionEntry(
            className: part,
            imageId: '$revisionId-$part',
            imageUrl: '/api/reference/images/$revisionId-$part',
            width: 100,
            height: 80,
            boxes: const [ReferenceBox(0, 0, 100, 80)],
            contextRatio: 0.1,
          ),
      ],
    );
  }

  @override
  Future<Uint8List> fetchImageUrl(
    AppSettings settings,
    String relativeUrl, {
    required String bearerToken,
  }) async {
    images.add(relativeUrl);
    if (failImage) throw StateError('sample image missing');
    if (corruptImage) return Uint8List.fromList([1, 2, 3]);
    if (delayedImage != null) return delayedImage!.future;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAGQAAABQCAIAAABga0e4AAAAl0lEQVR4nO3QUQkAIBTAwBfRECYxuRX8G8LBAoybtY8em/zgo2DBgpUHCxasPFiwYOXBggUrDxYsWHmwYMHKgwULVh4sWLDyYMGClQcLFqw8WLBg5cGCBSsPFixYebBgwcqDBQtWHixYsPJgwYKVBwsWrDxYsGDlwYIFKw8WLFh5sGDByoMFC1YeLFiw8mDBgpUHCxasvAvNf9msKaoTQwAAAABJRU5ErkJggg==',
    );
  }
}

class _Credentials implements SecureCredentialBackend {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
