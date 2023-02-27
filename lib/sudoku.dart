// Copyright (C) 2023 Adriano Souza (adriano.souza113@gmail.com)

// qqwing - Sudoku solver and generator
// Copyright (C) 2006-2014 Stephen Ostermiller http://ostermiller.org/
// Copyright (C) 2007 Jacques Bensimon (jacques@ipm.com)
// Copyright (C) 2011 Jean Guillerez (j.guillerez - orange.fr)
// Copyright (C) 2014 Michael Catanzaro (mcatanzaro@gnome.org)
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

import 'dart:math' as math;

enum Difficulty {
  unknown,
  easy,
  medium,
  hard,
}

enum Symmetry {
  none,
  rotate90,
  rotate180,
  mirror,
  flip,
  random,
}

const int gridSize = 3;
const int rowColSecSize = gridSize * gridSize;
const int secGroupSize = rowColSecSize * gridSize;
const int boardSize = rowColSecSize * rowColSecSize;
const int possibilitiesSize = boardSize * rowColSecSize;

int cellToColumn(int cell) => cell % rowColSecSize;

int cellToRow(int cell) => cell ~/ rowColSecSize;

int cellToSection(int cell) =>
    (cell ~/ secGroupSize * gridSize) + cellToColumn(cell) ~/ gridSize;

int cellToSectionStartCell(int cell) =>
    (cell ~/ secGroupSize * secGroupSize) +
    (cellToColumn(cell) ~/ gridSize * gridSize);

int rowToFirstCell(int row) => rowColSecSize * row;

int columnToFirstCell(int column) => column;

int sectionToFirstCell(int section) =>
    (section % gridSize * gridSize) + (section ~/ gridSize * secGroupSize);

int getPossibilityIndex(int valueIndex, int cell) =>
    valueIndex + (rowColSecSize * cell);

int rowColumnToCell(int row, int column) => (row * rowColSecSize) + column;

int sectionToCell(int section, int offset) =>
    sectionToFirstCell(section) +
    ((offset ~/ gridSize) * rowColSecSize) +
    (offset % gridSize);

int _getlogCount(List<LogItem> value, LogType logType) =>
    value.fold(0, (p, e) => e.logType == logType ? p + 1 : p);

enum LogType {
  given,
  single,
  hiddenSingleRow,
  hiddenSingleColumn,
  hiddenSingleSection,
  guess,
  rollback,
  nakedPairRow,
  nakedPairColumn,
  nakedPairSection,
  pointingPairTripleRow,
  pointingPairTripleColumn,
  rowBox,
  columnBox,
  hiddenPairRow,
  hiddenPairColumn,
  hiddenPairSection
}

class LogItem {
  const LogItem({
    required this.round,
    required this.logType,
    this.value = 0,
    this.position = -1,
  });

  final int round;
  final LogType logType;
  final int value;
  final int position;

  @override
  String toString() {
    String result = 'Round: $round - ';

    switch (logType) {
      case LogType.given:
        result += 'Mark given';
        break;
      case LogType.rollback:
        result += 'Roll back round';
        break;
      case LogType.guess:
        result += 'Mark guess (start round)';
        break;
      case LogType.hiddenSingleRow:
        result += 'Mark single possibility for value in row';
        break;
      case LogType.hiddenSingleColumn:
        result += 'Mark single possibility for value in column';
        break;
      case LogType.hiddenSingleSection:
        result += 'Mark single possibility for value in section';
        break;
      case LogType.single:
        result += 'Mark only possibility for cell';
        break;
      case LogType.nakedPairRow:
        result += 'Remove possibilities for naked pair in row';
        break;
      case LogType.nakedPairColumn:
        result += 'Remove possibilities for naked pair in column';
        break;
      case LogType.nakedPairSection:
        result += 'Remove possibilities for naked pair in section';
        break;
      case LogType.pointingPairTripleRow:
        result +=
            'Remove possibilities for row because all values are in one section';
        break;
      case LogType.pointingPairTripleColumn:
        result +=
            'Remove possibilities for column because all values are in one section';
        break;
      case LogType.rowBox:
        result +=
            'Remove possibilities for section because all values are in one row';
        break;
      case LogType.columnBox:
        result +=
            'Remove possibilities for section because all values are in one column';
        break;
      case LogType.hiddenPairRow:
        result += 'Remove possibilities from hidden pair in row';
        break;
      case LogType.hiddenPairColumn:
        result += 'Remove possibilities from hidden pair in column';
        break;
      case LogType.hiddenPairSection:
        result += 'Remove possibilities from hidden pair in section';
        break;
      default:
        result += '!!! Performed unknown optimization !!!';
        break;
    }

    if (value > 0 || position > -1) {
      result += ' (';

      bool printed = false;

      if (position > -1) {
        result +=
            'Row: ${cellToRow(position) + 1} - Column: ${cellToColumn(position) + 1}';
        printed = true;
      }

      if (value > 0) {
        if (printed) {
          result += ' - ';
        }

        result += 'Value: $value';
      }

      result += ')';
    }

    return result;
  }
}

class Sudoku {
  Sudoku()
      : _puzzle = List.filled(boardSize, 0, growable: false),
        _solution = List.filled(boardSize, 0, growable: false),
        _solutionRound = List.filled(boardSize, 0, growable: false),
        _possibilities = List.filled(possibilitiesSize, 0, growable: false),
        _randomBoards =
            List.generate(boardSize, (value) => value, growable: false),
        _randomPossibilities =
            List.generate(rowColSecSize, (value) => value, growable: false),
        _recordHistory = false,
        _logHistory = false,
        _solveHistory = [],
        _solveInstructions = [],
        _lastSolveRound = 0;

