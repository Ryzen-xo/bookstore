import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../checkout/checkout_page.dart';

/// The cart, styled as a paper receipt.
class CartPage extends StatefulWidget {
  const CartPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartLine> _lines = [];
  final _coupon = TextEditingController();
  String _applied = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppStateScope.read(context);
    if (state.user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final lines = await state.repo.cart(state.user!.id);
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  Future<void> _qty(CartLine line, int delta) async {
    final state = AppStateScope.read(context);
    final newQty = line.qty + delta;
    try {
      await state.repo.setCartQty(state.user!.id, line.book.id, newQty);
      await state.refreshCart();
      await _load();
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    }
  }

  Future<void> _remove(CartLine line) async {
    final state = AppStateScope.read(context);
    await state.repo.removeFromCart(state.user!.id, line.book.id);
    await state.refreshCart();
    await _load();
  }

  void _applyCoupon() {
    final code = _coupon.text.trim().toUpperCase();
    if (code == 'STUDENT10') {
      setState(() => _applied = code);
      showToast(context, 'STUDENT10 applied — 10% off.');
    } else {
      showToast(context, 'That coupon is not valid. Try STUDENT10.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    Widget content;
    if (_loading) {
      content = const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()));
    } else if (!state.loggedIn) {
      content = EmptyState(icon: Icons.shopping_bag_outlined, title: 'Your cart awaits', message: 'Sign in to start adding books.', action: FolioButton(label: 'Sign in', style: FolioButtonStyle.accent, onPressed: () => state.openLogin()));
    } else if (_lines.isEmpty) {
      content = EmptyState(icon: Icons.shopping_bag_outlined, title: 'Your cart is empty', message: 'Browse the shop and add a few good books.', action: FolioButton(label: 'Browse books', style: FolioButtonStyle.accent, onPressed: () => state.setShellIndex(1)));
    } else {
      final discount = Pricing.discount(_subtotal, _applied);
      final shipping = Pricing.shipping(_subtotal);
      final total = Pricing.total(_subtotal, _applied);
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your cart', style: FolioText.h1(context)),
        const SizedBox(height: 4),
        Text('${_lines.length} ${_lines.length == 1 ? 'title' : 'titles'}', style: FolioText.caption(context)),
        const SizedBox(height: 20),
        ..._lines.map((l) => _line(context, l)),
        const SizedBox(height: 16),
        // Coupon.
        Row(children: [
          Expanded(child: FolioField(controller: _coupon, label: 'Coupon code', hint: 'STUDENT10')),
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 18), child: FolioButton(label: 'Apply', style: FolioButtonStyle.outline, onPressed: _applyCoupon)),
        ]),
        const SizedBox(height: 20),
        _receipt(context, discount, shipping, total),
        const SizedBox(height: 20),
        FolioButton(label: 'Checkout · ${money(total)}', icon: Icons.arrow_forward, style: FolioButtonStyle.accent, expand: true, onPressed: () async {
          final placed = await pushPage<bool>(context, CheckoutPage(coupon: _applied));
          if (placed == true) {
            _applied = '';
            _coupon.clear();
            await _load();
          }
        }),
      ]);
    }

    if (widget.embedded) {
      return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), child: ContentWidth(child: content));
    }
    return FolioPage(title: 'Cart', kicker: 'Shelf', body: content);
  }

  Widget _line(BuildContext context, CartLine l) {
    final f = context.f;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CoverArt(color: l.book.color(), title: l.book.title, author: l.book.author, width: 54),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.book.title, style: FolioText.title(context), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(l.book.author, style: FolioText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _stepper(context, l),
            Text(money(l.lineTotal), style: FolioText.title(context).copyWith(color: f.accent)),
            Tappable(onTap: () => _remove(l), semanticLabel: 'Remove', child: Icon(Icons.delete_outline, size: 20, color: f.muted)),
          ]),
        ])),
      ]),
    );
  }

  Widget _stepper(BuildContext context, CartLine l) {
    final f = context.f;
    Widget btn(IconData icon, VoidCallback onTap) => Tappable(
          onTap: onTap,
          child: Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: f.ink)),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, () => _qty(l, -1)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${l.qty}', style: FolioText.title(context))),
        btn(Icons.add, () => _qty(l, 1)),
      ]),
    );
  }

  Widget _receipt(BuildContext context, double discount, double shipping, double total) {
    final f = context.f;
    Widget row(String label, String value, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(label, style: (bold ? FolioText.title(context) : FolioText.bodySmall(context)).copyWith(color: color)),
            const Spacer(),
            Text(value, style: (bold ? FolioText.title(context) : FolioText.bodySmall(context)).copyWith(color: color)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: f.surface, border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        row('Subtotal', money(_subtotal)),
        if (discount > 0) row('Discount (STUDENT10)', '−${money(discount)}', color: f.success),
        row('Shipping', shipping == 0 ? 'Free' : money(shipping)),
        const FolioDivider(),
        const SizedBox(height: 4),
        row('Total', money(total), bold: true, color: f.accent),
      ]),
    );
  }
}
