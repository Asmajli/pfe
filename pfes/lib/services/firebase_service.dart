import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

// ══════════════════════════════════════════════════════
//  AUTH SERVICE
// ══════════════════════════════════════════════════════
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStream => _auth.authStateChanges();

  Future<AppUser> login(String email, String password) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      return _fetchUser(c.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw _authErr(e);
    }
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? vehiclePlate,
    String? zone,
  }) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      final user = AppUser(
        uid: c.user!.uid, email: email.trim(),
        name: name.trim(), phone: phone.trim(),
        role: UserRole.client,
        vehiclePlate: vehiclePlate, zone: zone,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(user.uid).set(user.toMap());
      return user;
    } on FirebaseAuthException catch (e) {
      throw _authErr(e);
    }
  }

  Future<void> logout() => _auth.signOut();

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _authErr(e);
    }
  }

  Future<AppUser> _fetchUser(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return AppUser.fromMap(uid, doc.data()!);
    doc = await _db.collection('admins').doc(uid).get();
    if (doc.exists) return AppUser.fromMap(uid, doc.data()!);
    throw 'Compte introuvable';
  }

  String _authErr(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found'       => 'Aucun compte avec cet email.',
      'wrong-password'       => 'Mot de passe incorrect.',
      'email-already-in-use' => 'Email déjà utilisé.',
      'weak-password'        => 'Mot de passe trop faible (6 car. min).',
      'invalid-email'        => 'Email invalide.',
      'too-many-requests'    => 'Trop de tentatives, réessayez plus tard.',
      _                      => e.message ?? 'Erreur inconnue.',
    };
  }
}

// ══════════════════════════════════════════════════════
//  PARKING SERVICE
// ══════════════════════════════════════════════════════
class ParkingService {
  final _db = FirebaseFirestore.instance;

  // Seulement les zones avec un agent assigné (isOpen: true)
  Stream<List<ParkingZone>> get zonesStream =>
      _db.collection('zones')
          .where('isOpen', isEqualTo: true)
          .orderBy('name').snapshots()
          .asyncMap((s) async {
            final now = DateTime.now();
            final zones = <ParkingZone>[];
            for (final doc in s.docs) {
              final zone = ParkingZone.fromDoc(doc);
              final resvSnap = await _db.collection('reservations')
                  .where('zoneId', isEqualTo: zone.id)
                  .where('status', whereIn: ['active', 'upcoming'])
                  .get();
              final realOccupied = resvSnap.docs.length;
              if (zone.occupiedSpots != realOccupied) {
                _db.collection('zones').doc(zone.id)
                    .update({'occupiedSpots': realOccupied});
              }
              zones.add(zone.copyWith(occupiedSpots: realOccupied));
            }
            return zones;
          });

  Future<ParkingZone?> getZone(String id) async {
    final d = await _db.collection('zones').doc(id).get();
    return d.exists ? ParkingZone.fromDoc(d) : null;
  }

  Future<void> updateOccupancy(String zoneId, int delta) =>
      _db.collection('zones').doc(zoneId).update(
          {'occupiedSpots': FieldValue.increment(delta)});

