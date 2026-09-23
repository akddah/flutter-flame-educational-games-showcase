import 'package:ajyal_flame_showcase/games/icy_tower.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Icy Tower: controls, jumping, climbing, game over and restart', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = IcyTowerGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    Future<void> run(double seconds) async {
      for (int i = 0; i < seconds * 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    expect(game.platforms.length, greaterThan(10));
    expect(game.player.ground, isNotNull);
    final startX = game.player.x;

    // Hold the right half of the d-pad.
    final dpadRight = (game.dpad.position + Vector2(game.dpad.size.x * .75, game.dpad.size.y / 2)).toOffset();
    final g1 = await tester.startGesture(dpadRight);
    await run(.3);
    expect(game.dpad.dir, 1);
    expect(game.player.vel.x, greaterThan(100));
    // Slide finger to the left half without lifting -> direction flips.
    await g1.moveTo(dpadRight - const Offset(90, 0));
    await run(.3);
    expect(game.dpad.dir, -1);
    await g1.up();
    await run(.05);
    expect(game.dpad.dir, 0);
    expect(game.player.x, isNot(startX));

    // Tap jump (quick press, no movement).
    final jumpCenter = (game.jumpButton.position + game.jumpButton.size / 2).toOffset();
    await tester.tapAt(jumpCenter);
    await run(.05);
    expect(game.player.ground, isNull, reason: 'player should be airborne after jump');
    expect(game.started, isTrue);
    await run(1.2);
    expect(game.player.ground, isNotNull, reason: 'player should land again');

    // Hold jump + run: climb automatically for a while.
    final jg = await tester.startGesture(jumpCenter);
    final rg = await tester.startGesture(dpadRight);
    await run(4);
    await rg.up();
    await jg.up();
    debugPrint('floor=${game.maxFloor} score=${game.score} over=${game.over}');

    // Stop playing: the scrolling camera (or falling) should end the round.
    if (!game.scrolling) {
      game.player.position.y = game.camY + game.size.y + 200;
    }
    await run(40);
    expect(game.over, isTrue);
    expect(game.panel, isNotNull);

    // Restart button.
    await run(1);
    final restart = game.panel!.restart.absoluteCenter.toOffset();
    await tester.tapAt(restart);
    await run(.1);
    expect(game.over, isFalse);
    expect(game.maxFloor, 0);
    expect(game.player.ground, isNotNull);
  });
}
