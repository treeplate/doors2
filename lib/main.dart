import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:platformy/fpw_template.dart'
    if (dart.library.io) 'file_picker_wrapper_io.dart';

import 'dart:math';

import 'midi-parser.dart';
import 'physics.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

double fps = 0;
double maxFps = 0;

Duration stopwatchElapsed = Duration.zero;

List<Impassable> imps = [
  Box(Offset(60, 90), Colors.grey),
  Button(Offset(60, 50), 0),
  Door(Offset(100, 80)),
  Impassable(Offset(-110, 200), Offset(-100, 0), Offset.zero),
];

class TitleScreen extends StatelessWidget {
  final void Function(Impassable, bool) startGame;
  final VoidCallback toggleDarkMode;

  final bool darkMode;

  TitleScreen(this.startGame,
      {Key? key, required this.darkMode, required this.toggleDarkMode})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return GameWidget(
      title: "Wooden Doors 2 (Hold D to start)",
      nextLevel: (i, o, ip, ticks, winner) {
        if (i != 1) {
          assert(i == -1);
          // look they're not supposed to be here so let's reward them by bringing them to the first level
        }
        if (ip) {
          stopwatchElapsed = Duration.zero;
          o.moveDir = Offset.zero;
        }
        startGame(o, ip);
      },
      impassables: imps,
      sXVel: 1,
      endX: 120,
      auto: true,
      doTasIn: false,
      darkMode: darkMode,
      toggleDarkMode: toggleDarkMode,
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
      Impassable(Offset(-210, 400), Offset(-200, 0),
          Offset.zero), // if you can't fix the bug, work around it!
      Box(Offset(00, 10), null),
      RBox(Offset(10, 400), null),
      DBox(Offset(21, 400), null),
      DBox(Offset(30, 10), null),
      Box(Offset(40, 400), null),
      RBox(Offset(50, 10), null),
      ABox(Offset(60, 400), null),
      DBox(Offset(70, 10), null),
      Box(Offset(80, 400), null),
      RBox(Offset(90, 10), null),
      ABox(Offset(100, 400), null),
      ABox(Offset(110, 10), null),
      Box(Offset(120, 400), null),
      Box(Offset(131, 400), null),
    ],
    [
      Impassable(Offset(200, 200), Offset(300, 100), Offset.zero),
    ],
    [
      Impassable(Offset(200, 50), Offset(300, 0), Offset.zero),
    ],
    [
      Box(Offset(30, 10), null),
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
    [
      Bouncy(Offset(251, 50), Offset(300, 0), true),
      MovingPlatform(
          Offset(200, 20), Offset(50, 0), Offset(200, 270), Offset(0, 1)),
      Impassable(Offset(380, 310), Offset(500, 0), Offset.zero),
      Impassable(Offset(200, 300), Offset(250, 310), Offset.zero),
      Impassable(Offset(360, 300), Offset(379, 310), Offset.zero),
    ],
  ];

  final List<Rect> playerWrap = [Rect.fromLTRB(0, 0, 0, 0)];
  final List<String> texts = [
    "You found the secret box room!",
    "D to move the yellow square right (and A to move it left). Get to the far right (the green beacon).",
    "W to jump.",
    "E near a box to pick up the box, and E to drop it",
    "If you put a box on a button, the corresponding door opens.",
    "More boxes, more buttons.",
    "The platform will bring you up.",
    "Challenge level!",
    "Slide the box under",
    "Bouncy Platforms!",
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
    500,
  ];

  late bool darkMode =
      View.of(this.context).platformDispatcher.platformBrightness ==
          Brightness.dark;
  void toggleDarkMode() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  Map<int, LevelData> levelData = {};
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: titleScreen
          ? TitleScreen(darkMode: darkMode, toggleDarkMode: toggleDarkMode,
              (o, ip) {
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
                            Text(
                              levelData.entries
                                  .map((e) => "level ${e.key}: ${e.value}")
                                  .join('\n'),
                              style: TextStyle(color: Colors.brown),
                            ),
                          ],
                        ),
                        SizedBox(width: 10),
                        DoorWidget(),
                      ],
                    ),
                  ),
                )
              : SizedBox(
                  height: 400,
                  child: GameWidget(
                    doTasIn: true,
                    darkMode: darkMode,
                    toggleDarkMode: toggleDarkMode,
                    title:
                        '${texts[level]} (previous level ${levelData[level - 1] ?? 'does not exist'})',
                    endX: goals[level],
                    nextLevel: (i, o, ip, ticks, winner) {
                      setState(() {
                        levels[min(levels.length - 1, max(level + i, 0))]
                            .add(o);

                        correctCollisions(levels[min(levels.length - 1,
                            max(level + i, 0))]); // o may be somewhere bad
                        if (ip) {
                          if (i == 1) {
                            levelData[level] = LevelData(winner, ticks);
                          }
                          if (level == levels.length - 1 && i == 1) {
                            endScreen = true;
                            return;
                          }
                          if (level + i >= 0) {
                            level += i;
                          }
                        }
                      });
                    },
                    impassables: levels[level],
                  ),
                ),
    );
  }
}

