import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 초기화 (initNotification 메서드로 이름 변경)
  static Future<void> initNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // 알림 플러그인 초기화
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 시간대 데이터 초기화
    tz.initializeTimeZones(); 
    // 한국 타임존으로 설정 (Asia/Seoul)
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));    

  }

  static const MethodChannel _channel = MethodChannel('com.example.flutter_application_1/permissions');


  // 정확한 알람 권한 요청 메서드
  static Future<void> requestExactAlarmPermission() async {
    final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
    
    if (exactAlarmStatus.isGranted) {
      print("Exact alarm permission granted");
    } else {
      print("Exact alarm permission denied");
    }
  }

  // 권한 요청 메서드
  static Future<void> requestPermissions() async {
    // 알림 권한 요청
    final notificationStatus = await Permission.notification.request();
    if (notificationStatus.isGranted) {
      print("Notification Permission granted");
    } else if (notificationStatus.isDenied) {
      // 사용자가 권한을 거부한 경우, 다시 요청하거나 안내 메시지 표시
      print("Notification Permission denied");
      // 예를 들어 다시 요청할 수도 있습니다:
      final retryStatus = await Permission.notification.request();
      if (retryStatus.isGranted) {
        print("Notification Permission granted on retry");
      } else {
        print("Notification Permission still denied on retry");
      }
    }

    // 정확한 알람 권한 요청
    final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
    if (exactAlarmStatus.isGranted) {
      print("Exact alarm permission granted");
    } else if (exactAlarmStatus.isDenied) {
      print("Exact alarm permission denied");
    }
  }

  // 알림 예약 메서드
  static Future<void> showNotification(
      int id, String title, String body, DateTime scheduledTime) async {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
final tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, scheduledTime.year, scheduledTime.month, scheduledTime.day, scheduledTime.hour, scheduledTime.minute, scheduledTime.second);
final now = tz.TZDateTime.now(tz.local);
    if (scheduledTime.isBefore(now)) {
      print("경고: 과거 시간으로 알림을 설정할 수 없습니다.");
    }
    print('Scheduling notification for $scheduledTime');
    print('Scheduled TZ Date: $scheduledDate');

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'todo_channel',
      'TODO Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails notificationDetails =

        NotificationDetails(android: androidNotificationDetails);

    try {
      // 32비트 범위에 맞게 ID를 수정
      final notificationId = (id % (2 ^ 31)); // 32비트로 ID 제한

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exact,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime, 
      );
      print('---Scheduling notification for $scheduledTime');
      print('---Scheduled TZ Date: $scheduledDate'); 
      print('---Notification scheduled successfully.');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }
}