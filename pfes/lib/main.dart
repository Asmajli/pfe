import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

// ── Background task name ────────────────────────────
const _taskName = 'checkReservations';

// ── Background callback (top-level) ─────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _taskName) {
      await Firebase.initializeApp();
      final uid = inputData?['uid'] as String?;
      if (uid == null) return true;

      final db  = FirebaseFirestore.instance;
      final now = DateTime.now();

      // نجيب حجوزات المستخدم النشطة
      final snap = await db.collection('reservations')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['active', 'upcoming'])
          .get();

      for (final doc in snap.docs) {
        final data   = doc.data();
        final endTs  = data['endTime'] as Timestamp?;
        if (endTs == null) continue;
        final endTime  = endTs.toDate();
        final remaining = endTime.difference(now).inMinutes;
        final zoneName  = data['zoneName'] ?? '';
        final spotNum   = data['spotNumber'] ?? '';

        // باقي بين 13 و 17 دقيقة → نبعث notification
        if (remaining >= 13 && remaining <= 17) {
          await _sendOneSignalNotification(
            userId: uid,
            title: '⏰ Réservation bientôt expirée',
            body: '$zoneName — Il vous reste $remaining min · Place $spotNum',
          );
        }
        // باقي بين 3 و 7 دقائق
        else if (remaining >= 3 && remaining <= 7) {
          await _sendOneSignalNotification(
            userId: uid,
            title: '🚨 Expire dans $remaining min !',
            body: '$zoneName · Place $spotNum — Prolonger ?',
          );
        }
      }
    }
    return true;
  });
}

Future<void> _sendOneSignalNotification({
  required String userId,
  required String title,
  required String body,
}) async {
  try {
    await http.post(
      Uri.parse('https://api.onesignal.com/notifications'),
      headers: {
        'Authorization': 'Key ${NotificationService.restApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'app_id': NotificationService.appId,
        'include_aliases': {'external_id': [userId]},
        'target_channel': 'push',
        'headings': {'en': title, 'fr': title},
        'contents': {'en': body, 'fr': body},
      }),
    );
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  Stripe.publishableKey = 'pk_test_REMPLACE_MOI';
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();

  // ── Init Workmanager ──
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  await initializeDateFormatting('fr_FR');
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  runApp(const ProviderScope(child: ParkApp()));
}

class ParkApp extends ConsumerWidget {
  const ParkApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentUserProvider, (_, next) {
      next.whenData((user) {
        if (user != null) {
          NotificationService.setUser(user.uid);
          // ── تسجيل background task كل 15 دقيقة ──
          Workmanager().registerPeriodicTask(
            'reservation-check-${user.uid}',
            _taskName,
            frequency: const Duration(minutes: 15),
            inputData: {'uid': user.uid},
            constraints: Constraints(networkType: NetworkType.connected),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
          );
        } else {
          NotificationService.logoutUser();
          Workmanager().cancelAll();
        }
      });
    });
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ParkApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}