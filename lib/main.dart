import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'dart:math';

import 'physics.dart';

void main() {
  runApp(MyApp());
}

Duration stopwatchElapsed = Duration.zero;

List<Impassable> imps = [
  Box(Offset(60, 90), Colors.orange),
  Button(Offset(60, 50), 0),
  Door(Offset(100, 80)),
  Impassable(Offset(-110, 200), Offset(-100, 0), Offset.zero),
  Player(Offset(0, 0), Offset(0, 0)),
];

class TitleScreen extends StatelessWidget {
  final void Function(Impassable, bool) startGame;

  TitleScreen(this.startGame, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return GameWidget(
      title: "Wooden Doors 2",
      nextLevel: (i, o, ip, time, winner) {
        if (i != 1) {
          assert(i == -1);
          return;
        }
        startGame(o, ip);
      },
      impassables: imps,
      sXVel: 1,
      endX: 120,
      auto: true,
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool titleScreen = true;

  bool endScreen = false;

  final List<List<Impassable>> levels = [
    [
      Box(Offset(00, 10), Colors.grey),
      Box(Offset(10, 10), Colors.grey),
      Box(Offset(20, 10), Colors.grey),
      Box(Offset(30, 10), Colors.grey),
      Box(Offset(40, 10), Colors.grey),
      Box(Offset(50, 10), Colors.grey),
      Box(Offset(60, 10), Colors.grey),
      Box(Offset(70, 10), Colors.grey),
      Box(Offset(80, 10), Colors.grey),
      Box(Offset(90, 10), Colors.grey),
    ],
    [
      Impassable(Offset(200, 200), Offset(300, 100), Offset.zero),
    ],
    [
      Impassable(Offset(200, 50), Offset(300, 0), Offset.zero),
    ],
    [
      Box(Offset(30, 10), Colors.grey),
      Impassable(Offset(50, 10), Offset(80, 0), Offset.zero),
      Impassable(Offset(210, 130), Offset(220, 0), Offset.zero),
    ],
    [
      Button(Offset(40, 20), 0),
      Impassable(Offset(150, 200), Offset(180, 30), Offset.zero),
      Impassable(Offset(180, 70), Offset(210, 30), Offset.zero),
      Door(Offset(210, 80)),
      Box(Offset(170, 10), Colors.grey),
    ],
    [
      Button(Offset(20, 20), 0),
      Button(Offset(60, 20), 1),
      Impassable(Offset(150, 200), Offset(180, 30), Offset.zero),
      Impassable(Offset(180, 70), Offset(210, 30), Offset.zero),
      Door(Offset(210, 80)),
      Door(Offset(220, 80)),
      Box(Offset(150, 10), Colors.grey),
      Box(Offset(170, 10), Colors.grey),
    ],
    [
      Impassable(Offset(210, 250), Offset(220, 0), Offset.zero),
      MovingPlatform(
          Offset(180, 20), Offset(210, 0), Offset(180, 250), Offset(0, 1)),
    ],
    [
      Impassable(Offset(80, 400), Offset(90, 310), Offset.zero),
      Impassable(Offset(50, 250), Offset(230, 240), Offset.zero),
      Impassable(Offset(220, 240), Offset(230, 0), Offset.zero),
      Impassable(Offset(80, 310), Offset(230, 300), Offset.zero),
      Door(Offset(70, 350)),
      Button(Offset(160, 20), 0),
      MovingPlatform(
          Offset(20, 20), Offset(50, 0), Offset(20, 270), Offset(0, 1)),
      Box(Offset(60, 260), Colors.grey),
    ],
    [
      Impassable(Offset(80, 400), Offset(90, 261), Offset.zero),
      Impassable(Offset(50, 250), Offset(100, 240), Offset.zero),
      Impassable(Offset(220, 240), Offset(230, 50), Offset.zero),
      Door(Offset(230, 71)),
      Button(Offset(100, 250), 0),
      MovingPlatform(
          Offset(20, 20), Offset(50, 0), Offset(20, 270), Offset(0, 1)),
      Impassable(Offset(130, 400), Offset(140, 240), Offset.zero),
      Box(Offset(60, 240), Colors.grey),
    ],
  ];

  final List<Rect> playerWrap = [Rect.fromLTRB(0, 0, 0, 0)];
  final List<String> texts = [
    "You found the secret box room!",
    "D to move the yellow square right. Get to the far right.",
    "W to jump.",
    "E near a box to pick up the box, and E to drop it",
    "If you put a box on a button, the corresponding door opens.",
    "More boxes, more buttons.",
    "The platform will bring you up.",
    "Challenge level!",
    "Slide the box under",
  ];
  int level = 1;

  List<double> goals = [
    320,
    320,
    320,
    230,
    230,
    230,
    230,
    230,
    270,
  ];
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: titleScreen
          ? TitleScreen((o, ip) {
              setState(() {
                if (ip) {
                  titleScreen = false;
                }
                levels[level].add(o..reset());
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "You have won the game in ${stopwatchElapsed.inSeconds}.${((stopwatchElapsed.inMilliseconds - stopwatchElapsed.inSeconds * 1000)).toString().padLeft(3, '0')} seconds (${stopwatchElapsed})",
                              style: TextStyle(color: Colors.brown),
                            ),
                            Text(
                              "Level results",
                              style: TextStyle(color: Colors.brown),
                            ),
                            ...levelData.map((e) => Text('$e'))
                          ],
                        ),
                        SizedBox(width: 10),
                        DoorWidget(),
                      ],
                    ),
                  ),
                )
              : GameWidget(
                  title:
                      '${texts[level]} (previous level ${level == 0 ? 'N/A' : '${levelData[level - 1]}'})',
                  endX: goals[level],
                  nextLevel: (i, o, ip, time, winner) {
                    setState(() {
                      levels[min(levels.length - 1, max(level + i, 0))].add(o);
                      if (ip) {
                        if (i == 1) {
                          levelData.last.time = time;
                          levelData.last.winner = winner;
                        }
                        if (level == levels.length - 1 && i == 1) {
                          endScreen = true;
                          return;
                        }
                        if (i == -1) {
                          if (level > 0) levelData.removeLast();
                        } else {
                          levelData.add(LevelData());
                        }
                        if (level + i >= 0) {
                          level += i;
                        }
                      }
                    });
                  },
                  impassables: levels[level],
                ),
    );
  }
}

