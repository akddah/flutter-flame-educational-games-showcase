import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------- ICY TOWER ----------
//
// Endless vertical platformer: climb a frozen tower by jumping between
// platforms. World space: y grows downward, floor 0 sits at y = 0 and every
// higher floor has a more negative y. `camY` is the world y shown at the top
// of the screen and only ever decreases (the camera never scrolls back down).

enum PlatformKind { normal, moving, crumbling, milestone }

class IcyTowerGame extends FlameGame with KeyboardEvents {
  // Session bests (kept across restarts while the app runs).
  static int bestScore = 0, bestFloor = 0;

  // Tower & physics tuning.
  static const wallW = 22.0;
  static const gravity = 2300.0;
  static const runAccel = 2100.0, airAccel = 1500.0;
  static const groundFriction = 1150.0, airFriction = 260.0; // icy = low friction
  static const maxRun = 440.0;
  static const baseJump = 880.0, speedJumpBonus = .5; // running fast = higher jumps
  static const coyoteTime = .09, jumpBuffer = .13;
  static const minJumpTime = .12; // a quick tap still clears one floor
  static const comboWindow = 3.0;
  static const playerHalfW = 11.0; // collision half-width (narrower than the art)

  final rnd = Random();
  final platforms = <IcePlatform>[];
  late IcyPlayer player;
  late FxLayer fx;
  late IcyHud hud;
  late DPad dpad;
  late PressButton jumpButton;
  GameOverPanel? panel;

  bool over = false, started = false, scrolling = false;
  double camY = 0, time = 0, shake = 0, scrollT = 0;
  int speedLevel = 0;
  int nextIndex = 0;
  double nextY = 0;
  int score = 0, bonus = 0, maxFloor = 0, lastLandFloor = 0;
  int comboJumps = 0, comboFloors = 0, bestCombo = 0;
  double comboTimer = 0;
  double jumpBufferT = 0, coyoteT = 0, jumpT = 0;
  bool keyLeft = false, keyRight = false, keyJump = false;

