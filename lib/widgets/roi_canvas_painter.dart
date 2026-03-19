import 'package:flutter/material.dart';

import '../models/roi_config.dart';

/// CustomPainter that visualizes ROI polygons on an image

class RoiCanvasPainter extends CustomPainter {
  final CameraRoiConfig config;
  final int selectedZoneIndex;
  final int? hoveredPointZone;
  final int? hoveredPointIndex;
  final Size canvasSize;

  RoiCanvasPainter({
    required this.config,
    required this.selectedZoneIndex,
    this.hoveredPointZone,
    this.hoveredPointIndex,
    required this.canvasSize,
  });

  double get scaleX =>
      config.imageWidth > 0 ? canvasSize.width / config.imageWidth : 1.0;
  double get scaleY =>
      config.imageHeight > 0 ? canvasSize.height / config.imageHeight : 1.0;

  Offset toCanvas(RoiPoint p) => Offset(p.x * scaleX, p.y * scaleY);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    for (var i = 0; i < config.allowedZones.length; i++) {
      final zone = config.allowedZones[i];
      final isSelected = i == selectedZoneIndex;
      _drawZone(canvas, zone, isSelected, i);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const gridSpacing = 50.0;
    for (double x = 0; x < size.width; x += gridSpacing * scaleX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSpacing * scaleY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawZone(Canvas canvas, RoiPolygon zone, bool isSelected, int zoneIndex) {
    if (zone.points.length < 2) return;

    final points = zone.points.map(toCanvas).toList();

    // Semi-transparent fill
    final fillColor = zone.enabled
        ? (isSelected
            ? Colors.cyan.withValues(alpha: 0.25)
            : Colors.amber.withValues(alpha: 0.15))
        : Colors.grey.withValues(alpha: 0.1);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    canvas.drawPath(path, fillPaint);

    // Outline
    final strokeColor = zone.enabled
        ? (isSelected ? Colors.cyanAccent : Colors.amber)
        : Colors.grey;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.5;

    canvas.drawPath(path, strokePaint);

    // Point handles
    for (var j = 0; j < points.length; j++) {
      final isHovered = hoveredPointZone == zoneIndex && hoveredPointIndex == j;
      final handleRadius = isHovered ? 7.0 : 5.0;

      final handlePaint = Paint()
        ..color = isHovered ? Colors.white : strokeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(points[j], handleRadius, handlePaint);

      final borderPaint = Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(points[j], handleRadius, borderPaint);
    }

    // Zone name label
    if (zone.name.isNotEmpty && points.isNotEmpty) {
      final centroid = _centroid(points);
      final textPainter = TextPainter(
        text: TextSpan(
          text: zone.name,
          style: TextStyle(
            color: strokeColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        centroid - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  Offset _centroid(List<Offset> points) {
    double cx = 0, cy = 0;
    for (final p in points) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / points.length, cy / points.length);
  }

  @override
  bool shouldRepaint(covariant RoiCanvasPainter oldDelegate) => true;
}