  Stream<List<Reservation>> userReservations(String uid) =>
      _db.collection('reservations')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Reservation.fromDoc).toList());

  Stream<List<Reservation>> activeForUser(String uid) =>
      _db.collection('reservations')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['active', 'upcoming'])
          .snapshots()
          .map((s) => s.docs.map(Reservation.fromDoc).toList());

  Stream<List<Reservation>> zoneActiveReservations(String zoneId) =>
      _db.collection('reservations')
          .where('zoneId', isEqualTo: zoneId)
          .where('status', whereIn: ['active', 'upcoming'])
          .orderBy('startTime')
          .snapshots()
          .map((s) => s.docs.map(Reservation.fromDoc).toList());

  Stream<List<Reservation>> zoneAllReservations(String zoneId) =>
      _db.collection('reservations')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Reservation.fromDoc).toList());


  // ══════════════════════════════════════════════════════
  //  VÉRIFICATION DISPONIBILITÉ — évite les conflits
  // ══════════════════════════════════════════════════════

  /// Vérifie si une place est disponible pour un créneau donné
  /// Retourne le nombre de places occupées pendant ce créneau
  Future<int> countOverlappingReservations({
    required String zoneId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _db.collection('reservations')
        .where('zoneId', isEqualTo: zoneId)
        .where('status', whereIn: ['upcoming', 'active'])
        .get();

    int count = 0;
    for (final doc in snap.docs) {
      final r = Reservation.fromDoc(doc);
      if (r.endTime == null) continue;
      // Vérifie le chevauchement
      final overlaps = r.startTime.isBefore(end) && r.endTime!.isAfter(start);
      if (overlaps) count++;
    }
    return count;
  }

  /// Vérifie si le client a déjà une réservation qui chevauche ce créneau
  Future<bool> hasClientConflict({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _db.collection('reservations')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['upcoming', 'active'])
        .get();

    for (final doc in snap.docs) {
      final r = Reservation.fromDoc(doc);
      if (r.endTime == null) continue;
      final overlaps = r.startTime.isBefore(end) && r.endTime!.isAfter(start);
      if (overlaps) return true;
    }
    return false;
  }

  Future<Reservation> createReservation({
    required AppUser user, required ParkingZone zone,
    required DateTime start, required DateTime end,
    required String spot, double? totalAmount,
  }) async {
    // ── 1. Vérifier conflit client ──
    final clientConflict = await hasClientConflict(
      userId: user.uid, start: start, end: end);
    if (clientConflict) {
      throw 'Vous avez déjà une réservation sur ce créneau.';
    }

    // ── 2. Vérifier disponibilité zone ──
    final occupied = await countOverlappingReservations(
      zoneId: zone.id, start: start, end: end);
    if (occupied >= zone.totalSpots) {
      throw 'Plus de places disponibles pour ce créneau.';
    }

    final ref = _db.collection('reservations').doc();
    final hours  = end.difference(start).inMinutes / 60.0;
    final amount = totalAmount ?? (zone.pricePerHour * hours);
    final r = Reservation(
      id: ref.id, userId: user.uid, userName: user.name,
      zoneId: zone.id, zoneName: zone.name,
      spotNumber: spot, vehiclePlate: user.vehiclePlate ?? '',
      startTime: start, endTime: end,
      pricePerHour: zone.pricePerHour,
      totalAmount: amount,
      status: ReservationStatus.upcoming,
      createdAt: DateTime.now(),
    );
    await ref.set(r.toMap());
    final url = Uri.parse("https://onesignal.com/api/v1/notifications");

  await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Basic os_v2_app_xpy3fspatvgcxa47hj7i2dctg6v2qmnd6hbudnupe6albhpkhcuucma4otl3acn5kh4esqsl6dvw7wzpkcskf2fgjnoxlihu5qewfzq",
    },
    body: jsonEncode({
      "app_id": "bbf1b2c9-e09d-4c2b-839f-3a7e8d0c5337",

      "include_aliases": {
        "external_id": [user.uid]
      },

      "target_channel": "push",

      "headings": {
        "en": "Réservation"
      },

      "contents": {
        "en": "Réservation près vous pouvez venir!  "
      },

      "send_after": DateTime.now()
          .add(const Duration(seconds: 10))
          .toUtc()
          .toIso8601String(),
    }),
  );
    return r;
  }

  Future<void> updateReservationStatus(String id, ReservationStatus st,
      {double? amount}) async {
    final data = <String, dynamic>{'status': st.name};
    if (st == ReservationStatus.completed) {
      data['endTime'] = Timestamp.now();
      if (amount != null) data['totalAmount'] = amount;
    }
    await _db.collection('reservations').doc(id).update(data);
  }

  Future<void> cancelReservation(String id) async {
    final doc = await _db.collection('reservations').doc(id).get();
    if (!doc.exists) return;
    final r = Reservation.fromDoc(doc);
    await updateReservationStatus(id, ReservationStatus.cancelled);
  }

  Future<void> prolongerReservation(String id, int extraMinutes) async {
    final doc = await _db.collection('reservations').doc(id).get();
    if (!doc.exists) return;
    final r = Reservation.fromDoc(doc);
    final newEnd = (r.endTime ?? DateTime.now()).add(Duration(minutes: extraMinutes));
    final extraAmount = (extraMinutes / 60.0) * r.pricePerHour;
    await _db.collection('reservations').doc(id).update({
      'endTime': Timestamp.fromDate(newEnd),
      'totalAmount': FieldValue.increment(extraAmount),
    });
  }

  Future<void> submitAvis({
    required String zoneId, required String zoneName,
    required String userId, required String userName,
    required int rating, required String comment,
  }) async {
    await _db.collection('avis').doc().set({
      'zoneId': zoneId, 'zoneName': zoneName,
      'userId': userId, 'userName': userName,
      'rating': rating, 'comment': comment,
      'createdAt': Timestamp.now(),
    });
  }

  // ══════════════════════════════════════════════════════
  //  AUTO-EXPIRE — annule les réservations si +30min de retard d'entrée
  // 
  Future<void> autoExpireNoShows(String uid) async {
    final now  = DateTime.now();
    final snap = await _db.collection('reservations')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'upcoming')
        .get();

    for (final doc in snap.docs) {
      final r = Reservation.fromDoc(doc);
      // Si +30 min après l'heure de début et pas encore entré → annuler
      final minutesLate = now.difference(r.startTime).inMinutes;
      if (minutesLate >= 30) {
        await doc.reference.update({'status': 'cancelled'});
        await updateOccupancy(r.zoneId, -1);
      }
    }
  }

  Future<void> syncReservationStatuses(String uid) async {
    final now  = DateTime.now();
    final snap = await _db.collection('reservations')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['upcoming', 'active'])
        .get();
    for (final doc in snap.docs) {
      final r = Reservation.fromDoc(doc);

      // ── 1. Réservation expirée → completed ──
      if (r.endTime != null && r.endTime!.isBefore(now)) {
        await doc.reference.update({'status': 'completed'});
        await updateOccupancy(r.zoneId, -1);
        continue;
      }

      // ── 2. Retard d'entrée > 30 min → annulation auto 
      // (client n'est pas entré : pas d'entryTime, statut encore upcoming)
      if (r.status == ReservationStatus.upcoming) {
        final minsAfterStart = now.difference(r.startTime).inMinutes;
        final hasEntered = (doc.data())['entryTime'] != null;
        if (minsAfterStart > 30 && !hasEntered) {
          await doc.reference.update({'status': 'cancelled', 'cancelReason': 'non_presentee'});
          await updateOccupancy(r.zoneId, -1);
          // Notifier le client
          NotificationService.sendToUser(
            uid,
            'Réservation annulée automatiquement',
            'Votre place ${r.spotNumber} à ${r.zoneName} a été libérée car vous ne vous êtes pas présenté dans les 30 min.',
          );
          continue;
        }
      }

      //  3. Upcoming → active si l'heure a commencé ──
      if (r.startTime.isBefore(now) &&
          (r.endTime == null || r.endTime!.isAfter(now)) &&
          r.status == ReservationStatus.upcoming) {
        await doc.reference.update({'status': 'active'});
      }
    }
  }

  /// Auto-cancel global (appelé par AutoSyncService) — vérifie TOUTES les réservations
  Future<void> syncAllPendingReservations() async {
    final now = DateTime.now();
    final snap = await _db.collection('reservations')
        .where('status', whereIn: ['upcoming', 'active'])
        .get();
    for (final doc in snap.docs) {
      final r = Reservation.fromDoc(doc);
      final data = doc.data();

      // Expirée
      if (r.endTime != null && r.endTime!.isBefore(now)) {
        await doc.reference.update({'status': 'completed'});
        continue;
      }

      // Retard > 30 min sans entrée
      if (r.status == ReservationStatus.upcoming) {
        final minsAfterStart = now.difference(r.startTime).inMinutes;
        final hasEntered = data['entryTime'] != null;
        if (minsAfterStart > 30 && !hasEntered) {
          await doc.reference.update({'status': 'cancelled', 'cancelReason': 'non_presentee'});
          await updateOccupancy(r.zoneId, -1);
          NotificationService.sendToUser(
            r.userId,
            'Réservation annulée',
            'Votre place ${r.spotNumber} à ${r.zoneName} a été libérée.',
          );
        }
      }
    }
  }

  Stream<List<VehicleLog>> zoneLogs(String zoneId) =>
      _db.collection('vehicle_logs')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map(VehicleLog.fromDoc).toList());

  Future<void> logVehicle({
    required String plate,
    required String ownerName,
    required ParkingZone zone,
    required String spot,
    required LogType type,
    required AppUser agent,
  }) async {
    final ref = _db.collection('vehicle_logs').doc();
    final log = VehicleLog(
      id: ref.id, plate: plate, ownerName: ownerName,
      zoneId: zone.id, zoneName: zone.name, spotNumber: spot,
      agentId: agent.uid, agentName: agent.name,
      type: type, timestamp: DateTime.now(),
    );
    await ref.set(log.toMap());
    await updateOccupancy(zone.id, type == LogType.entry ? 1 : -1);
  }

  // ══════════════════════════════════════════════════════
  //  GÉNÉRER QR SORTIE après scan entrée par l'agent
  //  → sauvegarde dans Firestore → visible immédiatement par le client
  // 
  Future<String> generateAndSaveExitQr({
    required String resvId,
    required String zoneId,
    required String zoneName,
    required String spot,
    required DateTime scheduledEnd,
    required double pricePerHour,
  }) async {
    final entryTime = DateTime.now();

    // Calcul retard éventuel (si client arrive après l'heure prévue)
    final retardMin  = entryTime.isAfter(scheduledEnd)
        ? entryTime.difference(scheduledEnd).inMinutes.toDouble()
        : 0.0;
    final retardAmt  = (retardMin / 60.0) * pricePerHour;

    // Format EXIT QR
    final exitQr =
        'EXIT|$resvId|$zoneId|$zoneName|$spot'
        '|${entryTime.toIso8601String()}'
        '|${scheduledEnd.toIso8601String()}'
        '|${retardAmt.toStringAsFixed(2)}';

    // Sauvegarder dans Firestore — le client verra ce QR dans son historique
    await _db.collection('reservations').doc(resvId).update({
      'exitQrData': exitQr,
      'entryTime':  entryTime.toIso8601String(),
      'status':     'active',
    });

    return exitQr;
  }
}