  double get scrollSpeed => 26.0 + speedLevel * 18;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    player = IcyPlayer()..priority = 3;
    fx = FxLayer()..priority = 5;
    world.addAll([player, fx]);
    hud = IcyHud()..priority = 10;
    dpad = DPad()..priority = 20;
    jumpButton = PressButton(
      size: Vector2.all(96),
      circle: true,
      onDown: () => jumpBufferT = jumpBuffer,
      painter: paintJumpButton,
      layout: (s) => Vector2(s.x - 18 - 96, s.y - 18 - 96),
    )..priority = 20;
    // Backdrop renders behind the world; screen-space layers live in the
    // viewport so the camera draws them on top of the world.
    add(TowerBackdrop()..priority = -10);
    camera.viewport.addAll([SnowLayer()..priority = 6, hud, dpad, jumpButton]);
    startRound();
  }

  void startRound() {
    for (final p in platforms.toList()) {
      p.removeFromParent();
    }
    platforms.clear();
    fx.clear();
    for (final t in world.children.whereType<FloatingText>().toList()) {
      t.removeFromParent();
    }
    for (final t in camera.viewport.children.whereType<FloatingText>().toList()) {
      t.removeFromParent();
    }
    panel?.removeFromParent();
    panel = null;

    over = started = scrolling = false;
    time = shake = scrollT = 0;
    speedLevel = 0;
    score = bonus = maxFloor = lastLandFloor = 0;
    comboJumps = comboFloors = bestCombo = 0;
    comboTimer = jumpBufferT = coyoteT = 0;
    camY = -size.y * .72;
    nextIndex = 0;
    nextY = 0;
    generate();
    player.reset(Vector2(size.x / 2, 0), platforms.first);
    hud.banner('تسلّق البرج! 🧊', 'CLIMB THE TOWER');
  }

  // ---------- level generation ----------
  double difficulty(int i) => (i / 160).clamp(0.0, 1.0);

  void generate() {
    while (nextY > camY - size.y * 1.2) {
      spawnPlatform(nextIndex, nextY);
      nextIndex++;
      final d = difficulty(nextIndex);
      nextY -= 88 + 36 * d + rnd.nextDouble() * 10;
    }
  }

  void spawnPlatform(int i, double y) {
    final d = difficulty(i);
    final inner = size.x - wallW * 2;
    PlatformKind kind = PlatformKind.normal;
    double width;
    if (i % 25 == 0) {
      kind = PlatformKind.milestone;
      width = inner;
    } else {
      width = max(64.0, inner * (.5 - .26 * d) + rnd.nextDouble() * inner * .12);
      final r = rnd.nextDouble();
      final movingP = i >= 12 ? .12 + .26 * d : 0.0;
      final crumbleP = i >= 20 ? .08 + .16 * d : 0.0;
      if (r < movingP) {
        kind = PlatformKind.moving;
      } else if (r < movingP + crumbleP) {
        kind = PlatformKind.crumbling;
      }
    }
    final x = wallW + rnd.nextDouble() * (inner - width);
    final p = IcePlatform(
      index: i,
      kind: kind,
      pos: Vector2(x, y),
      width: width,
      vx: kind == PlatformKind.moving ? (40 + 100 * d) * (rnd.nextBool() ? 1 : -1) : 0,
      minX: wallW,
      maxX: size.x - wallW,
    );
    if (kind == PlatformKind.normal && width > 90 && rnd.nextDouble() < .18) {
      p.add(Penguin(Vector2(rnd.nextBool() ? 16 : width - 16, 0)));
    }
    platforms.add(p);
    world.add(p);
  }

  // ---------- main loop ----------
  @override
  void update(double dt) {
    dt = min(dt, 1 / 30);
    super.update(dt);
    time += dt;
    if (!over) {
      stepPlayer(dt);
      updateCamera(dt);
      if (comboTimer > 0) {
        comboTimer -= dt;
        if (comboTimer <= 0) endCombo();
      }
      generate();
      for (final p in platforms.toList()) {
        if (p.y > camY + size.y + 150) p.removeFromParent();
      }
      if (player.y - 30 > camY + size.y) gameOver();
    } else {
      player.vel.y = min(player.vel.y + gravity * dt, 1500);
      player.position += player.vel * dt;
    }
    shake = max(0, shake - dt * 30);
    final s = shake > 0 ? shake : 0.0;
    camera.viewfinder.position =
        Vector2((rnd.nextDouble() - .5) * s, camY + (rnd.nextDouble() - .5) * s);
  }

  bool overlaps(IcePlatform pl) =>
      player.x + playerHalfW > pl.x && player.x - playerHalfW < pl.x + pl.width;

  void stepPlayer(double dt) {
    final p = player;
    final v = p.vel;
    final left = dpad.dir < 0 || keyLeft, right = dpad.dir > 0 || keyRight;
    final dir = (right ? 1 : 0) - (left ? 1 : 0);
    final jumpHeld = jumpButton.held || keyJump;
    jumpBufferT -= dt;
    coyoteT -= dt;
    final onGround = p.ground != null;

    // Horizontal: accelerate while held, slide on ice when released.
    if (dir != 0) {
      var a = onGround ? runAccel : airAccel;
      if (v.x * dir < 0) a *= onGround ? 1.7 : 1.3; // snappy turnarounds
      v.x += dir * a * dt;
      p.facing = dir.toDouble();
    } else {
      final f = (onGround ? groundFriction : airFriction) * dt;
      v.x = v.x.abs() <= f ? 0 : v.x - f * v.x.sign;
    }
    v.x = v.x.clamp(-maxRun, maxRun);

    // Jump (buffered press, coyote time, or hold to keep bouncing).
    if ((jumpBufferT > 0 || (jumpHeld && onGround)) && (onGround || coyoteT > 0)) {
      doJump();
    }

    final g0 = p.ground;
    if (g0 != null) p.x += g0.dx; // ride moving platforms
    if (p.ground == null) {
      // Releasing jump early cuts the jump short (after a minimum hop).
      jumpT += dt;
      final g = v.y < 0 && !jumpHeld && jumpT > minJumpTime ? gravity * 1.8 : gravity;
      v.y = min(v.y + g * dt, 1500);
    }

    p.x += v.x * dt;
    final minX = wallW + 13, maxX = size.x - wallW - 13;
    if (p.x < minX || p.x > maxX) {
      p.x = p.x.clamp(minX, maxX);
      if (v.x != 0) {
        final airborne = p.ground == null;
        // Icy Tower wall bounce: keeps momentum in the air.
        v.x = -v.x * (airborne ? .8 : .3);
        if (airborne && v.x.abs() > 150) {
          fx.puff(Vector2(p.x + (p.x < size.x / 2 ? -12 : 12), p.y - 22), 5, spread: 60);
        }
      }
    }

    final ground = p.ground;
    if (ground != null) {
      if (!ground.solid || !ground.isMounted || !overlaps(ground)) {
        p.ground = null;
        coyoteT = coyoteTime;
      } else {
        p.y = ground.y;
        v.y = 0;
      }
    } else {
      final prevFeet = p.y;
      p.y += v.y * dt;
      if (v.y >= 0) {
        IcePlatform? hit;
        for (final pl in platforms) {
          if (!pl.solid || !overlaps(pl)) continue;
          if (prevFeet <= pl.y + 2 && p.y >= pl.y && (hit == null || pl.y < hit.y)) hit = pl;
        }
        if (hit != null) land(hit);
      }
    }
  }

  void doJump() {
    final v = player.vel;
    final speed = v.x.abs();
    v.y = -(baseJump + speed * speedJumpBonus);
    player.ground = null;
    coyoteT = jumpBufferT = jumpT = 0;
    player.onJump(spin: speed > maxRun * .82);
    fx.puff(player.position.clone(), 5, spread: 90);
    started = true;
  }

  void land(IcePlatform pl) {
    final impact = player.vel.y;
    player.y = pl.y;
    player.vel.y = 0;
    player.ground = pl;
    player.onLand(impact);
    pl.trigger();
    fx.puff(Vector2(player.x, pl.y), 6 + (impact / 110).round(),
        color: pl.kind == PlatformKind.milestone ? const Color(0xffFFF3C4) : Colors.white);
    if (impact > 1250) shake = 5;

    final n = pl.index;
    final jumped = n - lastLandFloor;
    if (jumped >= 2) {
      comboJumps++;
      comboFloors += jumped;
      comboTimer = comboWindow;
      world.add(FloatingText(Vector2(player.x, pl.y - 60),
          [('+$jumped', 22, const Color(0xffFFE066))], life: .8));
      if (comboJumps >= 2) fx.sparkle(Vector2(player.x, pl.y - 20), 8 + comboJumps * 2);
    } else {
      endCombo();
    }
    lastLandFloor = n;
    if (n > maxFloor) {
      if (n ~/ 25 > maxFloor ~/ 25) {
        fx.confetti(Vector2(size.x / 2, pl.y - 40), 40);
        hud.banner('الطابق $n! 🏔️', 'MILESTONE');
      }
      maxFloor = n;
      if (!scrolling && n >= 5) {
        scrolling = true;
        speedLevel = 1;
        hud.banner('البرج يتحرك! 🚀', "DON'T FALL BEHIND");
      }
    }
    recomputeScore();
  }

  void endCombo() {
    if (comboJumps >= 2) {
      final pts = comboFloors * comboFloors;
      bonus += pts;
      bestCombo = max(bestCombo, comboFloors);
      final (ar, en) = comboFloors < 8
          ? ('رائع!', 'GOOD')
          : comboFloors < 15
              ? ('مذهل!', 'SWEET')
              : comboFloors < 25
                  ? ('خارق!', 'AMAZING')
                  : ('أسطوري!', 'LEGENDARY');
      camera.viewport.add(FloatingText(Vector2(size.x / 2, size.y * .4), [
        ('$ar $en', 30, const Color(0xffFFE066)),
        ('COMBO $comboFloors FLOORS  +$pts', 17, Colors.white),
      ], life: 1.6, rise: 25)
        ..priority = 12);
      fx.confetti(Vector2(player.x, player.y - 30), 18 + comboFloors);
    }
    comboJumps = comboFloors = 0;
    comboTimer = 0;
    recomputeScore();
  }

  void recomputeScore() => score = maxFloor * 10 + bonus;

  void updateCamera(double dt) {
    final desired = player.y - size.y * .55;
    if (desired < camY) camY += (desired - camY) * (1 - exp(-7 * dt));
    // Never let the player leave through the top of the screen.
    final topLimit = player.y - 60 - size.y * .12;
    if (topLimit < camY) camY = topLimit;
    if (scrolling) {
      scrollT += dt;
      final lvl = min(6, 1 + scrollT ~/ 25);
      if (lvl != speedLevel) {
        speedLevel = lvl;
        hud.banner('أسرع! ⚡', 'HURRY UP!');
      }
      camY -= scrollSpeed * dt;
    }
  }

  void gameOver() {
    over = true;
    endCombo();
    final newBest = score > bestScore;
    bestScore = max(bestScore, score);
    bestFloor = max(bestFloor, maxFloor);
    shake = 8;
    player.vel.setValues(0, -300);
    panel = GameOverPanel(newBest: newBest)..priority = 30;
    camera.viewport.add(panel!);
  }

  // ---------- keyboard (desktop / web testing) ----------
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    keyLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    keyRight = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    final j = keysPressed.contains(LogicalKeyboardKey.space) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    if (j && !keyJump) {
      if (over) {
        if ((panel?.t ?? 0) >= 1) startRound();
      } else {
        jumpBufferT = jumpBuffer;
      }
    }
    keyJump = j;
    return KeyEventResult.handled;
  }

  static void paintJumpButton(Canvas c, PressButton b) {
    final r = b.size.x / 2;
    final center = Offset(r, r);
    final s = 1 - b.press * .08;
    c.save();
    c.translate(r, r);
    c.scale(s);
    c.translate(-r, -r);
    c.drawCircle(center + const Offset(0, 4), r - 2, Paint()..color = const Color(0x55000000));
    c.drawCircle(
        center,
        r - 2,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, r * 2), [
            Color.lerp(const Color(0xff7FE0FF), Colors.white, b.press * .4)!,
            const Color(0xff2E8BE6),
          ]));
    c.drawCircle(
        center,
        r - 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: .85));
    final arrow = Path()
      ..moveTo(r, r - 22)
      ..lineTo(r + 20, r)
      ..lineTo(r + 8, r)
      ..lineTo(r + 8, r + 14)
      ..lineTo(r - 8, r + 14)
      ..lineTo(r - 8, r)
      ..lineTo(r - 20, r)
      ..close();
    c.drawPath(arrow, Paint()..color = Colors.white);
    final tp = cachedText('قفز', 13, Colors.white, rtl: true);
    tp.paint(c, Offset(r - tp.width / 2, r + 17));
    c.restore();
  }
}

