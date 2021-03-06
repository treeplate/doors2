import 'dart:ui' show Offset, Rect, VoidCallback;

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, RawKeyDownEvent, RawKeyUpEvent;
import 'package:flutter/widgets.dart'
    show ChangeNotifier, RawKeyEvent, mustCallSuper;

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

List<LevelData> levelData = [LevelData()];

class LevelData {
  late final Duration startTime;
  Duration? time;
  LevelData();
  String toString() {
    return '(TIME: ${time == null ? 'TBD' : secondsMilliseconds(time!)})';
  }
}

String secondsMilliseconds(Duration elapsed) {
  return '${elapsed.inSeconds}.' +
      (elapsed.inMilliseconds - elapsed.inSeconds * 1000)
          .toString()
          .padLeft(3, '0') +
      ' ($elapsed)';
}

class PhysicsSimulator extends ChangeNotifier {
  static const double kVelStep = .1;

  bool keyCheck = false;
  bool get dashMode => false;
  static const double friction = 0.01;

  PhysicsSimulator(this.nextLevel, this.impassables, this.endX) {}

  final VoidCallback nextLevel;
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
    notifyListeners();
  }

  final List<Impassable> impassables;

  final double endX;
  Duration? duration1;
  Duration? duration2;
  Duration? duration3;
  late Duration tickTime;
  void tick(Duration arg) {
    if (duration1 != null &&
        duration2 != null &&
        duration3 != null &&
        arg - duration1! != duration2) {
      print('skipped a frame');
    }
    if (duration1 == null) {
      levelData.last.startTime = arg;
    }
    tickTime = arg;
    duration2 =
        duration1 != null && duration3 != null ? duration1! - duration3! : null;
    duration3 = duration1;
    duration1 = arg;
    for (Button button in impassables.whereType<Button>()) {
      (impassables[button.door] as Door).open = false;
    }
    for (Player player in impassables.whereType<Player>()) {
      final Impassable? holding = player.holding;
      if (holding != null && !impassables.contains(holding)) {
        impassables.add(holding);
      }
      holding?.topLeft -= Offset(0, 1);
      holding?.bottomRight -= Offset(0, 1);
      updateHoldingPos(player);
      if (player.topLeft.dx >= endX) {
        nextLevel();
        return;
      }
      player.bottomRight -= Offset(0, 1);
      colliding(player.rect);
      player.bottomRight += Offset(0, 1);
      if (collided is Button) {
        (impassables[(collided as Button).door] as Door).open = true;
      }

      player.moveDir += Offset(0, -1);
    }
    for (Box box in impassables.whereType<Box>()) {
      box.topLeft -= Offset(0, 1);
      box.bottomRight -= Offset(0, 1);
      if (colliding<Button>(box.rect)) {
        (impassables[(collided as Button).door] as Door).open = true;
      }
      box.topLeft += Offset(0, 1);
      box.bottomRight += Offset(0, 1);
    }
    for (Impassable platform in impassables) {
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
        platform.topLeft += Offset(speed, 0);
        platform.bottomRight += Offset(speed, 0);
        updateCollision(platform, speed, 0);
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
    if (platform is Player) {
      updateHoldingPos(platform);
      if (platform.holding != null && colliding(platform.holding!.rect)) {
        pushing.add(platform.holding!);
      }
    }
    bool reverting = false;
    while (!reverting) {
      if (pushing.any((element) => colliding(element.rect))) {
        if (collided == null || !collided!.pushable) reverting = true;
        if (collided is Button) {
          (impassables[(collided as Button).door] as Door).open = true;
        }
        collided?.topLeft += Offset(sX, sY);
        collided?.bottomRight += Offset(sX, sY);
        if (collided != null) {
          Impassable oldCollided = collided!;
          if (oldCollided is Player) {
            updateHoldingPos(oldCollided);
            if ((oldCollided).holding != null &&
                colliding((oldCollided).holding!.rect)) {
              pushing.add((oldCollided).holding!);
            }
          }
          pushing.add(oldCollided);
        }
      } else {
        break;
      }
      if (reverting) {
        for (Impassable? thing in pushing) {
          if (thing is! Door || !untick) {
            thing?.topLeft -= Offset(sX, sY);
            thing?.bottomRight -= Offset(sX, sY);
          }
          thing?.moveDir = Offset(
              sX == 0 || thing is Player ? thing.moveDir.dx : 0,
              sY == 0 ? thing.moveDir.dy : 0);
        }
        if (untick) platform.unTick();
        break;
      }
    }
  }

  LogicalKeyboardKey? j;
  LogicalKeyboardKey? t;
  LogicalKeyboardKey? r;
  LogicalKeyboardKey? l;
  void updateHoldingPos(Player player) {
    player.holding?.bottomRight = player.bottomRight +
        Offset(player.holding!.rect.width + 2, player.holding!.rect.height + 0);
    player.holding?.topLeft = player.bottomRight + Offset(2, 0);
    player.holding?.moveDir = Offset.zero;
  }

  void dispose() {
    super.dispose();
  }

  void handleKeyPress(RawKeyEvent event) {
    if (!stopwatch.isRunning) {
      stopwatch.start();
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
        if (event.logicalKey == LogicalKeyboardKey.add) {
          keyCheck = true;
          print('beep boop');
        }
        if (event.logicalKey == player.rightKeybind) {
          player.moveDir = Offset(2, player.moveDir.dy);
        } else if (event.logicalKey == player.leftKeybind) {
          player.moveDir = Offset(-2, player.moveDir.dy);
        } else if (event.logicalKey == player.jumpKeybind && !player.jumped) {
          jump(15, player);
          player.jumped = true;
        } else if (event.logicalKey == player.takeKeybind) {
          handleTake(player);
        }
      }
    }
  }

  void jump(double h, Player player) {
    player.topLeft -= Offset(0, 3);
    player.bottomRight -= Offset(0, 3);
    if (colliding(player.rect) || dashMode) {
      player.moveDir = Offset(player.moveDir.dx, h);
    }
    player.topLeft += Offset(0, 3);
    player.bottomRight += Offset(0, 3);
  }

  void handleTake(Player player) {
    final Impassable? holding = player.holding;
    if (holding != null) {
      holding.moveDir = Offset(player.moveDir.dx, player.moveDir.dy);
      player.holding = null;
      return;
    }
    player.topLeft += Offset(10, 0);
    player.bottomRight += Offset(10, 0);
    if (colliding(player.rect) && validTakeable(collided)) {
      Offset oldTL = collided!.topLeft;
      Offset oldBR = collided!.bottomRight;
      player.holding = collided;
      final Impassable? holding = player.holding;
      player.topLeft -= Offset(10, 0);
      player.bottomRight -= Offset(10, 0);
      updateHoldingPos(player);
      if (colliding(holding!.rect)) {
        holding.topLeft = oldTL;
        holding.bottomRight = oldBR;
        player.holding = null;
      }
      player.topLeft += Offset(10, 0);
      player.bottomRight += Offset(10, 0);
    }
    player.topLeft -= Offset(20, 0);
    player.bottomRight -= Offset(20, 0);
    if (colliding(player.rect) && validTakeable(collided)) {
      Offset oldTL = collided!.topLeft;
      Offset oldBR = collided!.bottomRight;
      player.holding = collided;
      final Impassable? holding = player.holding;
      player.topLeft += Offset(10, 0);
      player.bottomRight += Offset(10, 0);
      updateHoldingPos(player);
      if (colliding(holding!.rect)) {
        holding.topLeft = oldTL;
        holding.bottomRight = oldBR;
        player.holding = null;
      }
      player.topLeft -= Offset(10, 0);
      player.bottomRight -= Offset(10, 0);
    }
    player.topLeft += Offset(10, 0);
    player.bottomRight += Offset(10, 0);
  }
}

