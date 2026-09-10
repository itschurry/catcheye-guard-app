import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../widgets/status_label.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/remote_capture_api_service.dart';
import '../widgets/station_inspection_image.dart';

List<StationCaptureResult> mergeStationResultArchive(
  Iterable<StationCaptureResult> retained,
  Iterable<StationCaptureResult> fetched,
) {
  final byCycleId = <String, StationCaptureResult>{
    for (final result in retained)
      if (result.state.isFinal) result.cycleId: result,
  };
  for (final result in fetched) {
    byCycleId[result.cycleId] = result;
  }
  return byCycleId.values.toList(growable: false)..sort(
    (left, right) =>
        (right.requestedAtMs ?? 0).compareTo(left.requestedAtMs ?? 0),
  );
}

class InspectionResultsScreen extends StatefulWidget {
  const InspectionResultsScreen({super.key, this.api});

  final RemoteCaptureApiService? api;

  @override
  State<InspectionResultsScreen> createState() =>
      _InspectionResultsScreenState();
}

class _InspectionResultsScreenState extends State<InspectionResultsScreen> {
  late final RemoteCaptureApiService _api;
  String? _endpoint;
  int _requestGeneration = 0;
  int _imageRefresh = 0;
  String? _selectedInspectionId;
  final List<StationCaptureResult> _results = [];
  Timer? _pollTimer;
  String? _selectedCycleId;
  String? _error;
  DateTime? _lastUpdatedAt;
  bool _loading = true;
  bool _pollInFlight = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? RemoteCaptureApiService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh());
      _pollTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_refresh()),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final endpoint = context
        .watch<SettingsProvider>()
        .settings
        .buildApiUri('capture/results')
        .toString();
    if (_endpoint != null && _endpoint != endpoint) {
      _requestGeneration++;
      _pollInFlight = false;
      _results.clear();
      _selectedCycleId = null;
      _selectedInspectionId = null;
      _lastUpdatedAt = null;
      _error = null;
      _loading = true;
      unawaited(_refresh());
    }
    _endpoint = endpoint;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_pollInFlight || !mounted) return;
    _pollInFlight = true;
    final generation = _requestGeneration;
    final settings = context.read<SettingsProvider>().settings;
    List<StationCaptureResult>? nextResults;
    String? nextError;
    try {
      nextResults = (await _api.fetchStationResults(settings)).results;
    } catch (error) {
      nextError = '검사 결과 조회 실패: $error';
    } finally {
      if (generation == _requestGeneration) _pollInFlight = false;
    }
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      if (nextResults != null) {
        final merged = mergeStationResultArchive(_results, nextResults);
        _results
          ..clear()
          ..addAll(merged);
        if (!_results.any((result) => result.cycleId == _selectedCycleId)) {
          _selectedCycleId = _results.isEmpty ? null : _results.first.cycleId;
        }
        _lastUpdatedAt = DateTime.now();
      }
      _error = nextError;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _results.cast<StationCaptureResult?>().firstWhere(
      (result) => result?.cycleId == _selectedCycleId,
      orElse: () => null,
    );
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.deepOrange.withValues(alpha: 0.12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        Expanded(
          child: _loading && _results.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
              ? const _EmptyResults()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        children: [
                          SizedBox(height: 230, child: _buildResultList()),
                          const Divider(height: 1),
                          Expanded(child: _buildResultDetails(selected)),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 340, child: _buildResultList()),
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildResultDetails(selected)),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '검사 결과 · ${_results.length}건',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_lastUpdatedAt != null)
                  Text(
                    '마지막 조회 ${_formatClock(_lastUpdatedAt!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _pollInFlight
                ? null
                : () {
                    setState(() => _imageRefresh++);
                    unawaited(_refresh());
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = _results[index];
        final selected = result.cycleId == _selectedCycleId;
        return Material(
          color: selected
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12)
              : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              _selectedCycleId = result.cycleId;
              _selectedInspectionId = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.secondary
                      : const Color(0xFF484848),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatTimestamp(result.requestedAtMs),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(result.presentationStatus),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    [
                      _groupLabel(result.group),
                      ...result.inspections.values
                          .where((item) => _needsCheck(item.status))
                          .map(
                            (item) =>
                                '${_partLabel(item.inspectionId)} ${_statusLabel(item.status)}',
                          ),
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultDetails(StationCaptureResult? result) {
    if (result == null) return const Center(child: Text('검사 이력을 선택해.'));
    final inspections = result.inspections.values.toList(growable: false);
    final selected =
        inspections
            .where((item) => item.inspectionId == _selectedInspectionId)
            .firstOrNull ??
        inspections.where((item) => _needsCheck(item.status)).firstOrNull ??
        inspections.firstOrNull;
    final problems = inspections
        .where((item) => _needsCheck(item.status))
        .toList(growable: false);
    return SingleChildScrollView(
      key: ValueKey('capture-details-${result.cycleId}'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatTimestamp(result.requestedAtMs),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(result.presentationStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_groupLabel(result.group)} · ${problems.isEmpty
                ? result.state.isFinal
                      ? '부위별 판정 확인'
                      : '검사 진행 중'
                : problems.map((item) => '${_partLabel(item.inspectionId)} ${_statusLabel(item.status)}').join(' / ')}',
            style: TextStyle(
              color: problems.isEmpty ? Colors.white70 : Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (result.error.isNotEmpty || result.artifactError.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              [
                result.error,
                result.artifactError,
              ].where((text) => text.isNotEmpty).join('\n'),
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ],
          const SizedBox(height: 14),
          if (selected == null)
            Text(result.state.isFinal ? '검사 상세 기록이 없어.' : '검사 결과를 기다리는 중이야.')
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final inspection in inspections)
                  ChoiceChip(
                    label: Text(
                      '${_partLabel(inspection.inspectionId)} · ${_statusLabel(inspection.status)}',
                    ),
                    selected: inspection.inspectionId == selected.inspectionId,
                    avatar: Icon(
                      _needsCheck(inspection.status)
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: _needsCheck(inspection.status)
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
                    ),
                    onSelected: (_) => setState(
                      () => _selectedInspectionId = inspection.inspectionId,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            StationInspectionImage(
              key: ValueKey(
                '${result.cycleId}-${selected.inspectionId}-$_imageRefresh',
              ),
              result: result,
              inspection: selected,
              api: _api,
            ),
            const SizedBox(height: 14),
            _buildInspectionDetails(selected),
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('검사 기록 상세'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText('검사 ID: ${result.cycleId}'),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _detailValue('검사 구성', result.setId),
                  _detailValue('시작', _formatTimestamp(result.startedAtMs)),
                  _detailValue('완료', _formatTimestamp(result.finishedAtMs)),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showRawResult(result),
                icon: const Icon(Icons.data_object),
                label: const Text('원본 JSON'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionDetails(StationInspectionResult inspection) {
    final metrics = inspection.measurements['quality_metrics'];
    final limits = inspection.measurements['quality_limits'];
    const names = {
      'circularity': ('원형도', 'min_circularity', '≥'),
      'axis_ratio': ('축 비율', 'min_axis_ratio', '≥'),
      'relative_eccentricity': ('상대 편심', 'max_relative_eccentricity', '≤'),
      'arc_detection_rate': ('윤곽 검출률', 'min_arc_detection_rate', '≥'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_partLabel(inspection.inspectionId)} · ${_reasonLabel(inspection.reason)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('점검 항목: ${_checkLabel(inspection.reason)}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _detailValue('카메라', inspection.cameraId),
              _detailValue('검출 후보', '${inspection.detections.length}개'),
              if (inspection.latencyMs != null)
                _detailValue(
                  '검사 시간',
                  '${inspection.latencyMs!.toStringAsFixed(1)} ms',
                ),
            ],
          ),
          if (metrics is Map && limits is Map) ...[
            const SizedBox(height: 12),
            const Text(
              '형상 측정값 / 기준',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final item in names.entries)
              if (metrics[item.key] is num && limits[item.value.$2] is num)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${item.value.$1}: ${(metrics[item.key] as num).toStringAsFixed(3)} / ${item.value.$3} ${(limits[item.value.$2] as num).toStringAsFixed(3)}${inspection.failedMetrics.contains(item.key) ? ' · 기준 미달' : ''}',
                    style: TextStyle(
                      color: inspection.failedMetrics.contains(item.key)
                          ? Colors.orangeAccent
                          : Colors.white70,
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          Text(
            '판정 코드: ${inspection.reason}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (inspection.artifactError.isNotEmpty)
            Text(
              '이미지 저장 오류: ${inspection.artifactError}',
              style: const TextStyle(color: Colors.orangeAccent),
            ),
        ],
      ),
    );
  }

  Widget _detailValue(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: Colors.white54),
          ),
          TextSpan(text: value.isEmpty ? '-' : value),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'OK' || 'PRESENT' || 'COMPLETED' => Colors.greenAccent,
      'NG' || 'ABSENT' => Colors.redAccent,
      'RECHECK' => Colors.orangeAccent,
      'EQUIPMENT_ERROR' => Colors.deepOrangeAccent,
      'CANCELLED' || 'EXPIRED' => Colors.grey,
      _ => Colors.lightBlueAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color),
      ),
      child: Text(
        statusLabel(status.isEmpty ? 'UNKNOWN' : status),
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  void _showRawResult(StationCaptureResult result) {
    final json = result.rawJson.isEmpty
        ? {'cycle_id': result.cycleId, 'state': result.state.name}
        : result.rawJson;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('촬영 결과 JSON'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(json),
              style: const TextStyle(fontFamily: 'NotoSansKR', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int? milliseconds) {
    if (milliseconds == null) return '-';
    return _formatDateTime(
      DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal(),
    );
  }

  String _formatDateTime(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _formatClock(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 52, color: Colors.white38),
          SizedBox(height: 12),
          Text('아직 검사 결과가 없어'),
          SizedBox(height: 5),
          Text('뷰어에서 촬영하면 결과가 표시돼.', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

bool _needsCheck(String status) => status != 'PRESENT' && status != 'OK';
String _statusLabel(String status) => statusLabel(status);
String _partLabel(String id) => switch (id) {
  'bolt_head' => 'Bolt Head',
  'stud' => 'Stud',
  'nut_hole' => 'Nut Hole',
  'plain_hole' => 'Plain Hole',
  'nut' => 'Nut',
  _ => id,
};
String _groupLabel(String group) => switch (group) {
  'bolt_stud' => 'Bolt Head · Stud 검사',
  'nut' => 'Nut 검사',
  '' || 'all' => '전체 검사',
  _ => group,
};
String _reasonLabel(String reason) => switch (reason) {
  'TARGET_CONFIRMED' => '대상 검출',
  'NO_CANDIDATE' => '대상 미검출',
  'SHAPE_QUALITY_FAILED' => '형상 기준 미달',
  'SHAPE_QUALITY_OK' => '형상 기준 충족',
  'PLAIN_HOLE_DETECTED' => 'Plain Hole 검출',
  'NUT_HOLE_ABSENT' => 'Nut Hole 미확인',
  'GEOMETRY_NOT_FOUND' => '홀 윤곽 측정 실패',
  'QUALITY_LIMITS_NOT_CONFIGURED' => '형상 판정 기준 미설정',
  'LOW_CONFIDENCE_CANDIDATE' => '검출 확정 조건 미충족',
  _ => reason,
};
String _checkLabel(String reason) => switch (reason) {
  'TARGET_CONFIRMED' || 'SHAPE_QUALITY_OK' => '검출 위치가 실제 검사할 부품과 일치하는지 확인',
  'NO_CANDIDATE' || 'NUT_HOLE_ABSENT' => '부품 유무·위치·가림을 먼저 확인하고 조명과 초점 점검',
  'SHAPE_QUALITY_FAILED' => '측정값과 기준을 비교하고 홀 형상·이물·초점 점검',
  'GEOMETRY_NOT_FOUND' => '홀 경계의 초점·조명·반사·이물 확인',
  'PLAIN_HOLE_DETECTED' => '해당 위치의 Nut Hole·부품 장착 상태 확인',
  'QUALITY_LIMITS_NOT_CONFIGURED' => '장비의 형상 판정 기준 설정 필요',
  'LOW_CONFIDENCE_CANDIDATE' => '후보 위치·검출 점수와 필요한 부품 개수 확인',
  _ => '검사 이미지와 판정 코드를 확인',
};
