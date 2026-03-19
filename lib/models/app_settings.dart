// catcheye-guard app settings model

class AppSettings {
  String guardExecutablePath;
  String cameraPipeline;
  String modelParamPath;
  String modelBinPath;
  String metadataPath;
  String roiConfigPath;
  bool roiEnabled;
  bool roiAutoReload;
  bool renderPreview;
  bool filterByClass;
  int filterClassId;

  AppSettings({
    this.guardExecutablePath = '',
    this.cameraPipeline =
        'libcamerasrc ! '
        'video/x-raw,width=1280,height=720,framerate=30/1,format=NV12 ! '
        'videoflip video-direction=vert ! '
        'videoconvert ! '
        'video/x-raw,format=BGR ! '
        'appsink drop=true max-buffers=1 sync=false',
    this.modelParamPath = '',
    this.modelBinPath = '',
    this.metadataPath = '',
    this.roiConfigPath = '',
    this.roiEnabled = true,
    this.roiAutoReload = true,
    this.renderPreview = true,
    this.filterByClass = true,
    this.filterClassId = 0,
  });

  List<String> buildCommandArgs() {
    final args = <String>[];
    if (modelParamPath.isNotEmpty) args.add(modelParamPath);
    if (modelBinPath.isNotEmpty) args.add(modelBinPath);
    if (metadataPath.isNotEmpty) args.add(metadataPath);
    if (roiConfigPath.isNotEmpty) args.add(roiConfigPath);
    return args;
  }
}
