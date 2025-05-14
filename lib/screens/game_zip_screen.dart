import 'package:flutter/material.dart';
import 'dart:math';

class GameZipScreen extends StatefulWidget {
  const GameZipScreen({Key? key}) : super(key: key);

  @override
  State<GameZipScreen> createState() => _GameZipScreenState();
}

class _GameZipScreenState extends State<GameZipScreen> {
  // Grid size
  static const int gridSize = 7;
  static const double boardPx = 320;
  static const double cellPx = boardPx / gridSize;

  // Dot positions as grid coordinates (col, row)
  final List<Offset> _dotGridPositions = const [
    Offset(0, 0), // 1
    Offset(6, 0), // 2
    Offset(6, 6), // 3
    Offset(1, 6), // 4
    Offset(1, 1), // 5
    Offset(5, 1), // 6
    Offset(5, 5), // 7
    Offset(3, 3), // 8
  ];

  List<Offset> _userPath = [];
  int _currentTarget = 0; // Index of the next dot to reach
  bool _drawing = false;
  Offset? _lastDirection; // (1,0) for horizontal, (0,1) for vertical

  Offset _gridToPx(Offset grid) => Offset(grid.dx * cellPx + cellPx / 2, grid.dy * cellPx + cellPx / 2);
  Offset _pxToGrid(Offset px) => Offset((px.dx / cellPx).roundToDouble(), (px.dy / cellPx).roundToDouble());

  int? _getDotIndexAtGrid(Offset grid, {double radius = 1.0}) {
    for (int i = 0; i < _dotGridPositions.length; i++) {
      if ((_dotGridPositions[i] - grid).distance < radius) {
        return i;
      }
    }
    return null;
  }

