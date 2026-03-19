import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// Log file real-time viewer screen

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final List<String> _logLines = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _pathController = TextEditingController();
  String? _watchingPath;
  Timer? _pollTimer;
  int _lastFileLength = 0;
  bool _autoScroll = true;
  String? _errorMessage;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Log Viewer',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // File path input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: 'Log file or directory path',
                    hintText: 'log/',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorText: _errorMessage,
                  ),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: Icon(_watchingPath != null ? Icons.stop : Icons.play_arrow),
                label: Text(_watchingPath != null ? 'Stop' : 'Start Watch'),
                onPressed: _watchingPath != null ? _stopWatching : _startWatching,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Control bar
          Row(
            children: [
              if (_watchingPath != null)
                Chip(
                  avatar: const Icon(Icons.visibility, size: 14),
                  label: Text(
                    'Watching: $_watchingPath',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  const Text('Auto Scroll', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 18),
                tooltip: 'Clear Logs',
                onPressed: () => setState(() {
                  _logLines.clear();
                  _lastFileLength = 0;
                }),
              ),
              Text(
                '${_logLines.length} lines',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const Divider(),

          // Log content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: _logLines.isEmpty
                  ? const Center(
                      child: Text(
                        'Enter a file path and start watching to display logs.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _logLines.length,
                      itemBuilder: (context, index) {
                        final line = _logLines[index];
                        return Text(
                          line,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _logLineColor(line),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _logLineColor(String line) {
    if (line.contains('[error]') || line.contains('[ERROR]')) {
      return Colors.red.shade300;
    }
    if (line.contains('[warn]') || line.contains('[WARN]')) {
      return Colors.orange.shade300;
    }
    if (line.contains('[info]') || line.contains('[INFO]')) {
      return Colors.green.shade300;
    }
    if (line.contains('[debug]') || line.contains('[DEBUG]')) {
      return Colors.blue.shade300;
    }
    return Colors.grey.shade300;
  }

  Future<void> _startWatching() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _errorMessage = 'Enter a path');
      return;
    }

    // If directory, find the latest file
    String filePath = path;
    if (await Directory(path).exists()) {
      final dir = Directory(path);
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();
      if (files.isEmpty) {
        setState(() => _errorMessage = 'No .log files in directory');
        return;
      }
      files.sort((a, b) => b.path.compareTo(a.path));
      filePath = files.first.path;
    }

    if (!await File(filePath).exists()) {
      setState(() => _errorMessage = 'File not found: $filePath');
      return;
    }

    setState(() {
      _watchingPath = filePath;
      _errorMessage = null;
      _logLines.clear();
      _lastFileLength = 0;
    });

    // Initial load
    await _readNewContent();

    // Poll every 1 second
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _readNewContent();
    });
  }

  void _stopWatching() {
    _pollTimer?.cancel();
    _pollTimer = null;
    setState(() => _watchingPath = null);
  }

  Future<void> _readNewContent() async {
    if (_watchingPath == null) return;

    try {
      final file = File(_watchingPath!);
      final length = await file.length();
      if (length <= _lastFileLength) return;

      final raf = await file.open(mode: FileMode.read);
      await raf.setPosition(_lastFileLength);
      final bytes = await raf.read(length - _lastFileLength);
      await raf.close();

      final newText = String.fromCharCodes(bytes);
      final newLines = newText.split('\n').where((l) => l.isNotEmpty).toList();

      if (newLines.isNotEmpty) {
        setState(() {
          _logLines.addAll(newLines);
          _lastFileLength = length;
          // Max 10000 lines
          if (_logLines.length > 10000) {
            _logLines.removeRange(0, _logLines.length - 10000);
          }
        });

        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (_) {
      // Ignore file read failures (e.g., file is still being written)
    }
  }
}
