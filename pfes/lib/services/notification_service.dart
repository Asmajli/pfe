import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
// ══════════════════════════════════════════════════════
//  AUTO SYNC SERVICE — appelé par Workmanager
//  Fonctionne app fermée ✅
// ══════════════════════════════════════════════════════
class AutoSyncService {
  final _db = FirebaseFirestore.instance;

  static const String _appId  = 'bbf1b2c9-e09d-4c2b-839f-3a7e8d0c5337';
  static const String _apiKey =
      'os_v2_app_xpy3fspatvgcxa47hj7i2dctg6v2qmnd6hbudnupe6albhpkhcuucma4otl3acn5kh4esqsl6dvw7wzpkcskf2fgjnoxlihu5qewfzq';

  Future<void> syncAndNotify(String userId) async {
    final now  = DateTime.now();
    final snap = await _db
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['upcoming', 'active']).get();

    for (final doc in snap.docs) {
      final data      = doc.data();
      final endTime   = (data['endTime']   as Timestamp?)?.toDate();
      final startTime = (data['startTime'] as Timestamp?)?.toDate();
      final status    = data['status']   as String? ?? '';
      final zoneName  = data['zoneName'] as String? ?? 'parking';
      final spotNumber = data['spotNumber'] as String? ?? '';
      final hasEntered = data['entryTime'] != null;

      if (endTime == null) continue;

      // ── 1. Expirée → completed ──────────────────────
      if (endTime.isBefore(now)) {
        await doc.reference.update({'status': 'completed'});
        continue;
      }

      // ── 2. Retard >30 min sans entrée → annuler ────
      if (status == 'upcoming' && startTime != null && !hasEntered) {
        final minsLate = now.difference(startTime).inMinutes;
        if (minsLate >= 30) {
          await doc.reference.update({
            'status': 'cancelled',
            'cancelReason': 'non_presentee',
          });
          await _db.collection('zones')
              .doc(data['zoneId'] as String)
              .update({'occupiedSpots': FieldValue.increment(-1)});
          await _push(userId,
            '❌ Réservation annulée',
            'Absence >30 min. Place $spotNumber à $zoneName libérée.');
          continue;
        }
      }

      // ── 3. upcoming → active ────────────────────────
      if (status == 'upcoming' &&
          startTime != null &&
          startTime.isBefore(now)) {
        await doc.reference.update({'status': 'active'});
      }

      // ── 4. Rappels avant FIN ────────────────────────
      final diff = endTime.difference(now).inSeconds;

// ── 15 min reminder ─────────────────────
if (diff <= 15 && diff > 0 && data['notified_15sec'] != true) {
  await _push(
    userId,
    '⏰ Rappel parking',
    'Votre place $spotNumber à $zoneName expire dans $diff sec.'
  );

  await doc.reference.update({'notified_15sec': true});
}

// ── 5 min reminder ──────────────────────
if (diff <= 5 && diff > 0 && data['notified_5sec'] != true) {
  await _push(
    userId,
    '🚨 Expiration imminente',
    'Plus que $diff min — Place $spotNumber à $zoneName !'
  );

  await doc.reference.update({'notified_5sec': true});
}
    }
  }

  // ── API OneSignal correcte ──────────────────────────
  Future<void> _push(String userId, String title, String body) async {
    try {
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_apiKey', // ← Basic, pas Bearer
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {            // ← include_aliases, pas filters
            'external_id': [userId],
          },
          'target_channel': 'push',
          'headings': {'fr': title, 'en': title},
          'contents': {'fr': body,  'en': body},
          'priority': 10,
        }),
      );
    } catch (_) {}
  }
}

// ══════════════════════════════════════════════════════
//  REMINDER SERVICE — Timers locaux (app ouverte/fond)
//  + OneSignal immédiat quand le timer se déclenche
// ══════════════════════════════════════════════════════
class ReminderService {
  final Map<String, List<Timer>> _timers = {};

