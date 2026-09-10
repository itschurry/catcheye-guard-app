import 'package:flutter/material.dart';
import '../services/remote_capture_image_api_service.dart';

class CaptureStorageSummary extends StatelessWidget {
  const CaptureStorageSummary({
    super.key,
    required this.storage,
    this.summary,
    this.compact = false,
  });
  final CaptureStorageInfo storage;
  final String? summary;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final usedRatio = (storage.usedPercent / 100.0).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: Container(
        padding: EdgeInsets.all(compact ? 8 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFF303030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A4A4A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact)
              const Text(
                '저장 공간',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            if (!compact) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '여유 ${formatStorageBytes(storage.availableBytes)} / 전체 ${formatStorageBytes(storage.totalBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${storage.usedPercent.round()}% 사용 중',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: usedRatio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Text(
              summary ??
                  '이미지 ${formatStorageBytes(storage.captureBytes)} · ${storage.captureCount}개',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

String formatStorageBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
