import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/shell_nav.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/nexus_theme.dart';
import 'dashboard_screen.dart';
import 'nodes_screen.dart';
import 'import_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _screens = [
    DashboardScreen(),
    NodesScreen(),
    ImportScreen(),
    LogsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNav>();
    final desktop = MediaQuery.of(context).size.width > 720;
    return NexusAtmosphere(
      child: desktop
          ? _DesktopShell(index: nav.index, onNav: nav.goTo, screens: _screens)
          : _MobileShell(index: nav.index, onNav: nav.goTo, screens: _screens),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onNav;
  final List<Widget> screens;
  const _DesktopShell({
    required this.index,
    required this.onNav,
    required this.screens,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          Container(
            width: 204,
            decoration: BoxDecoration(
              color: dark ? NexusColors.bgDeep : const Color(0xFFF8FBFC),
              border: Border(
                right: BorderSide(
                  color: dark ? NexusColors.line : const Color(0x1A102027),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [
                              NexusColors.accent,
                              NexusColors.accentDeep
                            ],
                          ),
                        ),
                        child: const Icon(Icons.shield_moon_rounded,
                            size: 18, color: Color(0xFF042F2E)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'NEXUS',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              letterSpacing: 1.4,
                              fontSize: 18,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child:
                      Text('导航', style: Theme.of(context).textTheme.labelSmall),
                ),
                _NavTile(0, Icons.radar_rounded, '仪表盘', index, onNav),
                _NavTile(1, Icons.hub_outlined, '节点', index, onNav),
                _NavTile(2, Icons.file_download_outlined, '导入', index, onNav),
                _NavTile(3, Icons.terminal_rounded, '日志', index, onNav),
                _NavTile(4, Icons.tune_rounded, '设置', index, onNav),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: _SidebarStatus(),
                ),
                const Spacer(),
                const _SidebarVersion(),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(index: index, children: screens),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final int i;
  final IconData icon;
  final String label;
  final int index;
  final ValueChanged<int> onNav;
  const _NavTile(this.i, this.icon, this.label, this.index, this.onNav);

  @override
  Widget build(BuildContext context) {
    final active = index == i;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final inactive = onSurface.withOpacity(0.52);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onNav(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? NexusColors.accent.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? NexusColors.accent.withOpacity(0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? NexusColors.accent : inactive,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? onSurface : inactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarStatus extends StatelessWidget {
  const _SidebarStatus();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final session = context.watch<SessionProvider>();
    final settings = context.watch<SettingsProvider>();
    final updates = context.watch<UpdateProvider>();
    final line = dark ? NexusColors.line : const Color(0x1A102027);
    final surface =
        dark ? NexusColors.surface.withOpacity(0.72) : const Color(0xFFEAF2F4);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('运行状态', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          _StatusLine(
            icon: session.isConnected
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            label: session.isConnected ? '已连接' : '未连接',
            color: session.isConnected ? NexusColors.ok : null,
          ),
          const SizedBox(height: 7),
          _StatusLine(
            icon: Icons.swap_horiz_rounded,
            label: settings.autoFailover ? '故障转移开启' : '故障转移关闭',
            color: settings.autoFailover ? NexusColors.accent : null,
          ),
          if (updates.hasUpdate) ...[
            const SizedBox(height: 7),
            const _StatusLine(
              icon: Icons.system_update_rounded,
              label: '发现新版本',
              color: NexusColors.warn,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _StatusLine({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effective =
        color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.52);
    return Row(
      children: [
        Icon(icon, size: 15, color: effective),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effective,
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarVersion extends StatelessWidget {
  const _SidebarVersion();

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<UpdateProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        updates.currentVersion == '—'
            ? 'NEXUS'
            : 'NEXUS  v${updates.currentVersion}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onNav;
  final List<Widget> screens;
  const _MobileShell({
    required this.index,
    required this.onNav,
    required this.screens,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onNav,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar_rounded), label: '仪表盘'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), label: '节点'),
          NavigationDestination(
              icon: Icon(Icons.file_download_outlined), label: '导入'),
          NavigationDestination(
              icon: Icon(Icons.terminal_rounded), label: '日志'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: '设置'),
        ],
      ),
    );
  }
}
