import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Prefer front camera
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<String?> captureBase64() async {
    if (!_isInitialized || _controller == null) return null;

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();

      // Compress to 512x512 JPEG
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final resized = img.copyResize(decoded, width: 512, height: 512);
      final jpeg = img.encodeJpg(resized, quality: 70);

      return base64Encode(jpeg);
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
  }
}