// ══════════════════════════════════════════════════════
//  REMINDER SERVICE
// ══════════════════════════════════════════════════════
class ReminderService {
  final Map<String, List<Timer>> _timers = {};

  // ══════════════════════════════════════════════════════
  //  SCHEDULE REMINDERS — via OneSignal scheduled push
  //  Fonctionne même si l'app est fermée
  // 
 void scheduleReminders(Reservation r, String userId) {
    cancelReminders(r.id);
    if (r.endTime == null) return;

    final now   = DateTime.now();
    final start = r.startTime;
    final end   = r.endTime!;
    final timers = <Timer>[];

    // ── 15 sec avant DÉBUT ──
    _addTimer(timers, start.subtract(const Duration(seconds: 15)), now, () =>
      NotificationService.sendToUser(userId,
        '🅿️ Parking bientôt',
        'Votre réservation à ${r.zoneName} commence bientôt — Place ${r.spotNumber}'));

    // ── 5 sec avant DÉBUT ──
    _addTimer(timers, start.subtract(const Duration(seconds: 5)), now, () =>
      NotificationService.sendToUser(userId,
        '⚡ Parking maintenant !',
        'Rendez-vous à ${r.zoneName} — Place ${r.spotNumber}'));

    // ── Auto-annulation +30 sec sans entrée ──
    _addTimer(timers, start.add(const Duration(seconds: 30)), now, () async {
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
          NotificationService.sendToUser(userId,
            '❌ Réservation annulée',
            'Absence >30 sec. Place ${r.spotNumber} à ${r.zoneName} libérée.');
        }
      } catch (_) {}
    });

    // ── 15 sec avant FIN ──
    _addTimer(timers, end.subtract(const Duration(seconds: 15)), now, () =>
      NotificationService.sendToUser(userId,
        '⏰ Rappel parking',
        'Votre place ${r.spotNumber} à ${r.zoneName} expire bientôt'));

    // ── 5 sec avant FIN ──
    _addTimer(timers, end.subtract(const Duration(seconds: 5)), now, () =>
      NotificationService.sendToUser(userId,
        '⚠️ Expiration imminente',
        'Votre place ${r.spotNumber} expire dans quelques secondes !'));

    // ── À l'expiration ──
    _addTimer(timers, end, now, () {
      NotificationService.sendToUser(userId,
        '🔴 Réservation expirée',
        'Votre réservation à ${r.zoneName} est terminée');
      FirebaseFirestore.instance
          .collection('reservations').doc(r.id)
          .update({'status': 'completed'});
    });

    if (timers.isNotEmpty) _timers[r.id] = timers;
  }

  void _addTimer(List<Timer> list, DateTime when, DateTime now, Function() fn) {
    final diff = when.difference(now);
    if (!diff.isNegative && diff.inSeconds > 0) list.add(Timer(diff, fn));
  }

  void cancelReminders(String resvId) {
    _timers[resvId]?.forEach((t) => t.cancel());
    _timers.remove(resvId);
  }

  void cancelAll() {
    for (final timers in _timers.values) {
      for (final t in timers) {
        t.cancel();
      }
    }
    _timers.clear();
  }
}

