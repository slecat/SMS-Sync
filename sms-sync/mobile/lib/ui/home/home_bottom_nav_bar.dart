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

class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.currentIndex,
    required this.badgeLabel,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String label;
  final int currentIndex;
  final String? badgeLabel;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1B2232) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: isActive
                          ? const Color(0xFF60A5FA)
                          : Colors.white.withValues(alpha: 0.45),
                      size: 22,
                    ),
                    if (badgeLabel != null)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF0F1115),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            badgeLabel!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFFBFDBFE)
                        : Colors.white.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
