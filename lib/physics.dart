import 'dart:async';
import 'dart:ui' show Offset, Rect, VoidCallback, Size;

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, RawKeyDownEvent, RawKeyUpEvent;
import 'package:flutter/widgets.dart'
    show ChangeNotifier, RawKeyEvent, mustCallSuper;

final Stopwatch stopwatch = Stopwatch();

class PhysicsSimulator extends ChangeNotifier {
  static const double kVelStep = .1;
  static const bool dashMode = false;
  static const double friction = 0.01;

  PhysicsSimulator(this.nextLevel, this.impassables, this.endX);
  final VoidCallback nextLevel;

  Impassable? collided;
  bool colliding<T extends Impassable>([Impassable? obj]) {
    MapEntry<bool, Impassable?> r =
        collidingStatic<T>(player, impassables, obj);
    collided = r.value;
    return r.key;
  }

  static MapEntry<bool, Impassable?> collidingStatic<T extends Impassable>(
      Rect player, List<Impassable> impassables,
      [Impassable? obj]) {
    Rect rect = obj?.rect ?? player;
    Impassable? collided;
    if ((rect.top < 0 || rect.bottom > 400) && T == Impassable) {
      return MapEntry(true, collided);
    }
    for (Impassable wall in impassables) {
      if (!rect.intersect(wall.rect).isEmpty && wall is T && obj != wall) {
        collided = wall;
        return MapEntry(true, collided);
      }
    }
    if (obj != null && !rect.intersect(player).isEmpty) {
      return MapEntry(true, null);
    }
    collided = null;
    return MapEntry(false, collided);
  }

  void initState() {
    setUpdateTimer();
  }

  void reset() {
    for (Impassable obj in impassables) {
      Offset oTL = obj.topLeft;
      Offset oBR = obj.bottomRight;
      obj.reset();
      if (colliding(obj)) {
        obj.topLeft = oTL;
        obj.bottomRight = oBR;
      }
    }
    notifyListeners();
  }

  double playerX = 0;
  double playerY = 0;
  Rect get player => Offset(playerX, playerY) & Size(20, 20);
  double xVel = 0;
  double yVel = 0;
  final List<Impassable> impassables;

  Timer? timer;
  final double endX;

  void setUpdateTimer() {
    timer = Timer.periodic(Duration(milliseconds: (100 / 6).round()), (timer) {
      for (Button button in impassables.whereType<Button>()) {
        (impassables[button.door] as Door).open = false;
      }
      holding?.topLeft -= Offset(0, 1);
      holding?.bottomRight -= Offset(0, 1);
      playerY--;
      if (colliding(holding) && !colliding()) {
        playerY++;
        updateHoldingPos();
        playerY--;
        holding = null;
      }
      playerY++;
      updateHoldingPos();
      if (playerX >= endX) {
        playerX = 0;
        nextLevel();
        return;
      }
      assert(!colliding(), "ERROR: COLLIDING with $collided AT START");
      for (double i = 0; i < xVel.abs(); i += kVelStep) {
        playerX += (xVel < 0 ? -1 : 1) * kVelStep;
        updateHoldingPos();
        updateCollision(null, xVel, 0, true);
      }
      assert(!colliding(), "ERROR: COLLIDING after XMV");
      for (double i = 0; i < yVel.abs(); i += kVelStep) {
        var speed = (yVel < 0 ? -1 : 1) * kVelStep;
        playerY += speed;
        updateHoldingPos();
        if (colliding() || colliding(holding)) {
          playerY -= speed;
          updateHoldingPos();
          yVel = 0;
          break;
        }
      }
      if (collided is Button) {
        (impassables[(collided as Button).door] as Door).open = true;
      }

      yVel -= 1;
      for (Impassable platform in impassables) {
        platform.topLeft -= Offset(0, 1);
        platform.bottomRight -= Offset(0, 1);
        if (platform.moveDir.dx != 0 && colliding(platform)) {
          platform.moveDir.dx < 0
              ? platform.moveDir += Offset(friction, 0)
              : platform.moveDir -= Offset(friction, 0);
        }
        platform.topLeft += Offset(0, 1);
        platform.bottomRight += Offset(0, 1);
        for (double i = 0; i < platform.moveDir.dx.abs(); i += kVelStep) {
          double speed = (platform.moveDir.dx < 0 ? -1 : 1) * kVelStep;
          platform.topLeft += Offset(speed, 0);
          platform.bottomRight += Offset(speed, 0);
          bool playerMVD = false;
          if (colliding() || colliding(holding)) {
            playerX += speed;
            updateHoldingPos();
            playerMVD = true;
          }
          updateCollision(platform, speed, 0, playerMVD);
        }

        assert(!colliding());
        for (double i = 0; i < platform.moveDir.dy.abs(); i += kVelStep) {
          double speed = (platform.moveDir.dy < 0 ? -1 : 1) * kVelStep;
          platform.topLeft += Offset(0, speed);
          platform.bottomRight += Offset(0, speed);
          bool playerMVD = false;
          if (colliding() || colliding(holding)) {
            playerY += speed;
            updateHoldingPos();
            playerMVD = true;
          }

          updateCollision(platform, 0, speed, playerMVD);
        }
        double oX = platform.topLeft.dx;
        double oY = platform.topLeft.dy;
        platform.tick();
        double sX = platform.topLeft.dx - oX;
        double sY = platform.topLeft.dy - oY;

        bool playerMVD = false;
        if (colliding() || colliding(holding)) {
          playerX += sX;
          playerY += sY;
          playerMVD = true;
          updateHoldingPos();
        }
        if (sX != 0 || sY != 0)
          updateCollision(platform, sX, sY, playerMVD, untick: true);
      }
      notifyListeners();
    });
  }

