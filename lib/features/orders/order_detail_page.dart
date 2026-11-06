import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import 'invoice_page.dart';
import 'orders_page.dart';

/// Order tracking timeline, items, cancel and invoice.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  OrderDetail? _detail;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await AppStateScope.read(context).repo.orderDetail(widget.orderId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(context, title: 'Cancel order?', message: 'This will cancel order #${widget.orderId} and restore stock.', confirmLabel: 'Cancel order', danger: true);
    if (!ok) return;
    setState(() => _busy = true);
    final state = AppStateScope.read(context);
    try {
      await state.repo.cancelOrder(state.user!.id, widget.orderId);
      await _load();
      if (!mounted) return;
      showToast(context, 'Order cancelled.');
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance() async {
    setState(() => _busy = true);
    try {
      await AppStateScope.read(context).repo.advanceOrder(widget.orderId);
      await _load();
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final state = AppStateScope.of(context);
    if (_loading) return const FolioPage(title: 'Order', body: Center(child: Padding(padding: EdgeInsets.all(48), child: ThinkingDots())));
    final d = _detail;
    if (d == null) return FolioPage(title: 'Order', body: EmptyState(icon: Icons.receipt_long_outlined, title: 'Not found', message: 'This order could not be loaded.'));
    final canCancel = d.order.status == 'Placed' || d.order.status == 'Processing';
    return FolioPage(
      title: 'Order #${d.order.id}',
      kicker: d.order.trackingNo,
      actions: [IconButton(icon: Icon(Icons.receipt_outlined, color: f.ink), onPressed: () => pushPage(context, InvoicePage(detail: d)))],
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          orderStatusChip(context, d.order.status),
          const Spacer(),
          Text(money(d.order.total), style: FolioText.h3(context).copyWith(color: f.accent)),
        ]),
        const SizedBox(height: 6),
        Text('Placed ${niceDateTime(d.order.createdAt)}', style: FolioText.caption(context)),
        const SizedBox(height: 24),
        Text('TRACKING', style: FolioText.label(context)),
        const SizedBox(height: 12),
        _timeline(context, d),
        const SizedBox(height: 24),
        Text('ITEMS', style: FolioText.label(context)),
        const SizedBox(height: 12),
        ...d.items.map((it) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
              Expanded(child: Text('${it.qty} × ${it.title}', style: FolioText.bodySmall(context))),
              Text(money(it.lineTotal), style: FolioText.bodySmall(context)),
            ]))),
        const FolioDivider(),
        const SizedBox(height: 8),
        Row(children: [Text('Subtotal', style: FolioText.bodySmall(context)), const Spacer(), Text(money(d.subtotal), style: FolioText.bodySmall(context))]),
        if (d.adjustment.abs() > 0.001)
          Row(children: [Text('Discount / shipping', style: FolioText.bodySmall(context)), const Spacer(), Text(money(d.adjustment), style: FolioText.bodySmall(context))]),
        Row(children: [Text('Total', style: FolioText.title(context)), const Spacer(), Text(money(d.order.total), style: FolioText.title(context).copyWith(color: f.accent))]),
        const SizedBox(height: 20),
        Text('DELIVERY', style: FolioText.label(context)),
        const SizedBox(height: 6),
        Text('${d.shipName}\n${d.shipLine1}, ${d.shipCity}\n${d.payment}', style: FolioText.bodySmall(context)),
        const SizedBox(height: 24),
        if (canCancel)
          FolioButton(label: _busy ? 'Working…' : 'Cancel order', style: FolioButtonStyle.outline, expand: true, onPressed: _busy ? null : _cancel),
        if (state.demoTools && d.order.status != 'Delivered' && d.order.status != 'Cancelled') ...[
          const SizedBox(height: 12),
          FolioButton(label: 'Demo: advance status', icon: Icons.fast_forward, style: FolioButtonStyle.ink, expand: true, onPressed: _busy ? null : _advance),
        ],
      ]),
    );
  }

  Widget _timeline(BuildContext context, OrderDetail d) {
    final doneStatuses = d.events.map((e) => e.status).toSet();
    final cancelled = d.order.status == 'Cancelled';
    final flow = cancelled ? [...kOrderFlow.where((s) => doneStatuses.contains(s)), 'Cancelled'] : kOrderFlow;
    return Column(
      children: [
        for (var i = 0; i < flow.length; i++)
          _timelineRow(context, flow[i], doneStatuses.contains(flow[i]), i == flow.length - 1, d.events.where((e) => e.status == flow[i]).firstOrNull, cancelled && flow[i] == 'Cancelled'),
      ],
    );
  }

  Widget _timelineRow(BuildContext context, String status, bool done, bool last, OrderEvent? event, bool isCancel) {
    final f = context.f;
    final color = isCancel ? f.danger : (done ? f.success : f.rule);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(color: done ? color : f.card, border: Border.all(color: color, width: 2), shape: BoxShape.circle), child: done ? Icon(Icons.check, size: 11, color: f.paper) : null),
        if (!last) Container(width: 2, height: 40, color: done ? color : f.rule),
      ]),
      const SizedBox(width: 14),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(status, style: FolioText.title(context).copyWith(color: done ? f.ink : f.muted)),
          if (event != null) ...[
            const SizedBox(height: 2),
            Text(event.note, style: FolioText.caption(context)),
            Text(niceDateTime(event.at), style: FolioText.caption(context).copyWith(color: f.faint)),
          ],
        ]),
      )),
    ]);
  }
}
