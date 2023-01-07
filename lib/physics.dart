import 'dart:ui' show Offset, Rect;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart'
    show Color, LogicalKeyboardKey, RawKeyDownEvent, RawKeyEvent, RawKeyUpEvent;
import 'package:flutter/widgets.dart' show ChangeNotifier, mustCallSuper;

final Stopwatch stopwatch = Stopwatch();

class MovingPlatform extends Impassable {
  MovingPlatform(Offset offset, Offset offset2, this.endingPos, this.offset3)
      : super(offset, offset2, Offset.zero);
  final Offset offset3;
  final Offset endingPos;
  void tick() {
    super.tick();
    topLeft += offset3;
    bottomRight += offset3;
    if (topLeft.dy > endingPos.dy) {
      reset();
    }
  }

  void untick() {
    super.unTick();
    topLeft -= offset3;
    bottomRight -= offset3;
  }

  void reset() {
    super.reset();
    topLeft = oldTopLeft;
    bottomRight = oldBottomRight;
  }
}

List<LevelData> levelData = [
  LevelData()
    ..time = Duration.zero
    ..winner = 'Nobody',
  LevelData()
];

class LevelData {
  late final Duration startTime;
  Duration? time;

  late String winner;
  bool sti = false;
  LevelData();
  String toString() {
    return '(TIME: ${time == null ? 'TBD' : secondsMilliseconds(time!)}, WINNER $winner)';
  }
}

String secondsMilliseconds(Duration elapsed) {
  return '${elapsed.inSeconds}.' +
      (elapsed.inMilliseconds - elapsed.inSeconds * 1000)
          .toString()
          .padLeft(3, '0');
}

Duration roundedDuration(Duration arg) {
  return Duration(milliseconds: arg.inMilliseconds.floor());
}

class PhysicsSimulator extends ChangeNotifier {
  static const double kVelStep = .1;

  bool keyCheck = false;

  int ticks = 0;
  bool get dashMode => false;
  static const double friction = 0.01;

  PhysicsSimulator(this.nextLevel, this.impassables, this.endX) {}

  final void Function(int, Impassable, bool, Duration, String) nextLevel;
  bool validTakeable(Impassable? obj) {
    return obj?.pushable ?? false;
  }

  Impassable? collided;
  bool colliding<T extends Impassable>(Rect rect) {
    MapEntry<bool, Impassable?> r = collidingStatic<T>(impassables, rect);
    collided = r.value;
    return r.key;
  }

  static MapEntry<bool, Impassable?> collidingStatic<T extends Impassable>(
      List<Impassable> impassables, Rect rect) {
    Impassable? collided;
    if ((rect.top < 0 || rect.bottom > 400) && T == Impassable) {
      return MapEntry(true, collided);
    }
    for (Impassable wall in impassables) {
      if (!rect.intersect(wall.rect).isEmpty &&
          wall is T &&
          rect != wall.rect) {
        collided = wall;
        return MapEntry(true, collided);
      }
    }
    collided = null;
    return MapEntry(false, collided);
  }

  void reset() {
    for (Impassable obj in impassables) {
      Offset oTL = obj.topLeft;
      Offset oBR = obj.bottomRight;
      obj.reset();
      if (colliding(obj.rect)) {
        obj.topLeft = oTL;
        obj.bottomRight = oBR;
      }
    }
    while (true) {
      bool colliding1 = false;
      for (Impassable i in impassables) {
        if (colliding(i.rect)) {
          if (i.topLeft.dy > 400) {
            print('>400!');
          }
          colliding1 = true;
          i.topLeft = Offset(i.topLeft.dx, i.topLeft.dy + 10);
          i.bottomRight = Offset(i.bottomRight.dx, i.bottomRight.dy + 10);
        }
      }
      if (!colliding1) {
        break;
      }
    }
    notifyListeners();
  }

  final List<Impassable> impassables;