  // Add this helper method to check for path overlap
  bool _wouldOverlap(Offset nextGrid) {
    // Don't check the last position as we're moving from it
    for (int i = 0; i < _userPath.length - 1; i++) {
      // Check if the next grid position is already in our path
      if (_userPath[i] == nextGrid) {
        return true;
      }
      
      // Check if we're crossing a line segment
      if (i > 0) {
        final segmentStart = _userPath[i - 1];
        final segmentEnd = _userPath[i];
        final lastPos = _userPath.last;
        
        // Only check if segments are parallel (both horizontal or both vertical)
        if ((segmentStart.dx == segmentEnd.dx && lastPos.dx == nextGrid.dx) ||
            (segmentStart.dy == segmentEnd.dy && lastPos.dy == nextGrid.dy)) {
          
          // Check for horizontal line crossing
          if (segmentStart.dy == segmentEnd.dy && lastPos.dy == segmentStart.dy) {
            final minX = min(segmentStart.dx, segmentEnd.dx);
            final maxX = max(segmentStart.dx, segmentEnd.dx);
            final pathMinX = min(lastPos.dx, nextGrid.dx);
            final pathMaxX = max(lastPos.dx, nextGrid.dx);
            
            if (pathMinX <= maxX && pathMaxX >= minX) {
              return true;
            }
          }
          
          // Check for vertical line crossing
          if (segmentStart.dx == segmentEnd.dx && lastPos.dx == segmentStart.dx) {
            final minY = min(segmentStart.dy, segmentEnd.dy);
            final maxY = max(segmentStart.dy, segmentEnd.dy);
            final pathMinY = min(lastPos.dy, nextGrid.dy);
            final pathMaxY = max(lastPos.dy, nextGrid.dy);
            
            if (pathMinY <= maxY && pathMaxY >= minY) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  void _onPanStart(DragStartDetails details) {
    final localPos = details.localPosition;
    final grid = _pxToGrid(localPos);
    final dotIdx = _getDotIndexAtGrid(grid, radius: 2);
    if (dotIdx == 0 && _currentTarget == 0) {
      setState(() {
        _drawing = true;
        _userPath = [_dotGridPositions[0]];
        _lastDirection = null;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_drawing) return;
    final localPos = details.localPosition;
    final grid = _pxToGrid(localPos);
    final last = _userPath.isNotEmpty ? _userPath.last : null;
    
    // First check if we're within grid bounds
    if (grid.dx < 0 || grid.dx >= gridSize || grid.dy < 0 || grid.dy >= gridSize) {
      return; // Don't allow movement outside grid
    }

    if (last != null) {
      // Calculate movement in both directions
      final dx = (grid.dx - last.dx).abs();
      final dy = (grid.dy - last.dy).abs();

      // Determine intended direction based on initial movement
      if (_lastDirection == null) {
        // Extremely strict initial direction detection
        if (dx > 0.7 && dx > dy * 4.0) {
          // Check if moving horizontally would stay in bounds
          final nextX = last.dx + (grid.dx > last.dx ? 1 : -1);
          if (nextX < 0 || nextX >= gridSize) return;
          final nextGrid = Offset(nextX, last.dy);
          if (_wouldOverlap(nextGrid)) return; // Check for overlap
          _lastDirection = const Offset(1, 0); // horizontal
        } else if (dy > 0.7 && dy > dx * 4.0) {
          // Check if moving vertically would stay in bounds
          final nextY = last.dy + (grid.dy > last.dy ? 1 : -1);
          if (nextY < 0 || nextY >= gridSize) return;
          final nextGrid = Offset(last.dx, nextY);
          if (_wouldOverlap(nextGrid)) return; // Check for overlap
          _lastDirection = const Offset(0, 1); // vertical
        } else {
          return; // Not enough clear directional movement
        }
      }

      // Only allow movement in the locked direction with very strict thresholds
      Offset nextGrid = last;
      if (_lastDirection!.dx != 0) {
        // Horizontal movement - require almost no vertical deviation
        if (dx >= 0.8 && dy < 0.15) {
          final nextX = last.dx + _lastDirection!.dx * (grid.dx > last.dx ? 1 : -1);
          // Check horizontal bounds
          if (nextX < 0 || nextX >= gridSize) return;
          nextGrid = Offset(nextX, last.dy);
          if (_wouldOverlap(nextGrid)) return; // Check for overlap
        } else {
          // If very significant horizontal movement, maintain horizontal
          if (dx > dy * 3.5) {
            final nextX = last.dx + _lastDirection!.dx * (grid.dx > last.dx ? 1 : -1);
            // Check horizontal bounds
            if (nextX < 0 || nextX >= gridSize) return;
            nextGrid = Offset(nextX, last.dy);
            if (_wouldOverlap(nextGrid)) return; // Check for overlap
          } else {
            return; // Not enough horizontal movement or too much vertical
          }
        }
      } else if (_lastDirection!.dy != 0) {
        // Vertical movement - require almost no horizontal deviation
        if (dy >= 0.8 && dx < 0.15) {
          final nextY = last.dy + _lastDirection!.dy * (grid.dy > last.dy ? 1 : -1);
          // Check vertical bounds
          if (nextY < 0 || nextY >= gridSize) return;
          nextGrid = Offset(last.dx, nextY);
          if (_wouldOverlap(nextGrid)) return; // Check for overlap
        } else {
          // If very significant vertical movement, maintain vertical
          if (dy > dx * 3.5) {
            final nextY = last.dy + _lastDirection!.dy * (grid.dy > last.dy ? 1 : -1);
            // Check vertical bounds
            if (nextY < 0 || nextY >= gridSize) return;
            nextGrid = Offset(last.dx, nextY);
            if (_wouldOverlap(nextGrid)) return; // Check for overlap
          } else {
            return; // Not enough vertical movement or too much horizontal
          }
        }
      }

      // Only add if new cell
      if (_userPath.isEmpty || _userPath.last != nextGrid) {
        setState(() {
          _userPath.add(nextGrid);
          // Only allow direction change after a complete cell movement
          // and when almost completely stopped in the current direction
          if ((nextGrid - last).distance >= 1.0 &&
              (_lastDirection!.dx != 0 ? dy < 0.04 : dx < 0.08)) {
            _lastDirection = null;
          }
        });

        // Check if reached next dot
        if (_currentTarget + 1 < _dotGridPositions.length) {
          if ((nextGrid - _dotGridPositions[_currentTarget + 1]).distance < 0.5) {
            setState(() {
              _currentTarget++;
              if (_currentTarget == _dotGridPositions.length - 1) {
                _drawing = false; // Finished
              }
            });
          }
        }
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentTarget < _dotGridPositions.length - 1) {
      // Reset if not completed
      setState(() {
        _userPath = [];
        _currentTarget = 0;
        _drawing = false;
        _lastDirection = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Zip', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 20, color: Colors.black54),
                const SizedBox(width: 4),
                const Text('0:13', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Difficulty HARD', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _userPath = [];
                      _currentTarget = 0;
                      _drawing = false;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Clear', style: TextStyle(color: Colors.black54)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Game Board
          Center(
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Container(
                width: boardPx,
                height: boardPx,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
                child: CustomPaint(
                  painter: _ZipBoardPainterGrid(
                    dotGridPositions: _dotGridPositions,
                    userPath: _userPath,
                    showPath: _userPath.isNotEmpty,
                    gridSize: gridSize,
                    cellPx: cellPx,
                  ),
                  child: Container(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (_userPath.isNotEmpty) {
                          _userPath.removeLast();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F2),
                      foregroundColor: Colors.black54,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Undo'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F2),
                      foregroundColor: Colors.black54,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Hint'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // How to play
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    _dot(Colors.black, '1'),
                    _dot(Colors.black, '2'),
                    _dot(Colors.black, '3'),
                  ],
                ),
                const SizedBox(width: 8),
                const Text('Connect the dots in order'),
                const Spacer(),
                Icon(Icons.grid_on, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text('Fill every cell'),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('See results', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ZipBoardPainterGrid extends CustomPainter {
  final List<Offset> dotGridPositions;
  final List<Offset> userPath;
  final bool showPath;
  final int gridSize;
  final double cellPx;

  _ZipBoardPainterGrid({
    required this.dotGridPositions,
    required this.userPath,
    required this.showPath,
    required this.gridSize,
    required this.cellPx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid (optional, for debugging)
    // final gridPaint = Paint()
    //   ..color = Colors.white.withOpacity(0.1)
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 1;
    // for (int i = 0; i <= gridSize; i++) {
    //   canvas.drawLine(Offset(i * cellPx, 0), Offset(i * cellPx, size.height), gridPaint);
    //   canvas.drawLine(Offset(0, i * cellPx), Offset(size.width, i * cellPx), gridPaint);
    // }

    // Draw user path if any
    if (showPath && userPath.length > 1) {
      final pathPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round;
      final path = Path();
      path.moveTo(userPath[0].dx * cellPx + cellPx / 2, userPath[0].dy * cellPx + cellPx / 2);
      for (int i = 1; i < userPath.length; i++) {
        path.lineTo(userPath[i].dx * cellPx + cellPx / 2, userPath[i].dy * cellPx + cellPx / 2);
      }
      canvas.drawPath(path, pathPaint);
    }
    // Draw dots
    final dotPaint = Paint()..color = Colors.black;
    final textStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18);
    for (int i = 0; i < dotGridPositions.length; i++) {
      final center = Offset(dotGridPositions[i].dx * cellPx + cellPx / 2, dotGridPositions[i].dy * cellPx + cellPx / 2);
      canvas.drawCircle(center, 20, dotPaint);
      final textSpan = TextSpan(text: '${i + 1}', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: 40);
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 