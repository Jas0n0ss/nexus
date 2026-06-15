import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'nodes_screen.dart';
import 'import_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    NodesScreen(),
    ImportScreen(),
    LogsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 720;
    if (isDesktop) return _DesktopLayout(index: _index, onNav: (i) => setState(() => _index = i), screens: _screens);
    return _MobileLayout(index: _index, onNav: (i) => setState(() => _index = i), screens: _screens);
  }
}

// ── Desktop: left sidebar ──────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final int index;
  final ValueChanged<int> onNav;
  final List<Widget> screens;
  const _DesktopLayout({required this.index, required this.onNav, required this.screens});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0A12) : const Color(0xFFF7F7FA),
              border: Border(right: BorderSide(color: cs.onSurface.withOpacity(0.08))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 28),
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Text('🌐', style: TextStyle(fontSize: 16))),
                    ),
                    const SizedBox(width: 10),
                    Text('Nexus VPN', style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      letterSpacing: -0.3, color: cs.onSurface)),
                  ]),
                ),
                const SizedBox(height: 24),
                _navSection(context, '主菜单'),
                _navItem(context, 0, Icons.language_rounded, '仪表盘'),
                _navItem(context, 1, Icons.location_on_rounded, '节点列表'),
                _navItem(context, 2, Icons.upload_file_rounded, '导入配置'),
                _navItem(context, 3, Icons.article_rounded, '运行日志'),
                _navItem(context, 4, Icons.settings_rounded, '设置'),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('v1.0.0', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.3))),
                ),
              ],
            ),
          ),
          // Content
          Expanded(child: screens[index]),
        ],
      ),
    );
  }

  Widget _navSection(BuildContext ctx, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 0.8, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
  );

  Widget _navItem(BuildContext ctx, int i, IconData icon, String label) {
    final active = index == i;
    final cs = Theme.of(ctx).colorScheme;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: active
            ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onNav(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 17,
                color: active ? cs.primary : cs.onSurface.withOpacity(0.5)),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: active ? cs.onSurface : cs.onSurface.withOpacity(0.55))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Mobile: bottom tab bar ─────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final int index;
  final ValueChanged<int> onNav;
  final List<Widget> screens;
  const _MobileLayout({required this.index, required this.onNav, required this.screens});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onNav,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.language_rounded), label: '仪表盘'),
          NavigationDestination(icon: Icon(Icons.location_on_rounded), label: '节点'),
          NavigationDestination(icon: Icon(Icons.upload_file_rounded), label: '导入'),
          NavigationDestination(icon: Icon(Icons.article_rounded), label: '日志'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: '设置'),
        ],
      ),
    );
  }
}
