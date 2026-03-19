import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/roi_config_provider.dart';
import '../providers/settings_provider.dart';

/// Settings screen

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, RoiConfigProvider>(
      builder: (context, settingsProvider, roiProvider, _) {
        final settings = settingsProvider.settings;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Executable path
              _SectionCard(
                title: 'Executable',
                icon: Icons.terminal,
                children: [
                  _PathField(
                    label: 'catcheye-guard executable path',
                    value: settings.guardExecutablePath,
                    onChanged: settingsProvider.updateGuardPath,
                    onBrowse: () => _browseFile(
                      context,
                      'Select Executable',
                      settingsProvider.updateGuardPath,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Camera settings
              _SectionCard(
                title: 'Camera',
                icon: Icons.videocam,
                children: [
                  _TextField(
                    label: 'GStreamer Pipeline',
                    value: settings.cameraPipeline,
                    onChanged: settingsProvider.updateCameraPipeline,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Detector settings
              _SectionCard(
                title: 'Detector (YOLO26n + NCNN)',
                icon: Icons.model_training,
                children: [
                  _PathField(
                    label: 'Model Parameter File (.param)',
                    value: settings.modelParamPath,
                    onChanged: settingsProvider.updateModelParamPath,
                    onBrowse: () => _browseFile(
                      context,
                      'Select Parameter File',
                      settingsProvider.updateModelParamPath,
                      extensions: ['param'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PathField(
                    label: 'Model Binary File (.bin)',
                    value: settings.modelBinPath,
                    onChanged: settingsProvider.updateModelBinPath,
                    onBrowse: () => _browseFile(
                      context,
                      'Select Binary File',
                      settingsProvider.updateModelBinPath,
                      extensions: ['bin'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PathField(
                    label: 'Metadata File (.yaml)',
                    value: settings.metadataPath,
                    onChanged: settingsProvider.updateMetadataPath,
                    onBrowse: () => _browseFile(
                      context,
                      'Select Metadata File',
                      settingsProvider.updateMetadataPath,
                      extensions: ['yaml', 'yml'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ROI settings
              _SectionCard(
                title: 'ROI Settings',
                icon: Icons.crop_free,
                children: [
                  _PathField(
                    label: 'ROI Config File (.json)',
                    value: settings.roiConfigPath,
                    onChanged: (path) {
                      settingsProvider.updateRoiConfigPath(path);
                    },
                    onBrowse: () => _browseFile(
                      context,
                      'Select ROI Config File',
                      (path) {
                        settingsProvider.updateRoiConfigPath(path);
                        roiProvider.loadFromFile(path);
                      },
                      extensions: ['json'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable ROI'),
                    subtitle: const Text('Apply ROI intrusion detection to results'),
                    value: settings.roiEnabled,
                    onChanged: (v) => settingsProvider.updateRoiEnabled(v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ROI config summary
              _SectionCard(
                title: 'ROI Config Preview',
                icon: Icons.preview,
                children: [
                  _InfoRow('Camera ID', roiProvider.config.cameraId),
                  _InfoRow('Image Size',
                      '${roiProvider.config.imageWidth} × ${roiProvider.config.imageHeight}'),
                  _InfoRow('Zone Count', '${roiProvider.config.allowedZones.length}'),
                  _InfoRow('Active Zones',
                      '${roiProvider.config.allowedZones.where((z) => z.enabled).length}'),
                  if (roiProvider.filePath != null)
                    _InfoRow('Loaded File', roiProvider.filePath!),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _browseFile(
    BuildContext context,
    String title,
    ValueChanged<String> onSelected, {
    List<String>? extensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: title,
      type: extensions != null ? FileType.custom : FileType.any,
      allowedExtensions: extensions,
    );
    if (result != null && result.files.single.path != null) {
      onSelected(result.files.single.path!);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PathField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onBrowse;

  const _PathField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: value,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: 'Browse',
          onPressed: onBrowse,
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  const _TextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