// ---------- text helper ----------
final _textCache = <String, TextPainter>{};

TextPainter cachedText(String s, double fontSize, Color color,
    {bool rtl = false, FontWeight weight = FontWeight.w900}) {
  final key = '$s|$fontSize|${color.toARGB32()}|$rtl|${weight.value}';
  final hit = _textCache[key];
  if (hit != null) return hit;
  if (_textCache.length > 300) _textCache.clear();
  return _textCache[key] = TextPainter(
    text: TextSpan(
        text: s,
        style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: weight,
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 2))])),
    textAlign: TextAlign.center,
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
  )..layout();
}

void paintTextCentered(Canvas c, String s, Offset center, double fs, Color color,
    {bool rtl = false}) {
  final tp = cachedText(s, fs, color, rtl: rtl);
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

double easeOutBack(double t) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
}

// ---------- player ----------
class IcyPlayer extends PositionComponent with HasGameReference<IcyTowerGame> {
  final vel = Vector2.zero();
  IcePlatform? ground;
  double facing = 1;
  double sx = 1, sy = 1; // squash & stretch
  double spin = 0;
  bool spinning = false;
  double runPhase = 0, blinkT = 2, t = 0;

  IcyPlayer() : super(size: Vector2(34, 46), anchor: Anchor.bottomCenter);

  void reset(Vector2 pos, IcePlatform start) {
    position.setFrom(pos);
    vel.setZero();
    ground = start;
    facing = 1;
    sx = sy = 1;
    spin = 0;
    spinning = false;
  }

  void onJump({required bool spin}) {
    sx = .78;
    sy = 1.28;
    spinning = spin;
  }

  void onLand(double impact) {
    final k = (impact / 1400).clamp(.25, 1.0);
    sx = 1 + .32 * k;
    sy = 1 - .3 * k;
    spinning = false;
    spin = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    final k = 1 - exp(-14 * dt);
    sx += (1 - sx) * k;
    sy += (1 - sy) * k;
    if (spinning) spin += dt * 13;
    if (ground != null && vel.x.abs() > 30) {
      runPhase += vel.x.abs() * dt * .055;
    } else {
      runPhase += (0 - sin(runPhase)) * .2;
    }
    blinkT -= dt;
    if (blinkT < -.12) blinkT = 2 + Random().nextDouble() * 2.5;
    if (spinning && game.rnd.nextDouble() < .5) {
      game.fx.trail(Vector2(x, y - 22));
    }
  }

  @override
  void render(Canvas c) {
    final air = ground == null;
    c.save();
    c.translate(size.x / 2, size.y);
    c.rotate(vel.x / IcyTowerGame.maxRun * .12);
    c.scale(sx * facing, sy);
    if (spin != 0) {
      c.translate(0, -23);
      c.rotate(spin);
      c.translate(0, 23);
    }

    final step = sin(runPhase) * 4;
    final boot = Paint()..color = const Color(0xff5B3A29);
    // boots
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-10 + step, air ? -9 : -6, 9, 6),
            const Radius.circular(3)),
        boot);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(1 - step, air ? -8 : -6, 9, 6),
            const Radius.circular(3)),
        boot);

    // arms (up when airborne)
    final arm = Paint()..color = const Color(0xffE85D2A);
    final armA = air ? -2.4 : sin(runPhase) * .6;
    for (final (ox, a) in [(-11.0, armA), (11.0, air ? 2.4 : -armA)]) {
      c.save();
      c.translate(ox, -24);
      c.rotate(a);
      c.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-3, 0, 6, 12), const Radius.circular(3)),
          arm);
      c.drawCircle(const Offset(0, 12), 3.2, Paint()..color = const Color(0xff3A86FF)); // mitten
      c.restore();
    }

    // coat
    const coat = Rect.fromLTWH(-12, -29, 24, 24);
    c.drawRRect(
        RRect.fromRectAndRadius(coat, const Radius.circular(9)),
        Paint()
          ..shader = ui.Gradient.linear(
              coat.topCenter, coat.bottomCenter, [const Color(0xffFF9A4D), const Color(0xffF26A2E)]));
    c.drawLine(const Offset(2, -25), const Offset(2, -8),
        Paint()
          ..color = Colors.white.withValues(alpha: .55)
          ..strokeWidth = 1.5);

    // scarf + flapping tail
    final scarf = Paint()..color = const Color(0xffE63946);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -31, 26, 6), const Radius.circular(3)),
        scarf);
    c.save();
    c.translate(-9, -28);
    c.rotate(2.6 + sin(t * 16) * .25 + (air ? -.5 : 0) - vel.x.abs() / 1400);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, -2.5, 10 + vel.x.abs() / 90, 5),
            const Radius.circular(2.5)),
        scarf);
    c.restore();

    // head
    c.drawCircle(const Offset(0, -38), 11.5, Paint()..color = const Color(0xffFFD6A5));
    c.drawCircle(const Offset(10, -34), 2.6, Paint()..color = const Color(0x66FF6B8B));
    c.drawCircle(const Offset(-1, -33.5), 2.6, Paint()..color = const Color(0x66FF6B8B));

    // eyes (blink)
    final eyeH = blinkT < 0 ? 1.0 : 5.0;
    final eye = Paint()..color = const Color(0xff1F2937);
    c.drawOval(Rect.fromCenter(center: const Offset(3, -38.5), width: 3.4, height: eyeH), eye);
    c.drawOval(Rect.fromCenter(center: const Offset(8.5, -38.5), width: 3.4, height: eyeH), eye);
    // mouth
    if (air) {
      c.drawCircle(const Offset(6.5, -32.5), 1.9, eye);
    } else {
      c.drawArc(Rect.fromCenter(center: const Offset(6, -34), width: 7, height: 5), .3, 2.5,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0xff1F2937));
    }

    // beanie
    final hat = Path()
      ..addArc(Rect.fromCircle(center: const Offset(0, -40), radius: 12.5), pi, pi)
      ..close();
    c.drawPath(hat, Paint()..color = const Color(0xff3A86FF));
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -42, 26, 5), const Radius.circular(2.5)),
        Paint()..color = const Color(0xff8EC5FF));
    c.drawCircle(Offset(-1 + sin(t * 5) * .8, -53), 4.2, Paint()..color = Colors.white);
    c.restore();
  }
}

