import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // application te5dem  vertical
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // nithakem fi staut bar :Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // norbet bil li howa mat3 ficher firebase.option :Firebase initialization
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // nrigle biha langue  Locale setup
  await initializeDateFormatting('fr_FR');
  timeago.setLocaleMessages('fr', timeago.FrMessages());

  //y5lih ya9ra l Providers w ysta3ml state
  runApp(const ProviderScope(child: ParkApp()));
}
// htha widget principal
class ParkApp extends ConsumerWidget {
  const ParkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // htha bch nijib app_router
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ParkApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}