import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerShell extends StatelessWidget {
  final Widget child;

  const CustomerShell({super.key, required this.child});

  static const tabs = [
    _CustomerTab(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      path: '/home',
    ),
    _CustomerTab(
      label: 'Explore',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      path: '/explore',
    ),
    _CustomerTab(
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      path: '/orders',
    ),
    _CustomerTab(
      label: 'Account',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      path: '/account',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          final tab = tabs[index];

          if (index == currentIndex) {
            return;
          }

          context.go(tab.path);
        },
        destinations: tabs.map((tab) {
          return NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.activeIcon),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }

  int selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location.startsWith('/explore')) {
      return 1;
    }

    if (location.startsWith('/orders')) {
      return 2;
    }

    if (location.startsWith('/account')) {
      return 3;
    }

    return 0;
  }
}

class _CustomerTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _CustomerTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
