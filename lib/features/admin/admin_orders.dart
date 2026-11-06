import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../orders/orders_page.dart';

/// Admin: view all orders and change status.
class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});
  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  List<OrderSummary> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await AppStateScope.read(context).repo.allOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _setStatus(OrderSummary o, String status) async {
    try {
      await AppStateScope.read(context).repo.setOrderStatus(o.id, status);
      await _load();
      if (!mounted) return;
      showToast(context, 'Order #${o.id} → $status.');
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    }
  }

  Future<void> _advance(OrderSummary o) async {
    try {
      await AppStateScope.read(context).repo.advanceOrder(o.id);
      await _load();
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FolioPage(
      title: 'Orders',
      kicker: 'Admin',
      body: _loading
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()))
          : _orders.isEmpty
              ? EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders', message: 'Orders will appear here as customers place them.')
              : Column(children: [
                  for (final o in _orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PaperCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('Order #${o.id}', style: FolioText.title(context))),
                            orderStatusChip(context, o.status),
                          ]),
                          const SizedBox(height: 4),
                          Text('${niceDate(o.createdAt)} · ${money(o.total)} · ${o.trackingNo}', style: FolioText.caption(context)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            if (o.status != 'Delivered' && o.status != 'Cancelled')
                              FolioButton(label: 'Advance', icon: Icons.fast_forward, style: FolioButtonStyle.ink, onPressed: () => _advance(o)),
                            for (final s in kAllStatuses)
                              if (s != o.status)
                                FolioChip(label: s, onTap: () => _setStatus(o, s)),
                          ]),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}
