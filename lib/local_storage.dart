import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class LocalStorage {
  static const _kProfile = "suta_profile_v1";
  static const _kPeople = "suta_people_v1";

  static Future<void> saveProfile(UserProfile profile) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfile, jsonEncode(profile.toJson()));
  }

  static Future<UserProfile?> loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfile);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePeople(List<Person> people) async {
    final sp = await SharedPreferences.getInstance();
    final list = people.map((p) => p.toJson()).toList();
    await sp.setString(_kPeople, jsonEncode(list));
  }

  static Future<List<Person>?> loadPeople() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPeople);
    if (raw == null || raw.isEmpty) return null;

    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list
          .map((e) => Person.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kProfile);
    await sp.remove(_kPeople);
  }
}
