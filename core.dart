import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kBase = 'https://nazriya.musicmine.in/api';
const kKey = 'DARK_CHOOMU'; // TODO: baad me apne backend me shift karo

// ---------- Model ----------
class Song {
  final String id, title, artist, thumb;
  final int duration;
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumb,
    required this.duration,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: (j['id'] ?? '').toString(),
        title: _clean((j['title'] ?? '').toString()),
        artist: (j['uploader'] ?? '').toString().trim(),
        thumb: (j['thumbnail'] ?? '').toString(),
        duration: (j['duration'] ?? 0) is num ? (j['duration'] as num).toInt() : 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'uploader': artist,
        'thumbnail': thumb,
        'duration': duration,
      };

  // "Maruti (Official Video) Dhanda..." -> "Maruti"
  static String _clean(String t) {
    final c = t.split(RegExp(r'[(|\[]')).first.trim();
    return c.isEmpty ? t : c;
  }
}

// ---------- API ----------
class Api {
  static Uri _u(String ep, Map<String, String> p) =>
      Uri.parse('$kBase/$ep').replace(queryParameters: {...p, 'key': kKey});

  static Future<List<Song>> _songs(String ep, Map<String, String> p) async {
    final r = await http.get(_u(ep, p));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final d = jsonDecode(r.body);
    final list = d is List ? d : (d['results'] ?? d['data'] ?? []) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .where((s) => s.duration > 0 && s.duration <= 600) // reviews/vlogs hatao
        .toList();
  }

  static Future<List<Song>> search(String q) => _songs('search', {'q': q});
  static Future<List<Song>> trending() => _songs('trending', {});

  // Response format pata nahi, isliye flexible parsing
  static Future<List<String>> suggest(String q) async {
    try {
      final r = await http.get(_u('suggest', {'q': q}));
      final d = jsonDecode(r.body);
      final list =
          d is List ? d : (d['suggestions'] ?? d['results'] ?? []) as List;
      return list
          .map((e) => e is String ? e : (e['text'] ?? e['title'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .take(8)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String audioUrl(Song s) =>
      _u('audio', {'q': '${s.title} ${s.artist}'}).toString();
}

// ---------- Player ----------
class PlayerService extends ChangeNotifier {
  PlayerService._() {
    player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed) next(auto: true);
      notifyListeners();
    });
  }
  static final i = PlayerService._();

  final player = AudioPlayer();
  List<Song> queue = [];
  int index = -1;
  bool shuffle = false;
  LoopMode loop = LoopMode.off;
  Timer? _sleep;

  Song? get current => (index >= 0 && index < queue.length) ? queue[index] : null;

  Future<void> playQueue(List<Song> songs, int start) async {
    queue = List.of(songs);
    index = start;
    notifyListeners();
    await _load();
  }

  Future<void> _load() async {
    final s = current;
    if (s == null) return;
    try {
      await player.setAudioSource(AudioSource.uri(
        Uri.parse(Api.audioUrl(s)),
        tag: MediaItem(
          id: s.id,
          title: s.title,
          artist: s.artist,
          artUri: Uri.tryParse(s.thumb),
          duration: Duration(seconds: s.duration),
        ),
      ));
      player.play();
    } catch (_) {
      // play nahi hua; UI me spinner band ho jayega
    }
  }

  Future<void> next({bool auto = false}) async {
    if (queue.isEmpty) return;
    if (auto && loop == LoopMode.one) {
      await player.seek(Duration.zero);
      player.play();
      return;
    }
    if (shuffle && queue.length > 1) {
      index = Random().nextInt(queue.length);
    } else if (index < queue.length - 1) {
      index++;
    } else if (loop == LoopMode.all) {
      index = 0;
    } else {
      return;
    }
    notifyListeners();
    await _load();
  }

  Future<void> prev() async {
    if (player.position.inSeconds > 3 || index <= 0) {
      await player.seek(Duration.zero);
      return;
    }
    index--;
    notifyListeners();
    await _load();
  }

  void toggle() => player.playing ? player.pause() : player.play();

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleLoop() {
    loop = loop == LoopMode.off
        ? LoopMode.all
        : loop == LoopMode.all
            ? LoopMode.one
            : LoopMode.off;
    notifyListeners();
  }

  void setSleep(int? minutes) {
    _sleep?.cancel();
    if (minutes != null) {
      _sleep = Timer(Duration(minutes: minutes), () => player.pause());
    }
  }
}

// ---------- Liked songs ----------
class Library extends ChangeNotifier {
  Library._();
  static final i = Library._();
  List<Song> liked = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    liked = (p.getStringList('liked') ?? [])
        .map((e) => Song.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  bool isLiked(Song s) => liked.any((x) => x.id == s.id);

  Future<void> toggle(Song s) async {
    if (isLiked(s)) {
      liked.removeWhere((x) => x.id == s.id);
    } else {
      liked.insert(0, s);
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'liked', liked.map((e) => jsonEncode(e.toJson())).toList());
  }
}
