import 'dart:io';
import 'package:flutter/material.dart';

class PinItem {
  final String id;
  String name;

  bool muted;
  bool synced;

  bool inRange;
  DateTime lastStatusOn;

  int? rangeFeet;
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

  int get effectiveRangeFeet {
    final r = rangeFeet;
    if (r == null || r <= 0) return 1;
    return r;
  }

  double get effectiveDistanceFeet => distanceFeet ?? 0.0;

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "muted": muted,
        "synced": synced,
        "inRange": inRange,
        "lastStatusOn": lastStatusOn.toIso8601String(),
        "rangeFeet": rangeFeet,
        "distanceFeet": distanceFeet,
      };

  static PinItem fromJson(Map<String, dynamic> j) {
    return PinItem(
      id: j["id"] as String,
      name: (j["name"] as String?) ?? "",
      muted: (j["muted"] as bool?) ?? false,
      synced: (j["synced"] as bool?) ?? true,
      inRange: (j["inRange"] as bool?) ?? true,
      lastStatusOn: DateTime.tryParse((j["lastStatusOn"] as String?) ?? "") ??
          DateTime.now(),
      rangeFeet: (j["rangeFeet"] as num?)?.toInt(),
      distanceFeet: (j["distanceFeet"] as num?)?.toDouble(),
    );
  }
}

/// =======================================================
/// ✅ MAIN GROUP (Main)
/// =======================================================
class MainGroup {
  final String id;
  String name;
  IconData icon;

  /// BLE-linked pin ids
  List<String> pinIds;

  /// ✅ UI state fields (HomePage expects these)
  bool synced;
  bool muted;
  bool ringEnabled;
  bool lightEnabled;

  MainGroup({
    required this.id,
    required this.name,
    required this.icon,
    List<String>? pinIds,
    this.synced = true,
    this.muted = false,
    this.ringEnabled = true,
    this.lightEnabled = true,
  }) : pinIds = pinIds ?? [];

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "icon": _iconToJson(icon),
        "pinIds": pinIds,

        // ✅ persist UI state too
        "synced": synced,
        "muted": muted,
        "ringEnabled": ringEnabled,
        "lightEnabled": lightEnabled,
      };

  static MainGroup fromJson(Map<String, dynamic> j) {
    return MainGroup(
      id: j["id"] as String,
      name: (j["name"] as String?) ?? "",
      icon: _iconFromJson((j["icon"] as Map?)?.cast<String, dynamic>() ?? {}),
      pinIds: ((j["pinIds"] as List?) ?? const []).cast<String>(),

      // ✅ load UI state (safe defaults for old saves)
      synced: (j["synced"] as bool?) ?? true,
      muted: (j["muted"] as bool?) ?? false,
      ringEnabled: (j["ringEnabled"] as bool?) ?? true,
      lightEnabled: (j["lightEnabled"] as bool?) ?? true,
    );
  }
}

class Person {
  final String id;
  String name;
  final List<PinItem> pins;

  File? avatarFile;
  IconData? avatarIcon;

  /// ✅ mains for this person
  final List<MainGroup> mains;

  /// optional cache/helper map (you can rebuild whenever you need)
  Map<String, List<PinItem>> itemsByMain;

  Person({
    required this.id,
    required this.name,
    required this.pins,
    this.avatarFile,
    this.avatarIcon,
    List<MainGroup>? mains,
    Map<String, List<PinItem>>? itemsByMain,
  })  : mains = mains ?? [],
        itemsByMain = itemsByMain ?? {};

  /// Build mainId -> PinItem list from mains.pinIds
  void rebuildItemsByMain() {
    final byId = <String, PinItem>{for (final p in pins) p.id: p};
    final map = <String, List<PinItem>>{};
    for (final m in mains) {
      map[m.id] = m.pinIds.map((pid) => byId[pid]).whereType<PinItem>().toList();
    }
    itemsByMain = map;
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "pins": pins.map((p) => p.toJson()).toList(),
        "avatarPath": avatarFile?.path,
        "avatarIcon": avatarIcon == null ? null : _iconToJson(avatarIcon!),
        "mains": mains.map((m) => m.toJson()).toList(),
      };

  static Person fromJson(Map<String, dynamic> j) {
    final pins = ((j["pins"] as List?) ?? const [])
        .map((e) => PinItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final mains = ((j["mains"] as List?) ?? const [])
        .map((e) => MainGroup.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    File? file;
    final path = j["avatarPath"] as String?;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (f.existsSync()) file = f;
    }

    IconData? icon;
    final iconMap = (j["avatarIcon"] as Map?)?.cast<String, dynamic>();
    if (iconMap != null) icon = _iconFromJson(iconMap);

    final p = Person(
      id: j["id"] as String,
      name: (j["name"] as String?) ?? "",
      pins: pins,
      avatarFile: file,
      avatarIcon: icon,
      mains: mains,
    );

    p.rebuildItemsByMain();
    return p;
  }
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

  Map<String, dynamic> toJson() => {
        "fullName": _fullName,
        "email": _email,
        "avatarPath": _avatarFile?.path,
        "avatarIcon": _avatarIcon == null ? null : _iconToJson(_avatarIcon!),
      };

  static UserProfile fromJson(Map<String, dynamic> j) {
    File? file;
    final path = j["avatarPath"] as String?;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (f.existsSync()) file = f;
    }

    IconData? icon;
    final iconMap = (j["avatarIcon"] as Map?)?.cast<String, dynamic>();
    if (iconMap != null) icon = _iconFromJson(iconMap);

    return UserProfile(
      fullName: (j["fullName"] as String?) ?? "User",
      email: (j["email"] as String?) ?? "user@email.com",
      avatarFile: file,
      avatarIcon: icon,
    );
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

/// =======================================================
/// Icon serialization helpers
/// =======================================================
Map<String, dynamic> _iconToJson(IconData icon) => {
      "codePoint": icon.codePoint,
      "fontFamily": icon.fontFamily,
      "fontPackage": icon.fontPackage,
      "matchTextDirection": icon.matchTextDirection,
    };

IconData _iconFromJson(Map<String, dynamic> j) {
  final codePoint = (j["codePoint"] as num?)?.toInt() ?? Icons.circle.codePoint;
  return IconData(
    codePoint,
    fontFamily: j["fontFamily"] as String?,
    fontPackage: j["fontPackage"] as String?,
    matchTextDirection: (j["matchTextDirection"] as bool?) ?? false,
  );
}