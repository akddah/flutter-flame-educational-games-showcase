import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'games/icy_tower.dart';

void main() => runApp(const AjyalApp());

class AjyalApp extends StatelessWidget {
  const AjyalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أجيال الصالحية • Game Lab',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5B8E55)),
        fontFamily: 'Arial',
      ),
      home: const Directionality(textDirection: TextDirection.rtl, child: GameHub()),
    );
  }
}

class GameHub extends StatelessWidget {
  const GameHub({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _GameCardData(
          'Ocean Rescue', 'أنقذ البحر', '🌊', const Color(0xffDDF4FF), () => OceanRescueGame()),
      _GameCardData('Recycling Factory', 'مصنع التدوير', '♻️', const Color(0xffE5F6DD),
          () => RecyclingGame()),
      _GameCardData('Animal Adventure', 'مغامرة الحيوانات', '🐰', const Color(0xffFFF0D5),
          () => AnimalGame()),
      _GameCardData('Icy Tower', 'البرج الجليدي', '🧊', const Color(0xffE3EEFF),
          () => IcyTowerGame()),
    ];
    return Scaffold(
      backgroundColor: const Color(0xffFFF9EC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(children: [
              Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: const Text('🦊', style: TextStyle(fontSize: 32))),
              const SizedBox(width: 12),
              const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('أجيال الصالحية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text('GAME LAB • FLUTTER + FLAME',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ])),
              _pill('⭐ 1,240 XP'),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xff8FD3A7), Color(0xffF5D56B)]),
                  borderRadius: BorderRadius.circular(30)),
              child: const Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('جاهز للتحدي؟ 🚀',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('4 ألعاب فعلية • Score • Combo • Levels • Collision',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ])),
                Text('🎮', style: TextStyle(fontSize: 68))
              ]),
            ),
            const SizedBox(height: 24),
            const Text('اختر مغامرتك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...cards.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => GamePage(data: c))),
                    child: Ink(
                      padding: const EdgeInsets.all(18),
                      decoration:
                          BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(26)),
                      child: Row(children: [
                        Container(
                            width: 82,
                            height: 82,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.72),
                                borderRadius: BorderRadius.circular(24)),
                            child: Text(c.emoji, style: const TextStyle(fontSize: 48))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.arabic,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          Text(c.english,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 7),
                          const Text('3 مراحل  •  ⭐⭐⭐',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ])),
                        const CircleAvatar(
                            backgroundColor: Colors.white, child: Icon(Icons.play_arrow_rounded)),
                      ]),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: const Row(children: [
                Text('✨', style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Expanded(
                    child: Text('الديمو معمول بالكامل بـ Flutter + Flame بدون Unity.',
                        style: TextStyle(fontWeight: FontWeight.w800)))
              ]),
            )
          ],
        ),
      ),
    );
  }

  static Widget _pill(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)));
}

class _GameCardData {
  final String english, arabic, emoji;
  final Color color;
  final FlameGame Function() create;
  _GameCardData(this.english, this.arabic, this.emoji, this.color, this.create);
}

class GamePage extends StatefulWidget {
  final _GameCardData data;
  const GamePage({super.key, required this.data});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late FlameGame game;
  @override
  void initState() {
    super.initState();
    game = widget.data.create();
  }

  void restart() {
    setState(() => game = widget.data.create());
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xff111827),
          body: SafeArea(
              child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward)),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.data.arabic,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(widget.data.english,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                ])),
                IconButton.filledTonal(onPressed: restart, icon: const Icon(Icons.refresh_rounded)),
              ]),
            ),
            Expanded(
                child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: GameWidget(game: game),
            )),
          ])),
        ),
      );
}

// ---------- shared game components ----------
class HudText extends TextComponent {
  HudText(String text, Vector2 p, {Anchor anchor = Anchor.topLeft})
      : super(
            text: text,
            position: p,
            anchor: anchor,
            textRenderer: TextPaint(
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    shadows: [
                  Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                ])));
}

