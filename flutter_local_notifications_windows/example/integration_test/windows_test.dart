// The Windows plugin in the example app: initialize, then one notification
// shown and cancelled. Windows has no permission request: an unpackaged app
// can show notifications after initialize() registers its AUMID.

import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_local_notifications_windows/flutter_local_notifications_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const WindowsInitializationSettings _settings = WindowsInitializationSettings(
  appName: 'flutter_local_notifications_windows example',
  appUserModelId: 'com.dexterous.flutterLocalNotificationsWindowsExample',
  guid: 'b4c2b1a3-6f0e-4d58-9a1e-3c6f2d7e8a90',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsWindows plugin =
      FlutterLocalNotificationsWindows();

  testWidgets('initialize() succeeds', (WidgetTester tester) async {
    expect(await plugin.initialize(settings: _settings), isTrue);
  });

  testWidgets('show() and cancel() complete', (WidgetTester tester) async {
    await plugin.show(id: 1, title: 'Integration test', body: 'show()');
    await plugin.cancel(id: 1);
  });

  testWidgets('a shown notification is active until it is cancelled', (
    WidgetTester tester,
  ) async {
    const int id = 2;
    await plugin.show(
      id: id,
      title: 'Integration test',
      body: 'A shown notification is active until it is cancelled',
    );
    await _waitForActive(plugin, id, true);
    await plugin.cancel(id: id);
    await _waitForActive(plugin, id, false);
  });
}

/// Waits until the notification [id] is active ([active] true) or gone.
Future<void> _waitForActive(
  FlutterLocalNotificationsWindows plugin,
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
