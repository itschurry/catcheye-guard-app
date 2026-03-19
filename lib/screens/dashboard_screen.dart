import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/roi_config_provider.dart';
import '../providers/settings_provider.dart';
import '../services/process_manager_service.dart';

/// Dashboard screen — system status summary, process management, ROI summary

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProcessManagerService, RoiConfigProvider>(
      builder: (context, processManager, roiProvider, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text(
                    'CatchEye Guard',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Status card grid
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatusCard(
                    icon: Icons.play_circle_outline,
                    title: 'Process Status',
                    value: _statusText(processManager.status),
                    color: _statusColor(processManager.status),
                  ),
                  _StatusCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'Camera ID',
                    value: roiProvider.config.cameraId.isEmpty
                        ? 'Not set'
                        : roiProvider.config.cameraId,
                    color: Colors.blue,
                  ),
                  _StatusCard(
                    icon: Icons.aspect_ratio,
                    title: 'Image Size',
                    value:
                        '${roiProvider.config.imageWidth} × ${roiProvider.config.imageHeight}',
                    color: Colors.teal,
                  ),
                  _StatusCard(
                    icon: Icons.layers_outlined,
                    title: 'Allowed Zones',
                    value: '${roiProvider.config.allowedZones.length}',
                    color: Colors.amber,
                  ),
                  _StatusCard(
                    icon: Icons.check_circle_outline,
                    title: 'Active Zones',
                    value:
                        '${roiProvider.config.allowedZones.where((z) => z.enabled).length}',
                    color: Colors.green,
                  ),
                  _StatusCard(
                    icon: Icons.description_outlined,
                    title: 'ROI File',
                    value: roiProvider.filePath != null
                        ? roiProvider.filePath!.split('/').last
                        : 'None',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Process Control
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Process Control',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                            onPressed: processManager.isRunning
                                ? null
                                : () => _startProcess(context),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                            onPressed: processManager.isRunning
                                ? () => processManager.stop()
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Validation results
              if (roiProvider.validationIssues.isNotEmpty)
                Card(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'ROI Validation Issues (${roiProvider.validationIssues.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...roiProvider.validationIssues.map(
                          (issue) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $issue',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Recent Logs
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Recent Logs',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, size: 18),
                              tooltip: 'Clear Logs',
                              onPressed: processManager.clearLogs,
                            ),
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: processManager.logs.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No logs',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  itemCount: processManager.logs.length,
                                  itemBuilder: (context, index) {
                                    final logIndex =
                                        processManager.logs.length - 1 - index;
                                    return Text(
                                      processManager.logs[logIndex],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: processManager.logs[logIndex]
                                                .contains('[ERR]')
                                            ? Colors.red.shade300
                                            : processManager.logs[logIndex]
                                                    .contains('[WARN]')
                                                ? Colors.orange.shade300
                                                : Colors.grey.shade300,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startProcess(BuildContext context) {
    final settings = context.read<SettingsProvider>().settings;
    final processManager = context.read<ProcessManagerService>();

    if (settings.guardExecutablePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set the executable path in Settings before starting.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final args = settings.buildCommandArgs();
    // Add --stream flag so Flutter viewer can receive frames
    args.add('--stream');
    processManager.start(settings.guardExecutablePath, args);
  }

  String _statusText(GuardProcessStatus status) {
    switch (status) {
      case GuardProcessStatus.stopped:
        return 'Stopped';
      case GuardProcessStatus.starting:
        return 'Starting...';
      case GuardProcessStatus.running:
        return 'Running';
      case GuardProcessStatus.stopping:
        return 'Stopping...';
      case GuardProcessStatus.error:
        return 'Error';
    }
  }

  Color _statusColor(GuardProcessStatus status) {
    switch (status) {
      case GuardProcessStatus.stopped:
        return Colors.grey;
      case GuardProcessStatus.starting:
        return Colors.orange;
      case GuardProcessStatus.running:
        return Colors.green;
      case GuardProcessStatus.stopping:
        return Colors.orange;
      case GuardProcessStatus.error:
        return Colors.red;
    }
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
