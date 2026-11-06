import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Add a simulated card. We capture ONLY brand, last 4 and expiry — the full
/// number and CVV fields are deliberately not stored (CVV is never even asked).
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.userId});
  final int userId;
  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _number = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  String _brand = 'Visa';
  bool _busy = false;

  @override
  void dispose() {
    _number.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12) {
      showToast(context, 'Enter a card number (we keep only the last 4 digits).');
      return;
    }
    final last4 = digits.substring(digits.length - 4);
    final month = int.tryParse(_month.text.trim()) ?? 0;
    final yearRaw = int.tryParse(_year.text.trim()) ?? 0;
    final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
    if (month < 1 || month > 12 || year < 2024) {
      showToast(context, 'Enter a valid expiry month and year.');
      return;
    }
    setState(() => _busy = true);
    final state = AppStateScope.read(context);
    try {
      // Only brand + last4 + expiry are persisted. The full number is discarded.
      await state.repo.savePaymentMethod(widget.userId, brand: _brand, last4: last4, expMonth: month, expYear: year, isDefault: true);
      if (!mounted) return;
      showToast(context, 'Card saved (last 4 only).');
      Navigator.of(context).pop(true);
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Add payment method', style: FolioText.h2(context)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: f.accentSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.shield_outlined, color: f.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Simulated payment. We never store your full card number or CVV — only the brand, last 4 digits and expiry.', style: FolioText.caption(context))),
        ]),
      ),
      const SizedBox(height: 16),
      Text('CARD BRAND', style: FolioText.label(context)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final b in ['Visa', 'Mastercard', 'Amex'])
          FolioChip(label: b, selected: _brand == b, onTap: () => setState(() => _brand = b)),
      ]),
      const SizedBox(height: 16),
      FolioField(controller: _number, label: 'Card number', hint: '4242 4242 4242 4242', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19)]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: FolioField(controller: _month, label: 'Exp month', hint: '12', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)])),
        const SizedBox(width: 12),
        Expanded(child: FolioField(controller: _year, label: 'Exp year', hint: '29', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)])),
      ]),
      const SizedBox(height: 20),
      FolioButton(label: _busy ? 'Saving…' : 'Save card', style: FolioButtonStyle.accent, expand: true, onPressed: _busy ? null : _save),
    ]);
  }
}
