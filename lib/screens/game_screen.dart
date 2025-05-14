import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../helpers/unity_ad_helper.dart';
import 'dart:math' as math;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  static const double GRAVITY = 1.5;
  static const double JUMP_FORCE = -12.0;
  static const double SHEEP_SIZE = 60.0;
  static const double OBSTACLE_WIDTH = 80.0;
  static const double GAP_SIZE = 200.0;

  late AnimationController _controller;
  double sheepY = 0.0;
  double sheepVelocity = 0.0;
  List<double> obstacleX = []; // X positions of obstacles
  List<double> obstacleY = []; // Y positions of gaps
  bool isPlaying = false;
  bool gameOver = false;
  int score = 0;
  int highScore = 0;
  Timer? gameTimer;
  bool canShowAd = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    resetGame();
  }

  void resetGame() {
    setState(() {
      sheepY = 0.0;
      sheepVelocity = 0.0;
      obstacleX = [1.0]; // Start with one obstacle
      obstacleY = [_generateRandomGap()];
      isPlaying = false;
      gameOver = false;
      score = 0;
    });
  }

  double _generateRandomGap() {
    return -200 + math.Random().nextDouble() * 400; // Random gap position
  }

  void startGame() {
    if (isPlaying) return;
    
    setState(() {
      isPlaying = true;
      gameOver = false;
    });

    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!isPlaying) {
        timer.cancel();
        return;
      }

      setState(() {
        // Update sheep position
        sheepVelocity += GRAVITY;
        sheepY += sheepVelocity;

        // Update obstacles
        for (int i = 0; i < obstacleX.length; i++) {
          obstacleX[i] -= 4.0; // Move obstacles left

          // Check if sheep passed the obstacle
          if (obstacleX[i] < -0.2 && obstacleX[i] > -0.3) {
            score++;
            if (score > highScore) {
              highScore = score;
            }
          }
        }

        // Add new obstacle when needed
        if (obstacleX.last < 0.5) {
          obstacleX.add(1.2);
          obstacleY.add(_generateRandomGap());
        }

        // Remove off-screen obstacles
        if (obstacleX[0] < -0.5) {
          obstacleX.removeAt(0);
          obstacleY.removeAt(0);
        }

        // Check for collisions
        for (int i = 0; i < obstacleX.length; i++) {
          if (obstacleX[i] > 0.1 && obstacleX[i] < 0.5) {
            if (sheepY < obstacleY[i] - GAP_SIZE/2 || 
                sheepY > obstacleY[i] + GAP_SIZE/2) {
              gameOver = true;
              isPlaying = false;
              _showGameOver();
            }
          }
        }

        // Check boundaries
        if (sheepY > 1.0 || sheepY < -1.0) {
          gameOver = true;
          isPlaying = false;
          _showGameOver();
        }
      });
    });
  }

  void jump() {
    if (!isPlaying && !gameOver) {
      startGame();
    }
    if (isPlaying) {
      setState(() {
        sheepVelocity = JUMP_FORCE;
        _controller.forward(from: 0.0);
      });
    }
  }

  Future<void> _showGameOver() async {
    if (!canShowAd) return;

    gameTimer?.cancel();
    
    // Show game over dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $score'),
            Text('High Score: $highScore'),
            const SizedBox(height: 20),
            const Text('Watch an ad to continue?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              resetGame();
            },
            child: const Text('New Game'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show rewarded ad
              final adResult = await UnityAdHelper.showRewardedAd(context);
              if (adResult.success) {
                setState(() {
                  gameOver = false;
                  canShowAd = false;
                  // Resume game from where it ended
                  startGame();
                });
                // Reset ad flag after 1 minute
                Future.delayed(const Duration(minutes: 1), () {
                  setState(() => canShowAd = true);
                });
              } else {
                resetGame();
              }
            },
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      body: GestureDetector(
        onTapDown: (_) => jump(),
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.lightBlue[200]!,
                    Colors.lightBlue[100]!,
                  ],
                ),
              ),
            ),
            
            // Game elements
            CustomPaint(
              painter: GamePainter(
                sheepY: sheepY,
                obstacleX: obstacleX,
                obstacleY: obstacleY,
                rotation: _controller.value * 0.5,
              ),
              child: Container(),
            ),

            // Score display
            Positioned(
              top: 50,
              left: 20,
              child: Text(
                'Score: $score',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // High score display
            Positioned(
              top: 50,
              right: 20,
              child: Text(
                'Best: $highScore',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Start game instruction
            if (!isPlaying && !gameOver)
              const Center(
                child: Text(
                  'Tap to Start',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final double sheepY;
  final List<double> obstacleX;
  final List<double> obstacleY;
  final double rotation;

  GamePainter({
    required this.sheepY,
    required this.obstacleX,
    required this.obstacleY,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw sheep
    final sheepPaint = Paint()..color = Colors.white;
    final sheepX = size.width * 0.3;
    final sheepPosition = Offset(
      sheepX,
      size.height * 0.5 + sheepY * size.height * 0.3,
    );

    canvas.save();
    canvas.translate(sheepPosition.dx, sheepPosition.dy);
    canvas.rotate(rotation);
    canvas.translate(-sheepPosition.dx, -sheepPosition.dy);

    // Draw sheep body
    canvas.drawCircle(
      sheepPosition,
      _GameScreenState.SHEEP_SIZE / 2,
      sheepPaint,
    );

    // Draw sheep face
    final facePaint = Paint()..color = Colors.black;
    canvas.drawCircle(
      Offset(sheepPosition.dx + 15, sheepPosition.dy - 5),
      5,
      facePaint,
    );

    canvas.restore();

    // Draw obstacles
    final obstaclePaint = Paint()..color = Colors.green;
    for (int i = 0; i < obstacleX.length; i++) {
      final obstacleLeft = obstacleX[i] * size.width;
      final gapCenter = size.height * 0.5 + obstacleY[i];

      // Top obstacle
      canvas.drawRect(
        Rect.fromLTWH(
          obstacleLeft,
          0,
          _GameScreenState.OBSTACLE_WIDTH,
          gapCenter - _GameScreenState.GAP_SIZE / 2,
        ),
        obstaclePaint,
      );

      // Bottom obstacle
      canvas.drawRect(
        Rect.fromLTWH(
          obstacleLeft,
          gapCenter + _GameScreenState.GAP_SIZE / 2,
          _GameScreenState.OBSTACLE_WIDTH,
          size.height - (gapCenter + _GameScreenState.GAP_SIZE / 2),
        ),
        obstaclePaint,
      );
    }
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) {
    return oldDelegate.sheepY != sheepY ||
           oldDelegate.obstacleX != obstacleX ||
           oldDelegate.obstacleY != obstacleY ||
           oldDelegate.rotation != rotation;
  }
} 