class GameWidget extends StatefulWidget {
  final bool auto;

  final double endX;

  GameWidget(
      {Key? key,
      required this.title,
      required this.nextLevel,
      required this.impassables,
      required this.endX,
      this.sXVel = 0,
      this.auto = false})
      : super(key: key);

  final void Function(int, Impassable, bool, Duration, String) nextLevel;
  final String title;
  final double sXVel;

  final List<Impassable> impassables;

  @override
  _GameWidgetState createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget>
    with SingleTickerProviderStateMixin {
  late PhysicsSimulator physicsSimulator;
  late final Ticker ticker;
  @override
  void initState() {
    super.initState();
    setupPhysics(false);
    ticker = createTicker(tick)..start();
  }

  void setupPhysics(bool physicsSimExists) {
    if (physicsSimExists) {
      physicsSimulator.dispose();
    }
    physicsSimulator = PhysicsSimulator(
      (i, o, isPlayer, time, winner) {
        widget.nextLevel(i, o, isPlayer, time, winner);
      },
      widget.impassables,
      widget.endX,
    );
    physicsSimulator.addListener(() {
      setState(() {
        // equivalent to just calling markNeedsBuild
      });
    });
    while (true) {
      bool colliding = false;
      for (Impassable i in physicsSimulator.impassables.toList()) {
        if (physicsSimulator.colliding(i.rect)) {
          if (i.topLeft.dy > 400) {
            physicsSimulator.impassables.remove(i);
          }
          colliding = true;
          i.topLeft = Offset(i.topLeft.dx, i.topLeft.dy + 10);
          i.bottomRight = Offset(i.bottomRight.dx, i.bottomRight.dy + 10);
        }
      }
      if (!colliding) {
        break;
      }
    }
  }

  void reset() {
    physicsSimulator.reset();
  }

  late BuildContext focusContext;
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
              IconButton(onPressed: reset, icon: Icon(Icons.replay_outlined)),
              SizedBox(width: 40)
            ],
          ),
          body: GestureDetector(
            child: Center(
              child: LayoutBuilder(builder: (context, constraints) {
                return Container(
                  color: Colors.white,
                  height: 400,
                  child: CustomPaint(
                    painter: GamePainter(physicsSimulator.impassables,
                        physicsSimulator.dashMode, physicsSimulator.endX),
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

  void dispose() {
    ticker.dispose();
    physicsSimulator.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyPress(FocusNode node, RawKeyEvent event) {
    physicsSimulator.handleKeyPress(event);
    return KeyEventResult.handled;
  }

  void didUpdateWidget(GameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.impassables != widget.impassables) {
      setupPhysics(true);
    }
  }

  Duration pArg = Duration.zero;
  void tick(Duration arg) {
    if (arg - pArg >= Duration(milliseconds: 16)) {
      physicsSimulator.tick(
          Duration(milliseconds: (physicsSimulator.ticks * (1000 ~/ 60))));
      if (levelData.last.sti) {
        stopwatchElapsed =
            stopwatchElapsed + Duration(milliseconds: 1000 ~/ 60);
      }
      pArg = arg;
    }
  }
}

class GamePainter extends CustomPainter {
  static final TextPainter dash = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.flutter_dash.codePoint),
      style: TextStyle(
          fontFamily: Icons.flutter_dash.fontFamily,
          color: Colors.blue,
          fontSize: 20),
    ),
  )
    ..textDirection = TextDirection.ltr
    ..layout();
  final List<Impassable> impassables;

  final bool isDash;

  final double endX;

  GamePainter(this.impassables, this.isDash, this.endX);
  @override
  void paint(Canvas canvas, Size size) {
    if (impassables.every((a) => a is! PC)) {
      return;
    }
    double x = endX -
        (impassables.whereType<PC>().first.topLeft.dx - size.width / 2) +
        10;

    double x2 = -endX -
        (impassables.whereType<PC>().first.topLeft.dx - size.width / 2) +
        10;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.green
        ..strokeWidth = 20,
    );
    canvas.drawLine(
      Offset(x2, 0),
      Offset(x2, size.height),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 20,
    );
    for (double i = -1; i < size.width / 10; i++) {
      canvas.drawCircle(
          Offset(i * 10 - impassables.whereType<PC>().first.topLeft.dx % 10,
              size.height),
          1,
          Paint()..color = Colors.black);
      canvas.drawRect(
          Offset(i * 10 - impassables.whereType<PC>().first.topLeft.dx % 10,
                  0) &
              Size(1, 1),
          Paint()..color = Color(0xFF202020));
    }
    for (Impassable impassable in impassables) {
      Color color = impassable.color;
      canvas.drawRect(
        Rect.fromLTRB(
          impassable.topLeft.dx -
              (impassables.whereType<PC>().first.topLeft.dx - size.width / 2),
          (size.height) - (impassable.topLeft.dy),
          impassable.bottomRight.dx -
              (impassables.whereType<PC>().first.topLeft.dx - size.width / 2),
          (size.height) - (impassable.bottomRight.dy),
        ),
        Paint()..color = color,
      );
    }
    if (isDash)
      dash.paint(
          canvas,
          Offset(size.width / 2,
              ((size.height) - impassables.whereType<PC>().first.topLeft.dy)));
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
