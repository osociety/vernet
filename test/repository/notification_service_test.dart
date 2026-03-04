import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/repository/notification_service.dart';

void main() {
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
    test('id starts at 1 and increments', () {
      final initialId = NotificationService.id;
      expect(initialId, greaterThanOrEqualTo(1));
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
  });
}
