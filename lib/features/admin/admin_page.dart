import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import 'admin_books.dart';
import 'admin_orders.dart';
import 'admin_reviews.dart';
import 'admin_users.dart';

/// Admin dashboard. Role-guarded.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  AdminStats? _stats;
  List<Book> _low = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _guard() {
    final state = AppStateScope.read(context);
    if (!state.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showToast(context, 'Admin access only.');
          Navigator.of(context).maybePop();
        }
      });
      return false;
    }
    return true;
  }

  Future<void> _load() async {
    if (!_guard()) return;
    final repo = AppStateScope.read(context).repo;
    final stats = await repo.adminStats();
    final all = await repo.allBooks();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _low = all.where((b) => b.stock < 10).toList()..sort((a, b) => a.stock.compareTo(b.stock));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final s = _stats;
    return FolioPage(
      title: 'Back office',
      kicker: 'Admin',
      body: _loading || s == null
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                _stat(context, 'Revenue', money(s.revenue), Icons.payments_outlined, f.success),
                _stat(context, 'Orders', '${s.orders}', Icons.receipt_long_outlined, f.accent),
                _stat(context, 'Books', '${s.books}', Icons.menu_book_outlined, f.gold),
                _stat(context, 'Users', '${s.users}', Icons.people_outline, f.ink),
              ]),
              const SizedBox(height: 24),
              if (s.salesByDay.isNotEmpty) ...[
                const FolioHeader(label: 'Last 7 days', title: 'Sales'),
                const SizedBox(height: 16),
                PaperCard(child: _BarChart(entries: s.salesByDay.reversed.toList(), isMoney: true)),
                const SizedBox(height: 24),
              ],
              const FolioHeader(label: 'Manage', title: 'Back office'),
              const SizedBox(height: 12),
              _nav(context, Icons.menu_book_outlined, 'Books', 'Add, edit and remove titles', () => pushPage(context, const AdminBooksPage()).then((_) => _load())),
              _nav(context, Icons.people_outline, 'Users', 'Activate, deactivate, grant admin', () => pushPage(context, const AdminUsersPage())),
              _nav(context, Icons.local_shipping_outlined, 'Orders', 'Advance status, cancel', () => pushPage(context, const AdminOrdersPage()).then((_) => _load())),
              _nav(context, Icons.reviews_outlined, 'Reviews', 'Moderate reader reviews', () => pushPage(context, const AdminReviewsPage())),
              const SizedBox(height: 24),
              FolioHeader(label: 'Inventory', title: 'Low stock (${_low.length})'),
              const SizedBox(height: 12),
              if (_low.isEmpty)
                Text('All titles are well stocked.', style: FolioText.italic(context))
              else
                ..._low.take(8).map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(child: Text(b.title, style: FolioText.bodySmall(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        StampBadge('${b.stock} left', color: b.stock <= 5 ? f.danger : f.warning),
                      ]),
                    )),
            ]),
    );
  }

  Widget _stat(BuildContext context, String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      child: PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: FolioText.h2(context), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label.toUpperCase(), style: FolioText.label(context)),
        ]),
      ),
    );
  }

  Widget _nav(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) {
    final f = context.f;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PaperCard(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: f.accent),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: FolioText.title(context)),
            Text(sub, style: FolioText.caption(context)),
          ])),
          Icon(Icons.chevron_right, color: f.muted),
        ]),
      ),
    );
  }
}

/// A simple code-drawn bar chart.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.entries, this.isMoney = false});
  final List<MapEntry<String, double>> entries;
  final bool isMoney;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final maxV = entries.fold<double>(1, (m, e) => e.value > m ? e.value : m);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(isMoney ? '\$${e.value.toStringAsFixed(0)}' : '${e.value.toInt()}', style: FolioText.caption(context).copyWith(fontSize: 9), maxLines: 1),
                  const SizedBox(height: 4),
                  Container(height: (e.value / maxV) * 96 + 4, decoration: BoxDecoration(color: f.accent, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Text(e.key.length >= 5 ? e.key.substring(5) : e.key, style: FolioText.caption(context).copyWith(fontSize: 9), maxLines: 1),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
