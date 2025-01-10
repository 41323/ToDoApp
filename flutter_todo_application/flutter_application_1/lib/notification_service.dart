import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
// notification_service.dart
class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 초기화
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    tz.initializeTimeZones(); // 시간대 데이터 초기화
  }


  static const MethodChannel _channel = MethodChannel('com.example.flutter_application_1/permissions');

  static Future<void> requestExactAlarmPermission() async {
    try {
      final bool result = await _channel.invokeMethod('checkExactAlarmPermission');
      if (result) {
        print('Exact alarm permission granted');
      } else {
        print('Exact alarm permission denied');
      }
    } on PlatformException catch (e) {
      print("Failed to get permission: ${e.message}");
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
    // 알람 권한이 거부된 경우 적절히 처리
    print("Exact alarm permission denied");
  }
}

  // 알림을 예약하는 메서드
  static Future<void> showNotification(int id, String title, String body,
      DateTime scheduledTime) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

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

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exact, // 정확한 시간에 알림 예약
      matchDateTimeComponents: DateTimeComponents.dateAndTime, // 예약된 날짜와 시간을 맞춰서 알림 발생
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime, // 필수 매개변수
    );
  }
  

}
