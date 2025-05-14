import 'dart:math';
import 'package:flutter/material.dart';
import 'dot_position.dart';

class GameLevel {
  final int levelNumber;
  final String difficulty;
  final List<DotPosition> dots;
  final int targetTime;
  int? bestTime;
  int stars = 0;

  GameLevel({
    required this.levelNumber,
    required this.difficulty,
    required this.dots,
    required this.targetTime,
  });

  void updateScore(int completionTime) {
    if (bestTime == null || completionTime < bestTime!) {
      bestTime = completionTime;
    }
    
    // Calculate stars based on completion time relative to target time
    if (completionTime <= targetTime) {
      stars = 3;
    } else if (completionTime <= targetTime * 1.5) {
      stars = 2;
    } else {
      stars = 1;
    }
  }

  static GameLevel getLevel(int level) {
    if (level <= predefinedLevels.length) {
      return predefinedLevels[level - 1];
    }
    return _generateLevel(level);
  }

  static final List<GameLevel> predefinedLevels = [
    // Level 1 - Simple square
    GameLevel(
      levelNumber: 1,
      difficulty: 'EASY',
      targetTime: 30,
      dots: [
        DotPosition(x: 1, y: 1, number: 1),
        DotPosition(x: 5, y: 1, number: 2),
        DotPosition(x: 5, y: 5, number: 3),
        DotPosition(x: 1, y: 5, number: 4),
      ],
    ),
    
    // Level 2 - Pentagon
    GameLevel(
      levelNumber: 2,
      difficulty: 'EASY',
      targetTime: 30,
      dots: [
        DotPosition(x: 3, y: 1, number: 1),
        DotPosition(x: 5, y: 2, number: 2),
        DotPosition(x: 4, y: 5, number: 3),
        DotPosition(x: 2, y: 5, number: 4),
        DotPosition(x: 1, y: 2, number: 5),
      ],
    ),
    
    // Add more predefined levels as needed...
  ];

  static GameLevel _generateLevel(int level) {
    final random = Random(level); // Seeded random for consistent generation
    final gridSize = 6;
    final numDots = _calculateNumDots(level);
    
    // Keep trying until we get a valid level
    for (int attempt = 0; attempt < 100; attempt++) {
      final dots = _generateSolvablePattern(numDots, gridSize, random);
      if (dots != null) {
        return GameLevel(
          levelNumber: level,
          difficulty: _calculateDifficulty(level),
          dots: dots,
          targetTime: _calculateTargetTime(level, numDots),
        );
      }
    }
    
    // Fallback to a simple pattern if generation fails
    return _generateFallbackLevel(level, numDots, gridSize);
  }

  static int _calculateNumDots(int level) {
    final baseDots = 4;
    final additionalDots = (level - 1) ~/ 5; // Add a dot every 5 levels
    return min(baseDots + additionalDots, 8); // Cap at 8 dots
  }

  static String _calculateDifficulty(int level) {
    if (level <= 5) return 'EASY';
    if (level <= 10) return 'MEDIUM';
    if (level <= 15) return 'HARD';
    if (level <= 20) return 'EXPERT';
    if (level <= 25) return 'MASTER';
    return 'GRANDMASTER';
  }

  static int _calculateTargetTime(int level, int numDots) {
    // Base time of 20 seconds + 5 seconds per dot
    final baseTime = 20 + (numDots * 5);
    // Reduce target time as levels progress
    final timeReduction = min((level - 1) ~/ 5 * 2, 10);
    return max(baseTime - timeReduction, 15); // Minimum 15 seconds
  }

