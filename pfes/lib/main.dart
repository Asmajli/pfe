import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

// ── Workmanager background task ──────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      final userId = inputData?['userId'] as String?;
      if (userId != null && userId.isNotEmpty) {
        await AutoSyncService().syncAndNotify(userId);
      }
    } catch (_) {}
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  // ── OneSignal init ──────────────────────────────────
  OneSignal.initialize('bbf1b2c9-e09d-4c2b-839f-3a7e8d0c5337');
  await OneSignal.Notifications.requestPermission(true);
  OneSignal.User.addObserver((state) {
  debugPrint('✅ OneSignal externalId: ${state.current.externalId}');
});
OneSignal.Notifications.addForegroundWillDisplayListener((event) {
  event.notification.display(); // 
});
  await initializeDateFormatting('fr_FR');
  timeago.setLocaleMessages('fr', timeago.FrMessages());

  

  runApp(const ProviderScope(child: ParkApp()));
}

class ParkApp extends ConsumerStatefulWidget {
  const ParkApp({super.key});
  @override
  ConsumerState<ParkApp> createState() => _ParkAppState();
}

class _ParkAppState extends ConsumerState<ParkApp> {
  String? _linkedUserId;

  @override
  void initState() {
    super.initState();
    // ── راقبي تغيير الـ user ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(currentUserProvider, (_, next) {
        final user = next.asData?.value;
        if (user != null && user.uid != _linkedUserId) {
          _linkedUserId = user.uid;
          // ── ربط OneSignal بـ userId ──────────────────
          OneSignal.login(user.uid).then((_) {
          debugPrint('✅ OneSignal login: ${user.uid}');
          debugPrint('✅ OneSignal pushToken: ${OneSignal.User.pushSubscription.token}');
          });
        } else if (user == null && _linkedUserId != null) {
          _linkedUserId = null;
          // OneSignal.logout();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ParkApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}