import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { client, responsable }
enum ReservationStatus { upcoming, active, completed, cancelled }
enum LogType { entry, exit }

// ══════════════════════ APP USER ══════════════════════
class AppUser {
  final String uid, email, name, phone;
  final UserRole role;
  final String? vehiclePlate, vehicleModel, zone, shift;
  final String subscription;
  final double balance;
  final DateTime createdAt;

  const AppUser({
    required this.uid, required this.email,
    required this.name, required this.phone,
    required this.role,
    this.vehiclePlate, this.vehicleModel,
    this.zone, this.shift,
    this.subscription = 'standard',
    this.balance = 0,
    required this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> d) => AppUser(
    uid: uid, email: d['email'] ?? '', name: d['name'] ?? '',
    phone: d['phone'] ?? '',
    role: d['role'] == 'responsable' ? UserRole.responsable : UserRole.client,
    vehiclePlate: d['vehiclePlate'], vehicleModel: d['vehicleModel'],
    zone: d['zone'], shift: d['shift'],
    subscription: d['subscription'] ?? 'standard',
    balance: (d['balance'] ?? 0).toDouble(),
    createdAt: d['createdAt'] is Timestamp
        ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'email': email, 'name': name, 'phone': phone,
    'role': role.name, 'vehiclePlate': vehiclePlate,
    'vehicleModel': vehicleModel, 'zone': zone, 'shift': shift,
    'subscription': subscription, 'balance': balance,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ══════════════════════ PARKING ZONE ══════════════════
class ParkingZone {
  final String id, name, type, address;
  final int totalSpots, occupiedSpots;
  final double pricePerHour;
  final bool isOpen;
  final String openHours;

  const ParkingZone({
    required this.id, required this.name, required this.type,
    required this.address, required this.totalSpots,
    required this.occupiedSpots, required this.pricePerHour,
    this.isOpen = true, this.openHours = '24h/24',
  });

  int get freeSpots => totalSpots - occupiedSpots;
  double get rate => occupiedSpots / (totalSpots == 0 ? 1 : totalSpots);
  bool get isFull => freeSpots <= 0;

  factory ParkingZone.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ParkingZone(
      id: doc.id, name: d['name'] ?? '', type: d['type'] ?? 'exterieur',
      address: d['address'] ?? '', totalSpots: d['totalSpots'] ?? 0,
      occupiedSpots: d['occupiedSpots'] ?? 0,
      pricePerHour: (d['pricePerHour'] ?? 100).toDouble(),
      isOpen: d['isOpen'] ?? true, openHours: d['openHours'] ?? '24h/24',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name, 'type': type, 'address': address,
    'totalSpots': totalSpots, 'occupiedSpots': occupiedSpots,
    'pricePerHour': pricePerHour, 'isOpen': isOpen, 'openHours': openHours,
  };
}

// ══════════════════════ RESERVATION ══════════════════
class Reservation {
  final String id, userId, userName, zoneId, zoneName, spotNumber, vehiclePlate;
  final DateTime startTime;
  final DateTime? endTime;
  final double pricePerHour;
  final double? totalAmount;
  final ReservationStatus status;
  final DateTime createdAt;

  const Reservation({
    required this.id, required this.userId, required this.userName,
    required this.zoneId, required this.zoneName, required this.spotNumber,
    required this.vehiclePlate, required this.startTime, this.endTime,
    required this.pricePerHour, this.totalAmount,
    this.status = ReservationStatus.upcoming, required this.createdAt,
  });

  Duration get elapsed => (endTime ?? DateTime.now()).difference(startTime);
  double get computed => (elapsed.inMinutes / 60.0) * pricePerHour;

  factory Reservation.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final st = {
      'active': ReservationStatus.active,
      'completed': ReservationStatus.completed,
      'cancelled': ReservationStatus.cancelled,
    }[d['status']] ?? ReservationStatus.upcoming;
    return Reservation(
      id: doc.id, userId: d['userId'] ?? '', userName: d['userName'] ?? '',
      zoneId: d['zoneId'] ?? '', zoneName: d['zoneName'] ?? '',
      spotNumber: d['spotNumber'] ?? '', vehiclePlate: d['vehiclePlate'] ?? '',
      startTime: (d['startTime'] as Timestamp).toDate(),
      endTime: d['endTime'] != null ? (d['endTime'] as Timestamp).toDate() : null,
      pricePerHour: (d['pricePerHour'] ?? 100).toDouble(),
      totalAmount: d['totalAmount']?.toDouble(), status: st,
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId, 'userName': userName, 'zoneId': zoneId,
    'zoneName': zoneName, 'spotNumber': spotNumber, 'vehiclePlate': vehiclePlate,
    'startTime': Timestamp.fromDate(startTime),
    'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
    'pricePerHour': pricePerHour, 'totalAmount': totalAmount,
    'status': status.name, 'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ══════════════════════ VEHICLE LOG ══════════════════
class VehicleLog {
  final String id, plate, ownerName, zoneId, zoneName, spotNumber;
  final String responsableId, responsableName;
  final LogType type;
  final DateTime timestamp;

  const VehicleLog({
    required this.id, required this.plate, required this.ownerName,
    required this.zoneId, required this.zoneName, required this.spotNumber,
    required this.responsableId, required this.responsableName,
    required this.type, required this.timestamp,
  });

  factory VehicleLog.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VehicleLog(
      id: doc.id, plate: d['plate'] ?? '', ownerName: d['ownerName'] ?? '',
      zoneId: d['zoneId'] ?? '', zoneName: d['zoneName'] ?? '',
      spotNumber: d['spotNumber'] ?? '',
      responsableId: d['responsableId'] ?? '',
      responsableName: d['responsableName'] ?? '',
      type: d['type'] == 'entry' ? LogType.entry : LogType.exit,
      timestamp: (d['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'plate': plate, 'ownerName': ownerName, 'zoneId': zoneId,
    'zoneName': zoneName, 'spotNumber': spotNumber,
    'responsableId': responsableId, 'responsableName': responsableName,
    'type': type.name, 'timestamp': Timestamp.fromDate(timestamp),
  };
}
