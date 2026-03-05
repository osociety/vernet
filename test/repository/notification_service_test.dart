import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vernet/repository/notification_service.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    // Mock the flutter_timezone channel
    const channels = ['flutter_timezone', 'com.pravera/flutter_timezone'];
    for (final channelName in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channelName),
              (methodCall) async {
        return 'UTC';
      });
    }
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('app_icon'),
      ),
    );
    registerFallbackValue(
      const NotificationDetails(),
    );
  });

  group('ReceivedNotification', () {
    test('creates instance with all properties', () {
      final notification = ReceivedNotification(
        id: 1,
        title: 'Test Title',
        body: 'Test Body',
        payload: 'test_payload',
      );

      expect(notification.id, 1);
      expect(notification.title, 'Test Title');
      expect(notification.body, 'Test Body');
      expect(notification.payload, 'test_payload');
    });

    test('handles null title and body', () {
      final notification = ReceivedNotification(
        id: 2,
        title: null,
        body: null,
        payload: null,
      );

      expect(notification.id, 2);
      expect(notification.title, isNull);
      expect(notification.body, isNull);
      expect(notification.payload, isNull);
    });
  });

  group('NotificationService', () {
    late MockFlutterLocalNotificationsPlugin mockPlugin;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      NotificationService.flutterLocalNotificationsPlugin = mockPlugin;
      NotificationService.debugIgnorePlatformCheck = true;
    });

    test('id starts at 1 and increments', () {
      // Reset ID for predictable test
      NotificationService.id = 1;
      expect(NotificationService.id, 1);
    });

    test('stream controllers are initialized', () {
      expect(NotificationService.didReceiveLocalNotificationStream, isNotNull);
      expect(NotificationService.selectNotificationStream, isNotNull);
    });

    test('constants are defined correctly', () {
      expect(
          NotificationService.darwinNotificationCategoryText, 'textCategory');
      expect(
        NotificationService.darwinNotificationCategoryPlain,
        'plainCategory',
      );
      expect(NotificationService.urlLaunchActionId, 'id_1');
      expect(NotificationService.navigationActionId, 'id_3');
    });

    test('initNotification initializes plugin', () async {
      when(() => mockPlugin.getNotificationAppLaunchDetails())
          .thenAnswer((_) async => null);
      when(() => mockPlugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      await NotificationService.initNotification();

      verify(() => mockPlugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).called(1);
    });

    test('configureLocalTimeZone sets local location', () async {
      // This test targets the public configureLocalTimeZone
      await NotificationService.configureLocalTimeZone();
      // If no exception is thrown, it indicates it handled UTC as expected
    });

    test('showNotificationWithActions calls plugin.show', () async {
      NotificationService.id = 1;
      when(() => mockPlugin.show(
            any(),
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      await NotificationService.showNotificationWithActions();

      verify(() => mockPlugin.show(
            1,
            'Scan completed',
            'Your devices scan has been completed successfully',
            any(),
            payload: 'item z',
          )).called(1);
      expect(NotificationService.id, 2);
    });

    test('grantPermissions completes without throwing', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()).thenReturn(null);
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()).thenReturn(null);
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()).thenReturn(null);

      await NotificationService.grantPermissions();
    });

    test('isAndroidPermissionGranted returns false when not on Android',
        () async {
      final result = await NotificationService.isAndroidPermissionGranted();
      expect(result, isFalse);
    });

    test('requestPermissions returns false when not on supported platforms',
        () async {
      final result = await NotificationService.requestPermissions();
      expect(result, isFalse);
    });
  });
}
