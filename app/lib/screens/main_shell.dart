import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/shell_nav.dart';
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
            width: 228,
            decoration: BoxDecoration(
              color: (dark ? NexusColors.bgDeep : Colors.white).withOpacity(0.72),
              border: const Border(right: BorderSide(color: NexusColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [NexusColors.accent, NexusColors.accentDeep],
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
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('导航', style: Theme.of(context).textTheme.labelSmall),
                ),
                _NavTile(0, Icons.radar_rounded, '仪表盘', index, onNav),
                _NavTile(1, Icons.hub_outlined, '节点', index, onNav),
                _NavTile(2, Icons.file_download_outlined, '导入', index, onNav),
                _NavTile(3, Icons.terminal_rounded, '日志', index, onNav),
                _NavTile(4, Icons.tune_rounded, '设置', index, onNav),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('v1.0', style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
            ),
          ),
          Expanded(child: screens[index]),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onNav(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? NexusColors.accent.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? NexusColors.accent.withOpacity(0.35) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? NexusColors.accent : NexusColors.textDim,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? Theme.of(context).colorScheme.onSurface
                      : NexusColors.textDim,
                ),
              ),
            ],
          ),
        ),
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
          NavigationDestination(icon: Icon(Icons.file_download_outlined), label: '导入'),
          NavigationDestination(icon: Icon(Icons.terminal_rounded), label: '日志'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: '设置'),
        ],
      ),
    );
  }
}
