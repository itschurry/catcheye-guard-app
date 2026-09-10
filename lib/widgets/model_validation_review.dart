import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/reference_credential_provider.dart';
import '../providers/settings_provider.dart';
import '../services/remote_reference_api_service.dart';
import 'zoomable_viewport.dart';

/// Reviews the saved input of each validation result, never the live camera.
class ModelValidationReview extends StatefulWidget {
  const ModelValidationReview({
    super.key,
    required this.model,
    required this.api,
  });

  final ReferenceModel model;
  final RemoteReferenceApiService api;

  @override
  State<ModelValidationReview> createState() => _ModelValidationReviewState();
}

class _ModelValidationReviewState extends State<ModelValidationReview> {
  String _source = 'prompt';
  String? _className;
  String? _connection;
  ReferenceRevisionEntry? _entry;
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;
  bool _showDetections = true;
  int _loadSession = 0;

  List<ModelValidationResult> get _results => widget.model.validation!.results
      .where((result) => result.source == _source)
      .toList(growable: false);

  ModelValidationResult? get _selected =>
      _results.where((result) => result.className == _className).firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>().settings;
    final credentials = context.watch<ReferenceCredentialProvider>();
    final connection =
        '${settings.buildApiUri('reference/revisions')}|${credentials.revision}';
    if (_connection != connection) {
      _connection = connection;
      _className = _results.firstOrNull?.className;
      unawaited(_loadImage());
    }
  }

  @override
  void didUpdateWidget(covariant ModelValidationReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.modelId != widget.model.modelId ||
        oldWidget.api != widget.api) {
      _source = 'prompt';
      _className = _results.firstOrNull?.className;
      unawaited(_loadImage());
    }
  }

  Future<void> _loadImage() async {
    final session = ++_loadSession;
    final selected = _selected;
    setState(() {
      _bytes = null;
      _entry = null;
      _error = null;
      _loading = true;
    });
    try {
      if (selected == null) throw StateError('선택한 부위의 검증 기록이 없어.');
      // Both groups were inspected by this candidate. Baseline means the
      // immutable initial sample revision, not another model's prediction.
      final revisionId = switch (selected.source) {
        'prompt' => widget.model.referenceRevisionId,
        'baseline' => 'refrev_initial',
        _ => throw StateError('지원하지 않는 검증 이미지 그룹: ${selected.source}'),
      };
      final settings = context.read<SettingsProvider>().settings;
      final token = await context.read<ReferenceCredentialProvider>().readToken(
        settings,
      );
      if (token == null) throw StateError('관리 토큰을 등록한 후 이미지를 확인해.');
      if (!mounted || session != _loadSession) return;
      final revision = await widget.api.fetchRevision(
        settings,
        revisionId,
        bearerToken: token,
      );
      if (revision.revisionId != revisionId) {
        throw StateError('요청한 검증 리비전과 서버 응답이 일치하지 않아.');
      }
      final entries = revision.entries
          .where((entry) => entry.className == selected.className)
          .toList();
      if (entries.length != 1) {
        throw StateError('검증 리비전에서 해당 부위의 원본 이미지를 확인할 수 없어.');
      }
      final entry = entries.single;
      final bytes = await widget.api.fetchImageUrl(
        settings,
        entry.imageUrl,
        bearerToken: token,
      );
      if (!mounted || session != _loadSession) return;
      setState(() {
        _entry = entry;
        _bytes = bytes;
      });
    } catch (error) {
      if (!mounted || session != _loadSession) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && session == _loadSession) setState(() => _loading = false);
    }
  }

  void _select(String source, String? className) {
    setState(() {
      _source = source;
      _className = _results.any((result) => result.className == className)
          ? className
          : _results.firstOrNull?.className;
    });
    unawaited(_loadImage());
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final entries = _results;
    final attention = entries
        .where((result) => !_isDetected(result.status))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '검증 이미지 확인',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          '두 이미지 그룹 모두 선택한 모델의 검사 결과야. 실시간 영상이 아니야.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'prompt', label: Text('이번 리비전')),
            ButtonSegment(value: 'baseline', label: Text('초기 기준 이미지')),
          ],
          selected: {_source},
          onSelectionChanged: (value) => _select(value.single, _className),
        ),
        const SizedBox(height: 10),
        Text(
          '확인 필요 $attention / ${entries.length}개 부위',
          style: TextStyle(
            color: attention > 0 ? Colors.orangeAccent : Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final result in entries)
              ChoiceChip(
                label: Text(
                  '${_part(result.className)} · ${_status(result.status)}',
                ),
                avatar: Icon(
                  _isDetected(result.status)
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 18,
                  color: _color(result.status),
                ),
                selected: result.className == _className,
                onSelected: (_) => _select(_source, result.className),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (selected == null)
          const Text('이 그룹에는 검증 결과가 없어.')
        else ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text('검증에 사용한 원본 이미지'),
              FilterChip(
                label: const Text('검출 박스 표시'),
                selected: _showDetections && selected.detections != null,
                onSelected: selected.detections == null
                    ? null
                    : (value) => setState(() => _showDetections = value),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (selected.detections == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '이 기록에는 검출 위치가 저장되지 않았어. 원본 이미지만 확인할 수 있어. 검출 박스는 서버 업데이트 후 새로 빌드한 모델부터 제공돼.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            )
          else if (selected.detections!.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('이 이미지에서 검출된 후보가 없어.'),
            ),
          _image(selected),
          const SizedBox(height: 8),
          if (_entry case final entry?)
            Text(
              '${entry.width} × ${entry.height} px · 휠 또는 +/−로 확대, 드래그로 이동',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          if (selected.detections case final detections?) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < detections.length; i++)
                  Text(
                    '#${i + 1} ${_part(detections[i].className)} · 검출 점수 ${(detections[i].confidence * 100).toStringAsFixed(1)}%',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _color(selected.status).withValues(alpha: 0.09),
              border: Border.all(
                color: _color(selected.status).withValues(alpha: 0.6),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_part(selected.className)} · ${_status(selected.status)}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _color(selected.status),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _reason(selected.reason),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('점검 항목: ${_check(selected.reason)}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ..._measurements(selected),
          const SizedBox(height: 10),
          Text(
            '판정 코드: ${selected.reason}${selected.latencyMs == null ? '' : ' · ${selected.latencyMs!.toStringAsFixed(1)} ms'}',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ],
    );
  }

  Widget _image(ModelValidationResult result) {
    final entry = _entry;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height:
            (constraints.maxWidth /
                    (entry == null ? 1.6 : entry.width / entry.height))
                .clamp(180.0, 480.0),
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: entry == null ? 16 / 10 : entry.width / entry.height,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '이미지를 불러오지 못했어.\n$_error',
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  )
                : ZoomableViewport(
                    key: ValueKey(
                      '${widget.model.modelId}-$_source-$_className-${entry!.imageId}',
                    ),
                    child: Image.memory(
                      _bytes!,
                      fit: BoxFit.fill,
                      errorBuilder: (_, error, _) => const Center(
                        child: Text(
                          '이미지 파일을 해석할 수 없어.',
                          style: TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) =>
                              Stack(
                                fit: StackFit.expand,
                                children: [
                                  child,
                                  if (frame != null &&
                                      _showDetections &&
                                      result.detections != null)
                                    CustomPaint(
                                      painter: ValidationDetectionsPainter(
                                        detections: result.detections!,
                                        imageWidth: entry.width,
                                        imageHeight: entry.height,
                                      ),
                                    ),
                                ],
                              ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _measurements(ModelValidationResult result) {
    final values = result.measurements['quality_metrics'];
    final limits = result.measurements['quality_limits'];
    final failed = result.measurements['failed_metrics'];
    if (values is! Map || limits is! Map) {
      return result.reason == 'SHAPE_QUALITY_FAILED'
          ? const [
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '이 기록에는 형상 측정값이 저장되지 않았어.',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            ]
          : const [];
    }
    const metrics = {
      'circularity': ('원형도', 'min_circularity', '≥'),
      'axis_ratio': ('축 비율', 'min_axis_ratio', '≥'),
      'relative_eccentricity': ('상대 편심', 'max_relative_eccentricity', '≤'),
      'arc_detection_rate': ('윤곽 검출률', 'min_arc_detection_rate', '≥'),
    };
    return [
      const SizedBox(height: 12),
      const Text('형상 측정값 / 기준', style: TextStyle(fontWeight: FontWeight.bold)),
      for (final metric in metrics.entries)
        if (values[metric.key] is num && limits[metric.value.$2] is num)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${metric.value.$1}: ${(values[metric.key] as num).toStringAsFixed(3)} / ${metric.value.$3} ${(limits[metric.value.$2] as num).toStringAsFixed(3)}${failed is List && failed.contains(metric.key) ? ' · 기준 미달' : ''}',
              style: TextStyle(
                color: failed is List && failed.contains(metric.key)
                    ? Colors.orangeAccent
                    : Colors.white70,
              ),
            ),
          ),
    ];
  }
}

/// Bounding boxes use the same image-pixel coordinates as server inference.
class ValidationDetectionsPainter extends CustomPainter {
  const ValidationDetectionsPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });
  final List<ModelValidationDetection> detections;
  final int imageWidth;
  final int imageHeight;

  Rect rectFor(ModelValidationDetection detection, Size size) => Rect.fromLTWH(
    detection.box[0] * size.width / imageWidth,
    detection.box[1] * size.height / imageHeight,
    detection.box[2] * size.width / imageWidth,
    detection.box[3] * size.height / imageHeight,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var index = 0; index < detections.length; index++) {
      final rect = rectFor(detections[index], size);
      canvas.drawRect(rect, paint);
      final text = TextPainter(
        text: TextSpan(
          text: '#${index + 1}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final origin = Offset(
        rect.left.clamp(0, (size.width - text.width - 8).clamp(0, size.width)),
        rect.top.clamp(
          0,
          (size.height - text.height - 4).clamp(0, size.height),
        ),
      );
      canvas.drawRect(
        origin & Size(text.width + 8, text.height + 4),
        Paint()..color = Colors.cyanAccent,
      );
      text.paint(canvas, origin + const Offset(4, 2));
      text.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ValidationDetectionsPainter oldDelegate) =>
      oldDelegate.detections != detections ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight;
}

bool _isDetected(String status) => status == 'PRESENT' || status == 'OK';
Color _color(String status) => _isDetected(status)
    ? Colors.greenAccent
    : status == 'NG' || status == 'ABSENT'
    ? Colors.orangeAccent
    : Colors.amberAccent;
String _status(String status) => switch (status) {
  'PRESENT' => '검출',
  'ABSENT' => '미검출',
  'OK' => 'OK',
  'NG' => 'NG',
  'RECHECK' => '재확인',
  'EQUIPMENT_ERROR' => '장비 오류',
  _ => status,
};
String _part(String name) => switch (name) {
  'bolt_head' => '볼트 헤드',
  'stud' => '스터드',
  'nut_hole' => '너트 홀',
  'plain_hole' => '일반 홀',
  'nut' => '너트',
  _ => name,
};
String _reason(String reason) => switch (reason) {
  'TARGET_CONFIRMED' => '검사 대상을 찾았어.',
  'NO_CANDIDATE' => '검사 대상을 찾지 못했어.',
  'SHAPE_QUALITY_FAILED' => '측정한 형상이 설정 기준에 미달해.',
  'PLAIN_HOLE_DETECTED' => '일반 홀이 검출됐어.',
  'SHAPE_QUALITY_OK' => '측정한 형상이 설정 기준을 충족해.',
  'NUT_HOLE_ABSENT' => '너트 홀을 확인하지 못했어.',
  'GEOMETRY_NOT_FOUND' => '홀의 윤곽을 측정하지 못했어.',
  'QUALITY_LIMITS_NOT_CONFIGURED' => '형상 판정 기준이 설정되지 않았어.',
  'LOW_CONFIDENCE_CANDIDATE' => '후보가 있지만 검출 확정 조건을 충족하지 못했어.',
  _ => reason,
};
String _check(String reason) => switch (reason) {
  'TARGET_CONFIRMED' => '검출 박스가 실제 부품 위치와 일치하는지 확인',
  'NO_CANDIDATE' => '부품 유무·위치·가림을 먼저 확인하고 조명과 초점 점검',
  'SHAPE_QUALITY_FAILED' => '아래 측정값과 기준을 비교하고 홀의 형상·이물·초점 점검',
  'PLAIN_HOLE_DETECTED' => '해당 위치에 너트 홀이 필요한지, 올바른 샘플인지 확인',
  'SHAPE_QUALITY_OK' => '측정한 부위가 실제 검사할 홀과 일치하는지 확인',
  'NUT_HOLE_ABSENT' => '너트 홀 유무·위치·가림 확인',
  'GEOMETRY_NOT_FOUND' => '홀 경계의 초점·조명·반사·이물 확인',
  'QUALITY_LIMITS_NOT_CONFIGURED' => '장비의 형상 판정 기준 설정 필요',
  'LOW_CONFIDENCE_CANDIDATE' => '검출 후보 위치·점수와 필요한 부품 개수 확인',
  _ => '원본 이미지와 판정 코드를 확인',
};
