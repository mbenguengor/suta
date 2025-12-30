import 'dart:io';
import 'package:flutter/material.dart';

class PinItem {
  final String id;
  String name;

  // Existing
  bool muted;
  bool synced;

  // ✅ status meaning "still in range"
  bool inRange;

  // ✅ when the current status was set
  DateTime lastStatusOn;

  // -------------------------------------------------------
  // ✅ NEW: Range + Distance
  // -------------------------------------------------------
  // Range in feet (nullable in model; UI uses effectiveRangeFeet)
  int? rangeFeet;

  // Distance estimate in feet (nullable until BLE provides it)
  double? distanceFeet;

  PinItem({
    required this.id,
    required this.name,
    this.muted = false,
    this.synced = true,
    this.inRange = true,
    DateTime? lastStatusOn,
    this.rangeFeet,
    this.distanceFeet,
  }) : lastStatusOn = lastStatusOn ?? DateTime.now();

  // ✅ If Range is empty → treat as “1” feet
  int get effectiveRangeFeet {
    final r = rangeFeet;
    if (r == null || r <= 0) return 1;
    return r;
  }

  // ✅ If distance is missing, treat as 0 ft (safe default until BLE)
  double get effectiveDistanceFeet => distanceFeet ?? 0.0;
}

class Person {
  final String id;
  String name;
  final List<PinItem> pins;

  // ✅ NEW: per-person avatar (like profile)
  File? avatarFile;
  IconData? avatarIcon;

  Person({
    required this.id,
    required this.name,
    required this.pins,
    this.avatarFile,
    this.avatarIcon,
  });
}

/// =======================================================
/// ✅ USER PROFILE (shared across Header + Settings)
/// =======================================================
class UserProfile extends ChangeNotifier {
  String _fullName;
  String _email;

  File? _avatarFile;
  IconData? _avatarIcon;

  UserProfile({
    required String fullName,
    required String email,
    File? avatarFile,
    IconData? avatarIcon,
  })  : _fullName = fullName,
        _email = email,
        _avatarFile = avatarFile,
        _avatarIcon = avatarIcon;

  String get fullName => _fullName;
  String get email => _email;

  File? get avatarFile => _avatarFile;
  IconData? get avatarIcon => _avatarIcon;

  void setFullName(String v) {
    final next = v.trim();
    if (next.isEmpty) return;
    if (next == _fullName) return;
    _fullName = next;
    notifyListeners();
  }

  void setEmail(String v) {
    final next = v.trim();
    if (next.isEmpty) return;
    if (next == _email) return;
    _email = next;
    notifyListeners();
  }

  void setAvatarFile(File file) {
    _avatarFile = file;
    _avatarIcon = null;
    notifyListeners();
  }

  void setAvatarIcon(IconData icon) {
    _avatarIcon = icon;
    _avatarFile = null;
    notifyListeners();
  }

  void clearAvatar() {
    _avatarFile = null;
    _avatarIcon = null;
    notifyListeners();
  }
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