import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// App settings state management Provider

class SettingsProvider extends ChangeNotifier {
  final AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

  void updateGuardPath(String path) {
    _settings.guardExecutablePath = path;
    notifyListeners();
  }

  void updateCameraPipeline(String pipeline) {
    _settings.cameraPipeline = pipeline;
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
}
