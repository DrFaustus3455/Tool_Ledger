import '../config/app_config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/inventory/data/models/tool_asset.dart';
import '../../features/inventory/presentation/asset_profile.dart';
import '../../shared/data/workspace_controller.dart';
import '../../shared/models/app_user.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import 'brand_mark.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const managerNav = [
  NavItem(
    '/manager/dashboard',
    'Command center',
    Icons.space_dashboard_outlined,
  ),
  NavItem('/manager/inventory', 'Inventory master', Icons.inventory_2_outlined),
  NavItem('/manager/scan', 'QR operations', Icons.qr_code_scanner),
  NavItem('/manager/loans', 'Lending records', Icons.receipt_long_outlined),
  NavItem(
    '/manager/approvals',
    'Approval center',
    Icons.verified_user_outlined,
  ),
  NavItem('/manager/archives', 'Asset archives', Icons.archive_outlined),
  NavItem(
    '/manager/finance',
    'Finance & depreciation',
    Icons.account_balance_outlined,
  ),
  NavItem('/manager/reports', 'Export center', Icons.table_view_outlined),
  NavItem('/manager/qr-labels', 'QR label studio', Icons.qr_code_2),
  NavItem('/manager/audit', 'Audit center', Icons.fact_check_outlined),
  NavItem(
    '/manager/accounts',
    'Account administration',
    Icons.manage_accounts_outlined,
  ),
  NavItem('/manager/settings', 'Settings & rules', Icons.tune),
];
const lenderNav = [
  NavItem(
    '/lender/workspace',
    'Lending workspace',
    Icons.space_dashboard_outlined,
  ),
  NavItem('/lender/scan', 'Scan equipment', Icons.qr_code_scanner),
  NavItem('/lender/loans', 'Loans & history', Icons.receipt_long_outlined),
  NavItem('/lender/inventory', 'Search inventory', Icons.inventory_2_outlined),
  NavItem(
    '/lender/approvals',
    'Approval requests',
    Icons.verified_user_outlined,
  ),
  NavItem('/lender/settings', 'Settings', Icons.tune),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _collapsed = false;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    if (user == null) return const SizedBox.shrink();
    final items = user.role == UserRole.manager ? managerNav : lenderNav;
    final mobile = MediaQuery.sizeOf(context).width < AppSizes.mobileBreakpoint;
    final compact =
        _collapsed ||
        MediaQuery.sizeOf(context).width < AppSizes.compactBreakpoint;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (!mobile)
              _Sidebar(
                items: items,
                location: widget.location,
                collapsed: compact,
                onCollapse: () => setState(() => _collapsed = !_collapsed),
              ),
            Expanded(
              child: Column(
                children: [
                  _Header(user: user, mobile: mobile),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: mobile
          ? _MobileNav(items: items, location: widget.location)
          : null,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.location,
    required this.collapsed,
    required this.onCollapse,
  });
  final List<NavItem> items;
  final String location;
  final bool collapsed;
  final VoidCallback onCollapse;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200),
    width: collapsed ? AppSizes.railWidth : AppSizes.sidebarWidth,
    decoration: BoxDecoration(
      color: context.colors.sidebar,
      border: Border(right: BorderSide(color: context.colors.border)),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 72,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 18 : 12),
            child: Row(
              children: [
                Expanded(child: BrandMark(compact: collapsed)),
                if (!collapsed)
                  IconButton(
                    onPressed: onCollapse,
                    tooltip: 'Collapse sidebar',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.keyboard_double_arrow_left,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (collapsed)
          IconButton(
            onPressed: onCollapse,
            tooltip: 'Expand sidebar',
            icon: const Icon(Icons.keyboard_double_arrow_right, size: 20),
          ),
        Divider(height: 1, color: context.colors.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            children: items.map((item) {
              final selected = location.startsWith(item.path);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tooltip(
                  message: collapsed ? item.label : '',
                  child: Material(
                    color: selected
                        ? context.colors.elevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    child: InkWell(
                      onTap: () => context.go(item.path),
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 46,
                        padding: EdgeInsets.symmetric(
                          horizontal: collapsed ? 18 : 12,
                        ),
                        decoration: BoxDecoration(
                          border: selected
                              ? Border.all(color: context.colors.border)
                              : null,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: selected
                                  ? context.colors.accent
                                  : context.colors.textSecondary,
                            ),
                            if (!collapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: selected
                                            ? context.colors.textPrimary
                                            : context.colors.textSecondary,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (!collapsed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Container(width: 7, height: 7, color: context.colors.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'OPERATIONS ONLINE\nMock repository',
                      style: monoStyle(
                        context,
                        size: 8,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.mobile});
  final AppUser user;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(workspaceProvider).value;
    final notifications =
        (data?.pendingApprovals ?? 0) +
        (data?.countStatus(AssetStatus.overdue) ?? 0) +
        (data?.countStatus(AssetStatus.missing) ?? 0);
    return Container(
      height: mobile ? 62 : 72,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 20),
      decoration: BoxDecoration(
        color: context.colors.sidebar,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          if (mobile)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: BrandMark(compact: true),
            ),
          if (!mobile) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OES / PRODUCT SUPPORT',
                  style: monoStyle(
                    context,
                    size: 9,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.role == UserRole.manager
                      ? 'MANAGER COMMAND'
                      : 'LENDER OPERATIONS',
                  style: monoStyle(
                    context,
                    size: 11,
                    color: context.colors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: InkWell(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const AssetSearchDialog(),
                  ),
                  borderRadius: BorderRadius.circular(5),
                  child: IgnorePointer(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: mobile
                            ? 'Search assets…'
                            : 'Global asset search  /  ID, serial, description',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        suffixIcon: mobile
                            ? null
                            : const Icon(Icons.keyboard_command_key),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!mobile) ...[
            const SizedBox(width: 14),
            Container(width: 7, height: 7, color: context.colors.accent),
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: monoStyle(
                context,
                size: 9,
                color: context.colors.textSecondary,
              ),
            ),
          ],
          Stack(
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const NotificationDialog(),
                ),
                icon: const Icon(Icons.notifications_none),
              ),
              if (notifications > 0)
                Positioned(
                  right: 6,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.colors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$notifications',
                      style: monoStyle(
                        context,
                        size: 8,
                        color: context.colors.sidebar,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<ThemeMode>(
            tooltip: 'Appearance',
            icon: const Icon(Icons.contrast),
            onSelected: (mode) =>
                ref.read(themeModeProvider.notifier).setMode(mode),
            itemBuilder: (_) => [
              for (final mode in ThemeMode.values)
                CheckedPopupMenuItem(
                  value: mode,
                  checked: ref.read(themeModeProvider) == mode,
                  child: Text(
                    mode.name[0].toUpperCase() + mode.name.substring(1),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile',
            onSelected: (value) async {
              if (value == 'settings') {
                context.go(
                  user.role == UserRole.manager
                      ? '/manager/settings'
                      : '/lender/settings',
                );
              }
              if (value == 'expire') {
                ref.read(sessionProvider.notifier).expire();
              }
              if (value == 'logout') {
                await ref.read(sessionProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${user.employeeId} • ${user.role.name.toUpperCase()}',
                      style: monoStyle(
                        context,
                        size: 9,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune),
                  title: Text('Settings'),
                ),
              ),
              if (!AppConfig.useLiveBackend)
                const PopupMenuItem(
                  value: 'expire',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.schedule),
                    title: Text('Simulate session expiry'),
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: context.colors.elevated,
                child: Text(
                  user.displayName.split(' ').map((v) => v[0]).take(2).join(),
                  style: monoStyle(
                    context,
                    size: 10,
                    color: context.colors.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.items, required this.location});
  final List<NavItem> items;
  final String location;
  @override
  Widget build(BuildContext context) {
    final primary = items.take(4).toList();
    final selected = primary.indexWhere(
      (item) => location.startsWith(item.path),
    );
    return NavigationBar(
      selectedIndex: selected < 0 ? 4 : selected,
      onDestinationSelected: (index) {
        if (index < 4) {
          context.go(primary[index].path);
          return;
        }
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: items
                  .map(
                    (item) => ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      selected: location.startsWith(item.path),
                      onTap: () {
                        Navigator.pop(context);
                        context.go(item.path);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
      destinations: [
        ...primary.map(
          (item) => NavigationDestination(
            icon: Icon(item.icon),
            label: item.label.split(' ').first,
          ),
        ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}

class AssetSearchDialog extends ConsumerStatefulWidget {
  const AssetSearchDialog({super.key});
  @override
  ConsumerState<AssetSearchDialog> createState() => _AssetSearchDialogState();
}

class _AssetSearchDialogState extends ConsumerState<AssetSearchDialog> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(workspaceProvider).value;
    final results =
        data?.assets
            .where(
              (a) =>
                  _query.isNotEmpty &&
                  '${a.id} ${a.serialNumber} ${a.description} ${a.partNumber}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .take(7)
            .toList() ??
        <ToolAsset>[];
    return AlertDialog(
      title: const Text('Global asset search'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Asset ID, serial number, description or part number',
              ),
            ),
            const SizedBox(height: 12),
            if (_query.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Start typing to search the authoritative asset registry.',
                ),
              )
            else if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No matching equipment found.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: results
                      .map(
                        (asset) => ListTile(
                          leading: const Icon(
                            Icons.precision_manufacturing_outlined,
                          ),
                          title: Text(asset.description),
                          subtitle: Text('${asset.id} • ${asset.serialNumber}'),
                          onTap: () {
                            Navigator.pop(context);
                            showAssetProfile(context, asset.id);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class NotificationDialog extends ConsumerWidget {
  const NotificationDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(workspaceProvider).value;
    return AlertDialog(
      title: const Text('Operational notifications'),
      content: SizedBox(
        width: 520,
        child: data == null
            ? const CircularProgressIndicator()
            : ListView(
                shrinkWrap: true,
                children: [
                  ...data.assets
                      .where(
                        (a) =>
                            a.status == AssetStatus.overdue ||
                            a.status == AssetStatus.missing,
                      )
                      .map(
                        (a) => ListTile(
                          leading: Icon(
                            Icons.warning_amber,
                            color: context.colors.danger,
                          ),
                          title: Text('${a.status.label}: ${a.id}'),
                          subtitle: Text(
                            a.currentBorrower.isEmpty
                                ? a.lyingAt
                                : a.currentBorrower,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            showAssetProfile(context, a.id);
                          },
                        ),
                      ),
                  ...data.approvals
                      .where((a) => a.status.name == 'pending')
                      .map(
                        (a) => ListTile(
                          leading: Icon(
                            Icons.verified_user_outlined,
                            color: context.colors.warning,
                          ),
                          title: Text('Authorization: ${a.assetId}'),
                          subtitle: Text(
                            '${a.requestedBy} • ${DateFormat('dd MMM HH:mm').format(a.requestedAt)}',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            showAssetProfile(context, a.assetId);
                          },
                        ),
                      ),
                  if (data.pendingApprovals +
                          data.countStatus(AssetStatus.overdue) +
                          data.countStatus(AssetStatus.missing) ==
                      0)
                    const ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('No operational alerts'),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