// ---------- platforms ----------
class IcePlatform extends PositionComponent with HasGameReference<IcyTowerGame> {
  static const thickness = 18.0, crumbleDelay = .45;
  static const zones = [
    (Color(0xffE3F8FF), Color(0xff5EC8F2)), // ice
    (Color(0xffD9FFF0), Color(0xff34C99A)), // mint
    (Color(0xffEEE3FF), Color(0xff9B7BFF)), // lavender
    (Color(0xffFFE3F1), Color(0xffFF7FB5)), // pink
    (Color(0xffFFF6CF), Color(0xffF5B83D)), // gold
  ];

  final int index;
  final PlatformKind kind;
  double vx;
  final double minX, maxX;
  double dx = 0, crumbleT = -1, fallV = 0, opacity = 1;
  bool solid = true;
  late final List<double> bumps, icicles;

  IcePlatform({
    required this.index,
    required this.kind,
    required Vector2 pos,
    required double width,
    this.vx = 0,
    this.minX = 0,
    this.maxX = 0,
  }) : super(position: pos, size: Vector2(width, thickness)) {
    final r = Random(index * 7919 + 13);
    bumps = [for (double x = 8; x < width - 8; x += 14 + r.nextDouble() * 16) x];
    icicles = [for (double x = 7; x < width - 7; x += 11 + r.nextDouble() * 14) x];
  }

  void trigger() {
    if (kind == PlatformKind.crumbling && crumbleT < 0) crumbleT = 0;
  }

  @override
  void onRemove() {
    game.platforms.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final oldX = x;
    if (kind == PlatformKind.moving) {
      x += vx * dt;
      if (x < minX) {
        x = minX;
        vx = vx.abs();
      } else if (x + width > maxX) {
        x = maxX - width;
        vx = -vx.abs();
      }
    }
    dx = x - oldX;
    if (crumbleT >= 0) {
      crumbleT += dt;
      if (crumbleT > crumbleDelay) {
        if (solid) game.fx.puff(Vector2(x + width / 2, y + 6), 10, spread: width);
        solid = false;
        fallV += 1400 * dt;
        y += fallV * dt;
        opacity = (1 - (crumbleT - crumbleDelay) / .6).clamp(0.0, 1.0);
        if (opacity <= 0) removeFromParent();
      }
    }
  }

  @override
  void renderTree(Canvas c) {
    if (opacity < 1) {
      c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: opacity));
      super.renderTree(c);
      c.restore();
    } else {
      super.renderTree(c);
    }
  }

  @override
  void render(Canvas c) {
    final w = width, h = height;
    final shakeX = crumbleT >= 0 && solid ? sin(crumbleT * 70) * 2.2 : 0.0;
    c.save();
    c.translate(shakeX, 0);
    var (top, bottom) = zones[(index ~/ 25) % zones.length];
    if (kind == PlatformKind.milestone) {
      top = const Color(0xffFFF3B0);
      bottom = const Color(0xffF2A93B);
    } else if (kind == PlatformKind.moving) {
      top = const Color(0xffC8F3FF);
      bottom = const Color(0xff22A7E0);
    } else if (kind == PlatformKind.crumbling) {
      top = const Color(0xffF4FBFF);
      bottom = const Color(0xffA9C9DA);
    }

    // icicles
    final ice = Paint()..color = bottom.withValues(alpha: .85);
    for (final ix in icicles) {
      final len = 5 + ((ix * 13.7 + index) % 8);
      c.drawPath(
          Path()
            ..moveTo(ix - 3.5, h - 2)
            ..lineTo(ix + 3.5, h - 2)
            ..lineTo(ix, h + len)
            ..close(),
          ice);
    }
    // body
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(9));
    c.drawRRect(body.shift(const Offset(0, 3)), Paint()..color = const Color(0x33000000));
    c.drawRRect(
        body, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [top, bottom]));
    c.drawLine(Offset(8, h * .45), Offset(w - 8, h * .45),
        Paint()
          ..color = Colors.white.withValues(alpha: .35)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);

    if (kind == PlatformKind.crumbling) {
      final crack = Paint()
        ..color = const Color(0xff6C8EA3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      for (double cx = w * .22; cx < w - 10; cx += w * .28) {
        c.drawPath(
            Path()
              ..moveTo(cx, 2)
              ..lineTo(cx + 5, h * .4)
              ..lineTo(cx - 2, h * .65)
              ..lineTo(cx + 4, h - 1),
            crack);
      }
    }
    if (kind == PlatformKind.moving) {
      final arrow = Paint()..color = Colors.white.withValues(alpha: .9);
      for (final (ax, d) in [(9.0, -1.0), (w - 9, 1.0)]) {
        c.drawPath(
            Path()
              ..moveTo(ax + d * 4, h / 2)
              ..lineTo(ax - d * 3, h / 2 - 5)
              ..lineTo(ax - d * 3, h / 2 + 5)
              ..close(),
            arrow);
      }
    }

    // snow cap
    final snow = Paint()..color = Colors.white;
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-2, -4, w + 4, 8), const Radius.circular(5)), snow);
    for (final bx in bumps) {
      c.drawCircle(Offset(bx, -3), 4.5 + (bx % 3), snow);
    }

    if (kind == PlatformKind.milestone || (index % 10 == 0 && index > 0)) {
      final label = index == 0 ? '🏁' : '$index';
      final plaqueW = 34.0 + label.length * 6;
      final plaque = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w / 2, h / 2 + 2), width: plaqueW, height: 17),
          const Radius.circular(8));
      c.drawRRect(plaque, Paint()..color = const Color(0xcc1F3A5F));
      paintTextCentered(c, label, Offset(w / 2, h / 2 + 2), 12, Colors.white);
    }
    c.restore();
  }
}