  // Recursion depth at which each of the numbers
  // in the solution were placed.  Useful for backing
  // out solve branches that don't lead to a solution.
  final List<int> _solutionRound;

  // The 729 integers that make up a the possible
  // values for a Sudoku puzzle. (9 possibilities
  // for each of 81 squares).  If possibilities[i]
  // is zero, then the possibility could still be
  // filled in according to the Sudoku rules.  When
  // a possibility is eliminated, possibilities[i]
  // is assigned the round (recursion level) at
  // which it was determined that it could not be
  // a possibility.
  final List<int> _possibilities;

  // An array the size of the board (81) containing each
  // of the numbers 0-n exactly once.  This array may
  // be shuffled so that operations that need to
  // look at each cell can do so in a random order.
  final List<int> _randomBoards;

  // An array with one element for each position (9), in
  // some random order to be used when trying each
  // position in turn during guesses.
  final List<int> _randomPossibilities;

  // A list of moves used to solve the puzzle.
  // This list contains all moves, even on solve
  // branches that did not lead to a solution.
  final List<LogItem> _solveHistory;

  // A list of moves used to solve the puzzle.
  // This list contains only the moves needed
  // to solve the puzzle, but doesn't contain
  // information about bad guesses.
  final List<LogItem> _solveInstructions;

  // The last round of solving.
  int _lastSolveRound;

  int _eliminatePositions = boardSize;

  Difficulty _difficulty = Difficulty.unknown;
  Difficulty get difficulty => _difficulty;
  set difficulty(Difficulty value) {
    _difficulty = value;

    switch (value) {
      case Difficulty.easy:
        _eliminatePositions = 25;
        break;
      case Difficulty.medium:
        _eliminatePositions = 35;
        break;
      case Difficulty.hard:
        _eliminatePositions = boardSize;
        break;
      default: 
        _eliminatePositions = boardSize;
    }
  }

  /// The 81 integers that make up a sudoku puzzle.
  /// Givens are 1-9, unknowns are 0.
  /// Once initialized, this puzzle remains as is.
  /// The answer is worked out in "solution".
  List<int> _puzzle;
  List<int> get puzzle => _puzzle;
  set puzzle(List<int> value) {
    _puzzle = value;
    if (!_reset()) {
      throw 'Possibility index';
    }
  }

  /// The 81 integers that make up a sudoku puzzle.
  /// The solution is built here, after completion
  /// all will be 1-9.
  final List<int> _solution;
  List<int> get solution => _solution;

  String printSolution() => _print(_solution);

  String printPuzzle() => _print(_puzzle);

  bool solve([int? round]) {
    if (round != null) {
      _lastSolveRound = round;

      while (_singleSolveMove(round)) {
        if (isSolved) {
          return true;
        }
        if (_isImpossible) {
          return false;
        }
      }

      int nextGuessRound = round + 1;
      int nextRound = round + 2;

      int guessNumber = 0;

      while (_guess(nextGuessRound, guessNumber)) {
        if (_isImpossible || !solve(nextRound)) {
          _rollbackRound(nextRound);
          _rollbackRound(nextGuessRound);
        } else {
          return true;
        }

        guessNumber += 1;
      }

      return false;
    } else {
      _reset();
      _shuffleRandom();
      return solve(2);
    }
  }

  /// Count the number of solutions to the puzzle
  /// but return two any time there are two or
  /// more solutions.  This method will run much
  /// faster than countSolutions() when there
  /// are many possible solutions and can be used
  /// when you are interested in knowing if the
  /// puzzle has zero, one, or multiple solutions.
  int countSolutionsLimited() => countSolutions(true);

  /// If the puzzle has no solutions at all.
  bool hasNoSolution() => countSolutionsLimited() == 0;

  /// The puzzle has a solution and only a single solution/
  bool hasUniqueSolution() => countSolutionsLimited() == 1;

  /// If the puzzle has more than one solution.
  bool hasMultipleSolutions() => countSolutionsLimited() > 1;

  bool get isSolved => solution.every((e) => e != 0);

  String printSolveHistory() => _printHistory(_solveHistory);

  void generatePuzzle() {
    generatePuzzleSymmetry(Symmetry.none);
  }

  /// Whether or not to record history.
  bool _recordHistory;
  set recordHistory(bool value) => _recordHistory = value;

  /// Whether or not to print history as it happens.
  bool _logHistory;
  set logHistory(bool value) => _logHistory = value;

