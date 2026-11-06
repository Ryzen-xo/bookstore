import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Add or edit a delivery address. Pops `true` on save.
class AddressSheet extends StatefulWidget {
  const AddressSheet({super.key, required this.userId, this.existing});
  final int userId;
  final Address? existing;
  @override
  State<AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<AddressSheet> {
  late final _label = TextEditingController(text: widget.existing?.label ?? 'Home');
  late final _name = TextEditingController(text: widget.existing?.fullName ?? '');
  late final _line1 = TextEditingController(text: widget.existing?.line1 ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _region = TextEditingController(text: widget.existing?.region ?? '');
  late final _postal = TextEditingController(text: widget.existing?.postalCode ?? '');
  late final _country = TextEditingController(text: widget.existing?.country ?? 'Pakistan');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late bool _default = widget.existing?.isDefault ?? true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_label, _name, _line1, _city, _region, _postal, _country, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _line1.text.trim().isEmpty || _city.text.trim().isEmpty) {
      showToast(context, 'Please fill in name, street and city.');
      return;
    }
    setState(() => _busy = true);
    final state = AppStateScope.read(context);
    final address = Address(
      id: widget.existing?.id ?? 0, userId: widget.userId, label: _label.text.trim(), fullName: _name.text.trim(),
      line1: _line1.text.trim(), city: _city.text.trim(), region: _region.text.trim(), postalCode: _postal.text.trim(),
      country: _country.text.trim(), phone: _phone.text.trim(), isDefault: _default,
    );
    await state.repo.saveAddress(widget.userId, address, id: widget.existing?.id);
    if (!mounted) return;
    showToast(context, 'Address saved.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(widget.existing == null ? 'Add address' : 'Edit address', style: FolioText.h2(context)),
      const SizedBox(height: 16),
      FolioField(controller: _label, label: 'Label', hint: 'Home / Work'),
      const SizedBox(height: 14),
      FolioField(controller: _name, label: 'Full name', hint: 'Recipient name'),
      const SizedBox(height: 14),
      FolioField(controller: _line1, label: 'Street address', hint: 'House, street, area'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: FolioField(controller: _city, label: 'City', hint: 'Karachi')),
        const SizedBox(width: 12),
        Expanded(child: FolioField(controller: _region, label: 'Region', hint: 'Sindh')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: FolioField(controller: _postal, label: 'Postal code', hint: '75600', keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: FolioField(controller: _country, label: 'Country', hint: 'Pakistan')),
      ]),
      const SizedBox(height: 14),
      FolioField(controller: _phone, label: 'Phone', hint: '+92 300 1234567', keyboardType: TextInputType.phone),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: context.f.accent,
        title: Text('Set as default', style: FolioText.body(context)),
        value: _default,
        onChanged: (v) => setState(() => _default = v),
      ),
      const SizedBox(height: 12),
      FolioButton(label: _busy ? 'Saving…' : 'Save address', style: FolioButtonStyle.accent, expand: true, onPressed: _busy ? null : _save),
    ]);
  }
}