  static const String _appId  = 'bbf1b2c9-e09d-4c2b-839f-3a7e8d0c5337';
  static const String _apiKey =
      'os_v2_app_xpy3fspatvgcxa47hj7i2dctg6v2qmnd6hbudnupe6albhpkhcuucma4otl3acn5kh4esqsl6dvw7wzpkcskf2fgjnoxlihu5qewfzq';

  void scheduleReminders(Reservation r, String userId) {
    cancelReminders(r.id);
    if (r.endTime == null) return;

    final now   = DateTime.now();
    final start = r.startTime;
    final end   = r.endTime!;
    final timers = <Timer>[];

    // ── 15 min avant DÉBUT ─────────────────────────────
    _addTimer(timers,
      start.subtract(const Duration(seconds: 15)), now, () => _push(userId,
        '🅿️ Parking bientôt',
        'Votre réservation à ${r.zoneName} commence dans 15 sec — Place ${r.spotNumber}'));


    // ── 5 min avant DÉBUT ──────────────────────────────
    _addTimer(timers,
      start.subtract(const Duration(seconds: 5)), now, () => _push(userId,
        '⚡ Parking dans 5 sec !',
        'Rendez-vous à ${r.zoneName} — Place ${r.spotNumber}'));

    // ── Auto-annulation +30 min sans entrée ────────────
    _addTimer(timers,
      start.add(const Duration(seconds: 30)), now, () async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('reservations').doc(r.id).get();
          if (!doc.exists) return;
          final data       = doc.data() as Map<String, dynamic>;
          final status     = data['status'] as String? ?? '';
          final hasEntered = data['entryTime'] != null;
          if (!hasEntered && (status == 'upcoming' || status == 'active')) {
            await FirebaseFirestore.instance
                .collection('reservations').doc(r.id)
                .update({'status': 'cancelled', 'cancelReason': 'non_presentee'});
            await FirebaseFirestore.instance
                .collection('zones').doc(r.zoneId)
                .update({'occupiedSpots': FieldValue.increment(-1)});
            await _push(userId,
              '❌ Réservation annulée',
              'Absence >30 min. Place ${r.spotNumber} à ${r.zoneName} libérée.');
          }
        } catch (_) {}
      });

    // ── 15 min avant FIN ───────────────────────────────
    _addTimer(timers,
      end.subtract(const Duration(seconds: 15)), now, () => _push(userId,
        '⏰ Rappel parking',
        'Votre place ${r.spotNumber} à ${r.zoneName} expire dans 15 sec'));

    // ── 5 min avant FIN ────────────────────────────────
    _addTimer(timers,
      end.subtract(const Duration(seconds: 5)), now, () => _push(userId,
        '⚠️ Expiration imminente',
        'Votre place ${r.spotNumber} à ${r.zoneName} expire dans 5 sec !'));

    // ── À l'expiration ─────────────────────────────────
    _addTimer(timers, end, now, () {
      _push(userId, '🔴 Réservation expirée',
          'Votre réservation à ${r.zoneName} est terminée');
      FirebaseFirestore.instance
          .collection('reservations').doc(r.id)
          .update({'status': 'completed'});
    });

    if (timers.isNotEmpty) _timers[r.id] = timers;
  }

  void _addTimer(List<Timer> list, DateTime when, DateTime now, Function() fn) {
    final diff = when.difference(now);
    if (!diff.isNegative && diff.inSeconds > 0) {
      list.add(Timer(diff, fn));
    }
  }

  Future<void> _push(String userId, String title, String body) async {
    try {
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_apiKey',
        },
        
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {'external_id': [userId]},
          'target_channel': 'push',
          'headings': {'fr': title, 'en': title},
          'contents': {'fr': body,  'en': body},
          'priority': 10,
        }),
      );
    } catch (_) {}
  }

  // Compatibilité ancien code
  void scheduleFor(String reservationId, String zoneName, DateTime endTime) {}

  void cancelReminders(String resvId) {
    _timers[resvId]?.forEach((t) => t.cancel());
    _timers.remove(resvId);
  }

  void cancelFor(String reservationId) => cancelReminders(reservationId);

  void cancelAll() {
    for (final timers in _timers.values) {
      for (final t in timers) {
        t.cancel();
      }
    }
    _timers.clear();
  }
}