  bool generatePuzzleSymmetry(Symmetry symmetry) {
    if (symmetry == Symmetry.random) {
      symmetry = _randomSymmetry;
    }

    // Don't record history while generating.
    bool recHistory = _recordHistory;
    _recordHistory = false;
    bool lHistory = _logHistory;
    _logHistory = false;

    _clearPuzzle();

    // Start by getting the randomness in order so that
    // each puzzle will be different from the last.
    _shuffleRandom();

    // Now solve the puzzle the whole way.  The solve
    // uses random algorithms, so we should have a
    // really randomly totally filled sudoku
    // Even when starting from an empty grid
    solve();

    if (symmetry == Symmetry.none) {
      // Rollback any square for which it is obvious that
      // the square doesn't contribute to a unique solution
      // (ie, squares that were filled by logic rather
      // than by guess)
      _rollbackNonGuesses();
    }

    // Record all marked squares as the puzzle so
    // that we can call countSolutions without losing it.
    for (int i = 0; i < boardSize; i += 1) {
      _puzzle[i] = solution[i];
    }

    // Re-randomize everything so that we test squares
    // in a different order than they were added.
    _shuffleRandom();

    // Remove one value at a time and see if
    // the _puzzle still has only one solution.
    // If it does, leave it out the point because
    // it is not needed.
    for (int i = 0; i < _eliminatePositions; i += 1) {
      // check all the positions, but in shuffled order
      int position = _randomBoards[i];

      if (_puzzle[position] > 0) {
        int positionsym1 = -1;
        int positionsym2 = -1;
        int positionsym3 = -1;

        switch (symmetry) {
          case Symmetry.rotate90:
            positionsym2 = rowColumnToCell(
                rowColSecSize - 1 - cellToColumn(position),
                cellToRow(position));
            positionsym3 = rowColumnToCell(cellToColumn(position),
                rowColSecSize - 1 - cellToRow(position));
            break;
          case Symmetry.rotate180:
            positionsym1 = rowColumnToCell(
                rowColSecSize - 1 - cellToRow(position),
                rowColSecSize - 1 - cellToColumn(position));
            break;
          case Symmetry.mirror:
            positionsym1 = rowColumnToCell(cellToRow(position),
                rowColSecSize - 1 - cellToColumn(position));
            break;
          case Symmetry.flip:
            positionsym1 = rowColumnToCell(
                rowColSecSize - 1 - cellToRow(position),
                cellToColumn(position));
            break;
          case Symmetry.none: // NOTE: No need to do anything
            break;
          default:
            throw 'Invalid symmetry value';
        }

        // try backing out the value and
        // counting solutions to the puzzle
        int savedValue = _puzzle[position];
        _puzzle[position] = 0;

        int savedSym1 = 0;
        if (positionsym1 >= 0) {
          savedSym1 = _puzzle[positionsym1];
          _puzzle[positionsym1] = 0;
        }

        int savedSym2 = 0;
        if (positionsym2 >= 0) {
          savedSym2 = _puzzle[positionsym2];
          _puzzle[positionsym2] = 0;
        }

        int savedSym3 = 0;
        if (positionsym3 >= 0) {
          savedSym3 = _puzzle[positionsym3];
          _puzzle[positionsym3] = 0;
        }

        _reset();

        if (countSolutions(true, 2) > 1) {
          // Put it back in, it is needed
          _puzzle[position] = savedValue;
          if (positionsym1 >= 0 && savedSym1 != 0) {
            _puzzle[positionsym1] = savedSym1;
          }
          if (positionsym2 >= 0 && savedSym2 != 0) {
            _puzzle[positionsym2] = savedSym2;
          }
          if (positionsym3 >= 0 && savedSym3 != 0) {
            _puzzle[positionsym3] = savedSym3;
          }
        }
      }
    }

    // Clear all solution info, leaving just the puzzle.
    _reset();

    // Restore recording history.
    _recordHistory = recHistory;
    _logHistory = lHistory;

    return true;
  }

  /// Get the number of cells that are
  /// set in the puzzle (as opposed to
  /// figured out in the solution
  int get givenCount => _puzzle.fold(0, (p, e) => e != 0 ? p + 1 : p);

  int get singleCount => _getlogCount(_solveInstructions, LogType.single);

  int get hiddenSingleCount =>
      _getlogCount(_solveInstructions, LogType.hiddenSingleRow) +
      _getlogCount(_solveInstructions, LogType.hiddenSingleColumn) +
      _getlogCount(_solveInstructions, LogType.hiddenSingleSection);

  int get nakedPairCount =>
      _getlogCount(_solveInstructions, LogType.nakedPairRow) +
      _getlogCount(_solveInstructions, LogType.nakedPairColumn) +
      _getlogCount(_solveInstructions, LogType.nakedPairSection);

  int get hiddenPairCount =>
      _getlogCount(_solveInstructions, LogType.hiddenPairRow) +
      _getlogCount(_solveInstructions, LogType.hiddenPairColumn) +
      _getlogCount(_solveInstructions, LogType.hiddenPairSection);

  int get boxLineReductionCount =>
      _getlogCount(_solveInstructions, LogType.rowBox) +
      _getlogCount(_solveInstructions, LogType.columnBox);

  int get pointingPairTripleCount =>
      _getlogCount(_solveInstructions, LogType.pointingPairTripleRow) +
      _getlogCount(_solveInstructions, LogType.pointingPairTripleColumn);

  int get guessCount => _getlogCount(_solveInstructions, LogType.guess);

  int get backtrackCount => _getlogCount(_solveInstructions, LogType.rollback);

  String printSolveInstructions() {
    if (isSolved) {
      return _printHistory(_solveInstructions);
    } else {
      return 'No solve instructions - Puzzle is not possible to solve.\n';
    }
  }

  /// Count the number of solutions to the puzzle.
  int countSolutions([bool limitToTwo = false, int? round]) {
    if (round == null) {
      // Don't record history while generating.
      bool recHistory = _recordHistory;
      _recordHistory = false;
      bool lHistory = _logHistory;
      _logHistory = false;

      _reset();
      int solutionCount = countSolutions(limitToTwo, 2);

      // Restore recording history.
      _recordHistory = recHistory;
      _logHistory = lHistory;

      return solutionCount;
    } else {
      while (_singleSolveMove(round)) {
        if (isSolved) {
          _rollbackRound(round);
          return 1;
        }

        if (_isImpossible) {
          _rollbackRound(round);
          return 0;
        }
      }

      int solutions = 0;
      int nextRound = round + 1;

      int guessNumber = 0;

      while (_guess(nextRound, guessNumber)) {
        solutions += countSolutions(limitToTwo, nextRound);

        if (limitToTwo && solutions >= 2) {
          _rollbackRound(round);
          return solutions;
        }

        guessNumber += 1;
      }

      _rollbackRound(round);
      return solutions;
    }
  }

  @override
  String toString() => _print(_puzzle);