// 
//  NOTIFICATION SERVICE — OneSignal REST API
//  Supports scheduled push (works when app is closed)
// 
class NotificationService {
  static const _apiKey =
      'os_v2_app_xpy3fspatvgcxa47hj7i2dctg774dndvxkfuanvsbrhjhb3ac6fkjnnjhpync4adotwvc34w7r6bkmmka2fwiwlqtgldrg5rs2qk2ry';
  static const _appId = 'bbf1b2c9-e09d-4c2b-839f-3a7e8d0c5337';

  static Future<void> init() async {}
  static Future<void> setUser(String userId) async {}
  static Future<void> logoutUser() async {}

  //  Envoi immédiat ou programmé 
  static Future<void> sendToUser(
    String userId,
    String title,
    String body, {
    DateTime? scheduledAt,
  }) async {
    try {
      final payload = <String, dynamic>{
        'app_id': _appId,
        'include_aliases': {
          'external_id': [userId],
        },
        'target_channel': 'push',
        'headings': {'fr': title, 'en': title},
        'contents': {'fr': body,  'en': body},
        'priority': 10,
      };

      // Notification programmée — OneSignal l'envoie à l'heure exacte
      // même si l'app est fermée
      if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
        final utc = scheduledAt.toUtc();
        // Format: "2024-01-15T14:30:00Z"
        payload['send_after'] =
            '${utc.year}-${_pad(utc.month)}-${_pad(utc.day)}T${_pad(utc.hour)}:${_pad(utc.minute)}:${_pad(utc.second)}Z';
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_apiKey',
        },
        body: jsonEncode(payload),
      );
      print('OneSignal: ${response.statusCode} — ${response.body}');
    } catch (e) {
      print('OneSignal error: $e');
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static void sendLocal({
    required String title,
    required String body,
    required String userId,
    DateTime? scheduledAt,
  }) => sendToUser(userId, title, body, scheduledAt: scheduledAt);
}

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
    if (!doc.exists) throw Exception('Réservation introuvable');
    final r      = Reservation.fromDoc(doc);
    final newEnd = (r.endTime ?? DateTime.now()).add(Duration(minutes: extraMinutes));
    final extra  = (extraMinutes / 60.0) * pricePerHour;
    await _db.collection('reservations').doc(reservationId).update({
      'endTime':     Timestamp.fromDate(newEnd),
      'totalAmount': FieldValue.increment(extra),
    });
    return newEnd;
  }
}

