import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../providers/providers.dart';
import '../../core/theme.dart';

class CameraPreviewWidget extends ConsumerWidget {
  final double size;

  const CameraPreviewWidget({super.key, this.size = 80});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraService = ref.watch(cameraServiceProvider);

    if (!cameraService.isInitialized || cameraService.controller == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardColor,
          border: Border.all(color: AppTheme.primaryColor, width: 2),
        ),
        child: Icon(Icons.camera_alt, color: AppTheme.textSecondary, size: size * 0.4),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cameraService.controller!.value.previewSize?.height ?? size,
              height: cameraService.controller!.value.previewSize?.width ?? size,
              child: CameraPreview(cameraService.controller!),
            ),
          ),
        ),
      ),
    );
  }
}
