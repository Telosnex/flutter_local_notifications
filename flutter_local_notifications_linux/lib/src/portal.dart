import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';

/// The notification portal (org.freedesktop.portal.Notification).
///
/// Sandboxed apps (Flatpak) must send notifications through the portal: it
/// knows the app ID, and the user controls the app's notifications in the
/// desktop's settings. The portal shows the app's own name and icon.
class NotificationPortal {
  /// Connects to the portal on the session bus.
  NotificationPortal([DBusClient? client])
    : _object = DBusRemoteObject(
        client ?? DBusClient.session(),
        name: 'org.freedesktop.portal.Desktop',
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
      );

  static const String _interface = 'org.freedesktop.portal.Notification';

  final DBusRemoteObject _object;

  /// Whether the app runs in a Flatpak sandbox, where the portal is the
  /// supported way to notify. `FLUTTER_LOCAL_NOTIFICATIONS_PORTAL` set to
  /// `1` or `0` overrides the check.
  static bool get inSandbox {
    final String? force =
        Platform.environment['FLUTTER_LOCAL_NOTIFICATIONS_PORTAL'];
    if (force == '1') {
      return true;
    }
    if (force == '0') {
      return false;
    }
    return File('/.flatpak-info').existsSync();
  }

  /// Shows or replaces the notification [id].
  ///
  /// [defaultAction] is the action name of a click on the notification;
  /// [buttons] maps action names to labels.
  Future<void> add(
    String id, {
    required String title,
    required String body,
    required String defaultAction,
    Map<String, String> buttons = const <String, String>{},
    String? themedIcon,
    bool urgent = false,
  }) => _object.callMethod(_interface, 'AddNotification', <DBusValue>[
    DBusString(id),
    DBusDict.stringVariant(<String, DBusValue>{
      'title': DBusString(title),
      'body': DBusString(body),
      'default-action': DBusString(defaultAction),
      if (urgent) 'priority': const DBusString('urgent'),
      if (themedIcon != null)
        'icon': DBusStruct(<DBusValue>[
          const DBusString('themed'),
          DBusVariant(DBusArray.string(<String>[themedIcon])),
        ]),
      if (buttons.isNotEmpty)
        'buttons': DBusArray(DBusSignature('a{sv}'), <DBusValue>[
          for (final MapEntry<String, String> b in buttons.entries)
            DBusDict.stringVariant(<String, DBusValue>{
              'label': DBusString(b.value),
              'action': DBusString(b.key),
            }),
        ]),
    }),
  ], replySignature: DBusSignature(''));

  /// Withdraws the notification [id].
  Future<void> remove(String id) => _object.callMethod(
    _interface,
    'RemoveNotification',
    <DBusValue>[DBusString(id)],
    replySignature: DBusSignature(''),
  );

  /// Clicks and button presses: (notification id, action name).
  Stream<(String, String)> get actionInvoked =>
      DBusRemoteObjectSignalStream(
        object: _object,
        interface: _interface,
        name: 'ActionInvoked',
        signature: DBusSignature('ssav'),
      ).map(
        (DBusSignal s) => (
          (s.values[0] as DBusString).value,
          (s.values[1] as DBusString).value,
        ),
      );
}
