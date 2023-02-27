class BlockState {
  BlockState(this.index);

  int index;
  bool flipped = false;
  int lastValue = 0;
  final List<int> values = List.filled(4, 0);
}
