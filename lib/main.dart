import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class TitleScreen extends StatelessWidget {
  final VoidCallback startGame;

  TitleScreen(this.startGame, {Key key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return GameWidget(
      title: "Wooden Doors 2",
      toEnd: () {
        startGame();
      },
      reset: () {},
      impassables: [Button(Offset(60, 50), titleDoor), titleDoor],
      sXVel: 1,
      autoJump: true,
    );
  }
}

final Door titleDoor = Door(Offset(100, 100));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

Door door = Door(Offset(210, 100));

class _MyAppState extends State<MyApp> {
  bool titleScreen = true;

  bool endScreen = false;

  final List<List<Impassable>> levels = [
    [
      Box(Offset(150, 10)),
      Box(Offset(170, 10)),
      Box(Offset(190, 10)),
      Box(Offset(230, 10)),
      Box(Offset(250, 10)),
      Box(Offset(270, 10)),
      Box(Offset(290, 10)),
      Box(Offset(310, 10)),
      Impassable(Offset(200, 200), Offset(300, 100), Offset.zero),
    ],
    [
      Impassable(Offset(200, 50), Offset(300, 0), Offset.zero),
    ],
    [
      Button(Offset(150, 50), door),
      Impassable(Offset(150, 130), Offset(180, 50), Offset.zero),
      Impassable(Offset(180, 50), Offset(210, 30), Offset.zero),
      door,
    ],
    [
      Box(Offset(150, 10)),
      Box(Offset(170, 10)),
      Box(Offset(190, 10)),
      Box(Offset(230, 10)),
      Box(Offset(250, 10)),
      Box(Offset(270, 10)),
      Box(Offset(290, 10)),
      Box(Offset(310, 10)),
      Button(Offset(150, 50), door),
      Impassable(Offset(150, 130), Offset(180, 50), Offset.zero),
      Impassable(Offset(180, 70), Offset(210, 30), Offset.zero),
      door,
    ],
  ];
  final List<String> texts = [
    "D to move the yellow square right. Get to the far right.",
    "W to jump.",
    "Jump under the red box, activating the button, to open the door.",
    "Press E to the IMMEDIATE left of the box to pick up the box. Press it again to stop."
  ];
  int level = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: titleScreen
          ? TitleScreen(() {
              setState(() {
                titleScreen = false;
              });
            })
          : endScreen
              ? Material(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DoorWidget(),
                        SizedBox(width: 10),
                        Text(
                          "The End (for now!)",
                          style: TextStyle(fontSize: 20, color: Colors.brown),
                        ),
                        SizedBox(width: 10),
                        DoorWidget()
                      ],
                    ),
                  ),
                )
              : GameWidget(
                  title: texts[level],
                  toEnd: () {
                    setState(() {
                      level++;
                      door.open = false;
                      if (level >= levels.length) {
                        endScreen = true;
                      }
                    });
                  },
                  reset: () {
                    setState(() {
                      titleScreen = true;
                      endScreen = false;
                      level = 0;
                      titleDoor.open = false;

                      door.open = false;
                    });
                  },
                  impassables: levels[level],
                ),
    );
  }
}

class GameWidget extends StatefulWidget {
  final bool autoJump;

  GameWidget(
      {Key key,
      @required this.title,
      @required this.toEnd,
      @required this.reset,
      @required this.impassables,
      this.sXVel = 0,
      this.autoJump = false})
      : super(key: key);

  final VoidCallback toEnd;
  final VoidCallback reset;
  final String title;
  final double sXVel;

  final List<Impassable> impassables;