class Emoji extends TextComponent {
  Emoji(String e, Vector2 p, double size, {Anchor anchor = Anchor.center})
      : super(
            text: e,
            position: p,
            anchor: anchor,
            textRenderer: TextPaint(style: TextStyle(fontSize: size)));
}

class TapEmoji extends TextComponent with TapCallbacks {
  final void Function(TapEmoji) tapped;
  TapEmoji(String e, Vector2 p, double size, this.tapped)
      : super(
            text: e,
            position: p,
            anchor: Anchor.center,
            textRenderer: TextPaint(style: TextStyle(fontSize: size)));
  @override
  bool containsLocalPoint(Vector2 p) =>
      p.x > -size.x * .35 && p.x < size.x * .35 && p.y > -size.y * .35 && p.y < size.y * .35;
  @override
  void onTapDown(TapDownEvent event) {
    tapped(this);
  }
}

// ---------- OCEAN RESCUE ----------
class OceanRescueGame extends FlameGame with DragCallbacks {
  final rnd = Random();
  late RectangleComponent boat;
  late Emoji boatIcon;
  late HudText scoreText, comboText, timeText;
  int score = 0, combo = 0;
  double timeLeft = 35, spawnClock = 0;
  bool ended = false;

  // Drag steering: the boat keeps the offset between finger and boat from the
  // moment the drag started, so grabbing anywhere never makes it jump.
  static const boatMargin = 45.0;
  static const followSharpness = 28.0; // higher = snappier follow
  int? dragPointer;
  double grabOffset = 0, targetX = 0;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xff3CB7E8)));
    for (int i = 0; i < 10; i++)
      add(Emoji(i.isEven ? '🐠' : '🫧',
          Vector2(rnd.nextDouble() * size.x, rnd.nextDouble() * size.y), 20));
    boat = RectangleComponent(
        position: Vector2(size.x / 2, size.y - 80),
        size: Vector2(86, 55),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.transparent);
    boatIcon = Emoji('🚤', boat.position.clone(), 54);
    targetX = boat.position.x;
    addAll([boat, boatIcon]);
    scoreText = HudText('⭐ 0', Vector2(18, 18));
    comboText = HudText('COMBO x1', Vector2(size.x / 2, 18), anchor: Anchor.topCenter);
    timeText = HudText('⏱ 35', Vector2(size.x - 18, 18), anchor: Anchor.topRight);
    addAll([scoreText, comboText, timeText]);
  }

  double clampBoatX(double x) => x.clamp(boatMargin, size.x - boatMargin);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (ended || dragPointer != null) return;
    dragPointer = event.pointerId;
    grabOffset = boat.position.x - event.canvasPosition.x;
    targetX = boat.position.x;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (ended || event.pointerId != dragPointer) return;
    targetX = clampBoatX(event.canvasEndPosition.x + grabOffset);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId == dragPointer) releaseBoat();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (event.pointerId == dragPointer) releaseBoat();
  }

  void releaseBoat() {
    dragPointer = null;
    targetX = boat.position.x; // stop right where the boat is
  }

  void moveBoat(double dt) {
    final t = 1 - exp(-followSharpness * dt); // frame-rate independent smoothing
    var x = boat.position.x + (targetX - boat.position.x) * t;
    if ((targetX - x).abs() < .5) x = targetX;
    boat.position.x = clampBoatX(x);
    boatIcon.position.setFrom(boat.position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (ended) return;
    moveBoat(dt);
    timeLeft -= dt;
    spawnClock += dt;
    timeText.text = '⏱ ${max(0, timeLeft).ceil()}';
    if (spawnClock > .58) {
      spawnClock = 0;
      spawn();
    }
    if (timeLeft <= 0) {
      ended = true;
      finish();
    }
  }

  void spawn() {
    final good = rnd.nextDouble() > .25;
    final e = good ? ['🥤', '🥫', '🧴', '🛍️'][rnd.nextInt(4)] : ['🐢', '🐟'][rnd.nextInt(2)];
    final obj = FallingThing(e, Vector2(30 + rnd.nextDouble() * (size.x - 60), -30), good,
        130 + rnd.nextDouble() * 100, (o) => hit(o));
    add(obj);
  }

  void hit(FallingThing o) {
    if (ended) return;
    if (o.good) {
      combo++;
      score += 10 * max(1, min(combo, 5));
    } else {
      combo = 0;
      score = max(0, score - 25);
    }
    scoreText.text = '⭐ $score';
    comboText.text = 'COMBO x${max(1, combo)}';
  }

  void finish() {
    add(RectangleComponent(size: size, paint: Paint()..color = Colors.black54));
    add(Emoji('🏆', Vector2(size.x / 2, size.y / 2 - 80), 86));
    add(TextComponent(
        text: 'أحسنت!\nScore: $score',
        position: Vector2(size.x / 2, size.y / 2 + 20),
        anchor: Anchor.center,
        textRenderer: TextPaint(
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900))));
  }
}

