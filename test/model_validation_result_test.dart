import 'package:flutter_test/flutter_test.dart';

import 'package:catcheye_studio/services/remote_reference_api_service.dart';

void main() {
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
}
