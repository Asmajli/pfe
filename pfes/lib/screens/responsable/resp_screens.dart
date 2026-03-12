// ══════════════════════════════════════════════════════
//  RESPONSABLE SHELL + ALL SCREENS
// ══════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── SHELL ──────────────────────────────────────────────
class RespShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const RespShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      // navigation bin les pages 
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          onTap: shell.goBranch,
          selectedItemColor: AppColors.green,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Tableau'),
            BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Contrôle'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  DASHBOARD
// ══════════════════════════════════════════════════════
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync  = ref.watch(currentUserProvider);
    final zonesAsync = ref.watch(zonesProvider);

    return Scaffold(
      body: SafeArea(child: CustomScrollView(slivers: [
        // ── Header
        SliverToBoxAdapter(child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: userAsync.when(
            data: (user) => Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting(), style: const TextStyle(fontSize: 12, color: AppColors.green)),
                Text(user?.name ?? 'Responsable', style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                if (user?.zone != null)
                  Container(margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.green.withOpacity(0.25))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(
                          color: AppColors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('En service · ${user!.zone}',
                          style: const TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w600)),
                    ])),
              ]),
              const Spacer(),
              Container(width: 42, height: 42,
                decoration: const BoxDecoration(gradient: AppColors.greenGrad, shape: BoxShape.circle),
                child: const Icon(Icons.shield, color: Colors.white, size: 22)),
            ]),
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox(),
          ),
        )),

        // ── Global stats
        SliverToBoxAdapter(child: zonesAsync.when(
          data: (zones) {
            final totalSpots    = zones.fold(0, (s, z) => s + z.totalSpots);
            final occupiedSpots = zones.fold(0, (s, z) => s + z.occupiedSpots);
            final freeSpots     = totalSpots - occupiedSpots;
            final rate          = totalSpots > 0 ? (occupiedSpots / totalSpots * 100).toInt() : 0;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.8,
                children: [
                  StatCard(value: '$totalSpots', label: 'Places totales',
                      icon: Icons.local_parking, accent: AppColors.blue2, trend: '5 zones'),
                  StatCard(value: '$occupiedSpots', label: 'Occupées',
                      icon: Icons.directions_car, accent: AppColors.red, trend: '$rate%'),
                  StatCard(value: '$freeSpots', label: 'Libres',
                      icon: Icons.check_circle_outline, accent: AppColors.green),
                  StatCard(value: '${zones.length}', label: 'Zones actives',
                      icon: Icons.layers_outlined, accent: AppColors.purple),
                ],
              ),
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.green)))),
          error: (e, _) => ErrorBox(message: e.toString()),
        )),

        // ── Zones detail
        const SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: SectionHeader(title: '🗺️ Occupation par zone'),
        )),

        zonesAsync.when(
          data: (zones) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final z = zones[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ParkCard(
                    onTap: () => context.push('/resp/dashboard/zone/${z.id}'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(_icon(z.type), style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text(z.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        StatusBadge(
                          label: z.isFull ? 'Plein' : '${z.freeSpots} libres',
                          color: z.isFull ? AppColors.red
                              : z.freeSpots <= 5 ? AppColors.yellow : AppColors.green,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
                      ]),
                      const SizedBox(height: 10),
                      OccBar(value: z.rate),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('${z.occupiedSpots}/${z.totalSpots} places',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const Spacer(),
                        Text('${(z.rate * 100).toInt()}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: z.rate >= 0.9 ? AppColors.red
                                    : z.rate >= 0.7 ? AppColors.yellow : AppColors.green)),
                      ]),
                    ]),
                  ).animate(delay: (i * 60).ms).fadeIn().slideX(begin: 0.05),
                );
              },
              childCount: zones.length,
            )),
          ),
          loading: () => const SliverToBoxAdapter(child: SizedBox()),
          error: (e, _) => SliverToBoxAdapter(child: ErrorBox(message: e.toString())),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ])),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? '🌅 Bonjour' : h < 18 ? '☀️ Bon après-midi' : '🌙 Bonsoir';
  }

  String _icon(String t) => {'vip':'⭐','couvert':'ju','souterrain':'🔽','pmr':'♿'}[t] ?? '🅿️';
}

