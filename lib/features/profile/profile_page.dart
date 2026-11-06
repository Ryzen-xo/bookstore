import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../state/app_state.dart';
import '../admin/admin_page.dart';
import '../orders/orders_page.dart';
import '../static/about_page.dart';
import '../static/faq_page.dart';
import '../wishlist/wishlist_page.dart';
import 'settings_page.dart';

/// Profile: library card, account links and admin entry.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    Widget content;
    if (!state.loggedIn) {
      content = EmptyState(
        icon: Icons.person_outline,
        title: 'Your library card',
        message: 'Sign in to see your orders, reading list and library card.',
        action: FolioButton(label: 'Sign in', style: FolioButtonStyle.accent, onPressed: () => state.openLogin()),
      );
    } else {
      final u = state.user!;
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('You', style: FolioText.h1(context)),
        const SizedBox(height: 16),
        _libraryCard(context, u.name, u.email, u.id),
        const SizedBox(height: 24),
        _menu(context, [
          _Item(Icons.receipt_long_outlined, 'My orders', () => pushPage(context, const OrdersPage())),
          _Item(Icons.favorite_border, 'Reading list', () => pushPage(context, const WishlistPage())),
          _Item(Icons.settings_outlined, 'Settings & security', () => pushPage(context, const SettingsPage())),
          if (u.isAdmin) _Item(Icons.admin_panel_settings_outlined, 'Admin back office', () => pushPage(context, const AdminPage()), accent: true),
          _Item(Icons.help_outline, 'Help & FAQ', () => pushPage(context, const FaqPage())),
          _Item(Icons.info_outline, 'About Shelf', () => pushPage(context, const AboutPage())),
        ]),
        const SizedBox(height: 20),
        FolioButton(label: 'Sign out', icon: Icons.logout, style: FolioButtonStyle.outline, expand: true, onPressed: () async {
          final ok = await confirmDialog(context, title: 'Sign out?', message: 'You can sign back in any time.', confirmLabel: 'Sign out');
          if (ok) {
            await state.logout();
            if (context.mounted) showToast(context, 'Signed out.');
          }
        }),
      ]);
    }

    if (embedded) return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), child: ContentWidth(child: content));
    return FolioPage(title: 'You', kicker: 'Shelf', body: content);
  }

  Widget _libraryCard(BuildContext context, String name, String email, int id) {
    final f = context.f;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [f.ink, f.isDark ? f.surface : const Color(0xFF33302A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.menu_book_rounded, color: f.paper, size: 22),
          const SizedBox(width: 8),
          Text('SHELF LIBRARY CARD', style: TextStyle(fontFamily: 'sans-serif', fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: f.paper.withValues(alpha: 0.8))),
          const Spacer(),
          Icon(Icons.auto_awesome, color: f.accent, size: 20),
        ]),
        const SizedBox(height: 20),
        Text(name, style: FolioText.h2(context).copyWith(color: f.paper)),
        const SizedBox(height: 2),
        Text(email, style: FolioText.caption(context).copyWith(color: f.paper.withValues(alpha: 0.7))),
        const SizedBox(height: 18),
        _barcode(context, id),
        const SizedBox(height: 6),
        Text('NO. ${id.toString().padLeft(8, '0')}', style: TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: 2, color: f.paper.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _barcode(BuildContext context, int seed) {
    final f = context.f;
    final bars = <Widget>[];
    var x = seed * 2654435761 % 2147483647;
    for (var i = 0; i < 44; i++) {
      x = (x * 1103515245 + 12345) % 2147483647;
      final w = 1.0 + (x % 3);
      bars.add(Container(width: w, height: 38, color: f.paper.withValues(alpha: 0.9), margin: const EdgeInsets.only(right: 1.5)));
    }
    return SizedBox(height: 38, child: Row(children: bars));
  }

  Widget _menu(BuildContext context, List<_Item> items) {
    final f = context.f;
    return Container(
      decoration: BoxDecoration(color: f.card, border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          Tappable(
            onTap: items[i].onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                Icon(items[i].icon, size: 21, color: items[i].accent ? f.accent : f.ink),
                const SizedBox(width: 14),
                Expanded(child: Text(items[i].label, style: FolioText.body(context).copyWith(color: items[i].accent ? f.accent : f.ink))),
                Icon(Icons.chevron_right, size: 20, color: f.muted),
              ]),
            ),
          ),
          if (i < items.length - 1) const FolioDivider(indent: 51),
        ],
      ]),
    );
  }
}

class _Item {
  _Item(this.icon, this.label, this.onTap, {this.accent = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
}
