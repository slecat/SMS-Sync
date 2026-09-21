import 'package:flutter/material.dart';

class HomeBottomNavBar extends StatelessWidget {
  const HomeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.smsCount,
    required this.onTabSelected,
  });

  final int currentIndex;
  final int smsCount;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTabSelected,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFDCE9E1),
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: smsCount > 0,
            label: Text(smsCount > 9 ? '9+' : '$smsCount'),
            child: const Icon(Icons.inbox_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: smsCount > 0,
            label: Text(smsCount > 9 ? '9+' : '$smsCount'),
            child: const Icon(Icons.inbox),
          ),
          label: '同步',
        ),
        const NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune),
          label: '连接',
        ),
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: '设置',
        ),
      ],
    );
  }
}
