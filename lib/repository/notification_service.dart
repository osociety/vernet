import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vernet/utils/app_strings.dart';
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

  /// Payload naming the scan list, used before the id was carried and for a
  /// scan whose row could not be read.
  static const String hostScanPayload = 'hostscan';

  /// Prefix of a payload naming the scan whose report to open.
  static const String scanReportPayloadPrefix = '$hostScanPayload/';

  /// Payload of the report for the scan [scanId].
  static String scanReportPayload(int scanId) =>
      '$scanReportPayloadPrefix$scanId';

  /// True for the payloads that should open a scan report. Notifications are
  /// delivered after an upgrade too, so the payload without an id still works.
  static bool isScanPayload(String? payload) =>
      payload == hostScanPayload ||
      (payload != null && payload.startsWith(scanReportPayloadPrefix));

  /// The scan named by [payload], or null meaning the most recent scan.
  static int? scanIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(scanReportPayloadPrefix)) {
      return null;
    }
    return int.tryParse(payload.substring(scanReportPayloadPrefix.length));
  }

  /// Channel carrying the scan-complete notifications.
  static const String scanChannelId = 'device_scans';

  /// Android shows this beside the channel id in its own settings screen, so it
  /// follows the language the app is running in.
  static String get scanChannelName => appStrings().notifScanChannelName;

  /// The placeholder channel id shipped before this rename. Android keeps a
  /// channel until it is deleted, so it would linger in the app's settings.
  static const String legacyScanChannelId = 'your channel id';

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
    final l10n = appStrings();
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

    // Must be a drawable resource name, and Android paints the status-bar icon
    // from its alpha channel only, so ic_notification is a white silhouette of
    // the Vernet mark cut from assets/app_icon.png, not the full-colour icon.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    final List<DarwinNotificationCategory> darwinNotificationCategories =
        <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        darwinNotificationCategoryText,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.text(
            'view_scan',
            l10n.notifViewScanAction,
            buttonTitle: l10n.notifViewAction,
            placeholder: l10n.notifViewScanPlaceholder,
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
      defaultActionName: l10n.notifLinuxAction,
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

    // The rename above orphans the placeholder channel, and Android keeps
    // channels until they are deleted, so drop it on startup. This runs before
    // runApp, so a failed cleanup must not hold the app hostage.
    if (Platform.isAndroid) {
      try {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.deleteNotificationChannel(channelId: legacyScanChannelId);
      } catch (error) {
        debugPrint('Could not remove the legacy channel: $error');
      }
    }
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

  static Future<void> showNotificationWithActions({
    int? scanId,
    int? deviceCount,
  }) async {
    if (globals.testingActive) {
      // Because notification is not working in test mode in github actions
      return;
    }
    if (Platform.isWindows && !debugIgnorePlatformCheck) {
      return await Future.value();
    }
    final l10n = appStrings();
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      scanChannelId,
      scanChannelName,
      channelDescription: l10n.notifScanChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          navigationActionId,
          l10n.notifViewAction,
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

    final LinuxNotificationDetails linuxNotificationDetails =
        LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: navigationActionId,
          label: l10n.notifViewAction,
        ),
      ],
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
      macOS: macOSNotificationDetails,
      linux: linuxNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      id: id++,
      title: l10n.notifScanDoneTitle,
      body: deviceCount == null
          ? l10n.notifScanDoneBody
          : l10n.notifScanFoundBody(
              deviceCount == 1
                  ? l10n.deviceCountOne
                  : l10n.deviceCountMany('$deviceCount'),
            ),
      notificationDetails: notificationDetails,
      payload: scanId == null ? hostScanPayload : scanReportPayload(scanId),
    );
  }

  static Future<void> showServerDownAlert(String serverName) async {
    if (Platform.isWindows && !debugIgnorePlatformCheck) return;
    final l10n = appStrings();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'server_alerts',
        l10n.notifServerChannelName,
        channelDescription: l10n.notifServerChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
    );
    await flutterLocalNotificationsPlugin.show(
      id: id++,
      title: l10n.notifServerDownTitle,
      body: l10n.notifServerDownBody(serverName),
      notificationDetails: details,
      payload: 'server_checker',
    );
  }

  /// Channel carrying the alerts for devices that are not trusted.
  static const String untrustedChannelId = 'untrusted_devices';

  static String get untrustedChannelName =>
      appStrings().notifUntrustedChannelName;

  /// Payload that opens the trusted devices screen when the alert is tapped.
  static const String untrustedDevicesPayload = 'untrusted_devices';

  static bool isUntrustedDevicesPayload(String? payload) =>
      payload == untrustedDevicesPayload;

  static Future<void> showUntrustedDevicesAlert(
    List<String> devices,
  ) async {
    if (devices.isEmpty) return;
    if (globals.testingActive) {
      return;
    }
    if (Platform.isWindows && !debugIgnorePlatformCheck) {
      return await Future.value();
    }
    final l10n = appStrings();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        untrustedChannelId,
        untrustedChannelName,
        channelDescription: l10n.notifUntrustedChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            navigationActionId,
            l10n.notifViewAction,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: darwinNotificationCategoryPlain,
      ),
      macOS: const DarwinNotificationDetails(
        categoryIdentifier: darwinNotificationCategoryPlain,
      ),
      linux: LinuxNotificationDetails(
        actions: <LinuxNotificationAction>[
          LinuxNotificationAction(
            key: navigationActionId,
            label: l10n.notifViewAction,
          ),
        ],
      ),
    );
    final listed = devices.take(3).join(', ');
    final body = devices.length == 1
        ? l10n.notifUntrustedBodyOne(devices.single)
        : l10n.notifUntrustedBodyMany(
            '${devices.length}',
            devices.length > 3
                ? '$listed ${l10n.notifUntrustedMore('${devices.length - 3}')}'
                : listed,
          );
    await flutterLocalNotificationsPlugin.show(
      id: id++,
      title: l10n.notifUntrustedTitle,
      body: body,
      notificationDetails: details,
      payload: untrustedDevicesPayload,
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
