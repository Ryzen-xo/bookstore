import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../state/app_state.dart';
import '../ai/chat_page.dart';
import '../browse/browse_page.dart';
import '../cart/cart_page.dart';
import '../home/home_page.dart';
import '../profile/profile_page.dart';

/// The five-slot home: Home · Browse · Librarian · Cart · You.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});
  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late final List<Widget> _tabs = const [
    HomePage(embedded: true),
    BrowsePage(embedded: true),
    ChatPage(),
    CartPage(embedded: true),
    ProfilePage(embedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final f = context.f;
    return Scaffold(
      backgroundColor: f.paper,
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: state.shellIndex, children: _tabs),
        ),
      ),
      bottomNavigationBar: FolioNavBar(
        index: state.shellIndex,
        onTap: state.setShellIndex,
        items: [
          const FolioNavItem(Icons.home_outlined, 'Home'),
          const FolioNavItem(Icons.search, 'Browse'),
          const FolioNavItem(Icons.auto_awesome, 'Librarian', center: true),
          FolioNavItem(Icons.shopping_bag_outlined, 'Cart', badge: state.cartCount),
          const FolioNavItem(Icons.person_outline, 'You'),
        ],
      ),
    );
  }
}
