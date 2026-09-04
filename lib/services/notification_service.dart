import 'package:hive/hive.dart';

class NotificationService {
  static Box get _settings => Hive.box('settings');

  static bool get remindersEnabled =>
      _settings.get('remindersEnabled', defaultValue: false) as bool;

  static void setRemindersEnabled(bool value) =>
      _settings.put('remindersEnabled', value);

  static String get reminderFrequency =>
      _settings.get('reminderFrequency', defaultValue: 'daily') as String;

  static void setReminderFrequency(String value) =>
      _settings.put('reminderFrequency', value);

  static Future<void> scheduleReminder() async {
    // TODO: implementar notificaciones cuando se actualice flutter_local_notifications
  }

  static Future<void> cancelAll() async {
    // TODO: implementar cancelación de notificaciones
  }
}