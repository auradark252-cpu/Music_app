import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.music_app.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
  );
  Library.i.load();
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Music',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: const ColorScheme.dark(primary: kAccent),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF121212),
            indicatorColor: Colors.transparent,
          ),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  final pages = const [HomeScreen(), SearchScreen(), LibraryScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
                NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Your Library'),
              ],
            ),
          ],
        ),
      );
}
