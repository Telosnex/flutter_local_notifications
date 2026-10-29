@TestOn('linux')
library;

import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_local_notifications_linux/src/portal.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake org.freedesktop.portal.Notification on a private bus.
class FakePortal extends DBusObject {
  FakePortal() : super(DBusObjectPath('/org/freedesktop/portal/desktop'));

  final List<(String, Map<String, DBusValue>)> added =
      <(String, Map<String, DBusValue>)>[];
  final List<String> removed = <String>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != 'org.freedesktop.portal.Notification') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (call.name) {
      case 'AddNotification':
        expect(call.signature, DBusSignature('sa{sv}'));
        added.add((
          (call.values[0] as DBusString).value,
          (call.values[1] as DBusDict).mapStringVariant(),
        ));
        return DBusMethodSuccessResponse();
      case 'RemoveNotification':
        removed.add((call.values[0] as DBusString).value);
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

void main() {
  late DBusServer server;
  late DBusClient portalSide;
  late DBusClient appSide;
  late FakePortal fake;

  setUp(() async {
    server = DBusServer();
    final Directory dir = await Directory.systemTemp.createTemp('portal_test');
    final DBusAddress address = await server.listenAddress(
      DBusAddress.unix(path: '${dir.path}/bus'),
    );
    portalSide = DBusClient(address);
    appSide = DBusClient(address);
    await portalSide.requestName('org.freedesktop.portal.Desktop');
    fake = FakePortal();
    await portalSide.registerObject(fake);
  });

  tearDown(() async {
    await appSide.close();
    await portalSide.close();
    await server.close();
  });

  test('AddNotification carries title, body, actions and icon', () async {
    final NotificationPortal portal = NotificationPortal(appSide);
    await portal.add(
      'flutter_local_notifications_7',
      title: 'Done',
      body: 'Your run finished',
      defaultAction: 'default',
      buttons: <String, String>{'open': 'Open', 'dismiss': 'Dismiss'},
      themedIcon: 'dialog-information',
      urgent: true,
    );
    final (String id, Map<String, DBusValue> n) = fake.added.single;
    expect(id, 'flutter_local_notifications_7');
    expect(n['title'], const DBusString('Done'));
    expect(n['body'], const DBusString('Your run finished'));
    expect(n['default-action'], const DBusString('default'));
    expect(n['priority'], const DBusString('urgent'));
    final List<Map<String, DBusValue>> buttons = (n['buttons']! as DBusArray)
        .children
        .map((DBusValue b) => (b as DBusDict).mapStringVariant())
        .toList();
    expect(buttons.map((Map<String, DBusValue> b) => b['action']), <DBusValue>[
      const DBusString('open'),
      const DBusString('dismiss'),
    ]);
    expect(
      (n['icon']! as DBusStruct).children.first,
      const DBusString('themed'),
    );
  });

  test('RemoveNotification and ActionInvoked', () async {
    final NotificationPortal portal = NotificationPortal(appSide);
    await portal.remove('flutter_local_notifications_7');
    expect(fake.removed, <String>['flutter_local_notifications_7']);

    final Future<(String, String)> next = portal.actionInvoked.first;
    // Let the match rule reach the bus before the signal is emitted.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await fake.emitSignal(
      'org.freedesktop.portal.Notification',
      'ActionInvoked',
      <DBusValue>[
        const DBusString('flutter_local_notifications_7'),
        const DBusString('open'),
        DBusArray.variant(<DBusValue>[]),
      ],
    );
    expect(await next.timeout(const Duration(seconds: 5)), (
      'flutter_local_notifications_7',
      'open',
    ));
  });
}