class Penguin extends PositionComponent {
  double t = Random().nextDouble() * 10;
  Penguin(Vector2 pos) : super(position: pos, size: Vector2(22, 26), anchor: Anchor.bottomCenter);

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
  }

  @override
  void render(Canvas c) {
    final bob = sin(t * 3) * 1.2;
    final waving = sin(t * .8) > .55;
    c.save();
    c.translate(11, 26 + bob - 3);
    final black = Paint()..color = const Color(0xff243447);
    // flippers
    for (final (s, a) in [(-1.0, .4), (1.0, waving ? -2.2 + sin(t * 14) * .5 : -.4)]) {
      c.save();
      c.translate(8.5 * s, -14);
      c.rotate(a * s);
      c.drawOval(const Rect.fromLTWH(-2.5, 0, 5, 11), black);
      c.restore();
    }
    c.drawOval(const Rect.fromLTWH(-9, -23, 18, 23), black);
    c.drawOval(const Rect.fromLTWH(-6, -17, 12, 16), Paint()..color = Colors.white);
    c.drawCircle(const Offset(-3, -17), 1.5, black);
    c.drawCircle(const Offset(3, -17), 1.5, black);
    c.drawPath(
        Path()
          ..moveTo(-2.5, -14)
          ..lineTo(2.5, -14)
          ..lineTo(0, -11)
          ..close(),
        Paint()..color = const Color(0xffFFA630));
    final foot = Paint()..color = const Color(0xffFFA630);
    c.drawOval(const Rect.fromLTWH(-7, -2, 6, 3), foot);
    c.drawOval(const Rect.fromLTWH(1, -2, 6, 3), foot);
    c.restore();
  }
}

// ---------- particles ----------
class _Particle {
  final Vector2 pos, vel;
  double life;
  final double maxLife, size, gravity, drag, spinSpeed;
  double angle = 0;
  final Color color;
  final int shape; // 0 circle, 1 sparkle, 2 confetti
  _Particle(this.pos, this.vel, this.life, this.size, this.color, this.shape,
      {this.gravity = 0, this.drag = 0, this.spinSpeed = 0})
      : maxLife = life;
}

class FxLayer extends Component {
  final _parts = <_Particle>[];
  final _rnd = Random();
  static const _festive = [
    Color(0xffFFE066),
    Color(0xff7FE0FF),
    Color(0xffFF7FB5),
    Color(0xff8CF29A),
    Color(0xffB79CFF)
  ];

  void clear() => _parts.clear();

  void puff(Vector2 at, int n, {Color color = Colors.white, double spread = 30}) {
    for (int i = 0; i < n; i++) {
      final dir = _rnd.nextBool() ? 1 : -1;
      _parts.add(_Particle(
          at + Vector2((_rnd.nextDouble() - .5) * spread, -2),
          Vector2(dir * (40 + _rnd.nextDouble() * 150), -20 - _rnd.nextDouble() * 110),
          .35 + _rnd.nextDouble() * .35,
          2 + _rnd.nextDouble() * 3.5,
          color,
          0,
          gravity: 380,
          drag: 3));
    }
  }

  void sparkle(Vector2 at, int n) {
    for (int i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * pi * 2, s = 80 + _rnd.nextDouble() * 180;
      _parts.add(_Particle(at.clone(), Vector2(cos(a) * s, sin(a) * s - 60),
          .5 + _rnd.nextDouble() * .4, 4 + _rnd.nextDouble() * 4, _festive[i % _festive.length], 1,
          gravity: 250, drag: 2, spinSpeed: 6));
    }
  }

  void confetti(Vector2 at, int n) {
    for (int i = 0; i < n; i++) {
      final a = -pi / 2 + (_rnd.nextDouble() - .5) * 2.2, s = 220 + _rnd.nextDouble() * 320;
      _parts.add(_Particle(at.clone(), Vector2(cos(a) * s, sin(a) * s),
          1 + _rnd.nextDouble() * .7, 5 + _rnd.nextDouble() * 4, _festive[_rnd.nextInt(5)], 2,
          gravity: 520, drag: 1.4, spinSpeed: (_rnd.nextDouble() - .5) * 18));
    }
  }

  void trail(Vector2 at) {
    _parts.add(_Particle(at + Vector2((_rnd.nextDouble() - .5) * 16, (_rnd.nextDouble() - .5) * 16),
        Vector2.zero(), .35, 3 + _rnd.nextDouble() * 3, _festive[_rnd.nextInt(5)], 1,
        spinSpeed: 5));
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final p in _parts) {
      p.vel.y += p.gravity * dt;
      if (p.drag > 0) p.vel.scale(max(0, 1 - p.drag * dt));
      p.pos.addScaled(p.vel, dt);
      p.angle += p.spinSpeed * dt;
      p.life -= dt;
    }
    _parts.removeWhere((p) => p.life <= 0);
  }

  @override
  void render(Canvas c) {
    final paint = Paint();
    for (final p in _parts) {
      final k = (p.life / p.maxLife).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: k);
      switch (p.shape) {
        case 0:
          c.drawCircle(p.pos.toOffset(), p.size * (.6 + .4 * k), paint);
        case 1:
          c.save();
          c.translate(p.pos.x, p.pos.y);
          c.rotate(p.angle);
          final s = p.size * (.5 + .5 * k);
          c.drawPath(
              Path()
                ..moveTo(0, -s)
                ..quadraticBezierTo(0, 0, s, 0)
                ..quadraticBezierTo(0, 0, 0, s)
                ..quadraticBezierTo(0, 0, -s, 0)
                ..quadraticBezierTo(0, 0, 0, -s),
              paint);
          c.restore();
        default:
          c.save();
          c.translate(p.pos.x, p.pos.y);
          c.rotate(p.angle);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * .55),
              paint);
          c.restore();
      }
    }
  }
}