class FallingThing extends TextComponent {
  final bool good;
  final double speed;
  final void Function(FallingThing) hit;
  FallingThing(String e, Vector2 p, this.good, this.speed, this.hit)
      : super(
            text: e,
            position: p,
            anchor: Anchor.center,
            textRenderer: TextPaint(style: const TextStyle(fontSize: 42)));
  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;
    final g = findGame() as OceanRescueGame;
    if ((position - g.boat.position).length < 48) {
      hit(this);
      removeFromParent();
    } else if (position.y > g.size.y + 40) {
      if (good) {
        g.combo = 0;
        g.comboText.text = 'COMBO x1';
      }
      removeFromParent();
    }
  }
}

// ---------- RECYCLING FACTORY ----------
class RecyclingGame extends FlameGame {
  final rnd = Random();
  int score = 0, lives = 3;
  double timeLeft = 45, spawnClock = 0;
  bool ended = false;
  late HudText scoreText, livesText, timeText;
  final bins = <String, Rect>{};

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xffF3E5C8)));
    final beltY = size.y * .43;
    add(RectangleComponent(
        position: Vector2(0, beltY),
        size: Vector2(size.x, 110),
        paint: Paint()..color = const Color(0xff58616A)));
    for (double x = 10; x < size.x; x += 55)
      add(RectangleComponent(
          position: Vector2(x, beltY + 48),
          size: Vector2(32, 14),
          paint: Paint()..color = Colors.white24));
    final bw = size.x / 3;
    const cats = ['paper', 'plastic', 'organic'];
    const icons = ['📄', '🧴', '🍎'];
    const labels = ['ورق', 'بلاستيك', 'عضوي'];
    for (int i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(i * bw, size.y - 150, bw, 150);
      bins[cats[i]] = r;
      add(RectangleComponent(
          position: Vector2(r.left + 5, r.top + 5),
          size: Vector2(r.width - 10, r.height - 10),
          paint: Paint()
            ..color =
                [const Color(0xff5CA8E8), const Color(0xffE6C84F), const Color(0xff6FC17A)][i]));
      add(Emoji(icons[i], Vector2(r.center.dx, r.top + 45), 40));
      add(TextComponent(
          text: labels[i],
          position: Vector2(r.center.dx, r.top + 100),
          anchor: Anchor.center,
          textRenderer: TextPaint(
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))));
    }
    scoreText = HudText('⭐ 0', Vector2(16, 16));
    livesText = HudText('❤️❤️❤️', Vector2(size.x / 2, 16), anchor: Anchor.topCenter);
    timeText = HudText('⏱ 45', Vector2(size.x - 16, 16), anchor: Anchor.topRight);
    addAll([scoreText, livesText, timeText]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (ended) return;
    timeLeft -= dt;
    spawnClock += dt;
    timeText.text = '⏱ ${max(0, timeLeft).ceil()}';
    if (spawnClock > .9) {
      spawnClock = 0;
      spawn();
    }
    if (timeLeft <= 0 || lives <= 0) {
      ended = true;
      finish();
    }
  }

  void spawn() {
    const pool = [
      ('📰', 'paper'),
      ('📦', 'paper'),
      ('🧴', 'plastic'),
      ('🥤', 'plastic'),
      ('🍎', 'organic'),
      ('🍌', 'organic')
    ];
    final it = pool[rnd.nextInt(pool.length)];
    add(FactoryItem(it.$1, it.$2, Vector2(-30, size.y * .43 + 55), 95 + rnd.nextDouble() * 45));
  }

  void resolve(FactoryItem item, String? cat) {
    if (cat == item.cat) {
      score += 20;
      scoreText.text = '⭐ $score';
    } else {
      lives--;
      livesText.text = '❤️' * max(0, lives);
    }
  }

  void finish() {
    add(RectangleComponent(size: size, paint: Paint()..color = Colors.black54));
    add(Emoji('♻️', Vector2(size.x / 2, size.y / 2 - 70), 82));
    add(TextComponent(
        text: 'المصنع نظيف!\nScore: $score',
        position: Vector2(size.x / 2, size.y / 2 + 30),
        anchor: Anchor.center,
        textRenderer: TextPaint(
            style:
                const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))));
  }
}

