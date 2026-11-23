import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

@immutable
class ShellDestination {
  const ShellDestination(this.label, this.icon, this.selectedIcon, this.location);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String location;
}

/// Bottom navigation on phones, NavigationRail from [AppBreakpoints.wide].
/// Each branch keeps its own stack (StatefulShellRoute).
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;

  void _select(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.wide;

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.card,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
