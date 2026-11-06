import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';

/// A clean, printable-style invoice.
class InvoicePage extends StatelessWidget {
  const InvoicePage({super.key, required this.detail});
  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final d = detail;
    return FolioPage(
      title: 'Invoice',
      kicker: 'Order #${d.order.id}',
      body: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: f.surface, border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: f.ink, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.menu_book_rounded, color: f.paper, size: 22)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Shelf', style: FolioText.h2(context)),
              Text('The editorial bookshop', style: FolioText.caption(context)),
            ]),
            const Spacer(),
            StampBadge(d.order.status, color: d.order.status == 'Cancelled' ? f.danger : f.success),
          ]),
          const SizedBox(height: 20),
          const FolioDivider(),
          const SizedBox(height: 16),
          _meta(context, 'Invoice no.', 'INV-${d.order.id.toString().padLeft(5, '0')}'),
          _meta(context, 'Date', niceDate(d.order.createdAt)),
          _meta(context, 'Tracking', d.order.trackingNo),
          _meta(context, 'Payment', d.payment),
          const SizedBox(height: 16),
          Text('BILL TO', style: FolioText.label(context)),
          const SizedBox(height: 4),
          Text('${d.shipName}\n${d.shipLine1}, ${d.shipCity}', style: FolioText.bodySmall(context)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(flex: 3, child: Text('ITEM', style: FolioText.label(context))),
            Expanded(child: Text('QTY', style: FolioText.label(context), textAlign: TextAlign.center)),
            Expanded(child: Text('PRICE', style: FolioText.label(context), textAlign: TextAlign.right)),
            Expanded(child: Text('TOTAL', style: FolioText.label(context), textAlign: TextAlign.right)),
          ]),
          const SizedBox(height: 8),
          const FolioDivider(),
          for (final it in d.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(flex: 3, child: Text(it.title, style: FolioText.bodySmall(context))),
                Expanded(child: Text('${it.qty}', style: FolioText.bodySmall(context), textAlign: TextAlign.center)),
                Expanded(child: Text(money(it.unitPrice), style: FolioText.bodySmall(context), textAlign: TextAlign.right)),
                Expanded(child: Text(money(it.lineTotal), style: FolioText.bodySmall(context), textAlign: TextAlign.right)),
              ]),
            ),
          const FolioDivider(),
          const SizedBox(height: 12),
          _total(context, 'Subtotal', money(d.subtotal)),
          if (d.adjustment.abs() > 0.001) _total(context, 'Discount / shipping', money(d.adjustment)),
          const SizedBox(height: 6),
          _total(context, 'Total paid', money(d.order.total), bold: true, color: f.accent),
          const SizedBox(height: 24),
          Center(child: Text('Thank you for reading with Shelf.', style: FolioText.italic(context))),
          const SizedBox(height: 4),
          Center(child: Text('This is a simulated invoice for a demo project — no real payment was taken.', style: FolioText.caption(context), textAlign: TextAlign.center)),
        ]),
      ),
    );
  }

  Widget _meta(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 110, child: Text(label, style: FolioText.caption(context))),
          Expanded(child: Text(value, style: FolioText.bodySmall(context))),
        ]),
      );

  Widget _total(BuildContext context, String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const Spacer(),
          Text('$label  ', style: (bold ? FolioText.title(context) : FolioText.bodySmall(context)).copyWith(color: color)),
          Text(value, style: (bold ? FolioText.title(context) : FolioText.bodySmall(context)).copyWith(color: color)),
        ]),
      );
}
