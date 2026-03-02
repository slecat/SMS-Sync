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
        color: const Color(0xFF0F1115),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HomeNavItem(
                index: 0,
                icon: Icons.dashboard_rounded,
                label: '总览',
                currentIndex: currentIndex,
                badgeLabel: smsCount > 0
                    ? (smsCount > 9 ? '9+' : '$smsCount')
                    : null,
                onTap: onTabSelected,
              ),
              _HomeNavItem(
                index: 1,
                icon: Icons.tune_rounded,
                label: '配置',
                currentIndex: currentIndex,
                badgeLabel: null,
                onTap: onTabSelected,
              ),
              _HomeNavItem(
                index: 2,
                icon: Icons.info_outline_rounded,
                label: '关于',
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
