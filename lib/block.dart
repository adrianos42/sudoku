import 'package:desktop/desktop.dart';

import 'package:flutter/services.dart';

import 'state.dart';

class Block extends StatefulWidget {
  const Block({
    super.key,
    required this.value,
    required this.readonly,
    required this.onNumberSelected,
    required this.onNumberRemoved,
    required this.onSelected,
    required this.onUnselected,
    required this.wrongValue,
    required this.state,
    required this.onFlipped,
  });

  final bool wrongValue;
  final int value;
  final bool readonly;
  final Function(int) onNumberSelected;
  final VoidCallback onSelected;
  final VoidCallback onUnselected;
  final VoidCallback onNumberRemoved;
  final VoidCallback onFlipped;
  final BlockState state;

  @override
  State<Block> createState() => _BlockState();
}

class _FlipIntent extends Intent {
  const _FlipIntent();
}

class _FlipAction extends Action<_FlipIntent> {
  _FlipAction(this._state);

  final _BlockState _state;

  @override
  Object? invoke(covariant _FlipIntent intent) {
    _state.widget.onFlipped();
    return null;
  }
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

class _ClearAction extends Action<_ClearIntent> {
  _ClearAction(this._state);

  final _BlockState _state;

  @override
  Object? invoke(covariant _ClearIntent intent) {
    _state.widget.onNumberRemoved();
    return null;
  }
}

class _NumberIntent extends Intent {
  const _NumberIntent(this.value);

  final int value;
}

class _NumberAction extends Action<_NumberIntent> {
  _NumberAction(this._state);

  final _BlockState _state;

  @override
  Object? invoke(covariant _NumberIntent intent) {
    _state.widget.onNumberSelected(intent.value);
    return null;
  }
}

class _BlockState extends State<Block> {
  bool hovered = false;
  final FocusNode _focusNode = FocusNode();

  final Map<LogicalKeySet, Intent> shortcuts = {
    LogicalKeySet(LogicalKeyboardKey.space): const _FlipIntent(),
    LogicalKeySet(LogicalKeyboardKey.backspace): const _ClearIntent(),
    LogicalKeySet(LogicalKeyboardKey.delete): const _ClearIntent(),
    LogicalKeySet(LogicalKeyboardKey.digit0): const _NumberIntent(0),
    LogicalKeySet(LogicalKeyboardKey.digit1): const _NumberIntent(1),
    LogicalKeySet(LogicalKeyboardKey.digit2): const _NumberIntent(2),
    LogicalKeySet(LogicalKeyboardKey.digit3): const _NumberIntent(3),
    LogicalKeySet(LogicalKeyboardKey.digit4): const _NumberIntent(4),
    LogicalKeySet(LogicalKeyboardKey.digit5): const _NumberIntent(5),
    LogicalKeySet(LogicalKeyboardKey.digit6): const _NumberIntent(6),
    LogicalKeySet(LogicalKeyboardKey.digit7): const _NumberIntent(7),
    LogicalKeySet(LogicalKeyboardKey.digit8): const _NumberIntent(8),
    LogicalKeySet(LogicalKeyboardKey.digit9): const _NumberIntent(9),
  };

  Color get background {
    final wrongNumber = widget.wrongValue;
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    final Color color;

    if (hovered) {
      color = colorScheme.shade[90];
    } else if (_focusNode.hasFocus) {
      if (widget.state.flipped) {
        color = colorScheme.primary[40];
      } else {
        color = wrongNumber ? colorScheme.error : colorScheme.primary[40];
      }
    } else if (widget.readonly) {
      color = colorScheme.background[0];
    } else {
      color = colorScheme.background[0];
    }

    return color;
  }

  Color get foreground {
    final wrongNumber = widget.wrongValue;
    final themeData = Theme.of(context);
    final textTheme = themeData.textTheme;
    final colorScheme = themeData.colorScheme;

    final Color color;

    if (hovered) {
      color = colorScheme.background[0];
    } else if (_focusNode.hasFocus) {
      color = textTheme.textHigh;
    } else if (wrongNumber) {
      color = textTheme.textError;
    } else {
      color = widget.readonly ? textTheme.textLow : textTheme.textHigh;
    }

    return color;
  }

  Widget createNumber() {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Text(
              widget.value.toString(),
              style: textTheme.monospace.copyWith(
                fontSize: constraints.maxWidth / 1.7,
                color: foreground,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget createAnnotation() {
    return LayoutBuilder(builder: (context, constraints) {
      final fontSize = constraints.maxWidth / 3.4;
      final themeData = Theme.of(context);
      final textStyle = themeData.textTheme.monospace.copyWith(
        fontSize: fontSize,
        color: foreground,
      );
      final colorScheme = themeData.colorScheme;
      final size = (constraints.maxWidth / 2.0).roundToDouble() - 2.0;

      Widget selectText(int i) {
        final text = widget.state.values[i] == 0
            ? ''
            : widget.state.values[i].toString();

        final borderSide =
            BorderSide(color: colorScheme.background[12], width: 1.0);

        return Container(
          alignment: Alignment.center,
          foregroundDecoration: BoxDecoration(
              border: Border(
            bottom: i == 0 || i == 1 ? borderSide : BorderSide.none,
            right: i == 0 || i == 2 ? borderSide : BorderSide.none,
            left: i == 1 || i == 3 ? borderSide : BorderSide.none,
            top: i == 2 || i == 3 ? borderSide : BorderSide.none,
          )),
          child: Center(
            child: Text(text, style: textStyle),
          ),
        );
      }

      Widget selectRow(int i) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: selectText(i * 2)),
            Expanded(child: selectText(i * 2 + 1)),
          ],
        );
      }

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: selectRow(0)),
          Expanded(child: selectRow(1)),
        ],
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget result;

    if (widget.state.flipped) {
      result = createAnnotation();
    } else if (widget.value > 0) {
      result = createNumber();
    } else {
      result = const SizedBox();
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: !widget.readonly
            ? <Type, Action<Intent>>{
                _FlipIntent: _FlipAction(this),
                _ClearIntent: _ClearAction(this),
                _NumberIntent: _NumberAction(this),
              }
            : {},
        child: Focus(
          focusNode: _focusNode,
          onFocusChange: (value) {
            setState(() {
              if (value) {
                widget.onSelected();
              } else {
                widget.onUnselected();
              }
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              setState(() {
                hovered = true;
              });
            },
            onExit: (_) {
              setState(() {
                hovered = false;
              });
            },
            child: GestureDetector(
              onTap: () {
                if (_focusNode.hasFocus) {
                  FocusScope.of(context)
                      .unfocus(disposition: UnfocusDisposition.scope);
                  widget.onUnselected();
                } else {
                  FocusScope.of(context).requestFocus(_focusNode);
                }
              },
              child: Container(
                color: background,
                child: result,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BlockBorder extends CustomPainter {
  const BlockBorder(
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
        (size.height / 2.0).roundToDouble(),
        size.width,
        2.0,
      ),
      paint,
    );

    // right
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width / 2.0).roundToDouble(),
        0.0,
        2.0,
        size.height,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(BlockBorder oldDelegate) => false;
}
