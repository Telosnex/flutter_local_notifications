import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');
  const IOSInitializationSettings initializationSettingsIOS =
      IOSInitializationSettings();
  // macOS has no way to grant the permission without a user (see
  // _macOSNotAuthorized), so the tests do not request it there.
  const DarwinInitializationSettings initializationSettingsMacOS =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
        defaultActionName: 'Open notification',
        defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
      );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
    macOS: initializationSettingsMacOS,
    linux: initializationSettingsLinux,
  );
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  group('initialize()', () {
    setUpAll(() async {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    });
    // initialize() returns whether notifications were authorized on iOS and
    // macOS.
    group('when notifications are authorized', () {
      testWidgets('can initialise', (WidgetTester tester) async {
        final bool? initialised = await flutterLocalNotificationsPlugin
            .initialize(settings: initializationSettings);
        expect(initialised, isTrue);
      });
    }, skip: Platform.isMacOS ? _macOSNotAuthorized : false);

    testWidgets(
      'initialize with settings equal to null for the targeting platform '
      'should throw an ArgumentError',
      (WidgetTester tester) async {
        const InitializationSettings initializationSettings =
            InitializationSettings();
        late Matcher errorMessageMatcher;
        if (Platform.isAndroid) {
          errorMessageMatcher = equals(
            'Android settings must be set when targeting Android platform.',
          );
        } else if (Platform.isIOS) {
          errorMessageMatcher = equals(
            'iOS settings must be set when targeting iOS platform.',
          );
        } else if (Platform.isLinux) {
          errorMessageMatcher = equals(
            'Linux settings must be set when targeting Linux platform.',
          );
        } else if (Platform.isMacOS) {
          errorMessageMatcher = equals(
            'macOS settings must be set when targeting macOS platform.',
          );
        } else {
          errorMessageMatcher = anything;
        }
        expect(
          () async => await flutterLocalNotificationsPlugin.initialize(
            settings: initializationSettings,
          ),
          throwsA(
            isArgumentError.having(
              (ArgumentError e) => e.message,
              'message',
              errorMessageMatcher,
            ),
          ),
        );
      },
    );
  });
  group('resolvePlatformSpecificImplementation()', () {
    setUpAll(() async {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
    });

    if (Platform.isIOS) {
      testWidgets('Can resolve iOS plugin implementation when running on iOS', (
        WidgetTester tester,
      ) async {
        expect(
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >(),
          isA<IOSFlutterLocalNotificationsPlugin>(),
        );
      });
    }

    if (Platform.isAndroid) {
      testWidgets(
        'Can resolve Android plugin implementation when running on Android',
        (WidgetTester tester) async {
          expect(
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >(),
            isA<AndroidFlutterLocalNotificationsPlugin>(),
          );
        },
      );
    }

    if (Platform.isIOS) {
      testWidgets(
        'Returns null trying to resolve Android plugin implementation when '
        'running on iOS',
        (WidgetTester tester) async {
          expect(
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >(),
            isNull,
          );
        },
      );
    }
    if (Platform.isAndroid) {
      testWidgets(
        'Returns null trying to resolve iOS plugin implementation when '
        'running on Android',
        (WidgetTester tester) async {
          expect(
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >(),
            isNull,
          );
        },
      );
    }

    testWidgets('Throws argument error requesting base class type', (
      WidgetTester tester,
    ) async {
      expect(
        () => flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation(),
        throwsArgumentError,
      );
    });
  });

  // CI grants the permission before the test: `pm grant ... POST_NOTIFICATIONS`
  // on Android, applesimutils on the iOS simulator.
  group('show() and cancel()', () {
    setUpAll(() async {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
    });

    // On every platform: the calls go through the plugin without an error.
    testWidgets('show() and cancel() complete', (WidgetTester tester) async {
      await flutterLocalNotificationsPlugin.show(
        id: 1,
        title: 'Integration test',
        body: 'show() and cancel() complete',
        notificationDetails: _details,
      );
      await flutterLocalNotificationsPlugin.cancel(id: 1);
    });

    group('when notifications are authorized', () {
      testWidgets('the notification permission is granted', (
        WidgetTester tester,
      ) async {
        if (Platform.isAndroid) {
          final AndroidFlutterLocalNotificationsPlugin android =
              flutterLocalNotificationsPlugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()!;
          expect(await android.requestNotificationsPermission(), isTrue);
          expect(await android.areNotificationsEnabled(), isTrue);
        } else if (Platform.isIOS) {
          final IOSFlutterLocalNotificationsPlugin ios =
              flutterLocalNotificationsPlugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()!;
          expect(
            await ios.requestPermissions(alert: true, badge: true, sound: true),
            isTrue,
          );
        }
      });

      testWidgets('a shown notification is active until it is cancelled', (
        WidgetTester tester,
      ) async {
        const int id = 2;
        await flutterLocalNotificationsPlugin.show(
          id: id,
          title: 'Integration test',
          body: 'A shown notification is active until it is cancelled',
          notificationDetails: _details,
        );
        await _waitForActive(flutterLocalNotificationsPlugin, id, true);
        await flutterLocalNotificationsPlugin.cancel(id: id);
        await _waitForActive(flutterLocalNotificationsPlugin, id, false);
      });
    }, skip: Platform.isMacOS ? _macOSNotAuthorized : false);
  });
}

/// Why the notification tests are skipped on macOS.
const String _macOSNotAuthorized =
    'macOS cannot grant the notification permission without a user: there is '
    'no simctl or applesimutils for it. On a CI runner, requestAuthorization '
    'waits for a prompt nobody answers. Locally, usernoted rejects the ad-hoc '
    'signed test app ("Failed to validate ... for use with identifier"). '
    'Unauthorized, nothing is delivered.';

const NotificationDetails _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'integration_test',
    'Integration test',
    channelDescription: 'Notifications of the integration test',
  ),
);

/// Waits until the notification [id] is active ([active] true) or gone.
Future<void> _waitForActive(
  FlutterLocalNotificationsPlugin plugin,
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