  Symmetry get _randomSymmetry {
    switch (math.Random.secure().nextInt(100) % 4) {
      case 0:
        return Symmetry.rotate90;
      case 1:
        return Symmetry.rotate180;
      case 2:
        return Symmetry.mirror;
      case 3:
        return Symmetry.flip;
      default:
        return Symmetry.rotate90;
    }
  }

  bool _reset() {
    _solution.fillRange(0, _solution.length, 0);
    _solutionRound.fillRange(0, _solutionRound.length, 0);
    _possibilities.fillRange(0, _possibilities.length, 0);

    _solveHistory.clear();
    _solveInstructions.clear();

    int round = 1;

    for (int position = 0; position < boardSize; position += 1) {
      if (_puzzle[position] > 0) {
        int valIndex = _puzzle[position] - 1;
        int valPos = getPossibilityIndex(valIndex, position);
        int value = _puzzle[position];

        if (_possibilities[valPos] != 0) {
          return false;
        }

        _mark(position, round, value);

        if (_logHistory || _recordHistory) {
          _addHistoryItem(
            LogItem(
              logType: LogType.given,
              position: position,
              round: round,
              value: value,
            ),
          );
        }
      }
    }

    return true;
  }

  bool _singleSolveMove(int round) =>
      _onlyPossibilityForCell(round) ||
      _onlyValueInSection(round) ||
      _onlyValueInRow(round) ||
      _onlyValueInColumn(round) ||
      _handleNakedPairs(round) ||
      _pointingRowReduction(round) ||
      _pointingColumnReduction(round) ||
      _rowBoxReduction(round) ||
      _colBoxReduction(round) ||
      _hiddenPairInRow(round) ||
      _hiddenPairInColumn(round) ||
      _hiddenPairInSection(round);

  bool _onlyPossibilityForCell(int round) {
    for (int position = 0; position < boardSize; position += 1) {
      if (solution[position] == 0) {
        int count = 0;
        int lastValue = 0;

        for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
          int valPos = getPossibilityIndex(valIndex, position);

          if (_possibilities[valPos] == 0) {
            count += 1;
            lastValue = valIndex + 1;
          }
        }

        if (count == 1) {
          _mark(position, round, lastValue);

          if (_logHistory || _recordHistory) {
            _addHistoryItem(
              LogItem(
                round: round,
                logType: LogType.single,
                value: lastValue,
                position: position,
              ),
            );
          }

          return true;
        }
      }
    }

