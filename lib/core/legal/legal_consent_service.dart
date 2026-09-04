import 'package:hive_flutter/hive_flutter.dart';

class LegalConsentService {
  static Box get _box => Hive.box('legal_consent');

  static Future<void> init() async {
    if (!Hive.isBoxOpen('legal_consent')) {
      await Hive.openBox('legal_consent');
    }
  }

  static Future<bool> hasAccepted() async {
    final accepted = _box.get('accepted', defaultValue: false);
    return accepted as bool;
  }

  static Future<void> accept() async {
    await _box.put('accepted', true);
  }

  static Future<void> reset() async {
    await _box.clear();
  }
}