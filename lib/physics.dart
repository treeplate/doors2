import 'dart:ui' show Offset, Rect;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart' show Color, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show ChangeNotifier, mustCallSuper;

final Stopwatch stopwatch = Stopwatch();

const bool playersCollide = false;

class Bouncy extends Impassable {
  Bouncy(Offset topLeft, Offset bottomRight, this.bounceVertically)
      : super(topLeft, bottomRight, Offset.zero);
  final bool bounceVertically;
  Color get color => bounceVertically ? Colors.green : Colors.blue;
}

class MovingPlatform extends Impassable {
  MovingPlatform(Offset tl, Offset br, this.endingPos, this.speed)
      : super(tl, br, Offset.zero);
  final Offset speed;
  final Offset endingPos;
  void tick() {
    super.tick();
    topLeft += speed;
    bottomRight += speed;
    if (topLeft.dy > endingPos.dy) {
      reset();
    }
  }

  void untick() {
    super.unTick();
    topLeft -= speed;
    bottomRight -= speed;
  }

  void reset() {
    super.reset();
    topLeft = oldTopLeft;
    bottomRight = oldBottomRight;
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

enum MoveKey { l, r, t, j }

MoveKey parseKey(String raw) {
  switch (raw) {
    case 'l':
      return MoveKey.l;
    case 'r':
      return MoveKey.r;
    case 'j':
      return MoveKey.j;
    case 't':
      return MoveKey.t;
  }
  throw FormatException();
}

void correctCollisions(List<Impassable> impassables) {
  while (true) {
    bool colliding1 = false;
    for (Impassable i in impassables.toList()) {
      if (PhysicsSimulator.collidingStatic(
              impassables, i.rect, playersCollide || i is! PC)
          .key) {
        colliding1 = true;
        if (i.topLeft.dy > 400) {
          i.topLeft = Offset(i.topLeft.dx - 1, 0);
          i.bottomRight = Offset(i.bottomRight.dx - 1, 0);
          print(i.topLeft);
        } else {
          i.topLeft = Offset(i.topLeft.dx, i.topLeft.dy + 1);
          i.bottomRight = Offset(i.bottomRight.dx, i.bottomRight.dy + 1);
        }
      }
    }
    if (!colliding1) {
      break;
    }
  }
}

enum BounceResult { wasntABouncy, vertical, horizontal }

class PhysicsSimulator extends ChangeNotifier {
  static const double kVelStep = .125;
  static const double friction = 0.01;
  double gravity = 1;
  double xGravity = 0;
  bool isDisposed = false;

  int ticks = 0;
  bool get dashMode => false;

  PhysicsSimulator(this.nextLevel, this.impassables, this.endX);

  final void Function(int, Impassable, bool, String) nextLevel;
  bool validTakeable(Impassable? obj) {
    return obj?.pushable ?? false;
  }

  Impassable? collided;
  bool colliding<T extends Impassable>(Rect rect, bool collideWithPlayer) {
    MapEntry<bool, Impassable?> r =
        collidingStatic<T>(impassables, rect, collideWithPlayer);
    collided = r.value;
    return r.key;
  }

  static MapEntry<bool, Impassable?> collidingStatic<T extends Impassable>(
      List<Impassable> impassables, Rect rect, bool collideWithPlayer) {
    Impassable? collided;
    if ((rect.top < 0 || rect.bottom > 400) && T == Impassable) {
      return MapEntry(true, collided);
    }
    for (Impassable wall in impassables) {
      if (!rect.intersect(wall.rect).isEmpty &&
          wall is T &&
          rect != wall.rect &&
          (collideWithPlayer || wall is! PC)) {
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
      if (colliding(obj.rect, playersCollide || obj is! PC)) {
        obj.topLeft = oTL;
        obj.bottomRight = oBR;
      }
    }
    correctCollisions(impassables);
    notifyListeners();
  }

  final List<Impassable> impassables;
  final List<Impassable> ghosts = [];

  final double endX;
  Duration? duration1;
  late Duration tickTime;

  void tick() {
    ticks++;
    for (Button button in impassables.whereType<Button>()) {
      List<Door> doors = impassables.whereType<Door>().toList();
      if (doors.length <= button.door) continue;
      (doors[button.door]).open = false;
    }
    for (PC player in impassables.whereType<PC>().toList()) {
      updateHoldingPos(player);
      player.bottomRight -= Offset(xGravity.sign, gravity.sign);
      colliding(player.rect, playersCollide);
      if (collided != null)
        checkForButtonAndBouncy(
          player,
          collided!,
        );
      player.bottomRight += Offset(xGravity.sign, gravity.sign);

      player.moveDir += Offset(-xGravity, -gravity);
    }
    for (Box box in impassables.whereType<Box>()) {
      box.topLeft -= Offset(xGravity.sign, gravity.sign);
      box.bottomRight -= Offset(xGravity.sign, gravity.sign);
      colliding(box.rect, true);
      if (collided != null)
        checkForButtonAndBouncy(
          box,
          collided!,
        );
      box.topLeft += Offset(xGravity.sign, gravity.sign);
      box.bottomRight += Offset(xGravity.sign, gravity.sign);

      box.moveDir += Offset(-xGravity, -gravity);
    }
    for (RBox box in impassables.whereType<RBox>()) {
      box.topLeft += Offset(xGravity.sign, gravity.sign);
      box.bottomRight += Offset(xGravity.sign, gravity.sign);
      colliding(box.rect, true);
      if (collided != null)
        checkForButtonAndBouncy(
          box,
          collided!,
        );
      box.topLeft -= Offset(xGravity.sign, gravity.sign);
      box.bottomRight -= Offset(xGravity.sign, gravity.sign);

      box.moveDir += Offset(xGravity, gravity);
    }
    for (ABox box in impassables.whereType<ABox>()) {
      box.topLeft += Offset(gravity.sign, xGravity.sign);
      box.bottomRight += Offset(gravity.sign, xGravity.sign);
      colliding(box.rect, true);
      if (collided != null)
        checkForButtonAndBouncy(
          box,
          collided!,
        );
      box.topLeft -= Offset(gravity.sign, xGravity.sign);
      box.bottomRight -= Offset(gravity.sign, xGravity.sign);

      box.moveDir += Offset(gravity, xGravity);
    }
    for (DBox box in impassables.whereType<DBox>()) {
      box.topLeft += Offset(gravity.sign, xGravity.sign);
      box.bottomRight += Offset(gravity.sign, xGravity.sign);
      colliding(box.rect, true);
      if (collided != null)
        checkForButtonAndBouncy(
          box,
          collided!,
        );
      box.topLeft -= Offset(gravity.sign, xGravity.sign);
      box.bottomRight -= Offset(gravity.sign, xGravity.sign);

      box.moveDir += Offset(-gravity, -xGravity);
    }
    for (Impassable platform in impassables) {
      platform.room = impassables;
      Offset? playerVel;
      if (platform is! PC) {
        platform.topLeft -= Offset(xGravity.sign, gravity.sign);
        platform.bottomRight -= Offset(xGravity.sign, gravity.sign);
        if (platform.moveDir.dx != 0 && colliding(platform.rect, true)) {
          platform.moveDir.dx < 0
              ? platform.moveDir += Offset(friction, 0)
              : platform.moveDir -= Offset(friction, 0);
        }
        platform.topLeft += Offset(xGravity.sign, gravity.sign);
        platform.bottomRight += Offset(xGravity.sign, gravity.sign);
      } else {
        playerVel = platform.moveDir;

        if (platform.pressedsInited && platform.leftPressed()) {
          platform.moveDir += Offset(-2 * gravity.sign, 2 * xGravity.sign);
        }
        if (!platform.pressedsInited && platform.preRightPressed() ||
            platform.pressedsInited && platform.rightPressed()) {
          platform.moveDir += Offset(2 * gravity.sign, -2 * xGravity.sign);
        }
      }
      for (double i = 0; i < platform.moveDir.dx.abs(); i += kVelStep) {
        if (platform.moveDir.dx == 0) break;
        double speed = (platform.moveDir.dx < 0 ? -1 : 1) * kVelStep;
        if (colliding(platform.rect, playersCollide || platform is! PC)) {
          print('colliding $platform $collided');
        }
        platform.topLeft += Offset(speed, 0);
        platform.bottomRight += Offset(speed, 0);
        updateCollision(platform, speed, 0);
        if (colliding(platform.rect, playersCollide || platform is! PC)) {
          notifyListeners();
          print('colliding $platform $collided');
        }
      }
      if (platform.moveDir != (playerVel ?? platform.moveDir)) {
        platform.moveDir = playerVel!;
      }
      if (!platform.isHolding && platform.topLeft.dx >= endX) {
        if (platform is PC) {
          platform.type.toString() + platform.jumpKeybind.keyLabel;
          if (platform.holding != null) {
            nextLevel(
                1,
                platform.holding!,
                platform.holding is PC,
                platform.holding!.type.toString() +
                     impassables.whereType<PC>().toList().cast().indexOf(platform.holding).toString());
          }
        }
        nextLevel(
          1,
          platform,
          platform is PC,
          platform.type.toString() + impassables.whereType<PC>().toList().cast().indexOf(platform).toString(),
        );
        impassables.remove(platform..reset());
        return;
      }
      if (platform.topLeft.dx <= -endX) {
        nextLevel(
          -1,
          platform,
          platform is PC,
          platform.type.toString() + impassables.whereType<PC>().toList().cast().indexOf(platform).toString(),
        );
        impassables.remove(platform..reset());
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
    for (Impassable p in impassables) {
      if (p is PC) {
        p.jumped = false;
      }
    }
    notifyListeners();
  }

  void updateCollision(Impassable platform, double sX, double sY,
      {bool untick = false}) {
    assert(sX != 0.0 || sY != 0.0);
    Set<Impassable> pushing = {platform};
    outer:
    while (true) {
      for (Impassable element in pushing.toList()) {
        if (!colliding(element.rect, playersCollide || element is! PC)) {
          continue;
        }
        if (collided != null) {
          var br = checkForButtonAndBouncy(element, collided!);
          if (br == BounceResult.vertical && sX == 0 ||
              br == BounceResult.horizontal && sY == 0) return;
        }
        if (collided == null || !collided!.pushable) {
          for (Impassable? thing in pushing) {
            assert(thing == platform || thing is! Door);
            if (thing is! Door) {
              thing?.topLeft -= Offset(sX, sY);
              thing?.bottomRight -= Offset(sX, sY);
              thing?.moveDir -= Offset(sX, sY);
            }
          }
          if (untick) platform.unTick();
          return;
        }
        if (pushing.contains(collided)) {
          print('ERROR: RECURSIVE');
          return;
        }
        collided!.topLeft += Offset(sX, sY);
        collided!.bottomRight += Offset(sX, sY);
        collided!.moveDir = Offset(sX, sY);
        pushing.add(collided!);
        continue outer;
      }
      break;
    }
  }

  BounceResult checkForButtonAndBouncy(
      Impassable element, Impassable collided2) {
    if (collided2 is Button) {
      (impassables.whereType<Door>().toList()[collided2.door]).open = true;
    }
    if (collided2 is Bouncy) {
      bounce(collided2, element);
      return collided2.bounceVertically
          ? BounceResult.vertical
          : BounceResult.horizontal;
    }
    return BounceResult.wasntABouncy;
  }

  void updateHoldingPos(PC player) {
    if (player.holding == null) {
      return;
    }
    Offset otl = player.holding!.topLeft;
    Offset obr = player.holding!.bottomRight;
    double boxDist = 5;
    player.holding!.bottomRight = ((player.bottomRight + Offset(-10, 10)) +
            Offset(gravity.sign * (15 + boxDist),
                -xGravity.sign * (15 + boxDist))) +
        Offset(5, -5);
    player.holding!.topLeft = player.holding!.bottomRight - Offset(10, -10);
    player.holding!.moveDir = Offset.zero;
    //impassables.add(Box(player.holding!.topLeft, Colors.blue));
    if (colliding(
        player.holding!.rect, playersCollide || player.holding is! PC)) {
      player.holding!.topLeft = otl;
      player.holding!.bottomRight = obr;
    }
  }

  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  void handleJDown(PC player) {
    if (!player.jumped) {
      jump(17, player);
      player.jumped = true;
    }
  }

  void jump(double h, PC player) {
    if (gravity.sign == 0 && xGravity.sign == 0) {
      _jump(h, player, gravity.sign.toInt(), xGravity.sign.toInt());
    } else {
      _jump(h, player, gravity.sign.toInt(), xGravity.sign.toInt());
    }
  }

  void _jump(double h, PC player, int yGravSign, int xGravSign) {
    player.topLeft -= Offset(3 * xGravSign / 1, 3 * yGravSign / 1);
    player.bottomRight -= Offset(3 * xGravSign / 1, 3 * yGravSign / 1);
    if (colliding(player.rect, playersCollide) || dashMode) {
      player.topLeft += Offset(6 * xGravSign / 1, 3 * yGravSign / 1);
      player.bottomRight += Offset(6 * xGravSign / 1, 3 * yGravSign / 1);
      player.moveDir += Offset(h * xGravSign, h * yGravSign);
    } else {
      player.topLeft += Offset(3 * xGravSign / 1, 3 * yGravSign / 1);
      player.bottomRight += Offset(3 * xGravSign / 1, 3 * yGravSign / 1);
    }
  }

  void handleTake(PC player) {
    final Impassable? holding = player.holding;
    if (holding != null) {
      Offset idir = player.moveDir;
      if (player.pressedsInited && player.leftPressed()) {
        player.moveDir += Offset(-2 * gravity.sign, 2 * xGravity.sign);
      }
      if (!player.pressedsInited && player.preRightPressed() ||
          player.pressedsInited && player.rightPressed()) {
        player.moveDir += Offset(2 * gravity.sign, -2 * xGravity.sign);
      }
      holding.moveDir = Offset(player.moveDir.dx, player.moveDir.dy);
      player.holding!.isHolding = false;
      player.holding!.color = player.holding!.startColor;
      player.holding = null;
      player.moveDir = idir;
      return;
    }
    player.topLeft += Offset(gravity.sign * 10, xGravity.sign * 10);
    player.bottomRight += Offset(gravity.sign * 10, xGravity.sign * 10);
    if (colliding(player.rect, playersCollide) && validTakeable(collided)) {
      player.holding = collided;
      player.holding!.color = Colors.orange;
      collided!.isHolding = true;
    }
    player.topLeft -= Offset(gravity.sign * 20, xGravity.sign * 20);
    player.bottomRight -= Offset(gravity.sign * 20, xGravity.sign * 20);
    if (colliding(player.rect, playersCollide) && validTakeable(collided)) {
      player.holding = collided;
      player.holding!.color = Colors.orange;
      collided!.isHolding = true;
    }
    player.topLeft += Offset(gravity.sign * 10, xGravity.sign * 10);
    player.bottomRight += Offset(gravity.sign * 10, xGravity.sign * 10);
  }

  String toString() {
    return 'PhysicsSimulator';
  }

  void bounce(Bouncy me, Impassable bounced) {
    if (me.bounceVertically) {
      bounced.moveDir = Offset(bounced.moveDir.dx, -bounced.moveDir.dy);
    } else {
      print('oldie: ${bounced.moveDir}');
      bounced.moveDir = Offset(-bounced.moveDir.dx, bounced.moveDir.dy);
      print('but the goodie: ${bounced.moveDir}');
    }
  }
}

class Impassable {
  bool isHolding = false;
  late final Color startColor = color;

  Impassable(this.topLeft, this.bottomRight, this.moveDir,
      [this.color = Colors.brown])
      : oldTopLeft = topLeft,
        oldBottomRight = bottomRight {
    startColor;
  }
  Offset topLeft;
  Offset bottomRight;
  List<Impassable>? room;
  final Offset oldTopLeft;
  final Offset oldBottomRight;
  Color color;
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
  String get type => 'RBox';
}

class DBox extends Impassable {
  DBox(Offset topLeft, Color? color)
      : super(topLeft, topLeft + Offset(10, -10), Offset.zero,
            color ?? Colors.lime);
  bool get pushable => true;
  String get type => 'DBox';
}

class ABox extends Impassable {
  ABox(Offset topLeft, Color? color)
      : super(topLeft, topLeft + Offset(10, -10), Offset.zero,
            color ?? Colors.green);
  bool get pushable => true;
  String get type => 'ABox';
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
    this.preRightPressed,
  ) : super(topLeft, bottomRight, moveDir, Colors.yellow);
  Impassable? holding;
  final LogicalKeyboardKey jumpKeybind;
  final LogicalKeyboardKey takeKeybind;
  final LogicalKeyboardKey rightKeybind;
  final LogicalKeyboardKey leftKeybind;
  bool jumped = false;
  bool pressedsInited = false;
  late final bool Function() leftPressed;
  final bool Function() preRightPressed;
  late final bool Function() rightPressed;
}

bool noop() {
  return false;
}

class Player extends PC {
  Player(Offset topLeft, Offset moveDir,
      [bool Function() prerightpressed = noop,
      LogicalKeyboardKey jumpKeybind = LogicalKeyboardKey.keyW,
      LogicalKeyboardKey takeKeybind = LogicalKeyboardKey.keyE,
      LogicalKeyboardKey rightKeybind = LogicalKeyboardKey.keyD,
      LogicalKeyboardKey leftKeybind = LogicalKeyboardKey.keyA])
      : super(topLeft, topLeft + Offset(20, -20), moveDir, jumpKeybind,
            takeKeybind, rightKeybind, leftKeybind, prerightpressed);
  bool get pushable => true;
  String get type => 'Player';
}