class FactoryItem extends TextComponent with DragCallbacks {
  final String cat;
  final double speed;
  bool dragging = false;
  FactoryItem(String e, this.cat, Vector2 p, this.speed)
      : super(
            text: e,
            position: p,
            anchor: Anchor.center,
            textRenderer: TextPaint(style: const TextStyle(fontSize: 46)));
  @override
  void update(double dt) {
    super.update(dt);
    if (dragging) return;
    position.x += speed * dt;
    final g = findGame() as RecyclingGame;
    if (position.x > g.size.x + 40) {
      g.resolve(this, null);
      removeFromParent();
    }
  }

  @override
  void onDragStart(DragStartEvent e) {
    super.onDragStart(e);
    dragging = true;
    priority = 100;
  }

  @override
  void onDragUpdate(DragUpdateEvent e) {
    position += e.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent e) {
    super.onDragEnd(e);
    final g = findGame() as RecyclingGame;
    String? target;
    for (final x in g.bins.entries) {
      if (x.value.contains(Offset(position.x, position.y))) target = x.key;
    }
    if (target != null) {
      g.resolve(this, target);
      removeFromParent();
    } else
      dragging = false;
  }
}

// ---------- ANIMAL ADVENTURE ----------
class AnimalGame extends FlameGame with DragCallbacks {
  final rnd = Random();
  int score = 0, round = 0;
  double timeLeft = 50;
  bool ended = false;
  late HudText scoreText, timeText, missionText;
  late Emoji hero;

