import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vernet/values/globals.dart' as globals;

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

class NotificationService {
  static int id = 1;
  @visibleForTesting
  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  @visibleForTesting
  static bool debugIgnorePlatformCheck = false;
  @visibleForTesting
  static bool skipPermissionRequests = false;

  /// Defines a iOS/MacOS notification category for text input actions.
  static const String darwinNotificationCategoryText = 'textCategory';

  /// Defines a iOS/MacOS notification category for plain actions.
  static const String darwinNotificationCategoryPlain = 'plainCategory';

  /// A notification action which triggers a App navigation event
  static const String navigationActionId = 'id_3';

  /// Payload used for notifications that should open the device scan page.
  static const String hostScanPayload = 'hostscan';

  static String? selectedNotificationPayload;

  /// Streams are created so that app can respond to notification-related events
  /// since the plugin is initialised in the `main` function
  static final StreamController<ReceivedNotification>
      didReceiveLocalNotificationStream =
      StreamController<ReceivedNotification>.broadcast();

  static final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  static Future<void> initNotification() async {
    if (Platform.isWindows && !debugIgnorePlatformCheck) {
      return await Future.value();
    }
    await configureLocalTimeZone();
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        !kIsWeb && Platform.isLinux
            ? null
            : await flutterLocalNotificationsPlugin
                .getNotificationAppLaunchDetails();
    // String initialRoute = HomePage.routeName;
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      selectedNotificationPayload =
          notificationAppLaunchDetails!.notificationResponse?.payload;
      // initialRoute = SecondPage.routeName;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    final List<DarwinNotificationCategory> darwinNotificationCategories =
        <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        darwinNotificationCategoryText,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.text(
            'view_scan',
            'View scan',
            buttonTitle: 'View',
            placeholder: 'Placeholder',
          ),
        ],
      ),
    ];

    /// Note: permissions aren't requested here just to demonstrate that can be
    /// done later
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: darwinNotificationCategories,
    );
    final LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
      defaultIcon: AssetsLinuxIcon('app_icon.png'),
    );
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        switch (notificationResponse.notificationResponseType) {
          case NotificationResponseType.selectedNotification:
            selectNotificationStream.add(notificationResponse.payload);
          case NotificationResponseType.selectedNotificationAction:
            if (notificationResponse.actionId == navigationActionId) {
              selectNotificationStream.add(notificationResponse.payload);
            }
          case NotificationResponseType.notificationDismissed:
            break;
        }
      },
    );
  }

  static Future<void> configureLocalTimeZone() async {
    if (kIsWeb || Platform.isLinux) {
      return;
    }
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo.identifier;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static Future<void> showNotificationWithActions({int? deviceCount}) async {
    if (globals.testingActive) {
      // Because notification is not working in test mode in github actions
      return;
    }
    if (Platform.isWindows && !debugIgnorePlatformCheck) {
      return await Future.value();
    }
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'Notifications about device searches',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          navigationActionId,
          'View',
        ),
      ],
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      categoryIdentifier: darwinNotificationCategoryPlain,
    );

    const DarwinNotificationDetails macOSNotificationDetails =
        DarwinNotificationDetails(
      categoryIdentifier: darwinNotificationCategoryPlain,
    );

    const LinuxNotificationDetails linuxNotificationDetails =
        LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: navigationActionId,
          label: 'View',
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
      macOS: macOSNotificationDetails,
      linux: linuxNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      id: id++,
      title: 'Device search complete',
      body: deviceCount == null
          ? 'Vernet finished looking for devices on your network'
          : 'Scan complete - found ${_deviceCountLabel(deviceCount)} '
              'on your network',
      notificationDetails: notificationDetails,
      payload: hostScanPayload,
    );
  }

  static Future<void> showServerDownAlert(String serverName) async {
    if (Platform.isWindows && !debugIgnorePlatformCheck) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'server_alerts',
        'Server alerts',
        channelDescription: 'Alerts when a monitored server is unreachable',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );
    await flutterLocalNotificationsPlugin.show(
      id: id++,
      title: 'Server is unreachable',
      body: '$serverName is down',
      notificationDetails: details,
      payload: 'server_checker',
    );
  }

  static Future<void> grantPermissions() async {
    if (Platform.isWindows && !debugIgnorePlatformCheck) {
      return await Future.value();
    }
    if (skipPermissionRequests || globals.testingActive) {
      return await Future.value();
    }
    await isAndroidPermissionGranted();
    await requestPermissions();
  }

  static Future<bool> isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      return await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    return false;
  }

  static Future<bool?> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      if (!_isNotificationsPlatformAvailable()) {
        return false;
      }
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      if (!_isNotificationsPlatformAvailable()) {
        return false;
      }
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      return await androidImplementation?.requestNotificationsPermission();
    }
    return false;
  }

  static bool _isNotificationsPlatformAvailable() {
    try {
      FlutterLocalNotificationsPlatform.instance;
      return true;
    } catch (_) {
      return false;
    }
  }
}

String _deviceCountLabel(int count) =>
    '$count ${count == 1 ? 'device' : 'devices'}';