  final double endX;
  Duration? duration1;
  late Duration tickTime;
  void tick(Duration arg) {
    ticks++;
    if (duration1 == null && levelData.length > 2) {
      if (levelData.last.sti) {
        levelData[levelData.length - 1] = LevelData();
      }
      levelData.last.startTime = arg;
      levelData.last.sti = true;
    }
    tickTime = arg;
    duration1 = arg;
    for (Button button in impassables.whereType<Button>()) {
      (impassables.whereType<Door>().toList()[button.door]).open = false;
    }
    for (Player player in impassables.whereType<Player>().toList()) {
      updateHoldingPos(player);
      player.bottomRight -= Offset(0, 1);
      colliding(player.rect);
      player.bottomRight += Offset(0, 1);
      if (collided is Button) {
        (impassables.whereType<Door>().toList()[(collided as Button).door])
            .open = true;
      }

      player.moveDir += Offset(0, -1);
    }
    for (Box box in impassables.whereType<Box>()) {
      box.topLeft -= Offset(0, 1);
      box.bottomRight -= Offset(0, 1);
      if (colliding<Button>(box.rect)) {
        (impassables.whereType<Door>().toList()[(collided as Button).door])
            .open = true;
      }
      box.topLeft += Offset(0, 1);
      box.bottomRight += Offset(0, 1);

      box.moveDir += Offset(0, -1);
    }
    for (RBox box in impassables.whereType<RBox>()) {
      box.topLeft += Offset(0, 1);
      box.bottomRight += Offset(0, 1);
      if (colliding<Button>(box.rect)) {
        (impassables.whereType<Door>().toList()[(collided as Button).door])
            .open = true;
      }
      box.topLeft -= Offset(0, 1);
      box.bottomRight -= Offset(0, 1);

      box.moveDir += Offset(0, 1);
    }
    for (Impassable platform in impassables) {
      platform.room = impassables;
      if (platform is! Player) {
        platform.topLeft -= Offset(0, 1);
        platform.bottomRight -= Offset(0, 1);
        if (platform.moveDir.dx != 0 && colliding(platform.rect)) {
          platform.moveDir.dx < 0
              ? platform.moveDir += Offset(friction, 0)
              : platform.moveDir -= Offset(friction, 0);
        }
        platform.topLeft += Offset(0, 1);
        platform.bottomRight += Offset(0, 1);
      }
      for (double i = 0; i < platform.moveDir.dx.abs(); i += kVelStep) {
        double speed = (platform.moveDir.dx < 0 ? -1 : 1) * kVelStep;
        assert(!colliding(platform.rect));
        platform.topLeft += Offset(speed, 0);
        platform.bottomRight += Offset(speed, 0);
        updateCollision(platform, speed, 0);
        assert(!colliding(platform.rect));
      }
      if (!platform.isHolding &&
          platform.topLeft.dx >= endX &&
          levelData.last.sti) {
        if (platform is Player) {
          levelData.last.time = tickTime - levelData.last.startTime;
          levelData.last.winner =
              platform.type.toString() + platform.jumpKeybind.keyLabel;
          if (platform.holding != null) {
            nextLevel(
                1,
                platform.holding!,
                platform.holding is Player,
                tickTime - levelData.last.startTime,
                platform.holding!.type.toString() +
                    (((platform.holding is Player ? platform.holding : null)
                                as Player?)
                            ?.jumpKeybind
                            .keyLabel ??
                        'Uhh'));
          }
        }
        impassables.remove(platform..reset());
        nextLevel(
            1,
            platform,
            platform is Player,
            tickTime - levelData.last.startTime,
            platform.type.toString() +
                ((platform is Player ? platform : null)?.jumpKeybind.keyLabel ??
                    'Uhh'));
        return;
      }
      if (platform.topLeft.dx <= -endX && levelData.last.sti) {
        impassables.remove(platform);
        nextLevel(
            -1,
            platform,
            platform is Player,
            tickTime - levelData.last.startTime,
            platform.type.toString() +
                ((platform is Player ? platform : null)?.jumpKeybind.keyLabel ??
                    'Uhh'));
        return;
      }
      for (double i = 0; i < platform.moveDir.dy.abs(); i += kVelStep) {
        double speed = (platform.moveDir.dy < 0 ? -1 : 1) * kVelStep;
        platform.topLeft += Offset(0, speed);
        platform.bottomRight += Offset(0, speed);

        updateCollision(platform, 0, speed);
      }
      double oX = platform.topLeft.dx;
      double oY = platform.topLeft.dy;
      platform.tick();
      double sX = platform.topLeft.dx - oX;
      double sY = platform.topLeft.dy - oY;

      if (sX != 0 || sY != 0) updateCollision(platform, sX, sY, untick: true);
    }
    notifyListeners();
  }