class Impassable {
  Impassable(this.topLeft, this.bottomRight, this.moveDir)
      : oldTopLeft = topLeft,
        oldBottomRight = bottomRight;
  Offset topLeft;
  Offset bottomRight;
  final Offset oldTopLeft;
  final Offset oldBottomRight;

  bool get pushable => false;
  Rect get rect => Rect.fromPoints(topLeft, bottomRight);
  Offset moveDir;
  void tick() {}

  void unTick() {}
  String toString() =>
      "$runtimeType ($hashCode) at $topLeft (moveDir: $moveDir)";
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
        super(topLeft, topLeft + Offset(10, -50), Offset.zero);
  bool open = false;
  double t = 1;
  void reset() {
    super.reset();
    open = false;
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
      : super(topLeft, topLeft + Offset(30, -20), Offset.zero);

  final int door;
  String toString() => "<Button>";
}

class Box extends Impassable {
  Box(Offset topLeft) : super(topLeft, topLeft + Offset(10, -10), Offset.zero);
  bool get pushable => true;
  @override
  void tick() {
    moveDir = moveDir - Offset(0, 1);
  }
}

class Player extends Impassable {
  Player(Offset topLeft, Offset moveDir,
      [this.jumpKeybind = LogicalKeyboardKey.keyW,
      this.takeKeybind = LogicalKeyboardKey.keyE,
      this.rightKeybind = LogicalKeyboardKey.keyD,
      this.leftKeybind = LogicalKeyboardKey.keyA])
      : super(topLeft, topLeft + Offset(20, -20), moveDir);
  Impassable? holding;
  final LogicalKeyboardKey jumpKeybind;
  final LogicalKeyboardKey takeKeybind;
  final LogicalKeyboardKey rightKeybind;
  final LogicalKeyboardKey leftKeybind;
  bool jumped = false;
  bool get pushable => true;
}