  static List<DotPosition>? _generateSolvablePattern(int numDots, int gridSize, Random random) {
    List<DotPosition> dots = [];
      
    // Start with first dot in a reasonable position
    dots.add(DotPosition(
      x: 1.0 + random.nextInt(gridSize - 2).toDouble(),
      y: 1.0 + random.nextInt(2).toDouble(),
      number: 1,
      ));
      
    // Generate remaining dots ensuring solvability
      for (int i = 1; i < numDots; i++) {
      List<DotPosition> validPositions = [];
          
      // Try multiple positions for each dot
      for (int y = 1; y < gridSize - 1; y++) {
        for (int x = 1; x < gridSize - 1; x++) {
          final candidate = DotPosition(
            x: x.toDouble(),
            y: y.toDouble(),
            number: i + 1,
          );
          
          if (_isValidDotPlacement(candidate, dots) && 
              _hasValidPath(dots.last, candidate, dots) &&
              !_wouldCreateDeadEnd(candidate, dots, gridSize, numDots - i - 1)) {
            validPositions.add(candidate);
          }
        }
      }
      
      if (validPositions.isEmpty) {
        return null; // Pattern is unsolvable, try again
      }
      
      // Choose a random valid position
      dots.add(validPositions[random.nextInt(validPositions.length)]);
          }
          
    return dots;
  }

  static bool _wouldCreateDeadEnd(DotPosition newDot, List<DotPosition> existingDots, int gridSize, int remainingDots) {
    if (remainingDots == 0) return false;
          
    // Check if there are enough valid positions for remaining dots
    int validPositionsCount = 0;
    for (int y = 1; y < gridSize - 1; y++) {
      for (int x = 1; x < gridSize - 1; x++) {
        final futurePosition = DotPosition(
          x: x.toDouble(),
          y: y.toDouble(),
          number: newDot.number + 1,
        );
        
        if (_isValidDotPlacement(futurePosition, [...existingDots, newDot]) &&
            _hasValidPath(newDot, futurePosition, [...existingDots, newDot])) {
          validPositionsCount++;
        }
      }
    }
    
    return validPositionsCount < remainingDots;
      }

  static GameLevel _generateFallbackLevel(int level, int numDots, int gridSize) {
    // Create a simple zigzag pattern that's always solvable
    List<DotPosition> dots = [];
    bool goingRight = true;
    double x = 1.0;
    double y = 1.0;
    
    for (int i = 0; i < numDots; i++) {
      dots.add(DotPosition(x: x, y: y, number: i + 1));
      
      if (goingRight) {
        if (x < gridSize - 2) {
          x += 1.0;
        } else {
          y += 1.0;
          goingRight = false;
        }
      } else {
        if (x > 1) {
          x -= 1.0;
    } else {
          y += 1.0;
          goingRight = true;
        }
    }
    }

    return GameLevel(
      levelNumber: level,
      difficulty: _calculateDifficulty(level),
      dots: dots,
      targetTime: _calculateTargetTime(level, numDots),
    );
  }

  static bool _isValidDotPlacement(DotPosition newDot, List<DotPosition> existingDots) {
    if (existingDots.isEmpty) return true;
    
    // Check minimum distance from other dots
    for (final dot in existingDots) {
      if (DotPosition.distanceBetween(dot, newDot) < 1.2) {
        return false;
      }
    }
    
    // Check if path to previous dot is valid
    final lastDot = existingDots.last;
    return _hasValidPath(lastDot, newDot, existingDots);
  }

  static bool _hasValidPath(DotPosition from, DotPosition to, List<DotPosition> allDots) {
    // Try both horizontal-then-vertical and vertical-then-horizontal paths
    return _checkPath(from, to, allDots, true) || _checkPath(from, to, allDots, false);
  }

  static bool _checkPath(DotPosition from, DotPosition to, List<DotPosition> allDots, bool horizontalFirst) {
    final midPoint = horizontalFirst
        ? DotPosition(x: to.x, y: from.y, number: -1)
        : DotPosition(x: from.x, y: to.y, number: -1);
    
    // Check if any dot lies on the path
    for (final dot in allDots) {
      if (dot == from || dot == to) continue;
      
      if (_dotLiesOnPath(from, midPoint, dot) || _dotLiesOnPath(midPoint, to, dot)) {
          return false;
      }
    }
    
    return true;
  }

  static bool _dotLiesOnPath(DotPosition start, DotPosition end, DotPosition dot) {
    if (start.x == end.x) {
      // Vertical line
      return dot.x == start.x &&
             dot.y >= min(start.y, end.y) &&
             dot.y <= max(start.y, end.y);
    } else {
      // Horizontal line
      return dot.y == start.y &&
             dot.x >= min(start.x, end.x) &&
             dot.x <= max(start.x, end.x);
    }
  }
} 