  void updateCollision(Impassable platform, double sX, double sY,
      {bool untick = false}) {
    assert(sX != 0.0 || sY != 0.0);
    Set<Impassable> pushing = {platform};
    outer:
    while (true) {
      for (Impassable element in pushing) {
        if (!colliding(element.rect)) {
          continue;
        }
        if (collided == null || !collided!.pushable) {
          for (Impassable? thing in pushing) {
            if (thing is! Door || !untick) {
              thing?.topLeft -= Offset(sX, sY);
              thing?.bottomRight -= Offset(sX, sY);
            }
            thing?.moveDir = Offset(
                sX == 0 || thing is PC ? thing.moveDir.dx : 0,
                sY == 0 ? thing.moveDir.dy : 0);
          }
          if (untick) platform.unTick();
          return;
        }
        if (collided is Button) {
          (impassables[(collided as Button).door] as Door).open = true;
        }
        assert(!pushing.contains(collided));
        collided!.topLeft += Offset(sX, sY);
        collided!.bottomRight += Offset(sX, sY);
        pushing.add(collided!);
        continue outer;
      }
      break;
    }
  }

  LogicalKeyboardKey? j;
  LogicalKeyboardKey? t;
  LogicalKeyboardKey? r;
  LogicalKeyboardKey? l;
  void updateHoldingPos(PC player) {
    if (player.holding == null) {
      return;
    }
    Offset otl = player.holding!.topLeft;
    Offset obr = player.holding!.bottomRight;
    player.holding!.bottomRight = player.bottomRight +
        Offset(player.holding!.rect.width + 2, player.holding!.rect.height + 0);
    player.holding!.topLeft = player.bottomRight + Offset(2, 0);
    player.holding!.moveDir = Offset.zero;
    if (colliding(player.holding!.rect)) {
      player.holding!.topLeft = otl;
      player.holding!.bottomRight = obr;
    }
  }

  void dispose() {
    super.dispose();
  }

  void handleKeyPress(RawKeyEvent event) {
    //print(event);
    if (levelData.length <= 2 && levelData.last.sti == false && ticks > 0) {
      levelData.last.startTime = tickTime;
      levelData.last.sti = true;
    }

    for (Player player in impassables.whereType()) {
      if (event is RawKeyUpEvent && !keyCheck) {
        if (event.logicalKey == player.jumpKeybind) player.jumped = false;
        if ((event.logicalKey == player.rightKeybind &&
                player.moveDir.dx == 2) ||
            (event.logicalKey == player.leftKeybind && player.moveDir.dx == -2))
          player.moveDir = Offset(0, player.moveDir.dy);
      }

      if (event is RawKeyDownEvent) {
        if (keyCheck) {
          if (event.logicalKey == LogicalKeyboardKey.add) {
            return;
          }
          if (j == null) {
            j = event.logicalKey;
            return;
          }
          if (t == null) {
            t = event.logicalKey;
            return;
          }
          if (r == null) {
            r = event.logicalKey;
            return;
          }
          if (l == null) {
            l = event.logicalKey;
            keyCheck = false;
            impassables
                .add(Player(Offset(0, 400), Offset.zero, j!, t!, r!, l!));
            j = null;
            t = null;
            r = null;
            l = null;
            print('boop beep');
            return;
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.keyR) {
          reset();
        }
        if (event.logicalKey == LogicalKeyboardKey.add) {
          keyCheck = true;
          print('beep boop');
        }
        if (event.logicalKey == LogicalKeyboardKey.keyR) {
          reset();
        }
        if (event.logicalKey == player.rightKeybind) {
          player.moveDir = Offset(2, player.moveDir.dy);
        } else if (event.logicalKey == player.leftKeybind) {
          player.moveDir = Offset(-2, player.moveDir.dy);
        } else if (event.logicalKey == player.jumpKeybind && !player.jumped) {
          jump(16, player);
          player.jumped = true;
        } else if (event.logicalKey == player.takeKeybind) {
          handleTake(player);
        }
      }
    }
  }

  void jump(double h, PC player) {
    player.topLeft -= Offset(0, 3);
    player.bottomRight -= Offset(0, 3);
    if (colliding(player.rect) || dashMode) {
      player.moveDir = Offset(player.moveDir.dx, h);
    }
    player.topLeft += Offset(0, 3);
    player.bottomRight += Offset(0, 3);
  }

  void handleTake(PC player) {
    final Impassable? holding = player.holding;
    if (holding != null) {
      holding.moveDir = Offset(player.moveDir.dx, player.moveDir.dy);
      player.holding!.isHolding = false;
      player.holding = null;
      return;
    }
    player.topLeft += Offset(10, 0);
    player.bottomRight += Offset(10, 0);
    if (colliding(player.rect) && validTakeable(collided)) {
      player.holding = collided;
      collided!.isHolding = true;
    }
    player.topLeft -= Offset(20, 0);
    player.bottomRight -= Offset(20, 0);
    if (colliding(player.rect) && validTakeable(collided)) {
      player.holding = collided;
      collided!.isHolding = true;
    }
    player.topLeft += Offset(10, 0);
    player.bottomRight += Offset(10, 0);
  }

  String toString() {
    return 'I am a P-S';
  }
}

class Impassable {
  bool isHolding = false;

