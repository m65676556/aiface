import 'dart:async';
import 'package:flutter/material.dart';
import 'expression.dart';
import 'pixel_face_painter.dart';

class PixelFaceWidget extends StatefulWidget {
  final Expression expression;
  final double size;

  const PixelFaceWidget({
    super.key,
    this.expression = Expression.neutral,
    this.size = 200,
  });

  @override
  State<PixelFaceWidget> createState() => _PixelFaceWidgetState();
}

class _PixelFaceWidgetState extends State<PixelFaceWidget>
    with TickerProviderStateMixin {
  late AnimationController _transitionController;
  late AnimationController _breathController;
  late Animation<double> _transitionAnimation;
  late Animation<double> _breathAnimation;

  late List<List<int>> _currentFrame;
  List<List<int>>? _nextFrame;
  bool _isBlinking = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _currentFrame = ExpressionData.getExpression(widget.expression);

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );
    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentFrame = _nextFrame ?? _currentFrame;
          _nextFrame = null;
        });
        _transitionController.reset();
      }
    });

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _startBlinkTimer();
  }

  void _startBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isBlinking && widget.expression != Expression.sleeping) {
        _blink();
      }
    });
  }

  Future<void> _blink() async {
    if (!mounted) return;
    _isBlinking = true;
    final blinkFrame = ExpressionData.getBlinkFrame(widget.expression);
    setState(() {
      _nextFrame = blinkFrame;
    });
    _transitionController.duration = const Duration(milliseconds: 100);
    await _transitionController.forward();
    if (!mounted) return;
    setState(() {
      _nextFrame = ExpressionData.getExpression(widget.expression);
    });
    _transitionController.duration = const Duration(milliseconds: 100);
    await _transitionController.forward();
    _isBlinking = false;
    _transitionController.duration = const Duration(milliseconds: 300);
  }

  @override
  void didUpdateWidget(PixelFaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression && !_isBlinking) {
      _nextFrame = ExpressionData.getExpression(widget.expression);
      _transitionController.duration = const Duration(milliseconds: 300);
      _transitionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _transitionController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_transitionAnimation, _breathAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _breathAnimation.value,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: PixelFacePainter(
                currentFrame: _currentFrame,
                nextFrame: _nextFrame,
                transitionProgress: _transitionAnimation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}
