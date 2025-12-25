class PinItem {
  final String id;
  String name;

  // Existing
  bool muted;
  bool synced;

  // ✅ NEW: status meaning "still in range"
  bool inRange;

  // ✅ NEW: when the current status was set
  DateTime lastStatusOn;

  PinItem({
    required this.id,
    required this.name,
    this.muted = false,
    this.synced = true,
    this.inRange = true,
    DateTime? lastStatusOn,
  }) : lastStatusOn = lastStatusOn ?? DateTime.now();
}

class Person {
  final String id;
  String name;
  final List<PinItem> pins;

  Person({
    required this.id,
    required this.name,
    required this.pins,
  });
}

/// =======================================================
/// NOTIFICATIONS MODEL
/// =======================================================

enum NotificationEventName { leftBehind, desync, notFound }

String notificationEventLabel(NotificationEventName e) {
  switch (e) {
    case NotificationEventName.leftBehind:
      return "Left Behind";
    case NotificationEventName.desync:
      return "Desync";
    case NotificationEventName.notFound:
      return "Not found";
  }
}

enum NotificationActionName { manuStop, autoStop, parentStop, none }

String notificationActionLabel(NotificationActionName a) {
  switch (a) {
    case NotificationActionName.manuStop:
      return "Manu-stop";
    case NotificationActionName.autoStop:
      return "Auto-stop";
    case NotificationActionName.parentStop:
      return "Parent-stop";
    case NotificationActionName.none:
      return "-";
  }
}

class AppNotification {
  final String id;

  final String personId;
  final String personName;

  final String pinId;
  final String pinName;

  final DateTime occurredAt;

  final NotificationEventName event;
  final NotificationActionName action;

  bool unread;

  AppNotification({
    required this.id,
    required this.personId,
    required this.personName,
    required this.pinId,
    required this.pinName,
    required this.occurredAt,
    required this.event,
    required this.action,
    this.unread = true,
  });
}