import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notification scheduler for task reminders and repeating habit reminders.
class LocalNotifications {
  LocalNotifications._();
  static final LocalNotifications instance = LocalNotifications._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final dynamic zone = await FlutterTimezone.getLocalTimezone();
      final String name = zone is String ? zone : (zone.identifier as String? ?? 'UTC');
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> scheduleTask({required String id, required String title, required DateTime when}) async {
    await initialize();
    await _requestPermissions();
    final DateTime now = DateTime.now();
    if (!when.isAfter(now)) {
      await cancel(id);
      return;
    }
    await _plugin.zonedSchedule(
      _id(id), title, 'Task reminder', _asTz(when),
      const NotificationDetails(
        android: AndroidNotificationDetails('tickoff_tasks', 'Task reminders', channelDescription: 'Reminders for your tasks', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'task:$id',
    );
  }

  Future<void> scheduleHabit({required String id, required String title, required int hour, required int minute, required Set<int> weekdays}) async {
    await initialize();
    await _requestPermissions();
    await cancel(id);
    for (final int weekday in weekdays) {
      final DateTime now = DateTime.now();
      DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);
      while (candidate.weekday != weekday || !candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        _id('$id-$weekday'), title, 'Time for your habit', _asTz(candidate),
        const NotificationDetails(
          android: AndroidNotificationDetails('tickoff_habits', 'Habit reminders', channelDescription: 'Reminders for your habits', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'habit:$id',
      );
    }
  }


  Future<void> _requestPermissions() async {
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> cancel(String id) async {
    await initialize();
    await _plugin.cancel(_id(id));
    for (int day = 1; day <= 7; day++) {
      await _plugin.cancel(_id('$id-$day'));
    }
  }

  int _id(String value) {
    int hash = 0x1fffffff;
    for (final int unit in value.codeUnits) { hash = 0x1fffffff & (hash + unit); hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10)); hash ^= hash >> 6; }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3)); hash ^= hash >> 11; hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash & 0x7fffffff;
  }

  tz.TZDateTime _asTz(DateTime value) => tz.TZDateTime.from(value, tz.local);
}