    return false;
  }

  bool _onlyValueInRow(int round) {
    for (int row = 0; row < rowColSecSize; row += 1) {
      for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
        int count = 0;
        int lastPosition = 0;

        for (int col = 0; col < rowColSecSize; col += 1) {
          int position = (row * rowColSecSize) + col;
          int valPos = getPossibilityIndex(valIndex, position);

          if (_possibilities[valPos] == 0) {
            count += 1;
            lastPosition = position;
          }
        }

        if (count == 1) {
          int value = valIndex + 1;

          if (_logHistory || _recordHistory) {
            _addHistoryItem(
              LogItem(
                round: round,
                logType: LogType.hiddenSingleRow,
                value: value,
                position: lastPosition,
              ),
            );
          }

          _mark(lastPosition, round, value);
          return true;
        }
      }
    }

    return false;
  }

  bool _onlyValueInColumn(int round) {
    for (int col = 0; col < rowColSecSize; col += 1) {
      for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
        int count = 0;
        int lastPosition = 0;

        for (int row = 0; row < rowColSecSize; row += 1) {
          int position = rowColumnToCell(row, col);
          int valPos = getPossibilityIndex(valIndex, position);

          if (_possibilities[valPos] == 0) {
            count += 1;
            lastPosition = position;
          }
        }

        if (count == 1) {
          int value = valIndex + 1;

          if (_logHistory || _recordHistory) {
            _addHistoryItem(
              LogItem(
                round: round,
                logType: LogType.hiddenSingleColumn,
                value: value,
                position: lastPosition,
              ),
            );
          }

          _mark(lastPosition, round, value);
          return true;
        }
      }
    }

    return false;
  }

  bool _onlyValueInSection(int round) {
    for (int sec = 0; sec < rowColSecSize; sec += 1) {
      int secPos = sectionToFirstCell(sec);

      for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
        int count = 0;
        int lastPosition = 0;

        for (int i = 0; i < gridSize; i += 1) {
          for (int j = 0; j < gridSize; j += 1) {
            int position = secPos + i + rowColSecSize * j;
            int valPos = getPossibilityIndex(valIndex, position);

            if (_possibilities[valPos] == 0) {
              count += 1;
              lastPosition = position;
            }
          }
        }

        if (count == 1) {
          int value = valIndex + 1;

          if (_logHistory || _recordHistory) {
            _addHistoryItem(
              LogItem(
                round: round,
                logType: LogType.hiddenSingleSection,
                value: value,
                position: lastPosition,
              ),
            );
          }

          _mark(lastPosition, round, value);
          return true;
        }
      }
    }

    return false;
  }

  bool _guess(int round, int guessNumber) {
    int localGuessCount = 0;
    int position = _findPositionWithFewestPossibilities();

    for (int i = 0; i < rowColSecSize; i += 1) {
      int valIndex = _randomPossibilities[i];
      int valPos = getPossibilityIndex(valIndex, position);

      if (_possibilities[valPos] == 0) {
        if (localGuessCount == guessNumber) {
          int value = valIndex + 1;

          if (_logHistory || _recordHistory) {
            _addHistoryItem(
              LogItem(
                round: round,
                logType: LogType.guess,
                value: value,
                position: position,
              ),
            );
          }

          _mark(position, round, value);

          return true;
        }

        localGuessCount += 1;
      }
    }

    return false;
  }

  bool get _isImpossible {
    for (int position = 0; position < boardSize; position += 1) {
      if (solution[position] == 0) {
        int count = 0;

        for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
          int valPos = getPossibilityIndex(valIndex, position);

          if (_possibilities[valPos] == 0) {
            count += 1;
          }
        }

        if (count == 0) {
          return true;
        }
      }
    }

    return false;
  }

  void _rollbackRound(int round) {
    if (_logHistory || _recordHistory) {
      _addHistoryItem(
        LogItem(
          round: round,
          logType: LogType.rollback,
        ),
      );
    }

    for (int i = 0; i < boardSize; i += 1) {
      if (_solutionRound[i] == round) {
        _solutionRound[i] = 0;
        solution[i] = 0;
      }
    }

    for (int i = 0; i < possibilitiesSize; i += 1) {
      if (_possibilities[i] == round) {
        _possibilities[i] = 0;
      }
    }

    while (_solveInstructions.isNotEmpty &&
        _solveInstructions.last.round == round) {
      _solveInstructions.removeLast();
    }
  }

  bool _pointingRowReduction(int round) {
    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      for (int section = 0; section < rowColSecSize; section += 1) {
        int secStart = sectionToFirstCell(section);
        bool inOneRow = true;
        int boxRow = -1;

        for (int j = 0; j < gridSize; j += 1) {
          for (int i = 0; i < gridSize; i += 1) {
            int secVal = secStart + i + (rowColSecSize * j);
            int valPos = getPossibilityIndex(valIndex, secVal);

            if (_possibilities[valPos] == 0) {
              if (boxRow == -1 || boxRow == j) {
                boxRow = j;
              } else {
                inOneRow = false;
              }
            }
          }
        }

        if (inOneRow && boxRow != -1) {
          bool doneSomething = false;
          int row = cellToRow(secStart) + boxRow;
          int rowStart = rowToFirstCell(row);

          for (int i = 0; i < rowColSecSize; i += 1) {
            int position = rowStart + i;
            int section2 = cellToSection(position);
            int valPos = getPossibilityIndex(valIndex, position);

            if (section != section2 && _possibilities[valPos] == 0) {
              _possibilities[valPos] = round;
              doneSomething = true;
            }
          }

          if (doneSomething) {
            if (_logHistory || _recordHistory) {
              _addHistoryItem(
                LogItem(
                  round: round,
                  logType: LogType.pointingPairTripleRow,
                  value: valIndex + 1,
                  position: rowStart,
                ),
              );
            }

            return true;
          }
        }
      }
    }

    return false;
  }

  bool _rowBoxReduction(int round) {
    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      for (int row = 0; row < rowColSecSize; row += 1) {
        final int rowStart = rowToFirstCell(row);
        bool inOneBox = true;
        int rowBox = -1;

        for (int i = 0; i < gridSize; i += 1) {
          for (int j = 0; j < gridSize; j += 1) {
            int column = i * gridSize + j;
            int position = rowColumnToCell(row, column);
            int valPos = getPossibilityIndex(valIndex, position);

            if (_possibilities[valPos] == 0) {
              if (rowBox == -1 || rowBox == i) {
                rowBox = i;
              } else {
                inOneBox = false;
              }
            }
          }
        }

        if (inOneBox && rowBox != -1) {
          bool doneSomething = false;
          int column = gridSize * rowBox;
          int secStart = cellToSectionStartCell(rowColumnToCell(row, column));
          int secStartRow = cellToRow(secStart);
          int secStartCol = cellToColumn(secStart);

          for (int i = 0; i < gridSize; i += 1) {
            for (int j = 0; j < gridSize; j += 1) {
              int row2 = secStartRow + i;
              int col2 = secStartCol + j;
              int position = rowColumnToCell(row2, col2);
              int valPos = getPossibilityIndex(valIndex, position);
              if (row != row2 && _possibilities[valPos] == 0) {
                _possibilities[valPos] = round;
                doneSomething = true;
              }
            }
          }

          if (doneSomething) {
            if (_logHistory || _recordHistory) {
              _addHistoryItem(
                LogItem(
                  round: round,
                  logType: LogType.rowBox,
                  value: valIndex + 1,
                  position: rowStart,
                ),
              );
            }

            return true;
          }
        }
      }
    }

    return false;
  }

  bool _colBoxReduction(int round) {
    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      for (int col = 0; col < rowColSecSize; col += 1) {
        final int colStart = columnToFirstCell(col);
        bool inOneBox = true;
        int colBox = -1;

        for (int i = 0; i < gridSize; i += 1) {
          for (int j = 0; j < gridSize; j += 1) {
            int row = i * gridSize + j;
            int position = rowColumnToCell(row, col);
            int valPos = getPossibilityIndex(valIndex, position);

            if (_possibilities[valPos] == 0) {
              if (colBox == -1 || colBox == i) {
                colBox = i;
              } else {
                inOneBox = false;
              }
            }
          }
        }

        if (inOneBox && colBox != -1) {
          bool doneSomething = false;
          int row = gridSize * colBox;
          int secStart = cellToSectionStartCell(rowColumnToCell(row, col));
          int secStartRow = cellToRow(secStart);
          int secStartCol = cellToColumn(secStart);

          for (int i = 0; i < gridSize; i += 1) {
            for (int j = 0; j < gridSize; j += 1) {
              int row2 = secStartRow + i;
              int col2 = secStartCol + j;
              int position = rowColumnToCell(row2, col2);
              int valPos = getPossibilityIndex(valIndex, position);

              if (col != col2 && _possibilities[valPos] == 0) {
                _possibilities[valPos] = round;
                doneSomething = true;
              }
            }
          }

          if (doneSomething) {
            if (_logHistory || _recordHistory) {
              _addHistoryItem(
                LogItem(
                  round: round,
                  logType: LogType.columnBox,
                  value: valIndex + 1,
                  position: colStart,
                ),
              );
            }

            return true;
          }
        }
      }
    }
    return false;
  }

  bool _pointingColumnReduction(int round) {
    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      for (int section = 0; section < rowColSecSize; section += 1) {
        int secStart = sectionToFirstCell(section);
        bool inOneCol = true;
        int boxCol = -1;

        for (int i = 0; i < gridSize; i += 1) {
          for (int j = 0; j < gridSize; j += 1) {
            int secVal = secStart + i + (rowColSecSize * j);
            int valPos = getPossibilityIndex(valIndex, secVal);

            if (_possibilities[valPos] == 0) {
              if (boxCol == -1 || boxCol == i) {
                boxCol = i;
              } else {
                inOneCol = false;
              }
            }
          }
        }

        if (inOneCol && boxCol != -1) {
          bool doneSomething = false;
          int col = cellToColumn(secStart) + boxCol;
          int colStart = columnToFirstCell(col);

          for (int i = 0; i < rowColSecSize; i += 1) {
            int position = colStart + (rowColSecSize * i);
            int section2 = cellToSection(position);
            int valPos = getPossibilityIndex(valIndex, position);

            if (section != section2 && _possibilities[valPos] == 0) {
              _possibilities[valPos] = round;
              doneSomething = true;
            }
          }

          if (doneSomething) {
            if (_logHistory || _recordHistory) {
              _addHistoryItem(
                LogItem(
                  round: round,
                  logType: LogType.pointingPairTripleColumn,
                  value: valIndex + 1,
                  position: colStart,
                ),
              );
            }

            return true;
          }
        }
      }
    }

    return false;
  }

  bool _hiddenPairInRow(int round) {
    for (int row = 0; row < rowColSecSize; row += 1) {
      for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
        int c1 = -1;
        int c2 = -1;
        int valCount = 0;

        for (int column = 0; column < rowColSecSize; column += 1) {
          int position = rowColumnToCell(row, column);
          int valPos = getPossibilityIndex(valIndex, position);

          if (_possibilities[valPos] == 0) {
            if (c1 == -1 || c1 == column) {
              c1 = column;
            } else if (c2 == -1 || c2 == column) {
              c2 = column;
            }
            valCount += 1;
          }
        }

        if (valCount == 2) {
          for (int valIndex2 = valIndex + 1;
              valIndex2 < rowColSecSize;
              valIndex2 += 1) {
            int c3 = -1;
            int c4 = -1;
            int valCount2 = 0;

            for (int column = 0; column < rowColSecSize; column += 1) {
              int position = rowColumnToCell(row, column);
              int valPos = getPossibilityIndex(valIndex2, position);

              if (_possibilities[valPos] == 0) {
                if (c3 == -1 || c3 == column) {
                  c3 = column;
                } else if (c4 == -1 || c4 == column) {
                  c4 = column;
                }
                valCount2 += 1;
              }
            }

            if (valCount2 == 2 && c1 == c3 && c2 == c4) {
              bool doneSomething = false;

              for (int valIndex3 = 0;
                  valIndex3 < rowColSecSize;
                  valIndex3 += 1) {
                if (valIndex3 != valIndex && valIndex3 != valIndex2) {
                  int position1 = rowColumnToCell(row, c1);
                  int position2 = rowColumnToCell(row, c2);
                  int valPos1 = getPossibilityIndex(valIndex3, position1);
                  int valPos2 = getPossibilityIndex(valIndex3, position2);

                  if (_possibilities[valPos1] == 0) {
                    _possibilities[valPos1] = round;
                    doneSomething = true;
                  }
                  if (_possibilities[valPos2] == 0) {
                    _possibilities[valPos2] = round;
                    doneSomething = true;
                  }
                }
              }

              if (doneSomething) {
                if (_logHistory || _recordHistory) {
                  _addHistoryItem(
                    LogItem(
                      round: round,
                      logType: LogType.hiddenPairRow,
                      value: valIndex + 1,
                      position: rowColumnToCell(row, c1),
                    ),
                  );
                }

                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  bool _hiddenPairInColumn(int round) {
    for (int column = 0; column < rowColSecSize; column += 1) {
      for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
        int r1 = -1;
        int r2 = -1;
        int valCount = 0;

        for (int row = 0; row < rowColSecSize; row += 1) {
          int position = rowColumnToCell(row, column);
          int valPos = getPossibilityIndex(valIndex, position);

          if (_possibilities[valPos] == 0) {
            if (r1 == -1 || r1 == row) {
              r1 = row;
            } else if (r2 == -1 || r2 == row) {
              r2 = row;
            }
            valCount += 1;
          }
        }

        if (valCount == 2) {
          for (int valIndex2 = valIndex + 1;
              valIndex2 < rowColSecSize;
              valIndex2 += 1) {
            int r3 = -1;
            int r4 = -1;
            int valCount2 = 0;

            for (int row = 0; row < rowColSecSize; row += 1) {
              int position = rowColumnToCell(row, column);
              int valPos = getPossibilityIndex(valIndex2, position);

              if (_possibilities[valPos] == 0) {
                if (r3 == -1 || r3 == row) {
                  r3 = row;
                } else if (r4 == -1 || r4 == row) {
                  r4 = row;
                }
                valCount2 += 1;
              }
            }

            if (valCount2 == 2 && r1 == r3 && r2 == r4) {
              bool doneSomething = false;

              for (int valIndex3 = 0;
                  valIndex3 < rowColSecSize;
                  valIndex3 += 1) {
                if (valIndex3 != valIndex && valIndex3 != valIndex2) {
                  int position1 = rowColumnToCell(r1, column);
                  int position2 = rowColumnToCell(r2, column);
                  int valPos1 = getPossibilityIndex(valIndex3, position1);
                  int valPos2 = getPossibilityIndex(valIndex3, position2);

                  if (_possibilities[valPos1] == 0) {
                    _possibilities[valPos1] = round;
                    doneSomething = true;
                  }

                  if (_possibilities[valPos2] == 0) {
                    _possibilities[valPos2] = round;
                    doneSomething = true;
                  }
                }
              }
              if (doneSomething) {
                if (_logHistory || _recordHistory) {
                  _addHistoryItem(
                    LogItem(
                      round: round,
                      logType: LogType.hiddenPairColumn,
                      value: valIndex + 1,
                      position: rowColumnToCell(r1, column),
                    ),
                  );
                }

                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  bool _hiddenPairInSection(int round) {
    for (int section = 0; section < rowColSecSize; section += 1) {
      for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
        int si1 = -1;
        int si2 = -1;
        int valCount = 0;

        for (int secInd = 0; secInd < rowColSecSize; secInd += 1) {
          int position = sectionToCell(section, secInd);
          int valPos = getPossibilityIndex(valIndex, position);

          if (_possibilities[valPos] == 0) {
            if (si1 == -1 || si1 == secInd) {
              si1 = secInd;
            } else if (si2 == -1 || si2 == secInd) {
              si2 = secInd;
            }
            valCount += 1;
          }
        }

        if (valCount == 2) {
          for (int valIndex2 = valIndex + 1;
              valIndex2 < rowColSecSize;
              valIndex2 += 1) {
            int si3 = -1;
            int si4 = -1;
            int valCount2 = 0;

            for (int secInd = 0; secInd < rowColSecSize; secInd += 1) {
              int position = sectionToCell(section, secInd);
              int valPos = getPossibilityIndex(valIndex2, position);

              if (_possibilities[valPos] == 0) {
                if (si3 == -1 || si3 == secInd) {
                  si3 = secInd;
                } else if (si4 == -1 || si4 == secInd) {
                  si4 = secInd;
                }
                valCount2 += 1;
              }
            }

            if (valCount2 == 2 && si1 == si3 && si2 == si4) {
              bool doneSomething = false;

              for (int valIndex3 = 0;
                  valIndex3 < rowColSecSize;
                  valIndex3 += 1) {
                if (valIndex3 != valIndex && valIndex3 != valIndex2) {
                  int position1 = sectionToCell(section, si1);
                  int position2 = sectionToCell(section, si2);
                  int valPos1 = getPossibilityIndex(valIndex3, position1);
                  int valPos2 = getPossibilityIndex(valIndex3, position2);

                  if (_possibilities[valPos1] == 0) {
                    _possibilities[valPos1] = round;
                    doneSomething = true;
                  }

                  if (_possibilities[valPos2] == 0) {
                    _possibilities[valPos2] = round;
                    doneSomething = true;
                  }
                }
              }

              if (doneSomething) {
                if (_logHistory || _recordHistory) {
                  _addHistoryItem(
                    LogItem(
                      round: round,
                      logType: LogType.hiddenPairSection,
                      value: valIndex + 1,
                      position: sectionToCell(section, si1),
                    ),
                  );
                }

                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  // Mark the given value at the given position.  Go through
  // the row, column, and section for the position and remove
  // the value from the possibilities.
  //
  // position Position into the board (0-80)
  // round Round to mark for rollback purposes
  // value The value to go in the square at the given position
  void _mark(int position, int round, int value) {
    if (solution[position] != 0) {
      throw ('Marking position that already has been marked.');
    }

    if (_solutionRound[position] != 0) {
      throw ('Marking position that was marked another round.');
    }

    int valIndex = value - 1;
    solution[position] = value;

    int possInd = getPossibilityIndex(valIndex, position);

    if (_possibilities[possInd] != 0) {
      throw ('Marking impossible position.');
    }

    // Take this value out of the possibilities for everything in the row
    _solutionRound[position] = round;
    int rowStart = cellToRow(position) * rowColSecSize;

    for (int col = 0; col < rowColSecSize; col += 1) {
      int rowVal = rowStart + col;
      int valPos = getPossibilityIndex(valIndex, rowVal);

      if (_possibilities[valPos] == 0) {
        _possibilities[valPos] = round;
      }
    }

    // Take this value out of the possibilities for everything in the column
    int colStart = cellToColumn(position);

    for (int i = 0; i < rowColSecSize; i += 1) {
      int colVal = colStart + (rowColSecSize * i);
      int valPos = getPossibilityIndex(valIndex, colVal);

      if (_possibilities[valPos] == 0) {
        _possibilities[valPos] = round;
      }
    }

    // Take this value out of the possibilities for everything in section
    int secStart = cellToSectionStartCell(position);

    for (int i = 0; i < gridSize; i += 1) {
      for (int j = 0; j < gridSize; j += 1) {
        int secVal = secStart + i + (rowColSecSize * j);
        int valPos = getPossibilityIndex(valIndex, secVal);

        if (_possibilities[valPos] == 0) {
          _possibilities[valPos] = round;
        }
      }
    }

    //This position itself is determined, it should have possibilities.
    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      int valPos = getPossibilityIndex(valIndex, position);
      if (_possibilities[valPos] == 0) {
        _possibilities[valPos] = round;
      }
    }
  }

  int _findPositionWithFewestPossibilities() {
    int minPossibilities = 10;
    int bestPosition = 0;

    for (int i = 0; i < boardSize; i += 1) {
      int position = _randomBoards[i];

      if (solution[position] == 0) {
        int count = 0;

        for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
          int valPos = getPossibilityIndex(valIndex, position);
          if (_possibilities[valPos] == 0) {
            count += 1;
          }
        }

        if (count < minPossibilities) {
          minPossibilities = count;
          bestPosition = position;
        }
      }
    }

    return bestPosition;
  }

  bool _handleNakedPairs(int round) {
    for (int position = 0; position < boardSize; position += 1) {
      int possibilities = _countPossibilities(position);

      if (possibilities == 2) {
        int row = cellToRow(position);
        int column = cellToColumn(position);
        int section = cellToSectionStartCell(position);
        for (int position2 = position; position2 < boardSize; position2 += 1) {
          if (position != position2) {
            int possibilities2 = _countPossibilities(position2);

            if (possibilities2 == 2 &&
                _arePossibilitiesSame(position, position2)) {
              if (row == cellToRow(position2)) {
                bool doneSomething = false;

                for (int column2 = 0; column2 < rowColSecSize; column2 += 1) {
                  int position3 = rowColumnToCell(row, column2);

                  if (position3 != position &&
                      position3 != position2 &&
                      _removePossibilitiesInOneFromTwo(
                          position, position3, round)) {
                    doneSomething = true;
                  }
                }

                if (doneSomething) {
                  if (_logHistory || _recordHistory) {
                    _addHistoryItem(
                      LogItem(
                        round: round,
                        logType: LogType.nakedPairRow,
                        value: 0,
                        position: position,
                      ),
                    );
                  }

                  return true;
                }
              }
              if (column == cellToColumn(position2)) {
                bool doneSomething = false;

                for (int row2 = 0; row2 < rowColSecSize; row2 += 1) {
                  int position3 = rowColumnToCell(row2, column);

                  if (position3 != position &&
                      position3 != position2 &&
                      _removePossibilitiesInOneFromTwo(
                        position,
                        position3,
                        round,
                      )) {
                    doneSomething = true;
                  }
                }

                if (doneSomething) {
                  if (_logHistory || _recordHistory) {
                    _addHistoryItem(
                      LogItem(
                        round: round,
                        logType: LogType.nakedPairColumn,
                        value: 0,
                        position: position,
                      ),
                    );
                  }

                  return true;
                }
              }

              if (section == cellToSectionStartCell(position2)) {
                bool doneSomething = false;
                int secStart = cellToSectionStartCell(position);

                for (int i = 0; i < gridSize; i += 1) {
                  for (int j = 0; j < gridSize; j += 1) {
                    int position3 = secStart + i + (rowColSecSize * j);

                    if (position3 != position &&
                        position3 != position2 &&
                        _removePossibilitiesInOneFromTwo(
                          position,
                          position3,
                          round,
                        )) {
                      doneSomething = true;
                    }
                  }
                }

                if (doneSomething) {
                  if (_logHistory || _recordHistory) {
                    _addHistoryItem(
                      LogItem(
                        round: round,
                        logType: LogType.nakedPairSection,
                        value: 0,
                        position: position,
                      ),
                    );
                  }

                  return true;
                }
              }
            }
          }
        }
      }
    }

    return false;
  }

  int _countPossibilities(int position) {
    int count = 0;

    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      int valPos = getPossibilityIndex(valIndex, position);

      if (_possibilities[valPos] == 0) {
        count += 1;
      }
    }

    return count;
  }

  bool _arePossibilitiesSame(int position1, int position2) {
    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      int valPos1 = getPossibilityIndex(valIndex, position1);
      int valPos2 = getPossibilityIndex(valIndex, position2);

      if ((_possibilities[valPos1] == 0 || _possibilities[valPos2] == 0) &&
          (_possibilities[valPos1] != 0 || _possibilities[valPos2] != 0)) {
        return false;
      }
    }

    return true;
  }

  void _addHistoryItem(LogItem logItem) {
    if (_logHistory) {
      print(logItem.toString());
    }

    if (_recordHistory) {
      _solveHistory.add(logItem);
      _solveInstructions.add(logItem);
    }
  }

  void _shuffleRandom() {
    _randomBoards.shuffle();
    _randomPossibilities.shuffle();
  }

  String _print(List<int> sudoku) {
    String result = '';

    for (int i = 0; i < boardSize; i += 1) {
      result += ' ';

      result += (sudoku[i] == 0 ? '.' : sudoku[i].toString());

      if (i == boardSize - 1) {
        result += '\n\n';
      } else if (i % rowColSecSize == rowColSecSize - 1) {
        result += '\n';

        if (i % secGroupSize == secGroupSize - 1) {
          result += '-------|-------|-------\n';
        }
      } else if (i % gridSize == gridSize - 1) {
        result += ' |';
      }
    }

    return result;
  }

  void _rollbackNonGuesses() {
    for (int i = 2; i <= _lastSolveRound; i += 2) {
      _rollbackRound(i);
    }
  }

  void _clearPuzzle() {
    _puzzle = List.filled(boardSize, 0);
    _reset();
  }

  String _printHistory(List<LogItem> value) {
    String result = '';

    if (!_recordHistory) {
      result += 'History was not recorded.\n';
    }

    for (int i = 0; i < value.length; i += 1) {
      result += '${i + 1}. ';
      result += value[i].toString();
      result += '\n';
    }

    result += '\n';

    return result;
  }

  bool _removePossibilitiesInOneFromTwo(
      int position1, int position2, int round) {
    bool doneSomething = false;

    for (int valIndex = 0; valIndex < rowColSecSize; valIndex += 1) {
      int valPos1 = getPossibilityIndex(valIndex, position1);
      int valPos2 = getPossibilityIndex(valIndex, position2);

      if (_possibilities[valPos1] == 0 && _possibilities[valPos2] == 0) {
        _possibilities[valPos2] = round;
        doneSomething = true;
      }
    }

    return doneSomething;
  }
}
