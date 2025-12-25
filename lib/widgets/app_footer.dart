import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  /// ✅ unread count (0 => hidden)
  final int unreadNotifications;

  const AppFooter({
    super.key,
    required this.index,
    required this.onTap,
    this.unreadNotifications = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6E8EF), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6), // ✅ original size
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              active: index == 0,
              onTap: () => onTap(0),
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
            ),
            _NavItem(
              active: index == 1,
              onTap: () => onTap(1),
              icon: Icons.checklist_outlined,
              activeIcon: Icons.checklist,
              label: 'Status',
            ),
            _NavItem(
              active: index == 2,
              onTap: () => onTap(2),
              icon: Icons.notifications_none,
              activeIcon: Icons.notifications,
              label: 'Notifications',
              unreadCount: unreadNotifications,
            ),
            _NavItem(
              active: index == 3,
              onTap: () => onTap(3),
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// ✅ used only for Notifications item
  final int unreadCount;

  const _NavItem({
    required this.active,
    required this.onTap,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Color(0xFF9CA3AF);
    const activeColor = Colors.black;

    final showBadge = unreadCount > 0;
    final badgeText = unreadCount > 99 ? "99+" : unreadCount.toString();

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔹 Top indicator (unchanged)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: 2,
                width: active ? 26 : 0,
                decoration: const BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
              const SizedBox(height: 6),

              // 🔹 Icon + badge (fixed positioning)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    active ? activeIcon : icon,
                    size: 26,
                    color: active ? activeColor : inactiveColor,
                  ),
                  if (showBadge)
                    Positioned(
                      right: -6, // ✅ sits on icon corner
                      top: -4,   // ✅ not too high, not over the indicator
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 3),

              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}