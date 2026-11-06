import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import 'chat_controller.dart';
import 'gemini_service.dart';

/// The AI Librarian chat. Works offline; goes online when a key is configured.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  ChatController? _controller;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _prompts = [
    'Something cozy under \$12',
    'Short sci-fi for a commute',
    'A bestseller to get me reading again',
    'Books like Dune',
    'An inspiring biography',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final state = AppStateScope.read(context);
    final c = ChatController(state);
    await c.init();
    if (!mounted) return;
    setState(() => _controller = c);
    final prefill = state.consumeChatPrefill();
    if (prefill != null && prefill.isNotEmpty) {
      _input.text = prefill;
      _send();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _controller?.send(text);
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _act(AiAction action) async {
    final state = AppStateScope.read(context);
    final book = await state.repo.bookById(action.bookId);
    if (book == null || !mounted) return;
    final isCart = action.type == 'add_to_cart';
    final ok = await confirmDialog(
      context,
      title: isCart ? 'Add to cart?' : 'Save to reading list?',
      message: '${isCart ? 'Add' : 'Save'} “${book.title}” (${money(book.price)})${isCart ? ' to your cart' : ' to your reading list'}?',
      confirmLabel: isCart ? 'Add to cart' : 'Save',
    );
    if (!ok || !mounted) return;
    if (!requireLogin(context)) return;
    try {
      if (isCart) {
        await state.addToCart(book.id);
      } else {
        await state.toggleWishlist(book.id);
      }
      if (!mounted) return;
      showToast(context, isCart ? 'Added to cart.' : 'Saved to your reading list.');
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final c = _controller;
    return Column(
      children: [
        // Header.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('THE LIBRARIAN', style: FolioText.label(context)),
              Text('Ask for your next read', style: FolioText.h2(context)),
            ])),
            _modeTag(context, c),
            const SizedBox(width: 8),
            FolioIconButton(icon: Icons.delete_outline, label: 'Clear chat', onTap: () async {
              final ok = await confirmDialog(context, title: 'Clear conversation?', message: 'This removes the chat history on this device.', confirmLabel: 'Clear', danger: true);
              if (ok) await c?.clear();
            }),
          ]),
        ),
        const FolioDivider(),
        // Messages.
        Expanded(
          child: c == null || !c.ready
              ? const Center(child: ThinkingDots())
              : c.entries.isEmpty
                  ? _empty(context)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      itemCount: c.entries.length + (c.busy ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == c.entries.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: ThinkingDots());
                        return _bubble(context, c.entries[i]);
                      },
                    ),
        ),
        // Error / retry.
        if (c != null && c.lastError != null && !c.lastOnline)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: Text('Offline answer shown. ${c.lastError}', style: FolioText.caption(context), maxLines: 2, overflow: TextOverflow.ellipsis)),
              TextButton(onPressed: c.busy ? null : () { c.retry(); _scrollDown(); }, child: Text('Retry online', style: TextStyle(color: f.accent))),
            ]),
          ),
        // Input.
        Container(
          decoration: BoxDecoration(color: f.card, border: Border(top: BorderSide(color: f.rule))),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(
            top: false,
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    style: FolioText.body(context),
                    cursorColor: f.accent,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask the librarian…',
                      hintStyle: FolioText.italic(context).copyWith(color: f.faint),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: f.rule), borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: f.accent), borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tappable(
                  onTap: c == null || c.busy ? null : _send,
                  semanticLabel: 'Send',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: f.accent, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text('Recommendations can be wrong. Prices and stock always come from the store. No personal data is sent.', style: FolioText.caption(context), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _modeTag(BuildContext context, ChatController? c) {
    final f = context.f;
    String label;
    Color color;
    if (c != null && c.busy) {
      label = 'THINKING';
      color = f.gold;
    } else if (c != null && c.configured && c.lastOnline) {
      label = 'ONLINE · GEMINI';
      color = f.success;
    } else {
      label = 'OFFLINE MODE';
      color = f.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontFamily: 'sans-serif', fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: color)),
    );
  }

  Widget _empty(BuildContext context) {
    final f = context.f;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        Icon(Icons.auto_awesome, size: 40, color: f.accent),
        const SizedBox(height: 16),
        Text('Hello, I’m your Shelf librarian.', style: FolioText.h2(context), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Tell me a mood, a genre, a budget or a book you loved. I’ll find your next read — even with no internet.', style: FolioText.body(context).copyWith(color: f.muted), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ..._prompts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tappable(
                onTap: () { _input.text = p; _send(); },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: f.card, border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(12)),
                  child: Text(p, style: FolioText.bodySmall(context)),
                ),
              ),
            )),
      ],
    );
  }

  Widget _bubble(BuildContext context, ChatEntry e) {
    final f = context.f;
    final isUser = e.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? f.ink : f.card,
                borderRadius: BorderRadius.circular(14),
                border: isUser ? null : Border.all(color: f.rule),
              ),
              child: isUser
                  ? Text(e.text, style: FolioText.body(context).copyWith(color: f.paper))
                  : TypewriterText(e.text, style: FolioText.body(context)),
            ),
            if (e.books.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 270,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: e.books.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    final b = e.books[i];
                    return SizedBox(
                      width: 140,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: BookCard(book: b, heroEnabled: false)),
                        if (e.whyById[b.id] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.whyById[b.id]!, style: FolioText.caption(context), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ]),
                    );
                  },
                ),
              ),
            ],
            if (e.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in e.actions)
                    FolioButton(
                      label: a.type == 'add_to_cart' ? 'Add to cart' : 'Save to list',
                      icon: a.type == 'add_to_cart' ? Icons.add_shopping_cart : Icons.bookmark_add_outlined,
                      style: FolioButtonStyle.outline,
                      onPressed: () => _act(a),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
