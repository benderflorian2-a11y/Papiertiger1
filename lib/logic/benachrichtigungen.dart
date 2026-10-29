import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdaten;
import 'package:timezone/timezone.dart' as tz;

import '../data/store.dart';
import 'zeitplan.dart';

/// Plant Push-Erinnerungen auf dem Handy, offline und ohne Server.
class Benachrichtigungen {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _bereit = false;
  static bool deaktiviert = false;
  static Timer? _verzoegerung;

  static const _kanal = AndroidNotificationDetails(
    'fristen',
    'Fristen und Termine',
    channelDescription: 'Erinnerungen an Fristen, Kündigungen, Garantien und Termine',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(android: _kanal);
  static const wochenId = 1;

  static Future<void> starten() async {
    if (_bereit || deaktiviert) return;
    tzdaten.initializeTimeZones();
    // Papiertiger ist für Deutschland gemacht.
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _bereit = true;
  }

  /// Fragt (ab Android 13) einmal nach der Erlaubnis für Benachrichtigungen.
  static Future<bool> erlaubnisAnfragen() async {
    if (deaktiviert) return false;
    await starten();
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Nach Änderungen kurz warten, dann alles neu planen.
  static void spaeterPlanen(AppStore store) {
    if (deaktiviert) return;
    _verzoegerung?.cancel();
    _verzoegerung = Timer(const Duration(seconds: 2), () => planen(store));
  }

  static Future<void> planen(AppStore store) async {
    if (deaktiviert) return;
    try {
      await starten();
      await _plugin.cancelAll();
      final e = store.erinnerungen;
      if (!e.aktiv) return;
      final jetzt = DateTime.now();
      final f = faelligkeiten(
          briefe: store.briefe, vertraege: store.vertraege, belege: store.belege, termine: store.termine);
      for (final x in erinnerungenPlanen(f, e, jetzt: jetzt)) {
        await _plugin.zonedSchedule(
          id: x.id,
          scheduledDate: tz.TZDateTime.from(x.zeit, tz.local),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: x.titel,
          body: x.text,
          payload: x.refId,
        );
      }
      if (e.wochenueberblick) {
        // Jeden Montag zur gewählten Uhrzeit.
        var montag = DateTime(jetzt.year, jetzt.month, jetzt.day, e.stunde);
        while (montag.weekday != DateTime.monday || !montag.isAfter(jetzt)) {
          montag = montag.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          id: wochenId,
          scheduledDate: tz.TZDateTime.from(montag, tz.local),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Dein Papierkram diese Woche',
          body: wochenText(f, heute: montag),
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (_) {
      // Erinnerungen dürfen die App nie stören.
    }
  }
}