// ══════════════════════════════════════════════════════
//  ZONE DETAIL
// ══════════════════════════════════════════════════════
class ZoneDetailScreen extends ConsumerWidget {
  final String zoneId;
  const ZoneDetailScreen({super.key, required this.zoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(zonesProvider);
    final logsAsync  = ref.watch(zoneLogsProvider(zoneId));
    final resvAsync  = ref.watch(zoneActiveResvProvider(zoneId));

    final zone = zonesAsync.asData?.value.where((z) => z.id == zoneId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(zone?.name ?? 'Zone'),
          leading: GestureDetector(onTap: () => context.pop(),
              child: const Icon(Icons.arrow_back_ios_new, size: 18))),
      body: zone == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              // ── Zone stats
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.8,
                children: [
                  StatCard(value: '${zone.totalSpots}', label: 'Total', icon: Icons.grid_view, accent: AppColors.blue2),
                  StatCard(value: '${zone.occupiedSpots}', label: 'Occupées', icon: Icons.directions_car, accent: AppColors.red),
                  StatCard(value: '${zone.freeSpots}', label: 'Libres', icon: Icons.check_circle_outline, accent: AppColors.green),
                  StatCard(value: '${zone.pricePerHour.toInt()} DZD', label: 'Prix/h', icon: Icons.payments_outlined, accent: AppColors.cyan),
                ],
              ),
              const SizedBox(height: 16),
              OccBar(value: zone.rate, height: 10),
              const SizedBox(height: 20),

              // ── Active reservations
              const SectionHeader(title: '📋 Réservations actives'),
              const SizedBox(height: 10),
              resvAsync.when(
                data: (list) => list.isEmpty
                    ? const _Empty(msg: 'Aucune réservation active')
                    : Column(children: list.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ParkCard(child: Row(children: [
                          const Icon(Icons.directions_car_outlined, color: AppColors.textMuted, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.vehiclePlate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text('${r.userName} · Place ${r.spotNumber}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ])),
                          StatusBadge(label: r.status == ReservationStatus.active ? 'En cours' : 'À venir',
                              color: r.status == ReservationStatus.active ? AppColors.green : AppColors.blue2),
                        ])),
                      )).toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorBox(message: e.toString()),
              ),
              const SizedBox(height: 20),

              // ── Recent logs
              const SectionHeader(title: '📜 Journal d\'entrées/sorties'),
              const SizedBox(height: 10),
              logsAsync.when(
                data: (logs) => logs.isEmpty
                    ? const _Empty(msg: 'Aucun mouvement enregistré')
                    : Column(children: logs.take(20).map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ParkCard(padding: const EdgeInsets.all(12), child: Row(children: [
                          Container(width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: (l.type == LogType.entry ? AppColors.green : AppColors.red).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(l.type == LogType.entry ? Icons.login : Icons.logout,
                                color: l.type == LogType.entry ? AppColors.green : AppColors.red, size: 16)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.plate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                            Text(l.ownerName, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ])),
                          Text(timeago.format(l.timestamp, locale: 'fr'),
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ])),
                      )).toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorBox(message: e.toString()),
              ),
            ]),
    );
  }
}

// ══════════════════════════════════════════════════════
//  SCANNER / CONTRÔLE VÉHICULES
// ══════════════════════════════════════════════════════
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override ConsumerState<ScannerScreen> createState() => _ScanState();
}

class _ScanState extends ConsumerState<ScannerScreen> {
  final _plateCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _spotCtrl  = TextEditingController();
  String? _selectedZoneId;
  bool _loading = false;

  @override void dispose() { _plateCtrl.dispose(); _ownerCtrl.dispose(); _spotCtrl.dispose(); super.dispose(); }

  Future<void> _log(LogType type) async {
    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null || _selectedZoneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Sélectionnez une zone')));
      return;
    }
    if (_plateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Entrez la plaque')));
      return;
    }
    setState(() => _loading = true);
    try {
      final zones = ref.read(zonesProvider).asData?.value ?? [];
      final zone  = zones.firstWhere((z) => z.id == _selectedZoneId);
      await ref.read(parkingServiceProvider).logVehicle(
        plate: _plateCtrl.text.trim().toUpperCase(),
        ownerName: _ownerCtrl.text.trim().isEmpty ? 'Inconnu' : _ownerCtrl.text.trim(),
        zone: zone,
        spot: _spotCtrl.text.trim().isEmpty ? '—' : _spotCtrl.text.trim(),
        type: type,
        resp: user,
      );
      if (!mounted) return;
      _plateCtrl.clear(); _ownerCtrl.clear(); _spotCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(type == LogType.entry ? '✅ Entrée enregistrée' : '✅ Sortie enregistrée'),
        backgroundColor: type == LogType.entry ? AppColors.green : AppColors.red,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesProvider);
    final logsAsync  = _selectedZoneId != null
        ? ref.watch(zoneLogsProvider(_selectedZoneId!))
        : const AsyncValue<List<VehicleLog>>.data([]);

    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle véhicules')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Zone selector
        const Text('ZONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        zonesAsync.when(
          data: (zones) => DropdownButtonFormField<String>(
            value: _selectedZoneId,
            decoration: const InputDecoration(hintText: 'Sélectionner une zone'),
            dropdownColor: AppColors.card,
            style: const TextStyle(color: AppColors.textPri, fontSize: 14),
            items: zones.map((z) => DropdownMenuItem(value: z.id,
                child: Text('${z.name} · ${z.freeSpots} libres'))).toList(),
            onChanged: (v) => setState(() => _selectedZoneId = v),
          ),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 20),

