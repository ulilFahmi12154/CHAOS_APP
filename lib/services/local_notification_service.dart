import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    // Set timezone to Asia/Jakarta (WIB - UTC+7)
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request notification permissions (mainly for iOS)
  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    bool granted = true;

    if (androidPlugin != null) {
      granted = await androidPlugin.requestNotificationsPermission() ?? false;
    }

    if (iosPlugin != null) {
      granted =
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return granted;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('📲 Notification tapped: ${response.payload}');
    // You can add navigation logic here if needed
  }

  /// Schedule a notification at a specific date and time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await initialize();

    // Convert to timezone-aware datetime
    final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'task_reminder_channel',
      'Pengingat Jadwal',
      channelDescription: 'Notifikasi pengingat jadwal pemupukan dan NPK',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('✅ Scheduled notification #$id for $scheduledDate');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  /// Show immediate notification (for testing)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Notifikasi untuk testing',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(id, title, body, notificationDetails);
      print('✅ Showed immediate notification #$id');
    } catch (e) {
      print('❌ Error showing notification: $e');
      rethrow;
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get all pending notification requests
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Schedule all fertilization reminders based on planting date
  Future<void> scheduleAllFertilizationReminders({
    required DateTime plantingDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Cancel all existing scheduled notifications
    await cancelAllNotifications();

    // Define all fertilization tasks (same as in history_screen.dart)
    final allTasks = [
      // FASE VEGETATIF (Hari 1-30)
      {'hari': 7, 'task': 'Pupuk Urea (N tinggi)', 'type': 'Vegetatif'},
      {'hari': 14, 'task': 'NPK 20-10-10', 'type': 'Vegetatif'},
      {'hari': 21, 'task': 'Pupuk Organik + Urea', 'type': 'Vegetatif'},
      {'hari': 28, 'task': 'NPK 25-5-5', 'type': 'Vegetatif'},
      // FASE GENERATIF (Hari 31-60)
      {'hari': 35, 'task': 'NPK 15-15-15 (Seimbang)', 'type': 'Generatif'},
      {'hari': 42, 'task': 'TSP/SP-36 (Fosfor)', 'type': 'Generatif'},
      {'hari': 49, 'task': 'NPK 16-16-16', 'type': 'Generatif'},
      {'hari': 56, 'task': 'Pupuk Organik Cair', 'type': 'Generatif'},
      // FASE PEMBUNGAAN (Hari 61-70)
      {'hari': 63, 'task': 'NPK 10-20-20 (P & K tinggi)', 'type': 'Pembungaan'},
      {'hari': 67, 'task': 'Pupuk Daun + KCl', 'type': 'Pembungaan'},
      // FASE PEMBUAHAN (Hari 71-90)
      {'hari': 73, 'task': 'NPK 10-10-30 (K tinggi)', 'type': 'Pembuahan'},
      {'hari': 77, 'task': 'KCl + Kalsium', 'type': 'Pembuahan'},
      {'hari': 82, 'task': 'Pupuk Organik Cair', 'type': 'Pembuahan'},
      {'hari': 87, 'task': 'NPK 8-12-32', 'type': 'Pembuahan'},
      // FASE SIAP PANEN (Hari 90+)
      {'hari': 92, 'task': 'Panen Perdana', 'type': 'Panen'},
      {'hari': 95, 'task': 'NPK Pemeliharaan 10-10-10', 'type': 'Panen'},
      {'hari': 100, 'task': 'Panen Berkala', 'type': 'Panen'},
    ];

    final now = DateTime.now();
    int notificationId = 1000; // Start from 1000 to avoid conflicts

    for (final task in allTasks) {
      final dayNumber = task['hari'] as int;
      final taskName = task['task'] as String;
      final taskType = task['type'] as String;

      // Calculate task date
      final taskDate = plantingDate.add(Duration(days: dayNumber - 1));

      // Schedule notification for Day D (the actual day) at 08:00 AM
      final dayD = DateTime(taskDate.year, taskDate.month, taskDate.day, 8, 0);
      if (dayD.isAfter(now)) {
        await scheduleNotification(
          id: notificationId++,
          title: 'Pengingat Jadwal',
          body: 'Hari ini adalah jadwal $taskName (Hari ke-$dayNumber)',
          scheduledDate: dayD,
        );

        // Save to notification history (will be visible on Day D)
        await _saveNotificationToHistory(
          title: 'Pengingat Jadwal',
          message: 'Hari ini adalah jadwal $taskName (Hari ke-$dayNumber)',
          scheduledDate: dayD,
          taskDay: dayNumber,
          taskName: taskName,
          taskType: taskType,
        );
      }

      // Schedule notification for Day D-1 (one day before) at 08:00 AM
      final dayDMinus1 = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day - 1,
        8,
        0,
      );
      if (dayDMinus1.isAfter(now)) {
        await scheduleNotification(
          id: notificationId++,
          title: 'Pengingat Jadwal',
          body: 'Besok adalah jadwal $taskName (Hari ke-$dayNumber)',
          scheduledDate: dayDMinus1,
        );

        // Save to notification history (will be visible on D-1)
        await _saveNotificationToHistory(
          title: 'Pengingat Jadwal',
          message: 'Besok adalah jadwal $taskName (Hari ke-$dayNumber)',
          scheduledDate: dayDMinus1,
          taskDay: dayNumber,
          taskName: taskName,
          taskType: taskType,
        );
      }
    }

    print('✅ Scheduled ${notificationId - 1000} reminders');
  }

  /// Save notification to Firestore for in-app notification history
  Future<void> _saveNotificationToHistory({
    required String title,
    required String message,
    required DateTime scheduledDate,
    required int taskDay,
    required String taskName,
    required String taskType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('task_notifications')
          .add({
            'title': title,
            'message': message,
            'scheduledDate': scheduledDate.millisecondsSinceEpoch,
            'taskDay': taskDay,
            'taskName': taskName,
            'taskType': taskType,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('❌ Error saving notification to history: $e');
    }
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('task_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Delete all notification history
  static Future<void> clearAllHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('task_notifications')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('❌ Error clearing notification history: $e');
    }
  }
}