  @override
  _GameWidgetState createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> {
  static const double kVelStep = 1;

  Impassable collided;
  VoidCallback get callback => widget.toEnd;
  bool colliding<T extends Impassable>([Impassable obj]) {
    Rect rect = obj?.rect ?? player;
    for (Impassable wall in impassables) {
      if (!rect.intersect(wall.rect).isEmpty && wall is T && obj != wall) {
        if (wall is Button) wall.door.open = !wall.door.open;
        collided = wall;
        return true;
      }
    }
    collided = null;
    if (rect.topLeft.dy < 0 || rect.topLeft.dy > 400) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    xVel = widget.sXVel;
    if (!widget.autoJump) setUpdateTimer();
  }

  double playerX = 0;
  double playerY = 0;
  Rect get player => Offset(playerX, playerY) & Size(20, 20);
  double xVel;
  double yVel = 0;
  List<Impassable> get impassables => widget.impassables;
  BuildContext focusContext;
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKey: _handleKeyPress,
      debugLabel: 'Button',
      child: Builder(builder: (context) {
        focusContext = context;
        Focus.of(focusContext).requestFocus();
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                  onPressed: widget.reset, icon: Icon(Icons.replay_outlined)),
              if (timer == null)
                IconButton(
                    onPressed: setUpdateTimer, icon: Icon(Icons.play_arrow)),
              SizedBox(width: 40)
            ],
          ),
          body: ColoredBox(
            color: Colors.black,
            child: GestureDetector(
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  color: Colors.white,
                  child: CustomPaint(
                    painter: GamePainter(playerX, playerY, impassables),
                    size: Size.square(200),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(width: 4)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Timer timer;
  double get endX {
    double maxResult = 0;
    for (Impassable impassable in impassables) {
      if ((impassable.bottomRight.dx + 100) > maxResult)
        maxResult = (impassable.bottomRight.dx + 100);
    }
    return maxResult;
  }

  void setUpdateTimer() {
    timer = Timer.periodic(
      Duration(milliseconds: (100 / 6).round()),
      (timer) {
        setState(() {
          holding?.topLeft -= Offset(0, 1);
          holding?.bottomRight -= Offset(0, 1);
          playerY--;
          if (colliding(holding) && !colliding()) {
            updateHoldingPos();
            holding = null;
          }
          playerY++;
          updateHoldingPos();
          if (playerX >= endX) {
            playerX = 0;
            callback();
          }
          if (playerX == 80 && widget.autoJump && !jumped) {
            jump(10);
            jumped = true;
          }
          if (colliding()) print("ERROR: COLLIDING AT START");
          for (double i = 0; i < kVelStep * xVel.abs(); i += kVelStep) {
            playerX += (xVel < 0 ? -1 : 1) * kVelStep;
            updateHoldingPos();
            if (colliding() || colliding(holding)) {
              playerX -= (xVel < 0 ? -1 : 1) * kVelStep;
              updateHoldingPos();
              break;
            }
          }
          if (colliding()) print("ERROR: COLLIDING AT START-ish");
          for (double i = 0; i < kVelStep * yVel.abs(); i += kVelStep) {
            var spd = (yVel < 0 ? -1 : 1) * kVelStep;
            playerY += spd;
            updateHoldingPos();
            if (colliding() || colliding(holding)) {
              playerY -= spd;
              updateHoldingPos();
              yVel = 0;
              break;
            }
          }

          yVel -= 1;
          for (Impassable platform in impassables) {
            platform.topLeft -= Offset(0, 1);
            platform.bottomRight -= Offset(0, 1);
            if (colliding(platform)) {
              platform.moveDir.dx < 0
                  ? platform.moveDir += Offset(.01, 0)
                  : platform.moveDir.dx == 0
                      ? null
                      : platform.moveDir -= Offset(.01, 0);
            }
            platform.topLeft += Offset(0, 1);
            platform.bottomRight += Offset(0, 1);
            for (double i = 0;
                i < kVelStep * platform.moveDir.dx.abs();
                i += kVelStep) {
              double spd = (platform.moveDir.dx < 0 ? -1 : 1) * kVelStep;
              platform.topLeft += Offset(spd, 0);
              platform.bottomRight += Offset(spd, 0);
              bool playerMVD = false;
              if (colliding() || colliding(holding)) {
                playerX += spd;
                updateHoldingPos();
                playerMVD = true;
              }
              updateCollision(platform, spd, 0, playerMVD);
            }

            if (colliding()) print("ERROR: COLLIDING AFTER PXMV");
            for (double i = 0;
                i < kVelStep * platform.moveDir.dy.abs();
                i += kVelStep) {
              double spd = (platform.moveDir.dy < 0 ? -1 : 1) * kVelStep;
              print("DEBUG: ${platform.topLeft} $spd");
              platform.topLeft += Offset(0, spd);
              platform.bottomRight += Offset(0, spd);
              bool playerMVD = false;
              if (colliding() || colliding(holding)) {
                playerY += spd;
                updateHoldingPos();
                playerMVD = true;
              }

              updateCollision(platform, 0, spd, playerMVD);
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
            updateCollision(platform, sX, sY, playerMVD);
          }
        });
      },
    );
  }

  void updateCollision(
      Impassable platform, double sX, double sY, bool playerMVD) {
    List<Impassable> pushing = [platform, null, holding];
    bool handling = true;
    while (handling) {
      if (pushing.any((element) => colliding(element)) &&
          (collided?.pushable ?? false)) {
        collided.topLeft += Offset(sX, sY);

        collided.bottomRight += Offset(sX, sY);
        pushing.add(collided);
      }
      if (collided == null) {
        for (Impassable thing in pushing) {
          thing?.topLeft -= Offset(sX, sY);
          thing?.bottomRight -= Offset(sX, sY);
          thing?.moveDir = Offset(0, 0);
        }
        if (playerMVD) {
          playerX -= sX;
          playerY -= sY;
        }
        updateHoldingPos();
        break;
      }
    }
  }

  void updateHoldingPos() {
    holding?.bottomRight = player.topLeft +
        Offset(player.width + holding.rect.width + 2, holding.rect.height + 1);
    holding?.topLeft = player.topLeft + Offset(player.width + 2, 1);
    holding?.moveDir = Offset.zero;
  }

  bool jumped = false;

  void dispose() {
    super.dispose();
    timer?.cancel();
  }

  KeyEventResult _handleKeyPress(FocusNode node, RawKeyEvent event) {
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
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && !jumped) {
        jump(5);
        jumped = true;
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
        handleTake();
      }
    }

    return KeyEventResult.handled;
  }

  void jump(double h) {
    playerY -= 3;
    if (colliding()) {
      yVel = h;
    }
    playerY += 3;
  }

  Impassable holding;
  void handleTake() {
    if (holding != null) {
      holding.moveDir = Offset(xVel, yVel);
      holding = null;
      return;
    }
    playerX++;
    playerY--;
    if (colliding<Box>()) {
      Offset oldTL = collided?.topLeft ?? Offset(0, 0);
      Offset oldBR = collided?.bottomRight ?? Offset(0, 0);
      holding = collided;
      updateHoldingPos();
      if (colliding(holding)) {
        holding?.topLeft = oldTL;
        holding?.bottomRight = oldBR;
        holding = null;
      }
    }
    playerX--;
    playerY++;
  }
}

class Impassable {
  Offset topLeft;
  Offset bottomRight;
  bool get pushable => false;
  Rect get rect => Rect.fromPoints(topLeft, bottomRight);
  Offset moveDir;
  void tick() {}
  Impassable(this.topLeft, this.bottomRight, this.moveDir);

  void unTick() {}
}

class Door extends Impassable {
  Door(Offset topLeft, {this.open = false})
      : t = open ? 0 : 1,
        super(topLeft, topLeft + Offset(10, -50), Offset.zero);
  bool open = false;
  double t = 1;
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

  final Door door;

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

class GamePainter extends CustomPainter {
  final double playerX;
  final double playerY;
  final List<Impassable> impassables;

  GamePainter(this.playerX, this.playerY, this.impassables);
  @override
  void paint(Canvas canvas, Size size) {
    if (playerX < 100)
      canvas.drawLine(Offset(0 - (playerX - 100), 200),
          Offset(0 - (playerX - 100), 0), Paint()..color = Colors.red);
    canvas.drawRect(
        Offset(size.width / 2, (size.height / 2) - playerY) & Size.square(20),
        Paint()..color = Colors.yellow);
    for (double i = -1; i < 21; i++) {
      canvas.drawCircle(Offset(i * 10 - playerX % 10, (size.height / 2) + 20),
          1, Paint()..color = Colors.black);
      canvas.drawCircle(Offset(i * 10 - playerX % 10, (size.height / 2) - 400),
          1, Paint()..color = Colors.white);
    }
    for (Impassable impassable in impassables) {
      canvas.drawRect(
        Rect.fromLTRB(
          math.max(
            math.min(
              impassable.topLeft.dx - (playerX - size.width / 2),
              size.width,
            ),
            0,
          ),
          (size.height / 2) - (impassable.topLeft.dy - 20),
          math.min(
            math.max(
              impassable.bottomRight.dx - (playerX - size.width / 2),
              0,
            ),
            size.width,
          ),
          (size.height / 2) - (impassable.bottomRight.dy - 20),
        ),
        Paint()..color = impassable is Button ? Colors.red : Colors.brown,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DoorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 50,
      color: Colors.brown,
    );
  }
}
