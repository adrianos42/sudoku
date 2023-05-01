import 'dart:async';

import 'package:desktop/desktop.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'actions.dart';
import 'sudoku.dart';

class AppData {
  const AppData({
    required this.gameData,
    required this.themeBrightness,
    required this.themeColor,
  });

  final GameData? gameData;
  final Brightness? themeBrightness;
  final PrimaryColors? themeColor;
}

class GameData {
  const GameData({
    required this.gameDuration,
    required this.puzzle,
    required this.redoActions,
    required this.undoActions,
    required this.difficulty,
  });

  final Difficulty difficulty;
  final List<int> puzzle;
  final Duration gameDuration;
  final List<BoardAction> undoActions;
  final List<BoardAction> redoActions;
}

class Data {
  static Future<SharedPreferences> get _data => SharedPreferences.getInstance();

  static set puzzle(List<int> value) {
    _data.then((data) {
      data.setStringList('puzzle', value.map((e) => e.toString()).toList());
    });
  }

  static set difficulty(Difficulty value) {
    _data.then((data) {
      data.setInt('difficulty', value.index);
    });
  }

  static set gameDuration(Duration value) {
    _data.then((data) {
      data.setInt('duration', value.inSeconds);
    });
  }

  static updateAction(String action, int length, int index, BoardAction value) {
    _data.then((data) {
      data.setInt('${action}_action_${index}_flippedIndex', value.flippedIndex);
      data.setInt('${action}_action_${index}_index', value.index);
      data.setInt('${action}_action_${index}_lastValue', value.lastValue);
      data.setInt('${action}_action_${index}_value', value.value);
      data.setInt(
          '${action}_action_${index}_actionType', value.actionType.index);
      data.setInt('${action}_action_length', length);
    });
  }

  static removeLastAction(String action, int length) {
    _data.then((data) {
      data.remove('${action}_action_${length}_flippedIndex');
      data.remove('${action}_action_${length}_index');
      data.remove('${action}_action_${length}_lastValue');
      data.remove('${action}_action_${length}_value');
      data.remove('${action}_action_${length}_actionType');
      data.setInt('${action}_action_length', length);
    });
  }

  static clearActions(String action, int length) {
    _data.then((data) {
      for (int i = 0; i < length; i += 1) {
        data.remove('${action}_action_${i}_flippedIndex');
        data.remove('${action}_action_${i}_index');
        data.remove('${action}_action_${i}_lastValue');
        data.remove('${action}_action_${i}_value');
        data.remove(
          '${action}_action_${i}_actionType',
        );
      }

      data.setInt('${action}_action_length', 0);
    });
  }

  static List<BoardAction>? _restoreActions(
      SharedPreferences data, String action) {
    final length = data.getInt('${action}_action_length');

    if (length != null) {
      final List<BoardAction> result = [];

      for (int i = 0; i < length; i += 1) {
        final flippedIndex = data.getInt('${action}_action_${i}_flippedIndex');
        final index = data.getInt('${action}_action_${i}_index');
        final lastValue = data.getInt('${action}_action_${i}_lastValue');
        final value = data.getInt('${action}_action_${i}_value');
        final actionType = data.getInt(
          '${action}_action_${i}_actionType',
        );

        if (flippedIndex == null ||
            index == null ||
            lastValue == null ||
            value == null ||
            actionType == null) {
          return null;
        }

        result.add(BoardAction(
          value: value,
          lastValue: lastValue,
          index: index,
          actionType: ActionType.values[actionType],
          flippedIndex: flippedIndex,
        ));
      }

      return result;
    }

    return null;
  }

  static GameData? _restoreGameData(SharedPreferences data) {
    final int? difficultyValue = data.getInt('difficulty');
    final int? durationValue = data.getInt('duration');
    final List<String>? puzzleValue = data.getStringList('puzzle');

    final List<BoardAction>? undoActions = _restoreActions(data, 'undo');
    final List<BoardAction>? redoActions = _restoreActions(data, 'redo');

    if (difficultyValue == null ||
        durationValue == null ||
        puzzleValue == null ||
        redoActions == null ||
        undoActions == null) {
      return null;
    }

    final Difficulty difficulty = Difficulty.values[difficultyValue];
    final List<int> puzzle = puzzleValue.map((e) => int.parse(e)).toList();
    final Duration gameDuration = Duration(seconds: durationValue);

    return GameData(
      gameDuration: gameDuration,
      puzzle: puzzle,
      redoActions: redoActions,
      undoActions: undoActions,
      difficulty: difficulty,
    );
  }

  static void clearGameData() {
    _data.then((data) {
      data.remove('difficulty');
      data.remove('duration');
      data.remove('puzzle');

      int? length = data.getInt('undo_action_length');

      if (length != null) {
        clearActions('undo', length);
        data.remove('undo_action_length');
      }

      length = data.getInt('redo_action_length');

      if (length != null) {
        clearActions('redo', length);
        data.remove('redo_action_length');
      }
    });
  }

  static Future<GameData?> restoreGameData() async {
    return _restoreGameData(await _data);
  }

  static set themeBrightness(Brightness value) {
    _data.then((data) {
      data.setInt('themeBrightness', value.index);
    });
  }

  static set themeColor(PrimaryColors value) {
    _data.then((data) {
      data.setInt('themeColor', value.index);
    });
  }

  static bool _hasLoadedData = false;
  static bool get hasLoadedData => _hasLoadedData;

  static Future<AppData> restoreAppData() async {
    final data = await _data;

    final GameData? gameData = _restoreGameData(data);

    final int? brightnessValue = data.getInt('themeBrightness');

    Brightness? brightness;

    if (brightnessValue != null) {
      brightness = Brightness.values[brightnessValue];
    }

    final int? themeColorValue = data.getInt('themeColor');

    PrimaryColors? themeColor;

    if (themeColorValue != null) {
      themeColor = PrimaryColors.values[themeColorValue];
    }

    _hasLoadedData = true;

    return AppData(
      gameData: gameData,
      themeBrightness: brightness,
      themeColor: themeColor,
    );
  }
}