  Impassable(this.topLeft, this.bottomRight, this.moveDir,
      [this.color = Colors.brown])
      : oldTopLeft = topLeft,
        oldBottomRight = bottomRight;
  Offset topLeft;
  Offset bottomRight;
  List<Impassable>? room;
  final Offset oldTopLeft;
  final Offset oldBottomRight;
  final Color color;
  String get type => 'Wall';

  bool get pushable => false;
  Rect get rect => Rect.fromPoints(topLeft, bottomRight);
  Offset moveDir;
  void tick() {}

  void unTick() {}
  String toString() => "$type ($hashCode) at $topLeft (moveDir: $moveDir)";
  @mustCallSuper
  void reset() {
    if (pushable) {
      topLeft = oldTopLeft;
      bottomRight = oldBottomRight;
    }
  }
}

class Door extends Impassable {
  Door(Offset topLeft, {this.open = false})
      : t = open ? 0 : 1,
        super(topLeft, topLeft + Offset(10, -50), Offset.zero, Colors.teal);
  bool open;
  double t = 1;
  String get type => 'Door';
  void reset() {
    super.reset();
    open = true;
    while (open && t < 1) {
      topLeft = Offset(topLeft.dx, topLeft.dy + 1);
      bottomRight = Offset(bottomRight.dx, bottomRight.dy + 1);
      t += 1 / 50;
    }
  }

  @override
  void tick() {
    if (open && t < 1) {
      topLeft = Offset(topLeft.dx, topLeft.dy + 1);
      bottomRight = Offset(bottomRight.dx, bottomRight.dy + 1);
      t += 1 / 50;
    }
    if (!open && t > 0) {
      topLeft = Offset(topLeft.dx, topLeft.dy - 1);
      bottomRight = Offset(bottomRight.dx, bottomRight.dy - 1);
      t -= 1 / 50;
    }
    t = (t * 50).round() / 50;
  }

  @override
  void unTick() {
    if (t == 1 || t == 0) {
      return;
    }
    open = !open;
    tick();
    open = !open;
  }
}

class Button extends Impassable {
  Button(Offset topLeft, this.door)
      : super(topLeft, topLeft + Offset(30, -20), Offset.zero, Colors.red);

  final int door;
  String toString() => "<Button>";
  String get type => 'Button';
}

class Box extends Impassable {
  Box(Offset topLeft, Color? color)
      : super(topLeft, topLeft + Offset(10, -10), Offset.zero,
            color ?? Colors.grey);
  bool get pushable => true;
  String get type => 'Box';
}

class RBox extends Impassable {
  RBox(Offset topLeft, Color? color)
      : super(topLeft, topLeft + Offset(10, -10), Offset.zero,
            color ?? Colors.yellow);
  bool get pushable => true;
  String get type => 'Box';
}

abstract class PC extends Impassable {
  PC(
    Offset topLeft,
    Offset bottomRight,
    Offset moveDir,
    this.jumpKeybind,
    this.takeKeybind,
    this.rightKeybind,
    this.leftKeybind,
  ) : super(topLeft, bottomRight, moveDir, Colors.yellow);
  Impassable? holding;
  final LogicalKeyboardKey jumpKeybind;
  final LogicalKeyboardKey takeKeybind;
  final LogicalKeyboardKey rightKeybind;
  final LogicalKeyboardKey leftKeybind;
  bool jumped = false;
}

class Player extends PC {
  Player(Offset topLeft, Offset moveDir,
      [LogicalKeyboardKey jumpKeybind = LogicalKeyboardKey.keyW,
      LogicalKeyboardKey takeKeybind = LogicalKeyboardKey.keyE,
      LogicalKeyboardKey rightKeybind = LogicalKeyboardKey.keyD,
      LogicalKeyboardKey leftKeybind = LogicalKeyboardKey.keyA])
      : super(topLeft, topLeft + Offset(20, -20), moveDir, jumpKeybind,
            takeKeybind, rightKeybind, leftKeybind);
  bool get pushable => true;
  String get type => 'Player';
}
