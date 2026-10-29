import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_local_notifications_linux/flutter_local_notifications_linux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Stands in for org.freedesktop.Notifications on the session bus and records
/// what the plugin sends.
class FakeNotificationServer extends DBusObject {
  FakeNotificationServer()
    : super(DBusObjectPath('/org/freedesktop/Notifications'));

  final List<List<DBusValue>> notifyCalls = <List<DBusValue>>[];
  final List<int> closedIds = <int>[];
  int _nextId = 1;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    switch (methodCall.name) {
      case 'Notify':
        notifyCalls.add(methodCall.values);
        return DBusMethodSuccessResponse(<DBusValue>[DBusUint32(_nextId++)]);
      case 'GetCapabilities':
        return DBusMethodSuccessResponse(<DBusValue>[
          DBusArray.string(<String>['body', 'actions', 'persistence']),
        ]);
      case 'CloseNotification':
        closedIds.add((methodCall.values[0] as DBusUint32).value);
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

/// Stands in for org.freedesktop.portal.Desktop, the notification portal of a
/// Flatpak sandbox, and records what the plugin sends.
class FakeNotificationPortal extends DBusObject {
  FakeNotificationPortal()
    : super(DBusObjectPath('/org/freedesktop/portal/desktop'));

  final List<String> addedIds = <String>[];
  final List<String> removedIds = <String>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.portal.Notification') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (methodCall.name) {
      case 'AddNotification':
        addedIds.add((methodCall.values[0] as DBusString).value);
        return DBusMethodSuccessResponse();
      case 'RemoveNotification':
        removedIds.add((methodCall.values[0] as DBusString).value);
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // CI runs this file twice: once with the plugin's default D-Bus path and
  // once with FLUTTER_LOCAL_NOTIFICATIONS_PORTAL=1, which takes the Flatpak
  // notification-portal path.
  final bool portalMode =
      Platform.environment['FLUTTER_LOCAL_NOTIFICATIONS_PORTAL'] == '1';

  const LinuxInitializationSettings settings = LinuxInitializationSettings(
    defaultActionName: 'Open notification',
  );

  late DBusClient bus;
  late FakeNotificationServer notifications;
  late FakeNotificationPortal portal;

  setUpAll(() async {
    bus = DBusClient.session();
    notifications = FakeNotificationServer();
    portal = FakeNotificationPortal();
    await bus.registerObject(notifications);
    await bus.registerObject(portal);
    expect(
      await bus.requestName('org.freedesktop.Notifications'),
      DBusRequestNameReply.primaryOwner,
    );
    expect(
      await bus.requestName('org.freedesktop.portal.Desktop'),
      DBusRequestNameReply.primaryOwner,
    );
  });

  tearDownAll(() async {
    await bus.close();
  });

  group('flutter_local_notifications_linux on Linux '
      '(${portalMode ? 'portal' : 'D-Bus'})', () {
    testWidgets('initialize returns true', (WidgetTester tester) async {
      final LinuxFlutterLocalNotificationsPlugin plugin =
          LinuxFlutterLocalNotificationsPlugin();
      expect(await plugin.initialize(settings: settings), isTrue);
    });

    testWidgets('show sends the notification to the right service', (
      WidgetTester tester,
    ) async {
      final LinuxFlutterLocalNotificationsPlugin plugin =
          LinuxFlutterLocalNotificationsPlugin();
      await plugin.initialize(settings: settings);
      await plugin.show(id: 4242, title: 'Hello', body: 'World');
      if (portalMode) {
        expect(portal.addedIds, isNotEmpty);
        expect(notifications.notifyCalls, isEmpty);
      } else {
        expect(notifications.notifyCalls, hasLength(1));
        final DBusValue summary = notifications.notifyCalls.last[3];
        expect((summary as DBusString).value, 'Hello');
        expect(portal.addedIds, isEmpty);
      }
    });

    testWidgets('cancel removes the notification', (WidgetTester tester) async {
      final LinuxFlutterLocalNotificationsPlugin plugin =
          LinuxFlutterLocalNotificationsPlugin();
      await plugin.initialize(settings: settings);
      await plugin.show(id: 7, title: 'Cancel me', body: 'body');
      await plugin.cancel(id: 7);
      if (portalMode) {
        expect(portal.removedIds, isNotEmpty);
      } else {
        expect(notifications.closedIds, isNotEmpty);
      }
    });

    testWidgets('getCapabilities reports the capabilities', (
      WidgetTester tester,
    ) async {
      final LinuxFlutterLocalNotificationsPlugin plugin =
          LinuxFlutterLocalNotificationsPlugin();
      await plugin.initialize(settings: settings);
      final LinuxServerCapabilities capabilities = await plugin
          .getCapabilities();
      expect(capabilities.body, isTrue);
      // The portal path reports what every desktop supports; the D-Bus path
      // reports what the notification server said.
      expect(capabilities.persistence, !portalMode);
    });
  });
}
