import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Displays a live JPEG frame stream with minimal overhead.

class LiveViewer extends StatelessWidget {
  final Uint8List? frameData;
  final BoxFit fit;

  const LiveViewer({
    super.key,
    required this.frameData,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (frameData == null || frameData!.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No frame',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Image.memory(
          frameData!,
          fit: fit,
          gaplessPlayback: true, // Prevents flicker between frames
          filterQuality: FilterQuality.low, // Fastest rendering
        ),
      ),
    );
  }
}
