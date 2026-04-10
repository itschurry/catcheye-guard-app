import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/roi_config_provider.dart';
import '../providers/settings_provider.dart';
import '../services/remote_guard_api_service.dart';
import '../widgets/roi_editor_canvas.dart';
import '../widgets/zone_list_panel.dart';

/// ROI Editor screen

class RoiEditorScreen extends StatelessWidget {
  const RoiEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoiConfigProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Toolbar
            _buildToolbar(context, provider),
            const Divider(height: 1),

            // Main area
            Expanded(
              child: Row(
                children: [
                  // Canvas
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Config info bar
                        _buildConfigInfoBar(provider),
                        // ROI canvas
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: RoiEditorCanvas(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Zone list panel
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: const ZoneListPanel(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, RoiConfigProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.edit_location_alt, size: 20),
          const SizedBox(width: 8),
          const Text(
            'ROI Editor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),

          // File path
          if (provider.filePath != null)
            Expanded(
              child: Text(
                provider.filePath!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Expanded(
              child: Text(
                'No file',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),

          if (provider.isDirty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade800,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Modified',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),

          // Action buttons
          IconButton(
            icon: const Icon(Icons.note_add_outlined, size: 20),
            tooltip: 'New Config',
            onPressed: provider.newConfig,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            tooltip: 'Open File',
            onPressed: () => _openFile(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined, size: 20),
            tooltip: 'Load ROI From Device',
            onPressed: () => _loadFromDevice(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.save, size: 20),
            tooltip: 'Save',
            onPressed: provider.isDirty
                ? () => _saveFile(context, provider)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.save_as, size: 20),
            tooltip: 'Save As',
            onPressed: () => _saveAsFile(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            tooltip: 'Push ROI To Device',
            onPressed: () => _pushToDevice(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigInfoBar(RoiConfigProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.black26,
      child: Row(
        children: [
          _InfoChip(
            label: 'Camera',
            value: provider.config.cameraId.isEmpty
                ? 'N/A'
                : provider.config.cameraId,
          ),
          const SizedBox(width: 16),
          _InfoChip(
            label: 'Resolution',
            value:
                '${provider.config.imageWidth} × ${provider.config.imageHeight}',
          ),
          const SizedBox(width: 16),
          _InfoChip(
            label: 'Zones',
            value: '${provider.config.allowedZones.length}',
          ),
          const Spacer(),
          if (provider.errorMessage != null)
            Row(
              children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  provider.errorMessage!,
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context, RoiConfigProvider provider) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Open ROI Config File',
    );
    if (result != null && result.files.single.path != null) {
      await provider.loadFromFile(result.files.single.path!);
    }
  }

  Future<void> _saveFile(BuildContext context, RoiConfigProvider provider) async {
    if (provider.filePath != null) {
      await provider.saveToFile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
        );
      }
    } else {
      await _saveAsFile(context, provider);
    }
  }

  Future<void> _saveAsFile(BuildContext context, RoiConfigProvider provider) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ROI Config File',
      fileName: 'roi_config.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      await provider.saveToFile(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: $result'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _loadFromDevice(
    BuildContext context,
    RoiConfigProvider provider,
  ) async {
    final settings = context.read<SettingsProvider>().settings;
    final api = RemoteGuardApiService();

    try {
      final config = await api.fetchRoi(settings);
      provider.loadFromConfig(
        config,
        sourceLabel: settings.buildApiUri('roi').toString(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ROI loaded from device')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ROI: $e')),
        );
      }
    }
  }

  Future<void> _pushToDevice(
    BuildContext context,
    RoiConfigProvider provider,
  ) async {
    final settings = context.read<SettingsProvider>().settings;
    final api = RemoteGuardApiService();

    try {
      await api.pushRoi(settings, provider.config);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ROI pushed to device')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to push ROI: $e')),
        );
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
