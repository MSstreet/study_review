// services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'logger_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _hasPermission = false;

  NotificationService._init();

  Future<bool> initialize() async {
    if (_isInitialized) return _hasPermission;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false, // 수동으로 권한 요청
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final initialized = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = initialized ?? false;
      
      if (_isInitialized) {
        LoggerService.info('Notification service initialized successfully');
      }

      return _isInitialized;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize notification service', error: e, stackTrace: stackTrace);
      _isInitialized = false;
      return false;
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    LoggerService.info('Notification tapped: ${notificationResponse.id}');
    // 알림 탭 시 특정 화면으로 이동하는 로직 추가 가능
  }

  Future<bool> requestPermission(BuildContext context) async {
    if (_hasPermission) return true;

    try {
      if (Platform.isAndroid) {
        // Android 13+ 권한 요청
        final androidImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          final exactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
          final notificationPermission = await androidImplementation.requestNotificationsPermission();
          
          _hasPermission = (exactAlarmPermission ?? false) && (notificationPermission ?? false);
        }
      } else if (Platform.isIOS) {
        final iosImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        
        if (iosImplementation != null) {
          _hasPermission = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ?? false;
        }
      }

      if (_hasPermission) {
        LoggerService.info('Notification permission granted');
      } else {
        LoggerService.warning('Notification permission denied');
        _showPermissionDialog(context);
      }

      return _hasPermission;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to request notification permission', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('알림 권한 필요'),
        content: Text('복습 알림을 받으려면 알림 권한을 허용해주세요.\n설정에서 직접 권한을 허용할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('나중에'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 설정 앱으로 이동하는 로직 추가 가능
            },
            child: Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<bool> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized || !_hasPermission) {
      LoggerService.warning('Cannot show notification: not initialized or no permission');
      return false;
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'review_channel',
        '복습 알림',
        channelDescription: '복습 시간을 알려주는 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      LoggerService.info('Immediate notification shown: $title');
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to show immediate notification', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized || !_hasPermission) {
      LoggerService.warning('Cannot schedule notification: not initialized or no permission');
      return false;
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'review_channel',
        '복습 알림',
        channelDescription: '복습 시간을 알려주는 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'complete_action',
            '완료',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_check'),
          ),
          AndroidNotificationAction(
            'later_action',
            '나중에',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_schedule'),
          ),
        ],
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      LoggerService.info('Notification scheduled: ID $id for ${scheduledDate.toString()}');
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to schedule notification', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      LoggerService.info('Notification cancelled: ID $id');
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to cancel notification', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      LoggerService.info('All notifications cancelled');
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to cancel all notifications', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get pending notifications', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // 테스트용 메서드들
  Future<bool> scheduleTestNotificationIn10Seconds() async {
    final scheduledDate = DateTime.now().add(Duration(seconds: 10));
    return await scheduleNotification(
      id: 999,
      title: '테스트 알림',
      body: '10초 후 알림이 정상적으로 작동합니다!',
      scheduledDate: scheduledDate,
    );
  }

  Future<bool> scheduleTestNotificationIn1Minute() async {
    final scheduledDate = DateTime.now().add(Duration(minutes: 1));
    return await scheduleNotification(
      id: 998,
      title: '복습 알림 테스트',
      body: '1분 후 알림 테스트입니다. 복습할 내용이 있습니다!',
      scheduledDate: scheduledDate,
    );
  }

  // 권한 상태 확인
  bool get hasPermission => _hasPermission;
  bool get isInitialized => _isInitialized;
}