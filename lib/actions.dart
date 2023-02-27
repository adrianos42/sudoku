enum ActionType {
  set,
  flip,
  add,
}

class BoardAction {
  const BoardAction({
    required this.value,
    required this.lastValue,
    required this.index,
    required this.actionType,
    this.flippedIndex = -1,
  });

  final int value;
  final int lastValue;
  final int index;
  final int flippedIndex;
  final ActionType actionType;

  @override
  int get hashCode => Object.hash(
        value,
        lastValue,
        index,
        actionType,
        flippedIndex,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BoardAction &&
        other.value == value &&
        other.lastValue == lastValue &&
        other.index == index &&
        other.actionType == actionType &&
        other.flippedIndex == flippedIndex;
  }

  @override
  String toString() {
    String result =
        'action { value: $value, lastValue: $lastValue, index: $index, actionType: $actionType';
    if (actionType == ActionType.flip) {
      result += ', flippledIndex: $flippedIndex';
    }
    result += ' }';
    return result;
  }
}