class FloatingText extends PositionComponent {
  final List<(String, double, Color)> lines;
  final double life, rise;
  double t = 0;
  FloatingText(Vector2 pos, this.lines, {this.life = 1, this.rise = 45})
      : super(position: pos, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    y -= rise * dt;
    if (t >= life) removeFromParent();
  }

  @override
  void render(Canvas c) {
    final pop = easeOutBack((t / .25).clamp(0.0, 1.0));
    final fade = (1 - (t - life + .35) / .35).clamp(0.0, 1.0);
    c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: fade));
    c.scale(pop);
    var dy = -lines.fold(0.0, (s, l) => s + l.$2 * 1.25) / 2;
    for (final (s, fs, color) in lines) {
      paintTextCentered(c, s, Offset(0, dy + fs * .62), fs, color);
      dy += fs * 1.25;
    }
    c.restore();
  }
}

// ---------- background & snow (screen space) ----------
class TowerBackdrop extends Component with HasGameReference<IcyTowerGame> {
  static const skies = [
    (Color(0xff1B2A6B), Color(0xff58B4EE)),
    (Color(0xff26185E), Color(0xff8C78F0)),
    (Color(0xff0D3553), Color(0xff3FC1C9)),
    (Color(0xff3A1856), Color(0xffEE86B8)),
  ];
  final _stars = <(double, double, double, double)>[];

  @override
  Future<void> onLoad() async {
    final r = Random(7);
    for (int i = 0; i < 70; i++) {
      _stars.add((r.nextDouble(), r.nextDouble(), .6 + r.nextDouble() * 1.6, r.nextDouble() * 6));
    }
  }

  @override
  void render(Canvas c) {
    final g = game;
    final w = g.size.x, h = g.size.y;
    final climb = -g.camY;

    // sky gradient that shifts colour as you climb
    final zf = max(0.0, climb) / 2600;
    final a = skies[zf.floor() % skies.length], b = skies[(zf.floor() + 1) % skies.length];
    final f = zf - zf.floor();
    c.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h),
              [Color.lerp(a.$1, b.$1, f)!, Color.lerp(a.$2, b.$2, f)!]));

    // stars (far layer)
    final star = Paint();
    for (final (sx, sy, r, ph) in _stars) {
      final y = (sy * h + climb * .05) % h;
      star.color = Colors.white.withValues(alpha: .35 + .45 * (.5 + .5 * sin(g.time * 2 + ph)));
      c.drawCircle(Offset(sx * w, y), r, star);
    }

    // moon
    final moon = Offset(w * .78, h * .15 + climb * .02);
    if (moon.dy < h + 60) {
      c.drawCircle(moon, 44,
          Paint()
            ..color = const Color(0x33FFF6C8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      c.drawCircle(moon, 28, Paint()..color = const Color(0xffFFF6D6));
      c.drawCircle(moon + const Offset(-8, -6), 6, Paint()..color = const Color(0x22B8A66A));
      c.drawCircle(moon + const Offset(9, 7), 4, Paint()..color = const Color(0x22B8A66A));
    }

    // distant ice mountains (fade out below as you climb)
    final base = h * .78 + climb * .18;
    if (base < h + 200) {
      for (final (col, amp, off) in [
        (const Color(0xff9FD8F5), 1.0, 0.0),
        (const Color(0xffD8F2FF), .7, .5),
      ]) {
        final path = Path()..moveTo(0, h);
        for (double x = 0; x <= w + 40; x += 40) {
          final peak = (sin(x * .018 + off * 7) + sin(x * .041 + off)) * 38 * amp;
          path.lineTo(x, base - 70 * amp - peak);
        }
        path
          ..lineTo(w, h)
          ..close();
        c.drawPath(path, Paint()..color = col.withValues(alpha: .55));
      }
      c.drawRect(Rect.fromLTWH(0, base, w, max(0, h - base)),
          Paint()..color = const Color(0x88E6F7FF));
    }

    // back wall of the tower (mid layer)
    const bh = 34.0, bw = 64.0;
    final off = climb * .4;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..strokeWidth = 1.5;
    final r0 = ((-bh - off) / bh).floor(), r1 = ((h - off) / bh).ceil();
    for (int r = r0; r <= r1; r++) {
      final y = r * bh + off;
      c.drawLine(Offset(0, y), Offset(w, y), line);
      final shift = r.isOdd ? bw / 2 : 0.0;
      for (double x = shift; x < w; x += bw) {
        c.drawLine(Offset(x, y), Offset(x, y + bh), line);
      }
      if (r % 5 == 0) {
        final hx = (((r * 2654435761) & 0xffff) / 0xffff) * (w - 120) + 60;
        final win = RRect.fromRectAndCorners(Rect.fromLTWH(hx - 14, y + 4, 28, bh * 1.6),
            topLeft: const Radius.circular(14), topRight: const Radius.circular(14));
        c.drawRRect(win, Paint()..color = const Color(0x40FFE9A8));
        c.drawRRect(
            win,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: .18));
      }
    }

    // side walls (move with the world)
    final wall = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(IcyTowerGame.wallW, 0),
          [const Color(0xff8FD6F5), const Color(0xffD5F3FF)]);
    final wallR = Paint()
      ..shader = ui.Gradient.linear(Offset(w - IcyTowerGame.wallW, 0), Offset(w, 0),
          [const Color(0xffD5F3FF), const Color(0xff8FD6F5)]);
    c.drawRect(Rect.fromLTWH(0, 0, IcyTowerGame.wallW, h), wall);
    c.drawRect(Rect.fromLTWH(w - IcyTowerGame.wallW, 0, IcyTowerGame.wallW, h), wallR);
    final joint = Paint()
      ..color = const Color(0x557BB8D6)
      ..strokeWidth = 1.5;
    final wo = climb % 30;
    for (double y = wo - 30; y < h; y += 30) {
      c.drawLine(Offset(0, y), Offset(IcyTowerGame.wallW, y), joint);
      c.drawLine(Offset(w - IcyTowerGame.wallW, y), Offset(w, y), joint);
    }
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..strokeWidth = 2;
    c.drawLine(const Offset(IcyTowerGame.wallW, 0), Offset(IcyTowerGame.wallW, h), edge);
    c.drawLine(Offset(w - IcyTowerGame.wallW, 0), Offset(w - IcyTowerGame.wallW, h), edge);
  }
}

