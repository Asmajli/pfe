import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/client/client_screens.dart';
import '../screens/agent/agent_screens.dart'; // ← nouveau fichier

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
        // agent → /agent/scan, client → /client/home
        return user.role == UserRole.agent
            ? '/agent/scan'
            : '/client/home';
      }
      return null;
    },

    routes: [

      // ── AUTH ─────────────────────────────────────
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // ══ CLIENT — 3 tabs ══════════════════════════
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
                  builder: (_, s) =>
                      BookingScreen(zoneId: s.pathParameters['zoneId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/client/reservations',
              builder: (_, __) => const ReservationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/client/profile',
              builder: (_, __) => const ClientProfileScreen(),
            ),
          ]),
        ],
      ),

      // ── Client routes hors shell ──
      GoRoute(path: '/client/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(
        path: '/client/avis/:zoneId',
        builder: (_, s) => AvisScreen(
          zoneId: s.pathParameters['zoneId']!,
          zoneName: s.uri.queryParameters['zoneName'] ?? '',
        ),
      ),

      // ══ AGENT DE PARKING — 3 tabs ════════════════
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AgentShell(shell: shell),
        branches: [
          // Tab 1 : Scanner (écran principal)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/agent/scan',
              builder: (_, __) => const AgentScanScreen(),
            ),
          ]),
          // Tab 2 : Journal
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/agent/journal',
              builder: (_, __) => const AgentJournalScreen(),
            ),
          ]),
          // Tab 3 : Profil
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/agent/profile',
              builder: (_, __) => const AgentProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});