class LevelData {
  final String winner;
  final int time;

  String toString() =>
      "$winner won in ${Duration(milliseconds: ((time / 60) * 1000).ceil())} ($time frames)";

  LevelData(this.winner, this.time);
}

bool tasOut = false;

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
      this.auto = false,
      this.doTasIn = true,
      required this.darkMode,
      required this.toggleDarkMode})
      : super(key: key);

  final void Function(int, Impassable, bool, int, String) nextLevel;
  final String title;
  final double sXVel;
  final bool doTasIn;
  final bool darkMode;
  final VoidCallback toggleDarkMode;

  final List<Impassable> impassables;

  @override
  _GameWidgetState createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget>
    with SingleTickerProviderStateMixin {
  late PhysicsSimulator physicsSimulator;
  late final Ticker ticker;
  bool setup = false;
  List<MidiDevice> midiDevices = [];
  StreamSubscription? incomingMidiMessages;
  @override
  void initState() {
    super.initState();
    MidiCommand().devices.then((value) {
      setState(() {
        midiDevices = value!;
      });
    });
    MidiCommand().onMidiSetupChanged!.listen((event) {
      MidiCommand().devices.then((value) {
        if (!mounted) return;
        setState(() {
          midiDevices = value!;
        });
      });
    });
    () async {
      if (widget.doTasIn && filePickerSupported) {
        PickedFile? firstFile = await pickFile();
        if (firstFile != null) {
          dir = dirname(firstFile.path);
          next = basename(firstFile.path);
          print('starting tas: $next');
        }
      }
    }()
        .then((value) => setupPhysics(false).then((value) async {
              ticker = createTicker(tick)..start();
              if (widget.title == "Wooden Doors 2 (Hold D to start)") {
                // TODO: make this not rely on title
                physicsSimulator.impassables.add(
                  Player(
                    Offset(0, 0),
                    Offset(0, 0),
                    () =>
                    rNotePressed ||
                    HardwareKeyboard.instance.logicalKeysPressed
                        .contains(LogicalKeyboardKey.keyD),
                  ),
                );
                reset(); // TODO: this is a hack
              } else {
                PC pc = physicsSimulator.impassables.firstWhere((element) => element is PC) as PC;
                pc.leftPressed = () =>
                    lPressedTas ||
                    lNotePressed ||
                    HardwareKeyboard.instance.logicalKeysPressed
                        .contains(LogicalKeyboardKey.keyA);
                pc.rightPressed = () =>
                    rPressedTas ||
                    rNotePressed ||
                    HardwareKeyboard.instance.logicalKeysPressed
                        .contains(LogicalKeyboardKey.keyD);
                      pc.pressedsInited = true;
              }
              setup = true;
            }));
  }

  PickedFile? outTas;
  String? dir;

  String? next;

  Future<void> setupPhysics(bool physicsSimExists) async {
    if (physicsSimExists) {
      print('moo');
      physicsSimulator.dispose();
    }
    List<List<MoveKey>> tas = [];
    var output = tasOut && filePickerSupported ? await pickFile() : null;
    if (output != null)
      outTas = output;
    else
      outTas = null;
    if (next != null) {
      PickedFile tasRec = getFile(join(dir!, next));
      if (tasRec.exists) {
        var lines = tasRec.readFileLines();
        next = lines.first;
        print('new tas: $next');

        tas = lines
            .skip(1)
            .map((e) => e.split(',').skip(1).map((e) => parseKey(e)).toList())
            .toList();
      } else {
        print('nope $tasRec');
      }
    }

    physicsSimulator = PhysicsSimulator(
      (i, o, isPlayer, winner) {
        widget.nextLevel(i, o, isPlayer, ticksMoved, winner);
        if (isPlayer) ticksMoved = 0;
      },
      widget.impassables,
      widget.endX,
    );
    tasKeys = tas;
    physicsSimulator.addListener(() {
      setState(() {
        // equivalent to just calling markNeedsBuild
      });
    });
    correctCollisions(physicsSimulator.impassables);
  }

  void reset() {
    physicsSimulator.reset();
  }

  bool keyCheck = false;
  LogicalKeyboardKey? j;
  LogicalKeyboardKey? t;
  LogicalKeyboardKey? r;
  LogicalKeyboardKey? l;
  void handleKeyPress(KeyEvent event) {
    //print(event);
    for (PC player in physicsSimulator.impassables.whereType()) {
      if (event is KeyDownEvent) {
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
            physicsSimulator.impassables.add(
              Player(
                Offset(0, 400),
                Offset.zero,
                ()=>false,
                j!,
                t!,
                r!,
                l!,
              )..pressedsInited = true..leftPressed = (() => HardwareKeyboard
                  .instance.logicalKeysPressed
                  .contains(l))
                ..rightPressed = () =>
                    HardwareKeyboard.instance.logicalKeysPressed.contains(r),
            );
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
        if (event.logicalKey == LogicalKeyboardKey.keyU) {
          physicsSimulator.gravity = -physicsSimulator.gravity;
          physicsSimulator.xGravity = -physicsSimulator.xGravity;
        }
        if (event.logicalKey == player.jumpKeybind && !player.jumped) {
          physicsSimulator.handleJDown(player);
        } else if (event.logicalKey == player.takeKeybind) {
          physicsSimulator.handleTake(player);
        }
      }
    }
  }

  int darkModeT = 0; // 0 = dark mode, 255 = light mode

  late BuildContext focusContext;
  @override
  Widget build(BuildContext context) {
    if (!setup) {
      return ColoredBox(color: Colors.yellow);
    }
    if (midiDevices.length > 1) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: Text(
                'Please disconnect all but one of the following MIDI devices:\n${midiDevices.map((e) => e.name).join('\n')}')),
      );
    }
    if (midiDevices.length > 0 &&
        (incomingMidiMessages == null || !midiDevices.single.connected)) {
      incomingMidiMessages?.cancel();
      PC p = physicsSimulator.impassables
          .firstWhere((element) => element is PC) as PC;
      incomingMidiMessages = MidiCommand().onMidiDataReceived!.listen((event) {
        MidiMessage msg = parseMidiMessage(event.data);
        if (!mounted) return;
        setState(() {
          if (msg is NoteOnMessage) {
            keyPressed = true;
            if (msg.note == 21) {
              lNotePressed = true;
            } else if (msg.note == 23) {
              rNotePressed = true;
            } else if (msg.note == 22) {
              physicsSimulator.handleJDown(p);
            } else if (msg.note == 24) {
              physicsSimulator.handleTake(p);
            } else if (msg.note == 25) {
              physicsSimulator.reset();
            }
          } else if (msg is NoteOffMessage) {
            keyPressed = true;
            if (msg.note == 21) {
              lNotePressed = false;
            } else if (msg.note == 23) {
              rNotePressed = false;
            }
          }
        });
      });
    }
    if (midiDevices.length > 0 && !midiDevices.single.connected) {
      MidiCommand().connectToDevice(midiDevices.single);
    }
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyPress,
      debugLabel: 'Button',
      child: Builder(builder: (context) {
        focusContext = context;
        Focus.of(focusContext).requestFocus();
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              if (midiDevices.length > 0) Icon(Icons.piano),
              IconButton(onPressed: reset, icon: Icon(Icons.replay_outlined)),
              IconButton(
                  onPressed: widget.toggleDarkMode,
                  icon: widget.darkMode
                      ? Icon(Icons.wb_sunny_outlined)
                      : Icon(Icons.mode_night_outlined)),
              SizedBox(width: 40)
            ],
          ),
          body: GestureDetector(
            child: Center(
              child: LayoutBuilder(builder: (context, constraints) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${fps.roundToDouble()} fps',
                      style: TextStyle(color: Colors.brown),
                    ),
                    Container(
                      color: Theme.of(context).canvasColor,
                      height: 400,
                      child: CustomPaint(
                        painter: GamePainter(
                            physicsSimulator.impassables,
                            physicsSimulator.ghosts,
                            physicsSimulator.dashMode,
                            physicsSimulator.endX,
                            Color(~Theme.of(context).canvasColor.value)
                                .withAlpha(255)),
                        size: Size(constraints.biggest.width, 400),
                      ),
                    ),
                    Text(
                      '${maxFps.roundToDouble()} possible fps',
                      style: TextStyle(color: Colors.brown),
                    ),
                  ],
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

  List<MoveKey> keys = [];
  bool keyPressed = false;
  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    keyPressed = true;
    if (physicsSimulator.impassables.every((element) => element is! PC))
      return KeyEventResult.ignored;
    handleKeyPress(event);
    if (event.logicalKey ==
        physicsSimulator.impassables.whereType<PC>().first.leftKeybind) {
      keys.add(MoveKey.l);
    }
    if (event.logicalKey ==
        physicsSimulator.impassables.whereType<PC>().first.rightKeybind) {
      keys.add(MoveKey.r);
    }
    if (event.logicalKey ==
        physicsSimulator.impassables.whereType<PC>().first.jumpKeybind) {
      keys.add(MoveKey.j);
    }
    if (event.logicalKey ==
        physicsSimulator.impassables.whereType<PC>().first.takeKeybind) {
      keys.add(MoveKey.t);
    }
    return KeyEventResult.handled;
  }

  void didUpdateWidget(GameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.impassables != widget.impassables) {
      setupPhysics(true);
    }
  }

  int ticksMoved = 0;
  Duration pArg = Duration.zero;
  Duration p2Arg = Duration.zero;
  List<double> fpss = [];
  List<double> mfpss = [];

  bool lPressedTas = false;
  bool rPressedTas = false;
  bool jPressedTas = false;
  bool tPressedTas = false;

  bool lNotePressed = false;
  bool rNotePressed = false;

  late List<List<MoveKey>> tasKeys;
  void tick(Duration arg) {
    if (widget.darkMode && darkModeT > 0) {
      darkModeT -= 20;
    } else if (!widget.darkMode && darkModeT < 255) {
      darkModeT += 20;
    }
    darkModeT = max(0, min(darkModeT, 255));
    if (mfpss.length >= 10) {
      maxFps = mfpss.fold<double>(
              0, (previousValue, element) => previousValue + element) /
          mfpss.length;
      mfpss = [];
    }
    mfpss.add(1 / (arg.inMilliseconds / 1000 - p2Arg.inMilliseconds / 1000));
    p2Arg = arg;
    if (arg - pArg >= Duration(milliseconds: 16) &&
        !physicsSimulator.isDisposed) {
      if (mfpss.length >= 10) {
        fps = fpss.fold<double>(
                0, (previousValue, element) => previousValue + element) /
            fpss.length;
        fpss = [];
      }
      fpss.add(1 / (arg.inMilliseconds / 1000 - pArg.inMilliseconds / 1000));
      if (outTas != null)
        outTas!.appendToFile(
          keys.isEmpty ? '\n' : ',${keys.map((e) => e.name).join(',')}\n',
        );
      keys = [];

      if (tasKeys.length > physicsSimulator.ticks &&
          tasKeys[physicsSimulator.ticks].length > 0) {
        keyPressed = true;
      }
      if (tasKeys.length > physicsSimulator.ticks &&
          physicsSimulator.impassables.any(
            (element) => element is PC,
          )) {
        for (MoveKey key in tasKeys[physicsSimulator.ticks]) {
          PC player =
              physicsSimulator.impassables.whereType<PC>().single;
          switch (key) {
            case MoveKey.l:
              if (!lPressedTas) {
                lPressedTas = true;
              } else {
                lPressedTas = false;
              }
              break;
            case MoveKey.r:
              if (!rPressedTas) {
                rPressedTas = true;
              } else {
                rPressedTas = false;
              }
              break;
            case MoveKey.t:
              if (tPressedTas) {
                tPressedTas = false;
              } else {
                tPressedTas = true;
                physicsSimulator.handleTake(player);
              }
              break;
            case MoveKey.j:
              if (!jPressedTas) {
                physicsSimulator.handleJDown(player);
                jPressedTas = true;
              } else {
                jPressedTas = false;
              }
              break;
          }
        }
      }
      physicsSimulator.tick();
      if (keyPressed) {
        ticksMoved++;
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
  final List<Impassable> ghosts;

  final bool isDash;

  final double endX;
  final Color contrastColor;

  GamePainter(this.impassables, this.ghosts, this.isDash, this.endX,
      this.contrastColor);
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
          Paint()..color = contrastColor);
      canvas.drawCircle(
          Offset(i * 10 - impassables.whereType<PC>().first.topLeft.dx % 10, 0),
          1,
          Paint()..color = contrastColor);
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
    for (Impassable impassable in ghosts) {
      Color color = impassable.color.withAlpha(0x80);
      canvas.drawRect(
        Rect.fromLTRB(
          impassable.topLeft.dx -
              (impassables.whereType<PC>().first.topLeft.dx - size.width / 2),
          (size.height) - (impassable.topLeft.dy),
          impassable.bottomRight.dx -
              (impassables.whereType<PC>().first.topLeft.dx - size.width / 2),
          (size.height) - (impassable.bottomRight.dy),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke,
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
