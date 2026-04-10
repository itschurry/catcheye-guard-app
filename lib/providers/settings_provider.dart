import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// App settings state management Provider

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

  void updateDetectorBaseUrl(String value) {
    _settings.detectorBaseUrl = value;
    notifyListeners();
  }

  void updateStreamPath(String value) {
    _settings.streamPath = value;
    notifyListeners();
  }

  void updateApiBasePath(String value) {
    _settings.apiBasePath = value;
    notifyListeners();
  }

  void updateCameraPipeline(String value) {
    _settings.cameraPipeline = value;
    notifyListeners();
  }

  void updateModelParamPath(String path) {
    _settings.modelParamPath = path;
    notifyListeners();
  }

  void updateModelBinPath(String path) {
    _settings.modelBinPath = path;
    notifyListeners();
  }

  void updateMetadataPath(String path) {
    _settings.metadataPath = path;
    notifyListeners();
  }

  void updateRoiConfigPath(String path) {
    _settings.roiConfigPath = path;
    notifyListeners();
  }

  void updateRoiEnabled(bool enabled) {
    _settings.roiEnabled = enabled;
    notifyListeners();
  }

  void updateRoiAutoReload(bool enabled) {
    _settings.roiAutoReload = enabled;
    notifyListeners();
  }

  void updateRenderPreview(bool enabled) {
    _settings.renderPreview = enabled;
    notifyListeners();
  }

  void updateFilterByClass(bool enabled) {
    _settings.filterByClass = enabled;
    notifyListeners();
  }

  void updateFilterClassId(int classId) {
    _settings.filterClassId = classId;
    notifyListeners();
  }

  void replaceSettings(AppSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  void applyRemoteSettings(AppSettings remoteSettings) {
    _settings = _settings.copyWith(
      cameraPipeline: remoteSettings.cameraPipeline,
      modelParamPath: remoteSettings.modelParamPath,
      modelBinPath: remoteSettings.modelBinPath,
      metadataPath: remoteSettings.metadataPath,
      roiConfigPath: remoteSettings.roiConfigPath,
      roiEnabled: remoteSettings.roiEnabled,
      roiAutoReload: remoteSettings.roiAutoReload,
      renderPreview: remoteSettings.renderPreview,
      filterByClass: remoteSettings.filterByClass,
      filterClassId: remoteSettings.filterClassId,
    );
    notifyListeners();
  }
}