class SnowLayer extends Component with HasGameReference<IcyTowerGame> {
  final _flakes = <List<double>>[]; // x, y, r, speed, phase
  final _rnd = Random();
  double? _lastCam;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_flakes.isEmpty) {
      for (int i = 0; i < 90; i++) {
        _flakes.add([
          _rnd.nextDouble() * size.x,
          _rnd.nextDouble() * size.y,
          .8 + _rnd.nextDouble() * 2.4,
          18 + _rnd.nextDouble() * 40,
          _rnd.nextDouble() * 6
        ]);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final g = game;
    final dCam = (_lastCam ?? g.camY) - g.camY; // > 0 while climbing
    _lastCam = g.camY;
    for (final f in _flakes) {
      f[1] += f[3] * dt + dCam * (.25 + f[2] * .18);
      f[0] += sin(g.time * 1.3 + f[4]) * 18 * dt;
      if (f[1] > g.size.y + 5) {
        f[1] -= g.size.y + 10;
        f[0] = _rnd.nextDouble() * g.size.x;
      } else if (f[1] < -5) {
        f[1] += g.size.y + 10;
      }
      if (f[0] < 0) f[0] += g.size.x;
      if (f[0] > g.size.x) f[0] -= g.size.x;
    }
  }

  @override
  void render(Canvas c) {
    final p = Paint();
    for (final f in _flakes) {
      p.color = Colors.white.withValues(alpha: .35 + f[2] * .2);
      c.drawCircle(Offset(f[0], f[1]), f[2], p);
    }
  }
}

// ---------- HUD ----------
class IcyHud extends Component with HasGameReference<IcyTowerGame> {
  String? _bannerA, _bannerB;
  double _bannerT = 10;

  void banner(String ar, String en) {
    _bannerA = ar;
    _bannerB = en;
    _bannerT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _bannerT += dt;
  }

  void _pill(Canvas c, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(18));
    c.drawRRect(rr, Paint()..color = const Color(0x661B2A4A));
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: .35));
  }

  @override
  void render(Canvas c) {
    final g = game;
    final w = g.size.x;
    const top = 12.0;

    // score
    _pill(c, const Rect.fromLTWH(30, top, 128, 40));
    paintTextCentered(c, '⭐ ${g.score}', const Offset(94, top + 20), 19, Colors.white);

    // floor
    _pill(c, Rect.fromLTWH(w - 30 - 110, top, 110, 40));
    paintTextCentered(c, '🧊 ${g.maxFloor}', Offset(w - 30 - 55, top + 16), 18, Colors.white);
    paintTextCentered(c, 'FLOOR', Offset(w - 30 - 55, top + 32), 9, Colors.white70);

    if (g.scrolling && !g.over) {
      paintTextCentered(c, '⚡x${g.speedLevel}', Offset(w - 30 - 55, top + 54), 13,
          const Color(0xffFFE066));
    }

    // combo meter
    if (g.comboJumps > 0) {
      final bw = min(200.0, w - 80);
      final r = Rect.fromLTWH((w - bw) / 2, top + 60, bw, 12);
      final k = (g.comboTimer / IcyTowerGame.comboWindow).clamp(0.0, 1.0);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = const Color(0x661B2A4A));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(r.left, r.top, r.width * k, r.height), const Radius.circular(6)),
          Paint()
            ..shader = ui.Gradient.linear(r.centerLeft, r.centerRight,
                [const Color(0xffFFD166), const Color(0xffFF5E9C)]));
      final pulse = 1 + sin(g.time * 12) * .04 * g.comboJumps.clamp(1, 5);
      c.save();
      c.translate(w / 2, top + 88);
      c.scale(pulse);
      paintTextCentered(c, 'COMBO x${g.comboJumps} • ${g.comboFloors} floors', Offset.zero, 15,
          const Color(0xffFFE066));
      c.restore();
    }

    // banner
    if (_bannerA != null && _bannerT < 1.8) {
      final pop = easeOutBack((_bannerT / .3).clamp(0.0, 1.0));
      final fade = (1 - (_bannerT - 1.4) / .4).clamp(0.0, 1.0);
      c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: fade));
      c.translate(w / 2, g.size.y * .22);
      c.scale(pop);
      paintTextCentered(c, _bannerA!, Offset.zero, 30, Colors.white, rtl: true);
      paintTextCentered(c, _bannerB!, const Offset(0, 30), 14, const Color(0xffBFEFFF));
      c.restore();
    }

    // start hint
    if (!g.started && !g.over) {
      final a = .55 + .45 * sin(g.time * 4);
      paintTextCentered(c, 'اضغط ⬆️ للقفز • ⬅️ ➡️ للحركة', Offset(w / 2, g.size.y * .42), 17,
          Colors.white.withValues(alpha: a),
          rtl: true);
      paintTextCentered(c, 'Run fast to jump higher!', Offset(w / 2, g.size.y * .42 + 26), 13,
          Colors.white.withValues(alpha: a * .8));
    }
  }
}

// ---------- controls ----------
/// Press-and-hold button driven by drag events (they fire on pointer down,
/// so the button reacts instantly and stays held even if the finger drifts).
class PressButton extends PositionComponent with DragCallbacks {
  final VoidCallback? onDown, onUp;
  final void Function(Canvas, PressButton) painter;
  final Vector2 Function(Vector2 gameSize)? layout;
  final bool circle;
  final _pointers = <int>{};
  double press = 0;

  PressButton({
    required Vector2 size,
    required this.painter,
    this.onDown,
    this.onUp,
    this.layout,
    this.circle = false,
    Vector2? position,
    Anchor anchor = Anchor.topLeft,
  }) : super(size: size, position: position, anchor: anchor);

  bool get held => _pointers.isNotEmpty;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (layout != null) position = layout!(size);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (circle) return (point - size / 2).length <= size.x / 2 + 14;
    return Rect.fromLTWH(-8, -8, size.x + 16, size.y + 16).contains(point.toOffset());
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final was = held;
    _pointers.add(event.pointerId);
    if (!was) onDown?.call();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_pointers.remove(event.pointerId) && !held) onUp?.call();
  }

  @override
  void update(double dt) {
    super.update(dt);
    press += ((held ? 1 : 0) - press) * (1 - exp(-25 * dt));
  }

  @override
  void render(Canvas c) => painter(c, this);
}