        // ── Vehicle form
        ParkCard(child: Column(children: [
          const Row(children: [
            Icon(Icons.directions_car, color: AppColors.green, size: 18),
            SizedBox(width: 8),
            Text('Informations véhicule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ParkField(label: 'Plaque *', hint: '16-12345-A', controller: _plateCtrl,
              prefix: const Icon(Icons.credit_card, color: AppColors.textMuted, size: 18)),
          const SizedBox(height: 12),
          ParkField(label: 'Propriétaire', hint: 'Nom (optionnel)', controller: _ownerCtrl,
              prefix: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 18)),
          const SizedBox(height: 12),
          ParkField(label: 'N° Place', hint: 'ex: A-14', controller: _spotCtrl,
              prefix: const Icon(Icons.grid_view, color: AppColors.textMuted, size: 18)),
          const SizedBox(height: 20),

          // ── Action buttons
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: _loading ? null : () => _log(LogType.entry),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGrad, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.login, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text('Entrée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (_loading) const SizedBox(width: 8),
                  if (_loading) const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _loading ? null : () => _log(LogType.exit),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red.withOpacity(0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout, color: AppColors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Sortie', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            )),
          ]),
        ])),
        const SizedBox(height: 24),

        // ── Recent logs
        const SectionHeader(title: '📜 Journal récent'),
        const SizedBox(height: 12),
        logsAsync.when(
          data: (logs) => logs.isEmpty
              ? const _Empty(msg: 'Aucun mouvement pour cette zone')
              : Column(children: logs.take(15).map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ParkCard(padding: const EdgeInsets.all(12), child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: (l.type == LogType.entry ? AppColors.green : AppColors.red).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        l.type == LogType.entry ? Icons.arrow_downward : Icons.arrow_upward,
                        color: l.type == LogType.entry ? AppColors.green : AppColors.red, size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.plate, style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', letterSpacing: 1)),
                      Text(l.ownerName, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(timeago.format(l.timestamp, locale: 'fr'),
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(l.spotNumber, style: const TextStyle(fontSize: 11, color: AppColors.cyan)),
                    ]),
                  ])).animate(delay: Duration.zero).fadeIn(),
                )).toList()),
          loading: () => const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.green))),
          error: (e, _) => ErrorBox(message: e.toString()),
        ),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════
//  RESPONSABLE PROFILE
// ══════════════════════════════════════════════════════
class RespProfileScreen extends ConsumerWidget {
  const RespProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          return ListView(padding: const EdgeInsets.all(20), children: [
            // ── Card
            ParkCard(
              bgColor: AppColors.green.withOpacity(0.07),
              borderColor: AppColors.green.withOpacity(0.3),
              child: Row(children: [
                Container(width: 58, height: 58,
                  decoration: const BoxDecoration(gradient: AppColors.greenGrad, shape: BoxShape.circle),
                  child: Center(child: Text(user.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  StatusBadge(label: '🛡️ Responsable', color: AppColors.green),
                ])),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Shift card
            ParkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SHIFT ACTUEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.schedule, color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                Text(user.shift ?? 'Matin 06:00 – 14:00',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              if (user.zone != null) Row(children: [
                const Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text(user.zone!, style: const TextStyle(fontSize: 13, color: AppColors.textSec)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: _shiftProgress(), minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              )),
              const SizedBox(height: 6),
              Text('${(_shiftProgress() * 100).toInt()}% du shift effectué',
                  style: const TextStyle(fontSize: 11, color: AppColors.green)),
            ])),
            const SizedBox(height: 16),

            // ── Info
            ParkCard(child: Column(children: [
              _Row(Icons.person_outline, 'Nom', user.name),
              const Divider(height: 20, color: AppColors.border),
              _Row(Icons.email_outlined, 'Email', user.email),
              const Divider(height: 20, color: AppColors.border),
              _Row(Icons.phone_outlined, 'Téléphone', user.phone.isEmpty ? '—' : user.phone),
              const Divider(height: 20, color: AppColors.border),
              _Row(Icons.layers_outlined, 'Zone', user.zone ?? '—'),
            ])),
            const SizedBox(height: 20),

            // ── Emergency contacts
            ParkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CONTACTS URGENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              _Row(Icons.admin_panel_settings_outlined, 'Admin', '+213 555 000 001'),
              const Divider(height: 16, color: AppColors.border),
              _Row(Icons.emergency, 'Urgence', '17'),
            ])),
            const SizedBox(height: 24),

            ParkButton(
              label: 'Déconnexion', icon: Icons.logout,
              outlined: true, colors: [AppColors.red],
              onTap: () async {
                await ref.read(authServiceProvider).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox(),
      ),
    );
  }

  double _shiftProgress() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 6, 0);
    final end   = DateTime(now.year, now.month, now.day, 14, 0);
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return 1;
    return now.difference(start).inMinutes / end.difference(start).inMinutes;
  }
}

Widget _Row(IconData icon, String label, String value) => Row(children: [
  Icon(icon, color: AppColors.textMuted, size: 18),
  const SizedBox(width: 12),
  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
  const Spacer(),
  Flexible(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
]);

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty({required this.msg});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(child: Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
  );
}