  // Drag steering (same feel as Ocean Rescue, but free X/Y): the hero keeps the
  // finger-to-hero offset from the moment the drag started, so it never jumps.
  static const heroMargin = 30.0;
  static const heroTopLimit = 100.0; // keep the hero below the HUD / mission text
  static const followSharpness = 28.0; // higher = snappier follow
  int? dragPointer;
  final grabOffset = Vector2.zero(), target = Vector2.zero();
  Emoji animal = Emoji('🐰', Vector2.zero(), 1);
  String needed = '🥕';
  final foods = ['🥕', '🍌', '🎋', '🍎'];

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xffBFE69A)));
    for (int i = 0; i < 8; i++)
      add(Emoji(['🌳', '🌼', '🪨'][rnd.nextInt(3)],
          Vector2(rnd.nextDouble() * size.x, 90 + rnd.nextDouble() * (size.y - 180)), 30));
    hero = Emoji('🧒', Vector2(size.x / 2, size.y - 80), 56);
    target.setFrom(hero.position);
    add(hero);
    scoreText = HudText('⭐ 0', Vector2(16, 16));
    timeText = HudText('⏱ 50', Vector2(size.x - 16, 16), anchor: Anchor.topRight);
    missionText = HudText('', Vector2(size.x / 2, 58), anchor: Anchor.topCenter);
    addAll([scoreText, timeText, missionText]);
    nextRound();
  }

  void nextRound() {
    if (round >= 6) {
      ended = true;
      finish();
      return;
    }
    round++;
    const missions = [('🐰', '🥕'), ('🐵', '🍌'), ('🐼', '🎋')];
    final m = missions[rnd.nextInt(missions.length)];
    needed = m.$2;
    animal.removeFromParent();
    animal = Emoji(
        m.$1,
        Vector2(55 + rnd.nextDouble() * (size.x - 110), 140 + rnd.nextDouble() * (size.y * .32)),
        70);
    add(animal);
    missionText.text = 'المهمة: اجمع $needed ثم أطعم ${m.$1}';
    for (int i = 0; i < 5; i++) {
      final f = foods[rnd.nextInt(foods.length)];
      add(FoodPickup(f,
          Vector2(45 + rnd.nextDouble() * (size.x - 90), 170 + rnd.nextDouble() * (size.y - 300))));
    }
  }

  bool carrying = false;
  Vector2 clampHero(Vector2 p) => Vector2(p.x.clamp(heroMargin, size.x - heroMargin),
      p.y.clamp(heroTopLimit, size.y - heroMargin));

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (ended || dragPointer != null) return;
    dragPointer = event.pointerId;
    grabOffset.setFrom(hero.position - event.canvasPosition);
    target.setFrom(hero.position);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (ended || event.pointerId != dragPointer) return;
    target.setFrom(clampHero(event.canvasEndPosition + grabOffset));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId == dragPointer) releaseHero();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (event.pointerId == dragPointer) releaseHero();
  }

  void releaseHero() {
    dragPointer = null;
    target.setFrom(hero.position); // stop right where the hero is
  }

  void moveHero(double dt) {
    final t = 1 - exp(-followSharpness * dt); // frame-rate independent smoothing
    final p = hero.position + (target - hero.position) * t;
    if (p.distanceTo(target) < .5) p.setFrom(target);
    hero.position = clampHero(p);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (ended) return;
    moveHero(dt); // before collision checks, so they use this frame's position
    timeLeft -= dt;
    timeText.text = '⏱ ${max(0, timeLeft).ceil()}';
    for (final f in children.whereType<FoodPickup>().toList()) {
      if ((f.position - hero.position).length < 42) {
        if (f.food == needed) {
          carrying = true;
          f.removeFromParent();
          score += 10;
          scoreText.text = '⭐ $score';
        } else {
          score = max(0, score - 5);
          scoreText.text = '⭐ $score';
          f.removeFromParent();
        }
      }
    }
    if (carrying && (animal.position - hero.position).length < 65) {
      score += 30;
      scoreText.text = '⭐ $score';
      carrying = false;
      for (final f in children.whereType<FoodPickup>().toList()) f.removeFromParent();
      nextRound();
    }
    if (timeLeft <= 0) {
      ended = true;
      finish();
    }
  }

  void finish() {
    add(RectangleComponent(size: size, paint: Paint()..color = Colors.black54));
    add(Emoji('🏆', Vector2(size.x / 2, size.y / 2 - 70), 86));
    add(TextComponent(
        text: 'بطل الحيوانات!\nScore: $score',
        position: Vector2(size.x / 2, size.y / 2 + 30),
        anchor: Anchor.center,
        textRenderer: TextPaint(
            style:
                const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))));
  }
}

class FoodPickup extends TextComponent {
  final String food;
  FoodPickup(this.food, Vector2 p)
      : super(
            text: food,
            position: p,
            anchor: Anchor.center,
            textRenderer: TextPaint(style: const TextStyle(fontSize: 38)));
}
