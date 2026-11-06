import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Admin: manage users (active / admin).
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await AppStateScope.read(context).repo.users();
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: 'Users',
      kicker: 'Admin',
      body: _loading
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: ThinkingDots()))
          : Column(children: [
              for (final u in _users)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PaperCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(backgroundColor: f.accentSoft, child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?', style: TextStyle(color: f.accent, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.name, style: FolioText.title(context)),
                          Text(u.email, style: FolioText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        if (u.isAdmin) StampBadge('Admin', color: f.accent),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: Text('Active', style: FolioText.bodySmall(context))),
                        Switch(value: u.isActive, activeColor: f.accent, onChanged: (v) async {
                          await AppStateScope.read(context).repo.setUserActive(u.id, v);
                          _load();
                        }),
                        const SizedBox(width: 16),
                        Expanded(child: Text('Admin', style: FolioText.bodySmall(context))),
                        Switch(value: u.isAdmin, activeColor: f.accent, onChanged: (v) async {
                          await AppStateScope.read(context).repo.setUserAdmin(u.id, v);
                          _load();
                        }),
                      ]),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
