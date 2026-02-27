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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HomeNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: '首页',
                currentIndex: currentIndex,
                badgeLabel: null,
                onTap: onTabSelected,
              ),
              _HomeNavItem(
                index: 1,
                icon: Icons.sms_rounded,
                label: '消息',
                currentIndex: currentIndex,
                badgeLabel: smsCount > 0
                    ? (smsCount > 9 ? '9+' : '$smsCount')
                    : null,
                onTap: onTabSelected,
              ),
              _HomeNavItem(
                index: 2,
                icon: Icons.devices_rounded,
                label: '设备',
                currentIndex: currentIndex,
                badgeLabel: null,
                onTap: onTabSelected,
              ),
              _HomeNavItem(
                index: 3,
                icon: Icons.settings_rounded,
                label: '设置',
                currentIndex: currentIndex,
                badgeLabel: null,
                onTap: onTabSelected,
              ),
            ],
          ),
        ),
      ),
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

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? const Color(0xFF6366F1)
                      : Colors.white.withValues(alpha: 0.4),
                  size: 24,
                ),
                if (badgeLabel != null)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF121212),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF6366F1)
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
