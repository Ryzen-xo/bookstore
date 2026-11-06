import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../orders/order_detail_page.dart';
import '../profile/address_sheet.dart';
import '../profile/payment_sheet.dart';

/// Three numbered steps: address → payment → review. Payment is simulated.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.coupon = ''});
  final String coupon;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  int _step = 0;
  List<Address> _addresses = [];
  List<PaymentMethod> _payments = [];
  List<CartLine> _lines = [];
  Address? _address;
  PaymentMethod? _payment;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppStateScope.read(context);
    final addresses = await state.repo.addresses(state.user!.id);
    final payments = await state.repo.paymentMethods(state.user!.id);
    final lines = await state.repo.cart(state.user!.id);
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _payments = payments;
      _lines = lines;
      _address = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.isNotEmpty ? addresses.first : Address(id: 0, userId: 0, label: '', fullName: '', line1: '', city: '', region: '', postalCode: '', country: '', phone: ''));
      _payment = payments.isNotEmpty ? payments.firstWhere((p) => p.isDefault, orElse: () => payments.first) : null;
      if (_address!.id == 0) _address = null;
      _loading = false;
    });
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  Future<void> _addAddress() async {
    final state = AppStateScope.read(context);
    final saved = await showFolioSheet<bool>(context, child: AddressSheet(userId: state.user!.id));
    if (saved == true) await _load();
  }

  Future<void> _addPayment() async {
    final state = AppStateScope.read(context);
    final saved = await showFolioSheet<bool>(context, child: PaymentSheet(userId: state.user!.id));
    if (saved == true) await _load();
  }

  Future<void> _placeOrder() async {
    if (_address == null) {
      showToast(context, 'Please add a delivery address.');
      setState(() => _step = 0);
      return;
    }
    if (_payment == null) {
      showToast(context, 'Please add a payment method.');
      setState(() => _step = 1);
      return;
    }
    setState(() => _busy = true);
    final state = AppStateScope.read(context);
    try {
      final orderId = await state.repo.placeOrder(
        userId: state.user!.id,
        shipName: _address!.fullName,
        address: _address!,
        paymentLabel: _payment!.label,
        coupon: widget.coupon,
      );
      await state.refreshCart();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderSuccessPage(orderId: orderId)));
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
    if (_loading) return const FolioPage(title: 'Checkout', body: Center(child: Padding(padding: EdgeInsets.all(48), child: ThinkingDots())));
    final total = Pricing.total(_subtotal, widget.coupon);
    return FolioPage(
      title: 'Checkout',
      kicker: 'Step ${_step + 1} of 3',
      bottom: Container(
        decoration: BoxDecoration(color: f.card, border: Border(top: BorderSide(color: f.rule))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FolioButton(
              label: _step < 2 ? 'Continue' : (_busy ? 'Placing order…' : 'Place order · ${money(total)}'),
              style: FolioButtonStyle.accent,
              expand: true,
              onPressed: _busy ? null : () {
                if (_step < 2) {
                  setState(() => _step++);
                } else {
                  _placeOrder();
                }
              },
            ),
          ),
        ),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _steps(context),
        const SizedBox(height: 24),
        if (_step == 0) _addressStep(context),
        if (_step == 1) _paymentStep(context),
        if (_step == 2) _reviewStep(context, total),
      ]),
    );
  }

  Widget _steps(BuildContext context) {
    final f = context.f;
    const labels = ['Address', 'Payment', 'Review'];
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        Expanded(child: Column(children: [
          Container(
            width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(color: i <= _step ? f.accent : f.rule, shape: BoxShape.circle),
            child: Text('${i + 1}', style: TextStyle(color: i <= _step ? Colors.white : f.muted, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(labels[i], style: FolioText.caption(context).copyWith(color: i <= _step ? f.ink : f.muted)),
        ])),
        if (i < 2) Expanded(child: Container(height: 1, color: f.rule, margin: const EdgeInsets.only(bottom: 20))),
      ],
    ]);
  }

  Widget _addressStep(BuildContext context) {
    final f = context.f;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Delivery address', style: FolioText.h2(context)),
      const SizedBox(height: 16),
      ..._addresses.map((a) => _selectTile(context, selected: _address?.id == a.id, onTap: () => setState(() => _address = a), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.label} · ${a.fullName}', style: FolioText.title(context)),
            const SizedBox(height: 4),
            Text(a.oneLine, style: FolioText.bodySmall(context).copyWith(color: f.muted)),
          ]))),
      const SizedBox(height: 12),
      FolioButton(label: 'Add new address', icon: Icons.add, style: FolioButtonStyle.outline, onPressed: _addAddress),
    ]);
  }

  Widget _paymentStep(BuildContext context) {
    final f = context.f;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Payment method', style: FolioText.h2(context)),
      const SizedBox(height: 8),
      Text('This is a simulated payment. We store only the brand, last 4 digits and expiry — never the full card number or CVV.', style: FolioText.caption(context)),
      const SizedBox(height: 16),
      ..._payments.map((p) => _selectTile(context, selected: _payment?.id == p.id, onTap: () => setState(() => _payment = p), child: Row(children: [
            Icon(Icons.credit_card, color: f.ink),
            const SizedBox(width: 12),
            Expanded(child: Text(p.label, style: FolioText.title(context))),
            Text('exp ${p.expiry}', style: FolioText.caption(context)),
          ]))),
      const SizedBox(height: 12),
      FolioButton(label: 'Add payment method', icon: Icons.add, style: FolioButtonStyle.outline, onPressed: _addPayment),
    ]);
  }

  Widget _reviewStep(BuildContext context, double total) {
    final f = context.f;
    final discount = Pricing.discount(_subtotal, widget.coupon);
    final shipping = Pricing.shipping(_subtotal);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Review your order', style: FolioText.h2(context)),
      const SizedBox(height: 16),
      ..._lines.map((l) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            Expanded(child: Text('${l.qty} × ${l.book.title}', style: FolioText.bodySmall(context))),
            Text(money(l.lineTotal), style: FolioText.bodySmall(context)),
          ]))),
      const FolioDivider(),
      const SizedBox(height: 8),
      _sumRow(context, 'Subtotal', money(_subtotal)),
      if (discount > 0) _sumRow(context, 'Discount', '−${money(discount)}', color: f.success),
      _sumRow(context, 'Shipping', shipping == 0 ? 'Free' : money(shipping)),
      _sumRow(context, 'Total', money(total), bold: true, color: f.accent),
      const SizedBox(height: 16),
      if (_address != null) Text('Ship to: ${_address!.fullName}, ${_address!.oneLine}', style: FolioText.caption(context)),
      if (_payment != null) Text('Pay with: ${_payment!.label}', style: FolioText.caption(context)),
    ]);
  }

  Widget _sumRow(BuildContext context, String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label, style: (bold ? FolioText.title(context) : FolioText.bodySmall(context)).copyWith(color: color)),
          const Spacer(),
          Text(value, style: (bold ? FolioText.title(context) : FolioText.bodySmall(context)).copyWith(color: color)),
        ]),
      );

  Widget _selectTile(BuildContext context, {required bool selected, required VoidCallback onTap, required Widget child}) {
    final f = context.f;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tappable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: f.card, border: Border.all(color: selected ? f.accent : f.rule, width: selected ? 1.6 : 1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? f.accent : f.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }
}

/// The order-success stamp.
class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({super.key, required this.orderId});
  final int orderId;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      showBack: false,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 40),
          Transform.rotate(
            angle: -0.08,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(border: Border.all(color: f.success, width: 3), borderRadius: BorderRadius.circular(12)),
              child: Text('ORDER PLACED', style: TextStyle(fontFamily: 'sans-serif', fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: f.success)),
            ),
          ),
          const SizedBox(height: 28),
          Text('Thank you!', style: FolioText.h1(context)),
          const SizedBox(height: 8),
          Text('Order #$orderId is confirmed. A tracking number has been generated.', style: FolioText.body(context).copyWith(color: f.muted), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          FolioButton(label: 'Track my order', icon: Icons.local_shipping_outlined, style: FolioButtonStyle.accent, expand: true, onPressed: () {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: orderId)));
          }),
          const SizedBox(height: 12),
          FolioButton(label: 'Back to shop', style: FolioButtonStyle.outline, expand: true, onPressed: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
          }),
        ]),
      ),
    );
  }
}
