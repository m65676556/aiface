import 'package:flutter/material.dart';
import 'expression.dart';

class PixelFacePainter extends CustomPainter {
  final List<List<int>> currentFrame;
  final List<List<int>>? nextFrame;
  final double transitionProgress; // 0.0 to 1.0

  PixelFacePainter({
    required this.currentFrame,
    this.nextFrame,
    this.transitionProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / ExpressionData.size;
    final cellHeight = size.height / ExpressionData.size;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int row = 0; row < ExpressionData.size; row++) {
      for (int col = 0; col < ExpressionData.size; col++) {
        final currentIdx = currentFrame[row][col];

        if (nextFrame != null && transitionProgress > 0) {
          final nextIdx = nextFrame![row][col];
          final currentColor = PixelPalette.colors[currentIdx];
          final nextColor = PixelPalette.colors[nextIdx];
          paint.color = Color.lerp(currentColor, nextColor, transitionProgress)!;
        } else {
          paint.color = PixelPalette.colors[currentIdx];
        }

        if (paint.color.a == 0) continue;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            col * cellWidth,
            row * cellHeight,
            cellWidth + 0.5, // slight overlap to avoid gaps
            cellHeight + 0.5,
          ),
          const Radius.circular(1.0),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(PixelFacePainter oldDelegate) {
    return oldDelegate.currentFrame != currentFrame ||
        oldDelegate.nextFrame != nextFrame ||
        oldDelegate.transitionProgress != transitionProgress;
  }
}
