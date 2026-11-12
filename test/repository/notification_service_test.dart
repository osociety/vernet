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
    // Windows skips notifications unless this test-only flag is enabled.
    NotificationService.debugIgnorePlatformCheck = true;
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

  tearDown(() {
    NotificationService.debugIgnorePlatformCheck = false;
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

  test('scan notification publishes to a named channel', () async {
    await NotificationService.showNotificationWithActions(deviceCount: 2);

    final details = verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: captureAny(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).captured.single as NotificationDetails;

    expect(details.android?.channelId, 'device_scans');
    expect(details.android?.channelName, 'Device scans');
    expect(details.android?.channelId,
        isNot(NotificationService.legacyScanChannelId));
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

  test('scan notification names the scan it reports', () async {
    await NotificationService.showNotificationWithActions(
      scanId: 1763,
      deviceCount: 2,
    );

    verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: 'hostscan/1763',
      ),
    ).called(1);
  });

  test('payloads resolve to the scan they name', () {
    expect(
      NotificationService.scanIdFromPayload(
        NotificationService.scanReportPayload(1763),
      ),
      1763,
    );
    expect(NotificationService.scanIdFromPayload('hostscan'), isNull);
    expect(NotificationService.scanIdFromPayload('hostscan/abc'), isNull);
    expect(NotificationService.scanIdFromPayload('server_checker'), isNull);
    expect(NotificationService.scanIdFromPayload(null), isNull);
  });

  test('only scan payloads open a scan report', () {
    expect(NotificationService.isScanPayload('hostscan'), isTrue);
    expect(NotificationService.isScanPayload('hostscan/1763'), isTrue);
    expect(NotificationService.isScanPayload('server_checker'), isFalse);
    expect(NotificationService.isScanPayload(null), isFalse);
    expect(NotificationService.isScanPayload(''), isFalse);
  });
}
