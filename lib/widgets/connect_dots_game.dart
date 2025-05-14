import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_level.dart';
import '../models/dot_position.dart';

class ConnectDotsGame extends StatefulWidget {
  final GameLevel level;
  final Function(int) onComplete;
  final VoidCallback onRestart;

  const ConnectDotsGame({
    Key? key,
    required this.level,
    required this.onComplete,
    required this.onRestart,
  }) : super(key: key);

  @override
  ConnectDotsGameState createState() => ConnectDotsGameState();
}

class ConnectDotsGameState extends State<ConnectDotsGame> {
  final List<List<Offset>> _paths = [];
  final List<bool> _dotsConnected = [];
  List<Offset> _currentPath = [];
  int _currentDotIndex = 0;
  Timer? _gameTimer;
  int _elapsedSeconds = 0;
  bool _isDragging = false;
  DotPosition? _lastConnectedDot;
  
  static const double _dotRadius = 20.0;
  static const double _hitTestRadius = 25.0;
  static const double _lineWidth = 3.0;
  
  @override
  void initState() {
    super.initState();
    _dotsConnected.addAll(List.filled(widget.level.dots.length, false));
    _startTimer();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _resetGame() {
    setState(() {
      _paths.clear();
      _currentPath.clear();
      _dotsConnected.fillRange(0, _dotsConnected.length, false);
      _currentDotIndex = 0;
      _elapsedSeconds = 0;
      _isDragging = false;
      _lastConnectedDot = null;
    });
    _startTimer();
    widget.onRestart();
  }

  void _checkGameCompletion() {
    if (_currentDotIndex >= widget.level.dots.length - 1) {
      _gameTimer?.cancel();
      widget.onComplete(_elapsedSeconds);
    }
  }

  bool _isValidNextDot(DotPosition dot) {
    return dot.number == _currentDotIndex + 1;
  }

  void _handlePanStart(DragStartDetails details) {
    final dot = _findNearestDot(details.localPosition);
    if (dot != null && dot.number == 1 && !_isDragging) {
      setState(() {
        _isDragging = true;
        _lastConnectedDot = dot;
        _currentPath = [dot.toOffset()];
        dot.isConnected = true;
        _dotsConnected[0] = true;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _lastConnectedDot == null) return;

    // Update current path for smooth line drawing
    setState(() {
      _currentPath.add(details.localPosition);
      
      // Optimize path by removing points that are too close together
      if (_currentPath.length > 2) {
        final last = _currentPath[_currentPath.length - 1];
        final secondLast = _currentPath[_currentPath.length - 2];
        if ((last - secondLast).distance < 5.0) {
          _currentPath.removeAt(_currentPath.length - 2);
        }
      }
    });

    // Check for connecting to next dot
    final nextDot = _findNearestDot(details.localPosition);
    if (nextDot != null && _isValidNextDot(nextDot) && !nextDot.isConnected) {
      setState(() {
        nextDot.isConnected = true;
        _dotsConnected[_currentDotIndex + 1] = true;
        _currentDotIndex++;
        _lastConnectedDot = nextDot;
        
        // Smooth the path by adding the exact dot position
        _currentPath.last = nextDot.toOffset();
        
        // Store completed path
        if (_currentPath.length >= 2) {
          _paths.add(List.from(_currentPath));
        }
        
        // Start new path from this dot
        _currentPath = [nextDot.toOffset()];
        
        _checkGameCompletion();
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      _isDragging = false;
      _currentPath.clear();
      
      // If we didn't complete the level, reset to last valid connection
      if (_currentDotIndex < widget.level.dots.length - 1) {
        for (int i = _currentDotIndex + 1; i < _dotsConnected.length; i++) {
          _dotsConnected[i] = false;
          widget.level.dots[i].isConnected = false;
        }
      }
    });
  }

  DotPosition? _findNearestDot(Offset position) {
    for (final dot in widget.level.dots) {
      if (dot.isNear(position, _hitTestRadius)) {
        return dot;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: CustomPaint(
        painter: _DotsAndLinesPainter(
          dots: widget.level.dots,
          paths: _paths,
          currentPath: _isDragging ? _currentPath : [],
          dotsConnected: _dotsConnected,
          dotRadius: _dotRadius,
          lineWidth: _lineWidth,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
        ),
      ),
    );
  }
}

class _DotsAndLinesPainter extends CustomPainter {
  final List<DotPosition> dots;
  final List<List<Offset>> paths;
  final List<Offset> currentPath;
  final List<bool> dotsConnected;
  final double dotRadius;
  final double lineWidth;

  _DotsAndLinesPainter({
    required this.dots,
    required this.paths,
    required this.currentPath,
    required this.dotsConnected,
    required this.dotRadius,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
      
    final connectedDotPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
      
    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw completed paths
    for (final path in paths) {
      if (path.length >= 2) {
        final pathMetrics = Path()..moveTo(path[0].dx, path[0].dy);
        for (int i = 1; i < path.length; i++) {
          pathMetrics.lineTo(path[i].dx, path[i].dy);
        }
        canvas.drawPath(pathMetrics, linePaint);
      }
    }

    // Draw current path
    if (currentPath.length >= 2) {
      final currentPathMetrics = Path()..moveTo(currentPath[0].dx, currentPath[0].dy);
      for (int i = 1; i < currentPath.length; i++) {
        currentPathMetrics.lineTo(currentPath[i].dx, currentPath[i].dy);
      }
      canvas.drawPath(currentPathMetrics, linePaint);
    }

    // Draw dots
    for (int i = 0; i < dots.length; i++) {
      final dot = dots[i];
      final center = dot.toOffset();
      
      // Draw dot
      canvas.drawCircle(
        center,
        dotRadius,
        dotsConnected[i] ? connectedDotPaint : dotPaint,
      );
      
      // Draw number
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${dot.number}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotsAndLinesPainter oldDelegate) {
    return true;
  }
} 