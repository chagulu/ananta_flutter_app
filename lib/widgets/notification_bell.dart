// File: lib/widgets/notification_bell.dart
import 'package:flutter/material.dart';
import '../core/notifications_center.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationsCenter.notifier,
      builder: (context, items, _) {
        final count = items.length;
        return PopupMenuButton<int>(
          tooltip: 'Notifications',
          offset: const Offset(0, 8),
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          itemBuilder: (_) {
            if (items.isEmpty) {
              return const [
                PopupMenuItem<int>(
                  value: -1,
                  enabled: false,
                  child: ListTile(
                    leading: Icon(Icons.notifications_off_outlined),
                    title: Text('No notifications'),
                  ),
                ),
              ];
            }
            final latest = items.take(8).toList();
            return [
              ...latest.asMap().entries.map((e) {
                final i = e.key;
                final n = e.value;
                return PopupMenuItem<int>(
                  value: i,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.notifications),
                    title: Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _relativeTime(n.at),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                );
              }),
              const PopupMenuDivider(),
              const PopupMenuItem<int>(
                value: -2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Clear all'),
                    Icon(Icons.clear_all, size: 18),
                  ],
                ),
              ),
            ];
          },
          onSelected: (idx) {
            if (idx == -2) {
              NotificationsCenter.clear();
              return;
            }
            // Optionally handle per-item actions by index.
          },
        );
      },
    );
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
