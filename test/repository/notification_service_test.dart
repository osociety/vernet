import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vernet/repository/notification_service.dart';

class MockLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalNotificationsPlugin plugin;

  setUp(() {
    plugin = MockLocalNotificationsPlugin();
    NotificationService.flutterLocalNotificationsPlugin = plugin;
    when(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
  });

  test('scan notification includes device count and navigation action',
      () async {
    await NotificationService.showNotificationWithActions(deviceCount: 3);

    final details = verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: 'Device search complete',
        body: 'Scan complete - found 3 devices on your network',
        notificationDetails: captureAny(named: 'notificationDetails'),
        payload: NotificationService.hostScanPayload,
      ),
    ).captured.single as NotificationDetails;

    expect(
      details.android?.actions?.single.id,
      NotificationService.navigationActionId,
    );
    expect(
      details.linux?.actions.single.key,
      NotificationService.navigationActionId,
    );
  });

  test('scan notification uses singular wording for one device', () async {
    await NotificationService.showNotificationWithActions(deviceCount: 1);

    verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: 'Device search complete',
        body: 'Scan complete - found 1 device on your network',
        notificationDetails: any(named: 'notificationDetails'),
        payload: NotificationService.hostScanPayload,
      ),
    ).called(1);
  });

  test('scan notification keeps generic body without a count', () async {
    await NotificationService.showNotificationWithActions();

    verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: 'Device search complete',
        body: 'Vernet finished looking for devices on your network',
        notificationDetails: any(named: 'notificationDetails'),
        payload: NotificationService.hostScanPayload,
      ),
    ).called(1);
  });
}
