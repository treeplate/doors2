import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      endX: 120,
      autoJump: true,
    );
  }
}

final Door titleDoor = Door(Offset(100, 80));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

Door door = Door(Offset(210, 80));

class _MyAppState extends State<MyApp> {
  bool titleScreen = false;

  bool endScreen = false;

  final List<List<Impassable>> levels = [
    [
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
      Box(Offset(170, 200)),
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

  List<double> goals = [320, 320, 230, 230];
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
                  endX: goals[level],
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
                      //titleScreen = true;
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

  final double endX;

  GameWidget(
      {Key key,
      @required this.title,
      @required this.toEnd,
      @required this.reset,
      @required this.impassables,
      @required this.endX,
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
  static const double kVelStep = .1;
  static const bool dashMode = false;
  static const double friction = 0.01;

  Impassable collided;
  VoidCallback get callback => widget.toEnd;
  bool colliding<T extends Impassable>([Impassable obj]) {
    Rect rect = obj?.rect ?? player;
    collided = null;
    if ((rect.top < 0 || rect.bottom > 400) && T == Impassable) {
      return true;
    }
    for (Impassable wall in impassables) {
      if (!rect.intersect(wall.rect).isEmpty && wall is T && obj != wall) {
        collided = wall;
        return true;
      }
    }
    collided = null;
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
          body: GestureDetector(
            child: Center(
              child: LayoutBuilder(builder: (context, constraints) {
                screenWidth = constraints.biggest.width;
                return Container(
                  color: Colors.white,
                  height: 400,
                  child: CustomPaint(
                    painter: GamePainter(
                        playerX, playerY, impassables, dashMode, endX),
                    size: Size(constraints.biggest.width, 400),
                  ),
                );
              }),
            ),
          ),
        );
      }),
    );
  }

  double screenWidth = double.infinity;
  Timer timer;
  double get endX => widget.endX;

  void setUpdateTimer() {
    timer = Timer.periodic(
      Duration(milliseconds: (100 / 6).round()),
      (timer) {
        setState(() {
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
            callback();
            return;
          }
          if (playerX == 80 && widget.autoJump && !jumped) {
            jump(10);
            jumped = true;
          }
          assert(!colliding(), "ERROR: COLLIDING AT START");
          for (double i = 0; i < xVel.abs(); i += kVelStep) {
            playerX += (xVel < 0 ? -1 : 1) * kVelStep;
            updateHoldingPos();
            if (colliding() || colliding(holding)) {
              playerX -= (xVel < 0 ? -1 : 1) * kVelStep;
              updateHoldingPos();
              break;
            }
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
            (collided as Button).door.open = !(collided as Button).door.open;
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
        });
      },
    );
  }

  void updateCollision(
      Impassable platform, double sX, double sY, bool playerMVD,
      {bool untick = false}) {
    assert(sX != 0.0 || sY != 0.0);
    Set<Impassable> pushing = {platform, holding};
    bool reverting = false;
    while (!reverting) {
      if (colliding()) {
        if (playerMVD) {
          reverting = true;
        } else {
          playerX += sX;
          playerY += sY;
        }
        playerMVD = true;
      } else if (pushing.any((element) => colliding(element))) {
        if (collided == null || !collided.pushable) reverting = true;
        collided?.topLeft += Offset(sX, sY);
        collided?.bottomRight += Offset(sX, sY);
        pushing.add(collided);
      } else {
        break;
      }
      if (reverting) {
        for (Impassable thing in pushing) {
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
        if (untick) platform.unTick();
        break;
      }
    }
  }

  void updateHoldingPos() {
    holding?.bottomRight = player.topLeft +
        Offset(player.width + holding.rect.width + 2, holding.rect.height + 0);
    holding?.topLeft = player.topLeft + Offset(player.width + 2, 0);
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
    if (colliding() || dashMode) {
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
    if (colliding<Box>() && collided != null) {
      Offset oldTL = collided.topLeft;
      Offset oldBR = collided.bottomRight;
      holding = collided;

      playerY++;
      playerX--;
      updateHoldingPos();
      if (colliding(holding)) {
        holding.topLeft = oldTL;
        holding.bottomRight = oldBR;
        holding = null;
      }
      playerY--;
      playerX++;
    }
    playerX--;
    playerY++;
  }
}

class Impassable {
  Impassable(this.topLeft, this.bottomRight, this.moveDir);
  Offset topLeft;
  Offset bottomRight;
  bool get pushable => false;
  Rect get rect => Rect.fromPoints(topLeft, bottomRight);
  Offset moveDir;
  void tick() {}

  void unTick() {}
  String toString() =>
      "$runtimeType ($hashCode) at $topLeft (moveDir: $moveDir)";
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
  static final TextPainter dash = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(Icons.flutter_dash.codePoint),
          style: TextStyle(
              fontFamily: Icons.flutter_dash.fontFamily,
              color: Colors.blue,
              fontSize: 20)))
    ..textDirection = TextDirection.ltr
    ..layout();
  final double playerX;
  final double playerY;
  final List<Impassable> impassables;

  final bool isDash;

  final double endX;

  GamePainter(
      this.playerX, this.playerY, this.impassables, this.isDash, this.endX);
  @override
  void paint(Canvas canvas, Size size) {
    for (double x = endX - (playerX - size.width / 2);
        x < endX - (playerX - size.width / 2) + 20;
        x++) {
      canvas.drawLine(
        Offset(x, playerX + 20 > x + (playerX - size.width / 2) ? size.height - playerY : 0),
        Offset(x, size.height),
        Paint()..color = Colors.green,
      );
    }
    canvas.drawRect(
        Offset(size.width / 2, ((size.height) - playerY) - 20) &
            Size.square(20),
        Paint()..color = Colors.yellow);
    canvas.drawRect(Rect.fromLTRB(size.width / 2, 0, size.width / 2 + 20, size.height - playerY), Paint()..color = Colors.black.withAlpha(20));
    if (isDash)
      dash.paint(
          canvas, Offset(size.width / 2, ((size.height) - playerY) - 20));
    for (double i = -1; i < size.width / 10; i++) {
      canvas.drawCircle(Offset(i * 10 - playerX % 10, size.height), 1,
          Paint()..color = Colors.black);
      canvas.drawRect(
          Offset(i * 10 - playerX % 10, 0) & Size(1, 1), Paint()..color = Color(0xFF202020));
    }
    for (Impassable impassable in impassables) {
      canvas.drawRect(
        Rect.fromLTRB(
          impassable.topLeft.dx - (playerX - size.width / 2),
          (size.height) - (impassable.topLeft.dy),
          impassable.bottomRight.dx - (playerX - size.width / 2),
          (size.height) - (impassable.bottomRight.dy),
        ),
        Paint()..color = impassable is Button ? Colors.red.withAlpha(100) : Colors.brown.withAlpha(100),
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
