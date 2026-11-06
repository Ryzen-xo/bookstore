import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import 'gemini_service.dart';
import 'offline_engine.dart';

/// One message in the conversation.
class ChatEntry {
  ChatEntry({
    required this.role,
    required this.text,
    this.books = const [],
    this.actions = const [],
    this.whyById = const {},
    this.online = false,
  });
  final String role; // 'user' | 'assistant'
  final String text;
  final List<Book> books;
  final List<AiAction> actions;
  final Map<int, String> whyById;
  final bool online;
}

/// Persists just the text of the conversation (no book objects, no PII).
class ChatHistoryStore {
  ChatHistoryStore._();
  static const _key = 'chatHistory';

  static Future<List<ChatEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ChatEntry(role: e['role'] as String, text: e['text'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ChatEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final slim = entries.map((e) => {'role': e.role, 'text': e.text}).toList();
    await prefs.setString(_key, jsonEncode(slim));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Orchestrates the online (Gemini) and offline (TF-IDF) engines. The offline
/// engine is always the guaranteed floor; online is a bonus when a key is set.
class ChatController extends ChangeNotifier {
  ChatController(this.state);
  final AppState state;

  final GeminiService gemini = GeminiService();
  OfflineEngine? engine;
  final List<ChatEntry> entries = [];
  bool busy = false;
  bool lastOnline = false;
  String? lastError;
  String storeFacts = '';
  bool _ready = false;

  bool get configured => gemini.configured;
  bool get ready => _ready;

  Future<void> init() async {
    if (_ready) return;
    final books = await state.repo.allBooks();
    engine = OfflineEngine(books);
    storeFacts = await _buildFacts();
    entries.addAll(await ChatHistoryStore.load());
    _ready = true;
    notifyListeners();
  }

  Future<String> _buildFacts() async {
    var facts = 'Shipping is \$2.99 under \$30 and free at \$30 or more. Returns within 14 days. Coupon STUDENT10 gives 10% off.';
    if (state.user != null) {
      final orders = await state.repo.orders(state.user!.id);
      if (orders.isNotEmpty) {
        final o = orders.first;
        // Only id / status / tracking — never name, address or card data.
        facts += ' Latest order #${o.id}: status ${o.status}, tracking ${o.trackingNo}.';
      }
    }
    return facts;
  }

  Future<List<Book>> _booksByIds(List<int> ids) async {
    final out = <Book>[];
    for (final id in ids) {
      final b = await state.repo.bookById(id);
      if (b != null) out.add(b);
    }
    return out;
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || busy || engine == null) return;

    final priorHistory = [
      for (final e in entries)
        if (e.role == 'user' || e.role == 'assistant') {'role': e.role == 'assistant' ? 'model' : 'user', 'text': e.text},
    ];

    entries.add(ChatEntry(role: 'user', text: t));
    busy = true;
    lastError = null;
    notifyListeners();

    final candidates = engine!.candidates(t, limit: 12).map((b) => b.toAiMap()).toList();

    AiReply? reply;
    if (gemini.configured) {
      reply = await gemini.ask(history: priorHistory, userText: t, candidates: candidates, storeFacts: storeFacts);
    }

    if (reply != null) {
      final books = await _booksByIds(reply.bookIds);
      entries.add(ChatEntry(role: 'assistant', text: reply.reply, books: books, actions: reply.actions, online: true));
      lastOnline = true;
    } else {
      lastError = gemini.lastError;
      final r = engine!.respond(t);
      entries.add(ChatEntry(role: 'assistant', text: r.text, books: r.books, whyById: r.whyById, online: false));
      lastOnline = false;
    }

    busy = false;
    notifyListeners();
    await ChatHistoryStore.save(entries);
  }

  Future<void> retry() async {
    if (busy) return;
    // Drop the last assistant reply and re-send the last user message.
    if (entries.isNotEmpty && entries.last.role == 'assistant') entries.removeLast();
    if (entries.isNotEmpty && entries.last.role == 'user') {
      final last = entries.removeLast();
      await send(last.text);
    } else {
      notifyListeners();
    }
  }

  Future<void> clear() async {
    entries.clear();
    engine?.reset();
    lastError = null;
    await ChatHistoryStore.clear();
    notifyListeners();
  }
}
