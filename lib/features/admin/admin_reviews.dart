import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Admin: moderate reviews across all books.
class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});
  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  List<(Book, Review)> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AppStateScope.read(context).repo;
    final books = await repo.allBooks();
    final all = <(Book, Review)>[];
    for (final b in books) {
      final rs = await repo.reviews(b.id, null);
      for (final r in rs) {
        all.add((b, r));
      }
    }
    all.sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    if (!mounted) return;
    setState(() {
      _reviews = all;
      _loading = false;
    });
  }

  Future<void> _delete(Review r) async {
    final ok = await confirmDialog(context, title: 'Delete review?', message: 'Remove this review by ${r.userName}?', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await AppStateScope.read(context).repo.deleteReview(r.id);
    await _load();
    if (!mounted) return;
    showToast(context, 'Review deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: 'Reviews',
      kicker: 'Admin',
      body: _loading
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()))
          : Column(children: [
              Text('${_reviews.length} reviews', style: FolioText.caption(context)),
              const SizedBox(height: 12),
              for (final pair in _reviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PaperCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(pair.$1.title, style: FolioText.title(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        StarRating(value: pair.$2.rating.toDouble(), size: 14),
                      ]),
                      const SizedBox(height: 6),
                      Text(pair.$2.body, style: FolioText.bodySmall(context)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('${pair.$2.userName} · ${niceDate(pair.$2.createdAt)}', style: FolioText.caption(context)),
                        const Spacer(),
                        Tappable(onTap: () => _delete(pair.$2), semanticLabel: 'Delete review', child: Icon(Icons.delete_outline, size: 19, color: f.danger)),
                      ]),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
