import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    required UserRole role,
    String? vehiclePlate,
    String? zone,
  }) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      final user = AppUser(
        uid: c.user!.uid, email: email.trim(),
        name: name.trim(), phone: phone.trim(), role: role,
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
    // نبحث أولاً في users
    var doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return AppUser.fromMap(uid, doc.data()!);

    // إذا ما لقيناهش نبحث في admins (responsable)
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

  // ─── Zones ─────────────────────────────────────────
  Stream<List<ParkingZone>> get zonesStream =>
      _db.collection('zones').orderBy('name').snapshots()
          .map((s) => s.docs.map(ParkingZone.fromDoc).toList());

  Future<ParkingZone?> getZone(String id) async {
    final d = await _db.collection('zones').doc(id).get();
    return d.exists ? ParkingZone.fromDoc(d) : null;
  }

  Future<void> updateOccupancy(String zoneId, int delta) =>
      _db.collection('zones').doc(zoneId).update(
          {'occupiedSpots': FieldValue.increment(delta)});

  // ─── Reservations ──────────────────────────────────
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

  // كل الحجوزات (بما فيها المنتهية)
  Stream<List<Reservation>> zoneAllReservations(String zoneId) =>
      _db.collection('reservations')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Reservation.fromDoc).toList());

  Future<Reservation> createReservation({
    required AppUser user, required ParkingZone zone,
    required DateTime start, required DateTime end,
    required String spot,
    double? totalAmount,
  }) async {
    final ref = _db.collection('reservations').doc();
    // نحسب المبلغ من الوقت إذا ما تمّ تمريره
    final hours = end.difference(start).inMinutes / 60.0;
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
    // نزيد occupiedSpots مباشرة عند الحجز
    await updateOccupancy(zone.id, 1);
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
    // نجيب الحجز باش نعرف الـ zoneId
    final doc = await _db.collection('reservations').doc(id).get();
    if (!doc.exists) return;
    final r = Reservation.fromDoc(doc);

    // نبدّل status لـ cancelled
    await updateReservationStatus(id, ReservationStatus.cancelled);

    // نرجع الـ occupiedSpots إذا كان الحجز active أو upcoming
    if (r.status == ReservationStatus.active || r.status == ReservationStatus.upcoming) {
      await updateOccupancy(r.zoneId, -1);
    }
  }

  // ─── Prolonger réservation ──────────────────────────
  Future<void> prolongerReservation(String id, int extraMinutes) async {
    final doc = await _db.collection('reservations').doc(id).get();
    if (!doc.exists) return;
    final r = Reservation.fromDoc(doc);
    final newEnd = (r.endTime ?? DateTime.now())
        .add(Duration(minutes: extraMinutes));
    final extraHours  = extraMinutes / 60.0;
    final extraAmount = r.pricePerHour * extraHours;
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
    final ref = _db.collection('avis').doc();
    await ref.set({
      'zoneId': zoneId, 'zoneName': zoneName,
      'userId': userId, 'userName': userName,
      'rating': rating, 'comment': comment,
      'createdAt': Timestamp.now(),
    });
  }
  // يتحقق من كل حجوزات المستخدم ويبدّل status تلقائياً
  Future<void> syncReservationStatuses(String uid) async {
    final now = DateTime.now();
    final snap = await _db.collection('reservations')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['upcoming', 'active'])
        .get();

    for (final doc in snap.docs) {
      final r = Reservation.fromDoc(doc);
      if (r.endTime != null && r.endTime!.isBefore(now)) {
        // وقت انتهى → completed
        await doc.reference.update({'status': 'completed'});
      } else if (r.startTime.isBefore(now) &&
          (r.endTime == null || r.endTime!.isAfter(now)) &&
          r.status == ReservationStatus.upcoming) {
        // بدأ الوقت → active
        await doc.reference.update({'status': 'active'});
      }
    }
  }

  // ─── Vehicle logs ───────────────────────────────────
  Stream<List<VehicleLog>> zoneLogs(String zoneId) =>
      _db.collection('vehicle_logs')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map(VehicleLog.fromDoc).toList());

  Future<void> logVehicle({
    required String plate, required String ownerName,
    required ParkingZone zone, required String spot,
    required LogType type, required AppUser resp,
  }) async {
    final ref = _db.collection('vehicle_logs').doc();
    final log = VehicleLog(
      id: ref.id, plate: plate, ownerName: ownerName,
      zoneId: zone.id, zoneName: zone.name, spotNumber: spot,
      responsableId: resp.uid, responsableName: resp.name,
      type: type, timestamp: DateTime.now(),
    );
    await ref.set(log.toMap());
    await updateOccupancy(zone.id, type == LogType.entry ? 1 : -1);
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
    // نبحث في users أولاً
    var doc = await db.collection('users').doc(fu.uid).get();
    if (doc.exists) { yield AppUser.fromMap(fu.uid, doc.data()!); continue; }
    // ثم في admins (responsable)
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
        (ref, zid) =>
            ref.read(parkingServiceProvider).zoneActiveReservations(zid));

final zoneAllResvProvider =
    StreamProvider.family<List<Reservation>, String>(
        (ref, zid) =>
            ref.read(parkingServiceProvider).zoneAllReservations(zid));