/// Left/right pad: one touch zone, the half under the finger decides the
/// direction, so sliding across switches direction without lifting.
class DPad extends PositionComponent with DragCallbacks {
  final _dirs = <int, int>{};
  double _pl = 0, _pr = 0;

  DPad() : super(size: Vector2(186, 88));

  int get dir => _dirs.isEmpty ? 0 : _dirs.values.last;

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    position = Vector2(18, gameSize.y - 18 - size.y);
  }

  int _dirAt(Vector2 local) => local.x < size.x / 2 ? -1 : 1;

  @override
  bool containsLocalPoint(Vector2 point) =>
      Rect.fromLTWH(-14, -24, size.x + 28, size.y + 38).contains(point.toOffset());

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dirs[event.pointerId] = _dirAt(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dirs.containsKey(event.pointerId)) {
      _dirs.remove(event.pointerId); // re-insert so this finger is the latest
      _dirs[event.pointerId] = _dirAt(event.localEndPosition);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dirs.remove(event.pointerId);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final k = 1 - exp(-25 * dt);
    _pl += ((dir < 0 ? 1 : 0) - _pl) * k;
    _pr += ((dir > 0 ? 1 : 0) - _pr) * k;
  }

  @override
  void render(Canvas c) {
    final r = size.y / 2;
    for (final (cx, d, p) in [(r, -1.0, _pl), (size.x - r, 1.0, _pr)]) {
      final center = Offset(cx, r);
      final s = 1 - p * .08;
      c.save();
      c.translate(center.dx, center.dy);
      c.scale(s);
      c.drawCircle(const Offset(0, 4), r - 2, Paint()..color = const Color(0x44000000));
      c.drawCircle(Offset.zero, r - 2,
          Paint()..color = Color.lerp(const Color(0x55FFFFFF), const Color(0xAAFFFFFF), p)!);
      c.drawCircle(
          Offset.zero,
          r - 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: .8));
      c.drawPath(
          Path()
            ..moveTo(d * 17, 0)
            ..lineTo(-d * 11, -16)
            ..lineTo(-d * 11, 16)
            ..close(),
          Paint()..color = Color.lerp(Colors.white, const Color(0xff2E8BE6), p)!);
      c.restore();
    }
  }
}

// ---------- game over ----------
class GameOverPanel extends Component with HasGameReference<IcyTowerGame> {
  final bool newBest;
  double t = 0;
  late PressButton restart;
  GameOverPanel({required this.newBest});

  static const cardH = 360.0;
  double get cardW => min(330.0, game.size.x - 40);

  @override
  Future<void> onLoad() async {
    restart = PressButton(
      size: Vector2(220, 56),
      anchor: Anchor.center,
      onUp: () {
        if (t >= 1) game.startRound();
      },
      painter: (c, b) {
        final rr = RRect.fromRectAndRadius(Offset.zero & b.size.toSize(), const Radius.circular(28));
        c.drawRRect(rr.shift(const Offset(0, 4)), Paint()..color = const Color(0x552E6B1F));
        c.drawRRect(
            rr,
            Paint()
              ..shader = ui.Gradient.linear(Offset.zero, Offset(0, b.size.y), [
                Color.lerp(const Color(0xff8CF29A), Colors.white, b.press * .3)!,
                const Color(0xff3DBE5A),
              ]));
        paintTextCentered(c, '↻  العب مرة أخرى', Offset(b.size.x / 2, b.size.y / 2 - 6), 19,
            Colors.white,
            rtl: true);
        paintTextCentered(c, 'RESTART', Offset(b.size.x / 2, b.size.y / 2 + 14), 10,
            Colors.white.withValues(alpha: .9));
      },
    );
    add(restart);
  }

  @override
  void update(double dt) {
    super.update(dt);
    t = min(1, t + dt / .45);
    final s = easeOutBack(t);
    final center = game.size / 2;
    restart
      ..scale = Vector2.all(max(.01, s))
      ..position = center + Vector2(0, (cardH / 2 - 50) * s);
  }

  @override
  void render(Canvas c) {
    final g = game;
    c.drawRect(Offset.zero & g.size.toSize(),
        Paint()..color = Colors.black.withValues(alpha: .55 * min(1, t * 2)));
    final s = easeOutBack(t);
    final w = cardW;
    c.save();
    c.translate(g.size.x / 2, g.size.y / 2);
    c.scale(max(.01, s));
    final card = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: cardH), const Radius.circular(30));
    c.drawRRect(card, Paint()..color = const Color(0xffF4FBFF));
    c.save();
    c.clipRRect(card);
    c.drawRect(
        Rect.fromLTWH(-w / 2, -cardH / 2, w, 110),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, -cardH / 2), Offset(0, -cardH / 2 + 110),
              [const Color(0xff58B4EE), const Color(0xff8C78F0)]));
    c.restore();

    paintTextCentered(c, '🧊', Offset(0, -cardH / 2 + 34), 38, Colors.white);
    paintTextCentered(c, 'انتهت الجولة!', Offset(0, -cardH / 2 + 74), 24, Colors.white, rtl: true);
    paintTextCentered(c, 'GAME OVER', Offset(0, -cardH / 2 + 98), 11, Colors.white70);

    const dark = Color(0xff1F2A44);
    final rows = [
      ('🏔️', 'Floor', '${g.maxFloor}'),
      ('⭐', 'Score', '${g.score}'),
      ('🔥', 'Best combo', '${g.bestCombo}'),
      ('🏆', 'Best', '${IcyTowerGame.bestScore}'),
    ];
    var y = -cardH / 2 + 138;
    for (final (icon, label, value) in rows) {
      final l = cachedText('$icon  $label', 16, dark, weight: FontWeight.w800);
      l.paint(c, Offset(-w / 2 + 28, y - l.height / 2));
      final v = cachedText(value, 20, dark);
      v.paint(c, Offset(w / 2 - 28 - v.width, y - v.height / 2));
      y += 34;
    }
    if (newBest) {
      final pulse = 1 + sin(g.time * 8) * .06;
      c.save();
      c.translate(w / 2 - 30, -cardH / 2 + 18);
      c.rotate(.35);
      c.scale(pulse);
      final rr = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 96, height: 26), const Radius.circular(13));
      c.drawRRect(rr, Paint()..color = const Color(0xffFFD166));
      paintTextCentered(c, 'NEW BEST!', Offset.zero, 13, const Color(0xff7A4B00));
      c.restore();
    }
    c.restore();
  }
}