  void updateCollision(
      Impassable? platform, double sX, double sY, bool playerMVD,
      {bool untick = false}) {
    assert(sX != 0.0 || sY != 0.0);
    Set<Impassable?> pushing = {platform, holding};
    bool reverting = false;
    while (!reverting) {
      if (colliding()) {
        if (playerMVD) {
          if (collided == null || !collided!.pushable) reverting = true;
          if (collided is Button) {
            (impassables[(collided as Button).door] as Door).open = true;
          }
          collided?.topLeft += Offset(sX, sY);
          collided?.bottomRight += Offset(sX, sY);
          pushing.add(collided);
        } else {
          playerX += sX;
          playerY += sY;
        }
        playerMVD = true;
      } else if (pushing.any((element) => colliding(element))) {
        if (collided == null || !collided!.pushable) reverting = true;
        if (collided is Button) {
          (impassables[(collided as Button).door] as Door).open = true;
        }
        collided?.topLeft += Offset(sX, sY);
        collided?.bottomRight += Offset(sX, sY);
        pushing.add(collided);
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
              sX == 0 ? thing.moveDir.dx : 0, sY == 0 ? thing.moveDir.dy : 0);
        }
        if (playerMVD) {
          playerX -= sX;
          playerY -= sY;
        }
        updateHoldingPos();
        if (untick) platform?.unTick();
        break;
      }
    }
  }

  void updateHoldingPos() {
    holding?.bottomRight = player.topLeft +
        Offset(
            player.width + holding!.rect.width + 2, holding!.rect.height + 0);
    holding?.topLeft = player.topLeft + Offset(player.width + 2, 0);
    holding?.moveDir = Offset.zero;
  }

  bool jumped = false;

  void dispose() {
    super.dispose();
    timer?.cancel();
  }

  void handleKeyPress(RawKeyEvent event) {
    if (!stopwatch.isRunning) stopwatch.start();
    if (event is RawKeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) jumped = false;
      if ((event.logicalKey == LogicalKeyboardKey.keyD && xVel == 2) ||
          (event.logicalKey == LogicalKeyboardKey.keyA && xVel == -2) ||
          (event.logicalKey == LogicalKeyboardKey.arrowRight && xVel == 1) ||
          (event.logicalKey == LogicalKeyboardKey.arrowLeft && xVel == -1))
        xVel = 0;
    }

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyD) {
        xVel = 2;
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        xVel = -2;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        xVel = 1;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        xVel = -1;
      } else if (event.logicalKey == LogicalKeyboardKey.keyW && !jumped) {
        jump(15);
        jumped = true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && !jumped) {
        jump(5);
        jumped = true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
        handleTake();
      }
    }
  }

  void jump(double h) {
    playerY -= 3;
    if (colliding() || dashMode) {
      yVel = h;
    }
    playerY += 3;
  }

  Impassable? holding;
  void handleTake() {
    if (holding != null) {
      holding!.moveDir = Offset(xVel, yVel);
      holding = null;
      return;
    }
    playerX += 10;
    if (colliding<Box>() && collided != null) {
      Offset oldTL = collided!.topLeft;
      Offset oldBR = collided!.bottomRight;
      holding = collided;

      playerX -= 10;
      updateHoldingPos();
      if (colliding(holding)) {
        holding!.topLeft = oldTL;
        holding!.bottomRight = oldBR;
        holding = null;
      }
      playerX += 10;
    }
    playerX -= 20;
    if (colliding<Box>() && collided != null) {
      Offset oldTL = collided!.topLeft;
      Offset oldBR = collided!.bottomRight;
      holding = collided;

      playerX += 10;
      updateHoldingPos();
      if (colliding(holding)) {
        holding!.topLeft = oldTL;
        holding!.bottomRight = oldBR;
        holding = null;
      }
      playerX -= 10;
    }
    playerX += 10;
  }
}

class Impassable {
  Impassable(this.topLeft, this.bottomRight, this.moveDir) {
    // ignore: unnecessary_statements
    oldBottomRight;
    // ignore: unnecessary_statements
    oldTopLeft;
  }
  Offset topLeft;
  Offset bottomRight;
  late final Offset oldTopLeft = topLeft;
  late final Offset oldBottomRight = bottomRight;

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