// ══════════════════════════════════════════════════════
//  PROVIDERS
// ══════════════════════════════════════════════════════
final authServiceProvider    = Provider<AuthService>((_) => AuthService());
final parkingServiceProvider = Provider<ParkingService>((_) => ParkingService());

final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final auth = FirebaseAuth.instance;
  final db   = FirebaseFirestore.instance;
  await for (final fu in auth.authStateChanges()) {
    if (fu == null) { yield null; continue; }
    var doc = await db.collection('users').doc(fu.uid).get();
    if (doc.exists) { yield AppUser.fromMap(fu.uid, doc.data()!); continue; }
    doc = await db.collection('admins').doc(fu.uid).get();
    if (doc.exists) { yield AppUser.fromMap(fu.uid, doc.data()!); continue; }
    yield null;
  }
});

final zonesProvider = StreamProvider<List<ParkingZone>>(
    (ref) => ref.read(parkingServiceProvider).zonesStream);

final userReservationsProvider =
    StreamProvider.family<List<Reservation>, String>(
        (ref, uid) => ref.read(parkingServiceProvider).userReservations(uid));

final activeReservationsProvider =
    StreamProvider.family<List<Reservation>, String>(
        (ref, uid) => ref.read(parkingServiceProvider).activeForUser(uid));

final zoneLogsProvider =
    StreamProvider.family<List<VehicleLog>, String>(
        (ref, zid) => ref.read(parkingServiceProvider).zoneLogs(zid));

final zoneActiveResvProvider =
    StreamProvider.family<List<Reservation>, String>(
        (ref, zid) => ref.read(parkingServiceProvider).zoneActiveReservations(zid));

final zoneAllResvProvider =
    StreamProvider.family<List<Reservation>, String>(
        (ref, zid) => ref.read(parkingServiceProvider).zoneAllReservations(zid));

final reminderServiceProvider =
    Provider<ReminderService>((_) => ReminderService());

final prolongationServiceProvider =
    Provider<ProlongationService>((_) => ProlongationService());

// Provider pour vérification disponibilité (accès direct au service)
final availabilityProvider = Provider<ParkingService>(
    (ref) => ref.read(parkingServiceProvider));