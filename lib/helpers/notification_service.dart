/// Notification service for managing bill reminders and app notifications
///
/// Handles scheduling, canceling, and displaying local notifications
/// for bill due dates and other app events.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/bill.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  Future<void> scheduleBillNotification(Bill bill) async {
    // Schedule notification for one day before the due date at 9:00 AM
    final scheduleTime = tz.TZDateTime.from(bill.dueDate, tz.local).subtract(const Duration(days: 1)).add(const Duration(hours: 9));

    // Ensure the scheduled time is in the future
    if (scheduleTime.isBefore(DateTime.now())) {
      return;
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'bill_reminders_channel',
      'Bill Reminders',
      channelDescription: 'Channel for bill reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
        
    await flutterLocalNotificationsPlugin.zonedSchedule(
      bill.id!,
      'Upcoming Bill Reminder',
      'Your bill "${bill.name}" for KSh ${bill.amount.toStringAsFixed(0)} is due tomorrow.',
      scheduleTime,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}