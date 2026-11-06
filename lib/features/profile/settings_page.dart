import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../ai/chat_controller.dart';
import 'address_sheet.dart';
import 'payment_sheet.dart';

/// Settings, security and saved addresses / payment methods.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Address> _addresses = [];
  List<PaymentMethod> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppStateScope.read(context);
    if (state.user == null) return;
    final a = await state.repo.addresses(state.user!.id);
    final p = await state.repo.paymentMethods(state.user!.id);
    if (!mounted) return;
    setState(() {
      _addresses = a;
      _payments = p;
    });
  }

  Future<void> _changePassword() async {
    final old = TextEditingController();
    final next = TextEditingController();
    final ok = await showFolioSheet<bool>(context, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Change password', style: FolioText.h2(context)),
      const SizedBox(height: 16),
      FolioField(controller: old, label: 'Current password', obscure: true),
      const SizedBox(height: 14),
      FolioField(controller: next, label: 'New password', obscure: true, hint: '8+ chars, a letter and a number'),
      const SizedBox(height: 20),
      FolioButton(label: 'Update password', style: FolioButtonStyle.accent, expand: true, onPressed: () => Navigator.of(context).pop(true)),
    ]));
    if (ok == true && mounted) {
      final state = AppStateScope.read(context);
      try {
        await state.repo.changePassword(state.user!.id, old.text, next.text);
        if (!mounted) return;
        showToast(context, 'Password updated.');
      } on AppError catch (e) {
        if (!mounted) return;
        showToast(context, e.message);
      }
    }
    old.dispose();
    next.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final state = AppStateScope.of(context);
    return FolioPage(
      title: 'Settings',
      kicker: 'Account',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('APPEARANCE', style: FolioText.label(context)),
        const SizedBox(height: 8),
        PaperCard(
          child: Row(children: [
            Icon(Icons.dark_mode_outlined, color: f.ink),
            const SizedBox(width: 12),
            Expanded(child: Text('Night reading mode', style: FolioText.body(context))),
            Switch(value: state.themeMode == ThemeMode.dark, activeColor: f.accent, onChanged: (v) => state.setTheme(v ? ThemeMode.dark : ThemeMode.light)),
          ]),
        ),
        const SizedBox(height: 20),
        Text('SECURITY', style: FolioText.label(context)),
        const SizedBox(height: 8),
        _tile(context, Icons.lock_outline, 'Change password', _changePassword),
        const SizedBox(height: 20),
        Text('DELIVERY ADDRESSES', style: FolioText.label(context)),
        const SizedBox(height: 8),
        ..._addresses.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaperCard(
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a.label}${a.isDefault ? ' · default' : ''}', style: FolioText.title(context)),
                    const SizedBox(height: 2),
                    Text(a.oneLine, style: FolioText.caption(context)),
                  ])),
                  IconButton(icon: Icon(Icons.edit_outlined, size: 19, color: f.muted), onPressed: () async {
                    final saved = await showFolioSheet<bool>(context, child: AddressSheet(userId: state.user!.id, existing: a));
                    if (saved == true) _load();
                  }),
                  IconButton(icon: Icon(Icons.delete_outline, size: 19, color: f.muted), onPressed: () async {
                    await state.repo.deleteAddress(a.id);
                    _load();
                  }),
                ]),
              ),
            )),
        FolioButton(label: 'Add address', icon: Icons.add, style: FolioButtonStyle.outline, onPressed: () async {
          final saved = await showFolioSheet<bool>(context, child: AddressSheet(userId: state.user!.id));
          if (saved == true) _load();
        }),
        const SizedBox(height: 20),
        Text('PAYMENT METHODS', style: FolioText.label(context)),
        const SizedBox(height: 8),
        ..._payments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaperCard(
                child: Row(children: [
                  Icon(Icons.credit_card, color: f.ink),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${p.label} · exp ${p.expiry}', style: FolioText.body(context))),
                  IconButton(icon: Icon(Icons.delete_outline, size: 19, color: f.muted), onPressed: () async {
                    await state.repo.deletePaymentMethod(p.id);
                    _load();
                  }),
                ]),
              ),
            )),
        FolioButton(label: 'Add payment method', icon: Icons.add, style: FolioButtonStyle.outline, onPressed: () async {
          final saved = await showFolioSheet<bool>(context, child: PaymentSheet(userId: state.user!.id));
          if (saved == true) _load();
        }),
        const SizedBox(height: 20),
        Text('LIBRARIAN & DEMO', style: FolioText.label(context)),
        const SizedBox(height: 8),
        PaperCard(
          child: Row(children: [
            Icon(Icons.science_outlined, color: f.ink),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Demo tools', style: FolioText.body(context)),
              Text('Show “advance order status” buttons for the demo.', style: FolioText.caption(context)),
            ])),
            Switch(value: state.demoTools, activeColor: f.accent, onChanged: state.setDemoTools),
          ]),
        ),
        const SizedBox(height: 10),
        _tile(context, Icons.chat_bubble_outline, 'Clear librarian chat history', () async {
          final ok = await confirmDialog(context, title: 'Clear chat history?', message: 'This removes the saved conversation on this device.', confirmLabel: 'Clear', danger: true);
          if (ok) {
            await ChatHistoryStore.clear();
            if (context.mounted) showToast(context, 'Chat history cleared.');
          }
        }),
      ]),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final f = context.f;
    return PaperCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: f.ink, size: 21),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: FolioText.body(context))),
        Icon(Icons.chevron_right, color: f.muted, size: 20),
      ]),
    );
  }
}
