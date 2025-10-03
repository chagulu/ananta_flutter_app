// File: lib/core/notifications_center.dart
import 'package:flutter/foundation.dart';

class AppNotification {
  final String title;
  final String body;
  final DateTime at;

  AppNotification({
    required this.title,
    required this.body,
    DateTime? at,
  }) : at = at ?? DateTime.now();
}

class NotificationsCenter {
  static final ValueNotifier<List<AppNotification>> notifier =
      ValueNotifier<List<AppNotification>>([]);

  static void add(AppNotification n) {
    final list = List<AppNotification>.from(notifier.value);
    list.insert(0, n);
    notifier.value = list;
  }

  static void clear() {
    notifier.value = const [];
  }
}
