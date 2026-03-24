import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/client/client_screens.dart';
import '../screens/responsable/resp_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final refreshNotifier = ValueNotifier(userAsync);
  ref.listen(currentUserProvider, (previous, next) {
    refreshNotifier.value = next;
  });

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,

    redirect: (context, state) {
      final user    = userAsync.asData?.value;
      final loading = userAsync.isLoading;
      final onAuth  = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (loading) return null;
      if (user == null && !onAuth) return '/login';
      if (user != null && onAuth) {
        return user.role == UserRole.responsable
            ? '/resp/dashboard'
            : '/client/home';
      }
      return null;
    },

    routes: [

      /// ───────── AUTH ─────────
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      /// ───────── CLIENT ─────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ClientShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/client/home',
              builder: (_, __) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'booking/:zoneId',
                  builder: (_, s) => BookingScreen(zoneId: s.pathParameters['zoneId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/client/reservations', builder: (_, __) => const ReservationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/client/profile', builder: (_, __) => const ClientProfileScreen()),
          ]),
        ],
      ),

      // ── Edit Profile (hors shell) ──
      GoRoute(
        path: '/client/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),

      // ── Avis (hors shell) ──
      GoRoute(
        path: '/client/avis/:zoneId',
        builder: (_, s) => AvisScreen(
          zoneId: s.pathParameters['zoneId']!,
          zoneName: s.uri.queryParameters['zoneName'] ?? '',
        ),
      ),

      /// ───────── RESPONSABLE ─────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => RespShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/resp/dashboard',
              builder: (_, __) => const DashboardScreen(),
              routes: [
                GoRoute(
                  path: 'zone/:zoneId',
                  builder: (_, s) => ZoneDetailScreen(zoneId: s.pathParameters['zoneId']!),
                  routes: [
                    // 🗺️ Carte visuelle des places
                    GoRoute(
                      path: 'map',
                      builder: (_, s) => ParkingMapScreen(zoneId: s.pathParameters['zoneId']!),
                    ),
                    GoRoute(
                      path: '3d',
                      builder: (_, s) => Virtual3DParkingScreen(zoneId: s.pathParameters['zoneId']!),
                    ),
                    GoRoute(
                      path: 'live',
                      builder: (_, s) => ParkingLiveScreen(zoneId: s.pathParameters['zoneId']!),
                    ),
                    // 📋 Liste toutes les réservations
                    GoRoute(
                      path: 'reservations',
                      builder: (_, s) => ZoneReservationsScreen(zoneId: s.pathParameters['zoneId']!),
                    ),
                    // 📊 Statistiques zone
                    GoRoute(
                      path: 'stats',
                      builder: (_, s) => ZoneStatsScreen(zoneId: s.pathParameters['zoneId']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/resp/scanner',
              builder: (_, __) => const ScannerScreen(),
              routes: [
                // 📷 QR Scanner
                GoRoute(
                  path: 'qr',
                  builder: (_, __) => const QRScannerScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/resp/profile', builder: (_, __) => const RespProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});