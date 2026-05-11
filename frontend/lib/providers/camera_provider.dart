import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraProvider with ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  FlashMode _flashMode = FlashMode.off;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  FlashMode get flashMode => _flashMode;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _cameras = await availableCameras();
    if (_cameras!.isEmpty) return;

    _controller = CameraController(
      _cameras![0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Camera Initialization Error: $e");
    }
  }

  Future<void> disposeCamera() async {
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint("Camera dispose error: $e");
      }
      _controller = null;
      _isInitialized = false;
      _flashMode = FlashMode.off;
      notifyListeners();
    }
  }

  Future<void> reinitialize() async {
    await disposeCamera();
    await initialize();
  }

  Future<void> toggleFlash() async {
    if (!_isInitialized) return;

    _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller!.setFlashMode(_flashMode);
    notifyListeners();
  }

  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller!.value.isTakingPicture) return null;

    try {
      final XFile file = await _controller!.takePicture();
      
      // Turn off flash if it was in torch mode
      if (_flashMode == FlashMode.torch) {
        await toggleFlash();
      }
      
      return file;
    } catch (e) {
      debugPrint("Error taking picture: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
