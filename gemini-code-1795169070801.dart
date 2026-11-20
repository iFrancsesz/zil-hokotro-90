import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ZilSnow90App());
}

class ZilSnow90App extends StatelessWidget {
  const ZilSnow90App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZIL D-470 Snow 90',
      home: SnowGameScreen(),
    );
  }
}

enum GamePhase { title, playing, gameOver }

enum ItemType { snowPile, iceRock, hazardCone }

class RoadEntity {
  double x;
  double y;
  final ItemType type;
  bool collected = false;

  RoadEntity({
    required this.x,
    required this.y,
    required this.type,
  });
}

class SnowGameScreen extends StatefulWidget {
  const SnowGameScreen({super.key});

  @override
  State<SnowGameScreen> createState() => _SnowGameScreenState();
}

class _SnowGameScreenState extends State<SnowGameScreen>
    with SingleTickerProviderStateMixin {
  static const int pixelW = 160;
  static const int pixelH = 240;

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final Random _rng = Random();

  GamePhase _phase = GamePhase.title;
  int _score = 0;
  int _bestScore = 0;
  int _lives = 3;
  double _roadScroll = 0.0;
  double _plowX = 0.0;
  double _invulnTimer = 0.0;
  double _blowerBoostTimer = 0.0;
  double _spawnTimer = 0.0;
  double _speed = 0.55;

  final List<RoadEntity> _entities = [];

  @override
  void initState() {
    super.initState();
    _entities.addAll([
      RoadEntity(x: -0.35, y: 0.25, type: ItemType.snowPile),
      RoadEntity(x: 0.40, y: 0.10, type: ItemType.iceRock),
      RoadEntity(x: 0.15, y: -0.10, type: ItemType.snowPile),
    ]);
    _ticker = createTicker(_onTick)..start();
  }

  void _startNewGame() {
    setState(() {
      _phase = GamePhase.playing;
      _score = 0;
      _lives = 3;
      _plowX = 0.0;
      _invulnTimer = 0.0;
      _blowerBoostTimer = 0.0;
      _spawnTimer = 0.2;
      _speed = 0.55;
      _entities.clear();
    });
  }

  void _onTick(Duration elapsed) {
    final double dt = _lastElapsed == Duration.zero
        ? 0.016
        : ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(0.0, 0.05);
    _lastElapsed = elapsed;

    if (_phase == GamePhase.playing) {
      _updatePlaying(dt);
    } else {
      _roadScroll = (_roadScroll + dt * 0.25) % 1.0;
    }

    if (mounted) setState(() {});
  }

  void _updatePlaying(double dt) {
    _speed = (0.55 + (_score / 1200.0)).clamp(0.55, 1.35);
    _roadScroll = (_roadScroll + dt * _speed) % 1.0;

    if (_invulnTimer > 0) _invulnTimer = max(0.0, _invulnTimer - dt);
    if (_blowerBoostTimer > 0) {
      _blowerBoostTimer = max(0.0, _blowerBoostTimer - dt);
    }

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnEntity();
      _spawnTimer = (0.58 - (_speed - 0.55) * 0.25).clamp(0.28, 0.65) +
          _rng.nextDouble() * 0.25;
    }

    const double plowY = 0.78;
    for (final e in _entities) {
      e.y += dt * _speed;
      if (!e.collected) {
        final bool yHit = (e.y - plowY).abs() < 0.085;
        final double hitRadiusX = e.type == ItemType.snowPile ? 0.30 : 0.24;
        if (yHit && (e.x - _plowX).abs() < hitRadiusX) {
          if (e.type == ItemType.snowPile) {
            e.collected = true;
            _score += 100;
            if (_score > _bestScore) _bestScore = _score;
            _blowerBoostTimer = 0.55;
            HapticFeedback.selectionClick();
          } else if (_invulnTimer <= 0) {
            e.collected = true;
            _lives -= 1;
            _invulnTimer = 1.2;
            HapticFeedback.heavyImpact();
            if (_lives <= 0) {
              _lives = 0;
              _phase = GamePhase.gameOver;
            }
          }
        }
      }
    }
    _entities.removeWhere((e) => e.y > 1.2 || e.collected);
  }

  void _spawnEntity() {
    final double r = _rng.nextDouble();
    final ItemType type = r < 0.60
        ? ItemType.snowPile
        : (r < 0.82 ? ItemType.iceRock : ItemType.hazardCone);

    double candidateX = (_rng.nextDouble() * 1.5) - 0.75;
    for (final existing in _entities) {
      if (existing.y < 0.15 && (existing.x - candidateX).abs() < 0.35) {
        candidateX = -candidateX;
        break;
      }
    }

    _entities.add(
      RoadEntity(
        x: candidateX.clamp(-0.75, 0.75),
        y: -0.12,
        type: type,
      ),
    );
  }

  void _movePlowByDelta(double normalizedDelta) {
    if (_phase != GamePhase.playing) return;
    setState(() {
      _plowX = (_plowX + normalizedDelta).clamp(-0.75, 0.75);
    });
  }

  void _setPlowFromLocalX(double localX, double totalWidth) {
    if (_phase != GamePhase.playing || totalWidth <= 0) return;
    final double norm = ((localX / totalWidth) * 2.0) - 1.0;
    setState(() {
      _plowX = (norm * 0.92).clamp(-0.75, 0.75);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1021),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFF141B33),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PONT: $_score',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ÉLET: ${'♥' * _lives}${'♡' * (3 - _lives)}',
                    style: const TextStyle(
                      color: Color(0xFFFF5252),
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'BEST: $_bestScore',
                    style: const TextStyle(
                      color: Color(0xFF80DEEA),
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: pixelW / pixelH,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          final double deltaNorm =
                              (details.delta.dx / constraints.maxWidth) * 1.8;
                          _movePlowByDelta(deltaNorm);
                        },
                        onTapDown: (details) {
                          _setPlowFromLocalX(
                            details.localPosition.dx,
                            constraints.maxWidth,
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _PixelSnowPainter(
                                roadScroll: _roadScroll,
                                plowX: _plowX,
                                invulnTimer: _invulnTimer,
                                blowerBoostTimer: _blowerBoostTimer,
                                entities: _entities,
                              ),
                            ),
                            if (_phase != GamePhase.playing)
                              Container(
                                color: Colors.black.withValues(alpha: 0.62),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _phase == GamePhase.title
                                          ? 'ZIL D-470\nHÓKOTRÓ 90'
                                          : 'GAME OVER',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFFF9800),
                                        fontFamily: 'monospace',
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _phase == GamePhase.title
                                          ? 'Gyűjtsd a hókupacokat (+100),\nkerüld a jeget és a bóját!\nHúzd vagy koppints az úton.'
                                          : 'Végső pontszám: $_score',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD32F2F),
                                        foregroundColor: Colors.white,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: _startNewGame,
                                      child: Text(
                                        _phase == GamePhase.title
                                            ? 'INDÍTÁS'
                                            : 'ÚJRA',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              color: const Color(0xFF141B33),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RetroStepButton(
                    label: '< BAL',
                    onStep: () => _movePlowByDelta(-0.18),
                  ),
                  _RetroStepButton(
                    label: 'JOBB >',
                    onStep: () => _movePlowByDelta(0.18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelSnowPainter extends CustomPainter {
  static const double pixelW = 160.0;
  static const double pixelH = 240.0;

  final double roadScroll;
  final double plowX;
  final double invulnTimer;
  final double blowerBoostTimer;
  final List<RoadEntity> entities;

  _PixelSnowPainter({
    required this.roadScroll,
    required this.plowX,
    required this.invulnTimer,
    required this.blowerBoostTimer,
    required this.entities,
  });

  void _px(Canvas c, Paint p, Color col, double x, double y, double w, double h) {
    p.color = col;
    c.drawRect(Rect.fromLTWH(x, y, w, h), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / pixelW, size.height / pixelH);
    final p = Paint()..isAntiAlias = false;

    // 1. Havas útpadka
    _px(canvas, p, const Color(0xFFD8E8F8), 0, 0, 160, 240);
    for (int i = 0; i < 14; i++) {
      final double sy = ((i * 23.0) + (roadScroll * 240.0)) % 240.0;
      final double sx =
          (i % 2 == 0) ? ((i * 7) % 20).toDouble() : (138 + (i * 5) % 18).toDouble();
      _px(canvas, p, const Color(0xFFB3CCE6), sx, sy, 6, 3);
    }

    // 2. Aszfaltút és piros-fehér szegély
    _px(canvas, p, const Color(0xFF2B2F3A), 24, 0, 112, 240);
    const double stripeH = 20;
    final double offset = roadScroll * stripeH * 2;
    for (double y = -stripeH * 2; y < 240 + stripeH * 2; y += stripeH) {
      final int idx = ((y + offset) / stripeH).floor();
      final Color col =
          (idx % 2 == 0) ? const Color(0xFFC62828) : const Color(0xFFECEFF1);
      _px(canvas, p, col, 21, y + (offset % stripeH), 3, stripeH);
      _px(canvas, p, col, 136, y + (offset % stripeH), 3, stripeH);
    }

    // Felezővonal
    const double dashPeriod = 30;
    final double dashOffset = roadScroll * dashPeriod;
    for (double y = -dashPeriod; y < 240 + dashPeriod; y += dashPeriod) {
      _px(canvas, p, const Color(0xFFF5F5F5), 79, y + dashOffset, 2, 14);
    }

    // 3. Hókupacok és akadályok
    for (final e in entities) {
      final double x = (80.0 + e.x * 42.0).roundToDouble();
      final double y = (e.y * 240.0).roundToDouble();
      if (e.type == ItemType.snowPile) {
        _px(canvas, p, const Color(0xFF90CAF9), x - 8, y + 2, 16, 4);
        _px(canvas, p, const Color(0xFFFFFFFF), x - 7, y - 2, 14, 5);
        _px(canvas, p, const Color(0xFFFFFFFF), x - 5, y - 5, 10, 4);
        _px(canvas, p, const Color(0xFFFFFFFF), x - 2, y - 7, 4, 3);
      } else if (e.type == ItemType.iceRock) {
        _px(canvas, p, const Color(0xFF37474F), x - 8, y - 4, 16, 9);
        _px(canvas, p, const Color(0xFF546E7A), x - 6, y - 7, 12, 4);
        _px(canvas, p, const Color(0xFF80DEEA), x - 5, y - 5, 4, 3);
      } else {
        _px(canvas, p, const Color(0xFF212121), x - 7, y + 3, 14, 3);
        _px(canvas, p, const Color(0xFFFF6D00), x - 5, y - 2, 10, 5);
        _px(canvas, p, const Color(0xFFFF6D00), x - 2, y - 7, 4, 5);
        _px(canvas, p, const Color(0xFFFFFFFF), x - 4, y - 1, 8, 2);
      }
    }

    // 4. ZIL D-470 hókotró
    final bool skipForBlink =
        invulnTimer > 0 && ((invulnTimer * 16).floor() % 2 == 0);
    if (!skipForBlink) {
      final double x = (80.0 + plowX * 42.0).roundToDouble();
      const double y = 186.0;

      // Kerekek
      _px(canvas, p, const Color(0xFF1A1C20), x - 12, y - 6, 3, 7);
      _px(canvas, p, const Color(0xFF1A1C20), x + 9, y - 6, 3, 7);
      _px(canvas, p, const Color(0xFF1A1C20), x - 12, y + 5, 3, 7);
      _px(canvas, p, const Color(0xFF1A1C20), x + 9, y + 5, 3, 7);

      // Narancssárga ZIL felépítmény és kabin
      _px(canvas, p, const Color(0xFFE67E22), x - 9, y + 2, 18, 11);
      _px(canvas, p, const Color(0xFFBA5A0A), x - 9, y + 11, 18, 2);
      _px(canvas, p, const Color(0xFFF39C12), x - 9, y - 5, 18, 8);
      _px(canvas, p, const Color(0xFF263238), x - 7, y - 4, 14, 3);

      // Fényszórók és villogó
      _px(canvas, p, const Color(0xFFFFEB3B), x - 6, y - 7, 3, 2);
      _px(canvas, p, const Color(0xFFFFEB3B), x + 3, y - 7, 3, 2);
      _px(canvas, p, const Color(0xFFFF9800), x - 1, y - 8, 2, 2);

      // Piros-fehér ZIL D-470 maróeke
      final Color bladeCol =
          blowerBoostTimer > 0 ? const Color(0xFFFF5252) : const Color(0xFFB71C1C);
      _px(canvas, p, bladeCol, x - 13, y - 13, 26, 6);
      _px(canvas, p, const Color(0xFFFFFFFF), x - 13, y - 13, 3, 2);
      _px(canvas, p, const Color(0xFFFFFFFF), x - 13, y - 9, 3, 2);
      _px(canvas, p, const Color(0xFFFFFFFF), x + 10, y - 13, 3, 2);
      _px(canvas, p, const Color(0xFFD32F2F), x + 10, y - 9, 3, 2);

      final double rotorShift = (((roadScroll * 12).floor() % 3) - 1).toDouble();
      _px(canvas, p, const Color(0xFF7F0000), x - 9 + rotorShift, y - 14, 18, 2);
    }

    // 5. Scanline effekt
    for (double y = 0; y < 240; y += 3) {
      _px(canvas, p, Colors.black.withValues(alpha: 0.14), 0, y, 160, 1);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PixelSnowPainter oldDelegate) => true;
}

class _RetroStepButton extends StatefulWidget {
  final String label;
  final VoidCallback onStep;

  const _RetroStepButton({
    required this.label,
    required this.onStep,
  });

  @override
  State<_RetroStepButton> createState() => _RetroStepButtonState();
}

class _RetroStepButtonState extends State<_RetroStepButton> {
  Timer? _repeatTimer;

  void _startHold() {
    widget.onStep();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      widget.onStep();
    });
  }

  void _stopHold() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _stopHold(),
      onTapCancel: _stopHold,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF263256),
          border: Border.all(color: const Color(0xFF7986CB), width: 2),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}