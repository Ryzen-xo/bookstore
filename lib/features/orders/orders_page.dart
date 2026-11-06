import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import 'order_detail_page.dart';

/// Order history.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<OrderSummary> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppStateScope.read(context);
    final orders = state.user == null ? <OrderSummary>[] : await state.repo.orders(state.user!.id);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: 'My orders',
      kicker: 'Shelf',
      body: _loading
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()))
          : _orders.isEmpty
              ? EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'When you place an order it will appear here with live tracking.')
              : Column(children: [
                  for (final o in _orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PaperCard(
                        onTap: () => pushPage(context, OrderDetailPage(orderId: o.id)).then((_) => _load()),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Order #${o.id}', style: FolioText.title(context)),
                            const SizedBox(height: 4),
                            Text('${niceDate(o.createdAt)} · ${o.itemCount} ${o.itemCount == 1 ? 'item' : 'items'}', style: FolioText.caption(context)),
                            const SizedBox(height: 6),
                            Text(o.trackingNo, style: FolioText.mono(context).copyWith(fontSize: 11)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            _statusChip(context, o.status),
                            const SizedBox(height: 8),
                            Text(money(o.total), style: FolioText.title(context).copyWith(color: f.accent)),
                          ]),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}

Widget _statusChip(BuildContext context, String status) {
  final f = context.f;
  Color c;
  switch (status) {
    case 'Delivered':
      c = f.success;
      break;
    case 'Cancelled':
      c = f.danger;
      break;
    case 'Shipped':
    case 'Out for delivery':
      c = f.accent;
      break;
    default:
      c = f.gold;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(border: Border.all(color: c), borderRadius: BorderRadius.circular(20)),
    child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'sans-serif', fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c)),
  );
}

/// Shared status chip used by detail/admin too.
Widget orderStatusChip(BuildContext context, String status) => _statusChip(context, status);
