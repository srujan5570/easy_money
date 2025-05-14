import 'package:flutter/material.dart';

class DotPosition {
  final double x;
  final double y;
  final int number;
  bool isConnected;

  DotPosition({
    required this.x,
    required this.y,
    required this.number,
    this.isConnected = false,
  });

  Offset toOffset() => Offset(x, y);

  static double distanceBetween(DotPosition a, DotPosition b) {
    return Offset(a.x - b.x, a.y - b.y).distance;
  }

  bool isNear(Offset position, double threshold) {
    final distance = (toOffset() - position).distance;
    return distance <= threshold;
  }

  @override
  String toString() => 'Dot #$number at ($x, $y)';
} 