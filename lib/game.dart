import 'dart:async';

import 'package:desktop/desktop.dart';
import 'package:flutter/foundation.dart';

import 'package:wakelock/wakelock.dart';

import 'actions.dart';
import 'block.dart';
import 'data.dart';
import 'state.dart';
import 'sudoku.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.difficulty,
    this.gameData,
  });

  final Difficulty difficulty;
  final GameData? gameData;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  String get title {
    switch (widget.difficulty) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
      default:
        throw 'Invalid difficulty';
    }
  }

  Sudoku board = Sudoku()..difficulty;
  List<int> puzzle = [];
  List<int> solution = [];
  int selectedIndex = -1;
  late Duration initialDuration;
  Stopwatch gameDuration = Stopwatch();
  Timer? gameTimer;
  late List<BlockState> blockStates;
  bool isPaused = false;

  List<BoardAction> undoActions = [];
  List<BoardAction> redoActions = [];

  bool get isCompleted => listEquals(board.puzzle, solution);
  Duration get totalDuration => initialDuration + gameDuration.elapsed;

  void resetBlockStates() {
    blockStates = List.generate(boardSize, (index) => BlockState(index));
  }

  void pushAction(BoardAction action) {
    if ((undoActions.isEmpty &&
            (action.actionType != ActionType.set ||
                action.lastValue != action.value)) ||
        undoActions.isNotEmpty && undoActions.last != action) {
      setState(() {
        Data.clearActions('redo', redoActions.length);

        redoActions.clear();
        undoActions.add(action);

        Data.updateAction(
          'undo',
          undoActions.length,
          undoActions.length - 1,
          undoActions.last,
        );
      });
    }
  }

  void undoAction() {
    setState(() {
      final action = undoActions.removeLast();
      Data.removeLastAction('undo', undoActions.length);

      switch (action.actionType) {
        case ActionType.set:
          markNumber(action.index, action.lastValue);
          break;
        case ActionType.flip:
          if (blockStates[action.index].flipped) {
            markNumber(action.index, blockStates[action.index].lastValue);
          } else {
            markNumber(action.index, 0);
          }

          blockStates[action.index].flipped =
              !blockStates[action.index].flipped;
          break;
        case ActionType.add:
          blockStates[action.index].values[action.flippedIndex] =
              action.lastValue;
          break;
        case ActionType.flipClear:
          for (int i = 0; i < action.flippedValues.length; i += 1) {
            blockStates[action.index].values[i] = action.flippedValues[i];
          }
          break;
      }

      redoActions.add(action);

      Data.updateAction(
        'redo',
        redoActions.length,
        redoActions.length - 1,
        redoActions.last,
      );
    });
  }

  void redoAction() {
    setState(() {
      final action = redoActions.removeLast();
      Data.removeLastAction('redo', redoActions.length);

      switch (action.actionType) {
        case ActionType.set:
          markNumber(action.index, action.value);
          break;
        case ActionType.flip:
          if (blockStates[action.index].flipped) {
            markNumber(action.index, blockStates[action.index].lastValue);
          } else {
            markNumber(action.index, 0);
          }

          blockStates[action.index].flipped =
              !blockStates[action.index].flipped;
          break;
        case ActionType.add:
          blockStates[action.index].values[action.flippedIndex] = action.value;
          break;

        case ActionType.flipClear:
          for (int i = 0; i < action.flippedValues.length; i += 1) {
            blockStates[action.index].values[i] = 0;
          }
          break;
      }

      undoActions.add(action);

      Data.updateAction(
        'undo',
        undoActions.length,
        undoActions.length - 1,
        undoActions.last,
      );
    });
  }

  void markNumber(int index, int value) {
    setState(() {
      board.puzzle[index] = value;
      board.solve();

      if (isCompleted) {
        final time = formatDuration();

        gameDuration.stop();
        gameDuration.reset();
        resetBlockStates();

        Dialog.showDialog(
          context,
          barrierDismissible: false,
          title: const Text('Congrats!'),
          body: Text(
            'You have completed the game in $time.',
          ),
          actions: [
            DialogAction(
              title: 'New Game',
              onPressed: () {
                Navigator.of(context).pop();
                generatePuzzle();
              },
            ),
            DialogAction(
                title: 'Close',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                })
          ],
        );
      }
    });
  }

  void addValue(int index, int value) {
    if (!blockStates[index].flipped) {
      pushAction(
        BoardAction(
          value: value,
          lastValue: board.puzzle[index],
          index: index,
          actionType: ActionType.set,
        ),
      );
      markNumber(index, value);
    } else {
      if (!blockStates[index].values.contains(value)) {
        final indexZero = blockStates[index].values.indexWhere((e) => e == 0);

        if (indexZero != -1) {
          pushAction(
            BoardAction(
              value: value,
              lastValue: blockStates[index].values[indexZero],
              flippedIndex: indexZero,
              index: index,
              actionType: ActionType.add,
            ),
          );

          setState(() {
            blockStates[index].values[indexZero] = value;
          });
        }
      }
    }
  }

  void removeBlockValue(int index) {
    setState(() {
      final flippedValues =
          blockStates[index].values.where((e) => e > 0).toList();

      pushAction(
        BoardAction(
          value: 0,
          lastValue: 0,
          flippedValues: flippedValues,
          index: index,
          actionType: ActionType.flipClear,
        ),
      );

      for (int i = 0; i < flippedValues.length; i += 1) {
        blockStates[index].values[i] = 0;
      }
    });
  }

  void removeValue(int index) {
    if (!blockStates[index].flipped) {
      pushAction(
        BoardAction(
          value: 0,
          lastValue: board.puzzle[index],
          index: index,
          actionType: ActionType.set,
        ),
      );
      markNumber(index, 0);
    } else {
      final indexNotZero =
          blockStates[index].values.lastIndexWhere((e) => e > 0);

      if (indexNotZero != -1) {
        pushAction(
          BoardAction(
            value: 0,
            lastValue: blockStates[index].values[indexNotZero],
            flippedIndex: indexNotZero,
            index: index,
            actionType: ActionType.add,
          ),
        );

        setState(() {
          blockStates[index].values[indexNotZero] = 0;
        });
      }
    }
  }

  void generatePuzzle([List<int>? newPuzzle]) {
    undoActions.clear();
    redoActions.clear();

    Data.difficulty = widget.difficulty;
    Data.clearActions('undo', 0);
    Data.clearActions('redo', 0);

    if (newPuzzle == null) {
      for (int i = 0; i < 1000; i += 1) {
        Data.gameDuration = Duration.zero;
        board.difficulty = widget.difficulty;
        board.recordHistory = true;
        board.logHistory = false;

        final hasPuzzle = board.generatePuzzleSymmetry(Symmetry.random);
        board.solve();

        if (hasPuzzle && board.difficulty == board.generatedDifficulty) {
          if (board.difficulty == Difficulty.easy && board.givenCount < 32) {
            continue;
          }

          if (board.difficulty == Difficulty.medium &&
              (board.givenCount > 32 || board.givenCount < 27)) {
            continue;
          }

          if (board.difficulty == Difficulty.hard && board.givenCount > 27) {
            continue;
          }

          puzzle = List.from(board.puzzle);
          solution = List.from(board.solution);

          Data.puzzle = puzzle;

          initialDuration = Duration.zero;
          resetBlockStates();
          gameDuration.reset();
          startTimer();

          return;
        }
      }
    } else {
      board.puzzle = List.from(newPuzzle);
      board.solve();

      puzzle = List.from(board.puzzle);
      solution = List.from(board.solution);

      gameDuration.reset();
      startTimer();

      return;
    }

    throw 'Could not generate game.';
  }

  void startTimer() {
    gameDuration.start();

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          Data.gameDuration = totalDuration;
        });
      }
    });
  }

  String formatDuration() {
    final e = totalDuration;
    return e.toString().split('.').first.padLeft(8, '0');
  }

  bool onlyValueInRow(int index) {
    final row = cellToRow(index);
    final rowStart = rowToFirstCell(row);

    for (int i = 0; i < rowColSecSize; i += 1) {
      final position = rowStart + i;
      if (index != position && board.puzzle[position] == board.puzzle[index]) {
        return false;
      }
    }

    return true;
  }

  bool onlyValueInColumn(int index) {
    final column = cellToColumn(index);
    final columnStart = columnToFirstCell(column);

    for (int i = 0; i < rowColSecSize; i += 1) {
      final position = columnStart + i * rowColSecSize;
      if (index != position && board.puzzle[position] == board.puzzle[index]) {
        return false;
      }
    }

    return true;
  }

  bool onlyValueInSection(int index) {
    final sectionStart = cellToSectionStartCell(index);
    for (int i = 0; i < gridSize; i += 1) {
      for (int j = 0; j < gridSize; j += 1) {
        int position = sectionStart + i + rowColSecSize * j;

        if (index != position &&
            board.puzzle[position] == board.puzzle[index]) {
          return false;
        }
      }
    }

    return true;
  }

  void pauseGame() async {
    setState(() {
      isPaused = true;
      gameDuration.stop();
      gameTimer?.cancel();
      gameTimer = null;
    });

    final _ = await Dialog.showCustomDialog(
      context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              color: Theme.of(context).colorScheme.background[0],
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 24.0,
              ),
              child: Text(
                'Game Paused',
                style: Theme.of(context).textTheme.title,
              ),
            ),
          ],
        );
      },
    );

    setState(() {
      isPaused = false;
      startTimer();
    });
  }

  void newGame() async {
    if (!listEquals(puzzle, board.puzzle)) {
      final result = await Dialog.showDialog<bool>(
        context,
        body: const Text(
          'Are you sure you want to create a new game?',
        ),
        title: const Text('New Game'),
        actions: [
          DialogAction(
            title: 'Yes',
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          DialogAction(
            title: 'No',
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
        ],
      );

      if (result != null && result) {
        generatePuzzle();
        setState(() {});
      }
    } else {
      generatePuzzle();
      setState(() {});
    }
  }

  void clearGame() async {
    final result = await Dialog.showDialog<bool>(
      context,
      body: const Text(
        'Are you sure you want to clear the board?',
      ),
      title: const Text('Clear'),
      actions: [
        DialogAction(
          title: 'Yes',
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
        DialogAction(
          title: 'No',
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );

    if (result != null && result) {
      setState(() {
        Data.clearActions('undo', undoActions.length);
        Data.clearActions('redo', redoActions.length);
        Data.gameDuration = Duration.zero;
        initialDuration = Duration.zero;

        resetBlockStates();
        gameDuration.reset();
        undoActions.clear();
        redoActions.clear();

        board.puzzle = List.from(puzzle);
      });
    }
  }

  bool isReadonly(int index) => puzzle[index] != 0;

  void flipBlock() {
    setState(() {
      blockStates[selectedIndex].flipped = !blockStates[selectedIndex].flipped;

      pushAction(
        BoardAction(
          value: 0,
          lastValue: board.puzzle[selectedIndex],
          index: selectedIndex,
          actionType: ActionType.flip,
        ),
      );

      if (blockStates[selectedIndex].flipped) {
        blockStates[selectedIndex].lastValue = board.puzzle[selectedIndex];
        markNumber(selectedIndex, 0);
      } else {
        markNumber(selectedIndex, blockStates[selectedIndex].lastValue);
      }
    });
  }

  Widget createBoard(Orientation orientation, bool reducedSize) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final colorSheme = Theme.of(context).colorScheme;

        final size = orientation == Orientation.landscape
            ? constraints.maxHeight
            : constraints.maxWidth;
        final y = reducedSize ? 10 : 9;
        final blockSize = ((size - 24.0) / y).floorToDouble();
        final totalSize = blockSize * 9 + 24.0;

        final blocks = <Widget>[];

        for (int x = 0; x < 9; x += 1) {
          final rowChildren = <Widget>[];

          for (int y = 0; y < 9; y += 1) {
            final rightPadding = (y + 1) % 3 == 0 ? 4.0 : 2.0;
            final i = x * 9 + y;

            final readonly = puzzle[i] != 0;

            final Widget result = Padding(
              padding: EdgeInsets.only(right: y == 8.0 ? 0.0 : rightPadding),
              child: SizedBox(
                width: blockSize,
                height: blockSize,
                child: Block(
                  value: isPaused ? 0 : board.puzzle[i],
                  state: blockStates[i],
                  wrongValue: !readonly &&
                      board.puzzle[i] != 0 &&
                      !isPaused &&
                      (!onlyValueInRow(i) ||
                          !onlyValueInColumn(i) ||
                          !onlyValueInSection(i)),
                  readonly: readonly,
                  onNumberRemoved: () => removeValue(i),
                  onUnselected: () {
                    if (selectedIndex == i) {
                      setState(() {
                        selectedIndex = -1;
                      });
                    }
                  },
                  onFlipped: () => flipBlock(),
                  onNumberSelected: (value) => addValue(i, value),
                  onSelected: () {
                    setState(() => selectedIndex = i);
                  },
                ),
              ),
            );

            rowChildren.add(result);
          }

          final bottomPadding = (x + 1) % 3 == 0 ? 4.0 : 2.0;

          blocks.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: x == 8 ? 0.0 : bottomPadding,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: rowChildren,
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: totalSize,
            width: totalSize,
            child: CustomPaint(
              foregroundPainter:
                  BoardBorder(colorSheme.background[12], blockSize),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: blocks,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget createNumbersSet(Orientation orientation, bool isBlockFlipped) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final textTheme = Theme.of(context).textTheme;
      final size = orientation == Orientation.landscape
          ? constraints.maxHeight
          : constraints.maxWidth;
      final blockSize = ((size - 24.0) / 10).floorToDouble();
      final totalSize = blockSize * 9 + 24.0;

      final textStyle = textTheme.monospace.copyWith(fontSize: blockSize / 2.0);
      final color = textTheme.textHigh;

      return Align(
        alignment: orientation == Orientation.landscape
            ? Alignment.bottomLeft
            : Alignment.bottomCenter,
        child: SizedBox(
          height: orientation == Orientation.landscape ? totalSize : blockSize,
          width: orientation == Orientation.portrait ? totalSize : blockSize,
          child: Flex(
            direction: orientation == Orientation.landscape
                ? Axis.vertical
                : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Button.text(
                '0',
                onPressed: selectedIndex == -1 || isReadonly(selectedIndex)
                    ? null
                    : () => removeValue(selectedIndex),
                onLongPress: isBlockFlipped
                    ? () => removeBlockValue(selectedIndex)
                    : null,
                active: selectedIndex != -1 &&
                    0 == board.puzzle[selectedIndex] &&
                    !blockStates[selectedIndex].flipped,
                theme: ButtonThemeData(
                  textStyle: textStyle,
                  highlightColor: textTheme.textPrimaryHigh,
                  color: color,
                ),
              ),
              ...List.generate(rowColSecSize, (index) {
                final completed = board.puzzle
                        .where((element) => element == index + 1)
                        .length >=
                    rowColSecSize;

                return Button.text(
                  (index + 1).toString(),
                  onPressed: completed ||
                          selectedIndex == -1 ||
                          isReadonly(selectedIndex)
                      ? null
                      : () => addValue(selectedIndex, index + 1),
                  active: selectedIndex != -1 &&
                      index + 1 == board.puzzle[selectedIndex] &&
                      !blockStates[selectedIndex].flipped,
                  theme: ButtonThemeData(
                    textStyle: textStyle,
                    disabledColor: completed ? textTheme.textLow : null,
                    highlightColor: textTheme.textPrimaryHigh,
                    color: color,
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();

    resetBlockStates();

    final gameData = widget.gameData;

    if (gameData != null) {
      initialDuration = gameData.gameDuration;
      generatePuzzle(gameData.puzzle);

      for (final action in gameData.undoActions) {
        redoActions.add(action);
        redoAction();
      }

      redoActions = gameData.redoActions;
    } else {
      initialDuration = Duration.zero;
      generatePuzzle();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    Wakelock.enable().catchError((_) {});
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    gameTimer = null;

    Wakelock.disable().catchError((_) {});

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final bool isBlockFlipped =
        selectedIndex != -1 && blockStates[selectedIndex].flipped;

    final Widget result = OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final size = orientation == Orientation.landscape
                ? constraints.maxHeight
                : constraints.maxWidth;

            final blockSize = ((size - 24.0) / 10).floorToDouble();
            final totalSize = blockSize * 11 + 24.0;

            final reducedBoardSize = orientation == Orientation.landscape
                ? totalSize > constraints.maxWidth
                : totalSize > constraints.maxHeight;

            return Flex(
              direction: orientation == Orientation.landscape
                  ? Axis.horizontal
                  : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (orientation == Orientation.portrait)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: createNumbersSet(orientation, isBlockFlipped),
                    ),
                  ),
                Center(
                  child: createBoard(orientation, reducedBoardSize),
                ),
                if (orientation == Orientation.landscape)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: createNumbersSet(orientation, isBlockFlipped),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    return WillPopScope(
      onWillPop: () async {
        if (!listEquals(puzzle, board.puzzle)) {
          final result = await Dialog.showDialog<bool>(
            context,
            body: const Text(
              'Are you sure you want to close the game?',
            ),
            title: const Text('Close'),
            actions: [
              DialogAction(
                title: 'Yes',
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
              DialogAction(
                title: 'No',
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
            ],
          );

          return result ?? false;
        }

        return true;
      },
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Button.icon(
                    Icons.arrow_back,
                    size: 36.0,
                    theme: ButtonThemeData(
                      color: textTheme.textHigh,
                      hoverColor: textTheme.textLow,
                      highlightColor: textTheme.textHigh,
                    ),
                    onPressed: () {
                      if (!listEquals(puzzle, board.puzzle)) {
                        Dialog.showDialog<bool>(
                          context,
                          body: const Text(
                            'Are you sure you want to close the game?',
                          ),
                          title: const Text('Close'),
                          actions: [
                            DialogAction(
                              title: 'Yes',
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                            ),
                            DialogAction(
                              title: 'No',
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                Text(
                  title,
                  style: textTheme.header,
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Button.icon(
                  Icons.undo,
                  onPressed: undoActions.isNotEmpty ? undoAction : null,
                ),
                Button.icon(
                  Icons.redo,
                  onPressed: redoActions.isNotEmpty ? redoAction : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Button.icon(
                    isBlockFlipped ? Icons.flip_to_back : Icons.flip_to_front,
                    onPressed: selectedIndex == -1 || isReadonly(selectedIndex)
                        ? null
                        : flipBlock,
                    tooltip: isBlockFlipped ? 'Value' : 'Annotations',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Button(
                    body: const Text('New Game'),
                    onPressed: newGame,
                  ),
                ),
                Button.text(
                  'Clear',
                  tooltip: 'Clear board',
                  onPressed:
                      !listEquals(puzzle, board.puzzle) ? clearGame : null,
                ),
                Button.text(
                  formatDuration(),
                  onPressed: pauseGame,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: result,
            ),
          ),
        ],
      ),
    );
  }
}

class BoardBorder extends CustomPainter {
  const BoardBorder(
    this.borderColor,
    this.blockSize,
  );

  final Color borderColor;
  final double blockSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = borderColor;

    double xy = blockSize + 2.0;

    // top
    canvas.drawRect(
      Rect.fromLTWH(
        0.0,
        0.0,
        size.width,
        2.0,
      ),
      paint,
    );

    // right
    canvas.drawRect(
      Rect.fromLTWH(
        size.width - 2.0,
        0.0,
        2.0,
        size.height,
      ),
      paint,
    );

    // left
    canvas.drawRect(
      Rect.fromLTWH(
        0.0,
        0.0,
        2.0,
        size.height,
      ),
      paint,
    );

    // bottom
    canvas.drawRect(
      Rect.fromLTWH(
        0.0,
        size.height - 2.0,
        size.width,
        2.0,
      ),
      paint,
    );

    for (int i = 1; i < rowColSecSize; i += 1) {
      final double width;

      if (i % gridSize == 0) {
        width = 4.0;
      } else {
        width = 2.0;
      }

      canvas.drawRect(
        Rect.fromLTWH(
          0.0,
          xy.roundToDouble(),
          size.width,
          width,
        ),
        paint,
      );

      canvas.drawRect(
        Rect.fromLTWH(
          xy.roundToDouble(),
          0.0,
          width,
          size.height,
        ),
        paint,
      );

      xy += blockSize + width;
    }
  }

  @override
  bool shouldRepaint(BoardBorder oldDelegate) => false;
}
