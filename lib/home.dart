import 'package:desktop/desktop.dart';
import 'data.dart';
import 'sudoku.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static ContextMenuItem<PrimaryColors> _menuItemPrimaryColor(
    PrimaryColors color,
  ) {
    return ContextMenuItem(
      value: color,
      child: Text(
        color.toString(),
      ),
    );
  }

  PrimaryColors? _primaryColor;
  bool isLoading = true;

  PrimaryColors get primaryColor =>
      _primaryColor ??
      PrimaryColors.fromPrimaryColor(Theme.of(context).colorScheme.primary)!;

  Widget _createColorButton() {
    List<ContextMenuItem<PrimaryColors>> itemBuilder(context) => [
          _menuItemPrimaryColor(PrimaryColors.coral),
          _menuItemPrimaryColor(PrimaryColors.sandyBrown),
          _menuItemPrimaryColor(PrimaryColors.orange),
          _menuItemPrimaryColor(PrimaryColors.goldenrod),
          _menuItemPrimaryColor(PrimaryColors.springGreen),
          _menuItemPrimaryColor(PrimaryColors.turquoise),
          _menuItemPrimaryColor(PrimaryColors.deepSkyBlue),
          _menuItemPrimaryColor(PrimaryColors.dodgerBlue),
          _menuItemPrimaryColor(PrimaryColors.cornflowerBlue),
          _menuItemPrimaryColor(PrimaryColors.royalBlue),
          _menuItemPrimaryColor(PrimaryColors.slateBlue),
          _menuItemPrimaryColor(PrimaryColors.purple),
          _menuItemPrimaryColor(PrimaryColors.violet),
          _menuItemPrimaryColor(PrimaryColors.hotPink),
          _menuItemPrimaryColor(PrimaryColors.red),
        ];

    return Builder(
      builder: (context) => ButtonTheme.merge(
        data: ButtonThemeData(
          color: Theme.of(context).textTheme.textPrimaryHigh,
          highlightColor: ButtonTheme.of(context).color,
        ),
        child: ContextMenuButton(
          const Icon(Icons.palette),
          itemBuilder: itemBuilder,
          value: primaryColor,
          onSelected: (PrimaryColors value) {
            final themeData = Theme.of(context);
            final colorScheme = themeData.colorScheme;
            _primaryColor = value;
            Data.themeColor = value;

            Theme.updateThemeData(
              context,
              themeData.copyWith(
                colorScheme: ColorScheme(
                  colorScheme.brightness,
                  primary: value.primaryColor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'New Game',
                  style: textTheme.header,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _createColorButton(),
                    _ThemeToggle(
                      onPressed: () => setState(() {
                        final invertedTheme = Theme.of(context).invertedTheme;
                        Theme.updateThemeData(context, invertedTheme);
                        Data.themeBrightness = invertedTheme.brightness;
                      }),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Difficulty',
                    style: textTheme.title,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Button.text('Easy', onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/game', arguments: Difficulty.easy);
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Button.text('Medium', onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/game', arguments: Difficulty.medium);
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Button.text('Hard', onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/game', arguments: Difficulty.hard);
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (Data.hasLoadedData) {
      return result;
    }

    result = isLoading
        ? Center(
            child: Image.asset('assets/sudoku.png'),
          )
        : result;

    return FutureBuilder(
      future: Future.delayed(const Duration(seconds: 1))
          .then((value) => Data.restoreAppData()),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data != null) {
            final data = snapshot.data!;

            WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
              ThemeData themeData = Theme.of(context);

              if (data.themeBrightness != null) {
                themeData = themeData.withBrightness(data.themeBrightness!);
              }

              if (data.themeColor != null) {
                final colorScheme = themeData.colorScheme;

                themeData = themeData.copyWith(
                  colorScheme: ColorScheme(
                    colorScheme.brightness,
                    primary: data.themeColor!.primaryColor
                  ),
                );
              }

              if (data.themeBrightness != null || data.themeColor != null) {
                Theme.updateThemeData(context, themeData);
              }

              if (data.gameData != null) {
                await Navigator.of(context)
                    .pushNamed('/game', arguments: snapshot.data!.gameData!);
              }

              setState(() => isLoading = false);
            });
          }
        }

        return result;
      },
    );
  }
}

class _ThemeToggle extends StatefulWidget {
  const _ThemeToggle({
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final VoidCallback onPressed;

  @override
  _ThemeToggleState createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle> {
  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final iconForeground = themeData.textTheme.textHigh;
    switch (themeData.brightness) {
      case Brightness.dark:
        return Button.icon(
          Icons.dark_mode,
          onPressed: widget.onPressed,
          style: ButtonThemeData(
            color: iconForeground,
          ),
        );
      case Brightness.light:
        return Button.icon(
          Icons.light_mode,
          onPressed: widget.onPressed,
          style: ButtonThemeData(color: iconForeground),
        );
    }
  }
}
