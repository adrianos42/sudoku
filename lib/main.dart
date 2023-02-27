import 'package:desktop/desktop.dart';

import 'home.dart';
import 'game.dart';
import 'sudoku.dart';
import 'data.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final desktopKey = GlobalKey();
  final splashKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final themeData = ThemeData.dark();

    return DesktopApp(
      key: desktopKey,
      title: 'Sudoku',
      theme: themeData.copyWith(
        colorScheme: ColorScheme(
          themeData.colorScheme.brightness,
          primary: PrimaryColor.cornflowerBlue,
        ),
      ),
      navigatorObservers: const [_AppNavigatorObserver()],
      onGenerateRoute: (settings) {
        final name = settings.name;

        switch (name) {
          case '/':
            return DesktopPageRoute(builder: (context) => const HomePage());
          case '/game':
            final Difficulty difficulty;
            GameData? gameData;

            if (settings.arguments is Difficulty) {
              difficulty = settings.arguments as Difficulty;
            } else {
              gameData = settings.arguments as GameData;
              difficulty = gameData.difficulty;
            }

            return DesktopPageRoute(
              settings: settings,
              builder: (context) {
                return GamePage(difficulty: difficulty, gameData: gameData);
              },
            );
          default:
            return DesktopPageRoute(
              builder: (context) {
                return const SizedBox();
              },
            );
        }
      },
    );
  }
}

class _AppNavigatorObserver implements NavigatorObserver {
  const _AppNavigatorObserver();

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route.settings.name == '/game') {
      Data.clearGameData();
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {}

  @override
  void didRemove(Route route, Route? previousRoute) {}

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {}

  @override
  void didStartUserGesture(Route route, Route? previousRoute) {}

  @override
  void didStopUserGesture() {}

  @override
  NavigatorState? get navigator => null;
}
