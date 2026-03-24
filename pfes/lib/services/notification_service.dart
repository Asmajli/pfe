import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/models.dart';

// ══════════════════════════════════════════════════════
//  ONESIGNAL NOTIFICATION SERVICE
// ══════════════════════════════════════════════════════
class NotificationService {
  static const appId      = 'bbf1b2c9-e09d-4c2b-839f-3a7e8d0c5337';
  static const restApiKey = 'os_v2_app_xpy3fspatvgcxa47hj7i2dctg6pmvsteb37esdvgzfpmaaqdwqfq3hplvmayzob3tljegctkd6is6kocnairlzzmmdhssbwxuiznr7q';

  // ── Init OneSignal ──────────────────────────────────
  static Future<void> init() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.none);
    OneSignal.initialize(appId);
    await OneSignal.Notifications.requestPermission(true);
  }

  // ── Login user (lie le device au userId) ───────────
  static void setUser(String userId) {
    OneSignal.login(userId);
  }

  static void logoutUser() {
    OneSignal.logout();
  }

  // ── Envoyer notification push via REST API ──────────
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Authorization': 'Key $restApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_aliases': {'external_id': [userId]},
          'target_channel': 'push',
          'headings': {'en': title, 'fr': title},
          'contents': {'en': body, 'fr': body},
          'small_icon': 'ic_stat_onesignal_default',
        }),
      );
    } catch (_) {}
  }
}

// ══════════════════════════════════════════════════════
//  RESERVATION REMINDER SERVICE
// ══════════════════════════════════════════════════════
class ReservationReminderService {
  final _timers = <String, List<Timer>>{};

  void scheduleReminders(Reservation r, String userId) {
    if (r.endTime == null) return;
    cancelReminders(r.id);
    final timers = <Timer>[];
    final now    = DateTime.now();

    // ── 15 min avant ──
    final remind15 = r.endTime!.subtract(const Duration(minutes: 15));
    if (remind15.isAfter(now)) {
      timers.add(Timer(remind15.difference(now), () {
        NotificationService.sendToUser(
          userId: userId,
          title: '⏰ Réservation bientôt expirée',
          body: '${r.zoneName} — Il vous reste 15 min · Place ${r.spotNumber}',
        );
      }));
    }

    // ── 5 min avant ──
    final remind5 = r.endTime!.subtract(const Duration(minutes: 5));
    if (remind5.isAfter(now)) {
      timers.add(Timer(remind5.difference(now), () {
        NotificationService.sendToUser(
          userId: userId,
          title: '🚨 Expire dans 5 min !',
          body: '${r.zoneName} · Place ${r.spotNumber} — Prolonger ?',
        );
      }));
    }

    // ── À l'expiration ──
    if (r.endTime!.isAfter(now)) {
      timers.add(Timer(r.endTime!.difference(now), () {
        NotificationService.sendToUser(
          userId: userId,
          title: '🅿️ Réservation expirée',
          body: '${r.zoneName} · Place ${r.spotNumber} — Merci de libérer la place',
        );
      }));
    }

    if (timers.isNotEmpty) _timers[r.id] = timers;
  }

  void cancelReminders(String id) {
    _timers[id]?.forEach((t) => t.cancel());
    _timers.remove(id);
  }

  void dispose() {
    for (final list in _timers.values) {
      for (final t in list) { t.cancel(); }
    }
    _timers.clear();
  }
}

final reminderServiceProvider = Provider<ReservationReminderService>((ref) {
  final s = ReservationReminderService();
  ref.onDispose(s.dispose);
  return s;
});

// ══════════════════════════════════════════════════════
//  PROLONGATION SERVICE
// ══════════════════════════════════════════════════════
class ProlongationService {
  final _db = FirebaseFirestore.instance;

  Future<DateTime> prolonger({
    required String reservationId,
    required int extraMinutes,
    required double pricePerHour,
  }) async {
    final doc = await _db.collection('reservations').doc(reservationId).get();
    if (!doc.exists) throw 'Réservation introuvable';
    final r = Reservation.fromDoc(doc);
    final newEnd    = (r.endTime ?? DateTime.now()).add(Duration(minutes: extraMinutes));
    final extraCost = (extraMinutes / 60.0) * pricePerHour;
    final newTotal  = (r.totalAmount ?? 0) + extraCost;
    await _db.collection('reservations').doc(reservationId).update({
      'endTime'    : Timestamp.fromDate(newEnd),
      'totalAmount': newTotal,
      'status'     : 'active',
    });
    return newEnd;
  }
}

final prolongationServiceProvider = Provider((_) => ProlongationService());