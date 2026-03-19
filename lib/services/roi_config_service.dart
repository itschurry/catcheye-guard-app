import 'dart:convert';
import 'dart:io';

import '../models/roi_config.dart';

/// ROI JSON file load/save service

class RoiConfigService {
  /// Load ROI config from JSON file
  static Future<CameraRoiConfig> loadFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('ROI config file not found', path);
    }
    final content = await file.readAsString();
    return fromJsonString(content);
  }

  /// Parse from JSON string
  static CameraRoiConfig fromJsonString(String jsonText) {
    final Map<String, dynamic> json = jsonDecode(jsonText);
    return CameraRoiConfig.fromJson(json);
  }

  /// Save to file
  static Future<void> saveToFile(CameraRoiConfig config, String path) async {
    final jsonStr = toJsonString(config);
    final file = File(path);
    await file.writeAsString(jsonStr);
  }

  /// Serialize to JSON string
  static String toJsonString(CameraRoiConfig config) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config.toJson());
  }

  /// ROI config validation
  static List<String> validate(CameraRoiConfig config) {
    final issues = <String>[];

    if (config.imageWidth <= 0) {
      issues.add('Invalid image width: ${config.imageWidth}');
    }
    if (config.imageHeight <= 0) {
      issues.add('Invalid image height: ${config.imageHeight}');
    }

    for (var i = 0; i < config.allowedZones.length; i++) {
      final zone = config.allowedZones[i];
      if (zone.points.length < 3) {
        issues.add('Zone "${ zone.name}" (index $i): At least 3 points required');
      }
      for (var j = 0; j < zone.points.length; j++) {
        final p = zone.points[j];
        if (p.x < 0 || p.x > config.imageWidth || p.y < 0 || p.y > config.imageHeight) {
          issues.add('Zone "${zone.name}" point $j: Out of image bounds (${p.x}, ${p.y})');
        }
      }
    }

    return issues;
  }
}
