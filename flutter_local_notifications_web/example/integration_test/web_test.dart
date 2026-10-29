// The web plugin in a browser: initialize (registers the plugin's service
// worker), the notification permission, then one notification shown and
// cancelled. CI grants the permission to the page's origin before the run, so
// requestNotificationsPermission() does not prompt.
//
// The web jobs run this file through test_driver/integration_test.dart, and
// telosnex_web_test keeps the browser console and checks the results.

import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_local_notifications_web/flutter_local_notifications_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telosnex_web_test/telosnex_web_test.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  installWebTestSupport(binding);

  final WebFlutterLocalNotificationsPlugin plugin =
      WebFlutterLocalNotificationsPlugin();

  testWidgets('initialize() registers the service worker', (
    WidgetTester tester,
  ) async {
    expect(WebFlutterLocalNotificationsPlugin.isSupported, isTrue);
    expect(await plugin.initialize(), isTrue);
  });

  testWidgets('the notification permission is granted', (
    WidgetTester tester,
  ) async {
    expect(await plugin.requestNotificationsPermission(), isTrue);
    expect(plugin.permissionStatus, WebNotificationPermission.granted);
  });

  testWidgets('a shown notification is active until it is cancelled', (
    WidgetTester tester,
  ) async {
    const int id = 7;
    await plugin.show(
      id: id,
      title: 'Integration test',
      body: 'A shown notification is active until it is cancelled',
      payload: 'payload',
    );
    await _waitForActive(plugin, id, true);
    await plugin.cancel(id: id);
    await _waitForActive(plugin, id, false);
  });
}

/// Waits until the notification [id] is active ([active] true) or gone.
Future<void> _waitForActive(
  WebFlutterLocalNotificationsPlugin plugin,
  int id,
  bool active,
) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  List<int> ids = <int>[];
  while (stopwatch.elapsed < const Duration(seconds: 10)) {
    ids = <int>[
      for (final ActiveNotification n in await plugin.getActiveNotifications())
        if (n.id != null) n.id!,
    ];
    if (ids.contains(id) == active) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail(
    'Notification $id is ${active ? 'not active' : 'still active'} after '
    '10 s. Active notifications: $ids',
  );
}
