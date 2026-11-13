import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'core.dart';

const kAccent = Color(0xFFF43F5E);
const kMaroon = Color(0xFF6B0F1A);

String fmt(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

// ---------- Small widgets ----------
class Thumb extends StatelessWidget {
  final String url;
  final double size;
  const Thumb(this.url, this.size, {super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.grey[850],
            child: const Icon(Icons.music_note),
          ),
        ),
      );
}

class SongList extends StatelessWidget {
  final List<Song> songs;
  const SongList(this.songs, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: PlayerService.i,
        builder: (_, __) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: songs.length,
          itemBuilder: (_, i) {
            final s = songs[i];
            final active = PlayerService.i.current?.id == s.id;
            return ListTile(
              leading: Thumb(s.thumb, 52),
              title: Text(s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, color: active ? kAccent : null)),
              subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(fmt(s.duration), style: const TextStyle(color: Colors.grey)),
              onTap: () => PlayerService.i.playQueue(songs, i),
            );
          },
        ),
      );
}

class Header extends StatelessWidget {
  final String text;
  const Header(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Text(text, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500)),
      );
}

// ---------- Home ----------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Song>> _f = Api.trending();

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header('Home'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Trending now', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Song>>(
                future: _f,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || (snap.data ?? []).isEmpty) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() => _f = Api.trending()),
                        child: const Text('Load nahi hua. Dobara try karo'),
                      ),
                    );
                  }
                  return SongList(snap.data!);
                },
              ),
            ),
          ],
        ),
      );
}

// ---------- Search ----------
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Song> _songs = [];
  List<String> _suggestions = [];
  bool _loading = false;
  String? _error;

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });
    try {
      final r = await Api.search(q);
      if (mounted) setState(() => _songs = r);
    } catch (_) {
      if (mounted) setState(() => _error = 'Kuch gadbad hui, dobara try karo');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final s = await Api.suggest(q.trim());
      if (mounted) setState(() => _suggestions = s);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header('Search'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Songs, artists...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {
                        _songs = [];
                        _suggestions = [];
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_suggestions.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    for (final s in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(s),
                          onPressed: () {
                            _ctrl.text = s;
                            _search(s);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
            Expanded(child: SongList(_songs)),
          ],
        ),
      );
}

// ---------- Library ----------
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header('Your Library'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Liked songs', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: Library.i,
                builder: (_, __) => Library.i.liked.isEmpty
                    ? const Center(child: Text('Abhi koi liked song nahi hai'))
                    : SongList(Library.i.liked),
              ),
            ),
          ],
        ),
      );
}

// ---------- Mini player ----------
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([PlayerService.i, Library.i]),
        builder: (ctx, _) {
          final p = PlayerService.i;
          final s = p.current;
          if (s == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(fullscreenDialog: true, builder: (_) => const NowPlayingScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              decoration: BoxDecoration(color: kMaroon, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: Thumb(s.thumb, 44),
                    title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Library.i.isLiked(s) ? Icons.favorite : Icons.favorite_border,
                              color: Library.i.isLiked(s) ? kAccent : null),
                          onPressed: () => Library.i.toggle(s),
                        ),
                        IconButton(
                          icon: Icon(p.player.playing ? Icons.pause : Icons.play_arrow, size: 30),
                          onPressed: p.toggle,
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<Duration>(
                    stream: p.player.positionStream,
                    builder: (_, snap) {
                      final pos = (snap.data ?? Duration.zero).inSeconds;
                      return LinearProgressIndicator(
                        value: s.duration > 0 ? (pos / s.duration).clamp(0.0, 1.0) : 0,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: kAccent,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
}

// ---------- Now playing ----------
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlayingScreen> {
  Color bg = kMaroon;
  String? _lastId;

  Future<void> _color(Song s) async {
    if (_lastId == s.id) return;
    _lastId = s.id;
    try {
      final pg = await PaletteGenerator.fromImageProvider(
        NetworkImage(s.thumb),
        size: const Size(100, 100),
      );
      final c = pg.darkMutedColor?.color ?? pg.dominantColor?.color;
      if (c != null && mounted) setState(() => bg = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([PlayerService.i, Library.i]),
        builder: (ctx, _) {
          final p = PlayerService.i;
          final s = p.current;
          if (s == null) {
            return const Scaffold(body: Center(child: Text('Kuch play nahi ho raha')));
          }
          _color(s);
          final st = p.player.processingState;
          final loading = st == ProcessingState.loading || st == ProcessingState.buffering;
          final liked = Library.i.isLiked(s);

          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg, const Color(0xFF0E0E0E)],
                  stops: const [0, .65],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const Spacer(),
                        const Text('NOW PLAYING', style: TextStyle(letterSpacing: 1.5, fontSize: 12)),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ]),
                      const Spacer(),
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(s.thumb, fit: BoxFit.cover),
                        ),
                      ),
                      const Spacer(),
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 26)),
                              Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 17, color: Colors.white70)),
                            ],
                          ),
                        ),
                        IconButton(
                          iconSize: 30,
                          icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                              color: liked ? kAccent : null),
                          onPressed: () => Library.i.toggle(s),
                        ),
                      ]),
                      StreamBuilder<Duration>(
                        stream: p.player.positionStream,
                        builder: (_, snap) {
                          final pos = snap.data ?? Duration.zero;
                          final total = (p.player.duration ?? Duration(seconds: s.duration)).inMilliseconds;
                          final v = pos.inMilliseconds.clamp(0, total).toDouble();
                          return Column(children: [
                            Slider(
                              value: v,
                              max: total <= 0 ? 1 : total.toDouble(),
                              onChanged: (x) => p.player.seek(Duration(milliseconds: x.toInt())),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [Text(fmt(pos.inSeconds)), Text(fmt(total ~/ 1000))],
                              ),
                            ),
                          ]);
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        IconButton(
                          icon: Icon(Icons.shuffle, color: p.shuffle ? kAccent : null),
                          onPressed: p.toggleShuffle,
                        ),
                        IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous), onPressed: p.prev),
                        GestureDetector(
                          onTap: p.toggle,
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.black)
                                : Icon(p.player.playing ? Icons.pause : Icons.play_arrow,
                                    color: Colors.black, size: 44),
                          ),
                        ),
                        IconButton(iconSize: 40, icon: const Icon(Icons.skip_next), onPressed: p.next),
                        IconButton(
                          icon: Icon(p.loop == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                              color: p.loop == LoopMode.off ? null : kAccent),
                          onPressed: p.cycleLoop,
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        PopupMenuButton<int>(
                          icon: const Icon(Icons.bedtime_outlined),
                          tooltip: 'Sleep timer',
                          onSelected: (m) => p.setSleep(m == 0 ? null : m),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 15, child: Text('15 min')),
                            PopupMenuItem(value: 30, child: Text('30 min')),
                            PopupMenuItem(value: 60, child: Text('60 min')),
                            PopupMenuItem(value: 0, child: Text('Off')),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.queue_music),
                          onPressed: () => showModalBottomSheet(
                            context: ctx,
                            backgroundColor: const Color(0xFF1A1A1A),
                            builder: (_) => SongList(PlayerService.i.queue),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
