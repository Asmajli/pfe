// ══════════════════════════════════════════════════════
//  RESPONSABLE SHELL + ALL SCREENS
// ══════════════════════════════════════════════════════
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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

    // إذا عندو zone → وجّهه مباشرة للخريطة البصرية
    final user  = userAsync.asData?.value;
    final zones = zonesAsync.asData?.value ?? [];
    if (user?.zone != null && zones.isNotEmpty) {
      final zoneObj = zones.where((z) => z.id == user!.zone)
          .cast<ParkingZone?>()
          .firstWhere((_) => true, orElse: () => null);
      if (zoneObj != null) {
        return _RespParkingMap(zone: zoneObj);
      }
    }

    return Scaffold(
      body: SafeArea(child: CustomScrollView(slivers: [
        // ── Header
        SliverToBoxAdapter(child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: userAsync.when(
            data: (user) {
              // نجيب اسم الـ zone من الـ zones list
              final zones = ref.watch(zonesProvider).asData?.value ?? [];
              final zoneObj = user?.zone != null
                  ? zones.where((z) => z.id == user!.zone).cast<ParkingZone?>().firstWhere((_) => true, orElse: () => null)
                  : null;
              final zoneName = zoneObj?.name ?? user?.zone ?? '';

              return Row(children: [
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
                      Text('En service · $zoneName',
                          style: const TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w600)),
                    ])),
              ]),
              const Spacer(),
              Container(width: 42, height: 42,
                decoration: const BoxDecoration(gradient: AppColors.greenGrad, shape: BoxShape.circle),
                child: const Icon(Icons.shield, color: Colors.white, size: 22)),
            ]);
            },
            loading: () => const SizedBox(height: 60),
            error: (_, __) => const SizedBox(),
          ),
        )),

        // ── Global stats
        SliverToBoxAdapter(child: zonesAsync.when(
          data: (zones) {
            final totalSpots    = zones.fold<int>(0, (s, z) => s + z.totalSpots);
            final occupiedSpots = zones.fold<int>(0, (s, z) => s + z.occupiedSpots);
            final freeSpots     = totalSpots - occupiedSpots;
            final rate          = totalSpots > 0 ? (occupiedSpots / totalSpots * 100).toInt() : 0;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
                children: [
                  StatCard(value: '$totalSpots', label: 'Places totales', icon: Icons.local_parking, accent: AppColors.blue2, trend: '5 zones'),
                  StatCard(value: '$occupiedSpots', label: 'Occupées', icon: Icons.directions_car, accent: AppColors.red, trend: '$rate%'),
                  StatCard(value: '$freeSpots', label: 'Libres', icon: Icons.check_circle_outline, accent: AppColors.green),
                  StatCard(value: '${zones.length}', label: 'Zones actives', icon: Icons.layers_outlined, accent: AppColors.purple),
                ],
              ),
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.green)))),
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
                          color: z.isFull ? AppColors.red : z.freeSpots <= 5 ? AppColors.yellow : AppColors.green,
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
                                color: z.rate >= 0.9 ? AppColors.red : z.rate >= 0.7 ? AppColors.yellow : AppColors.green)),
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

  String _icon(String t) => {'vip':'⭐','couvert':'🏗️','souterrain':'🔽','pmr':'♿'}[t] ?? '🅿️';
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

    final zone = zonesAsync.asData?.value
        .where((z) => z.id == zoneId)
        .cast<ParkingZone?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Text(zone?.name ?? 'Zone'),
        leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new, size: 18)),
      ),
      body: zone == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
                children: [
                  StatCard(value: '${zone.totalSpots}', label: 'Total', icon: Icons.grid_view, accent: AppColors.blue2),
                  StatCard(value: '${zone.occupiedSpots}', label: 'Occupées', icon: Icons.directions_car, accent: AppColors.red),
                  StatCard(value: '${zone.freeSpots}', label: 'Libres', icon: Icons.check_circle_outline, accent: AppColors.green),
                  StatCard(value: '${zone.pricePerHour.toInt()} DT', label: 'Prix/h', icon: Icons.payments_outlined, accent: AppColors.cyan),
                ],
              ),
              const SizedBox(height: 16),
              OccBar(value: zone.rate, height: 10),
              const SizedBox(height: 16),

              // ── Boutons accès rapide ──
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => context.push('/resp/dashboard/zone/${zone.id}/map'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.blue2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.blue2.withOpacity(0.3)),
                    ),
                    child: const Column(children: [
                      Text('🗺️', style: TextStyle(fontSize: 22)),
                      SizedBox(height: 4),
                      Text('Carte places', style: TextStyle(fontSize: 11, color: AppColors.blue2, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => context.push('/resp/dashboard/zone/${zone.id}/3d'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withOpacity(0.3)),
                    ),
                    child: const Column(children: [
                      Text('🏗️', style: TextStyle(fontSize: 22)),
                      SizedBox(height: 4),
                      Text('Vue 3D', style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => context.push('/resp/dashboard/zone/${zone.id}/reservations'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                    ),
                    child: const Column(children: [
                      Text('📋', style: TextStyle(fontSize: 22)),
                      SizedBox(height: 4),
                      Text('Réservations', style: TextStyle(fontSize: 11, color: AppColors.cyan, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => context.push('/resp/dashboard/zone/${zone.id}/stats'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.purple.withOpacity(0.3)),
                    ),
                    child: const Column(children: [
                      Text('📊', style: TextStyle(fontSize: 22)),
                      SizedBox(height: 4),
                      Text('Statistiques', style: TextStyle(fontSize: 11, color: AppColors.purple, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => context.push('/resp/dashboard/zone/${zone.id}/live'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Column(children: [
                      Text('📹', style: TextStyle(fontSize: 22)),
                      SizedBox(height: 4),
                      Text('Live', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
              ]),
              const SizedBox(height: 20),

              // ── Active reservations
              const SectionHeader(title: '📋 Réservations actives'),
              const SizedBox(height: 10),
              resvAsync.when(
                data: (list) => list.isEmpty
                    ? const _Empty(msg: 'Aucune réservation active')
                    : Column(
                        children: list.map<Widget>((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ParkCard(child: Row(children: [
                            const Icon(Icons.directions_car_outlined, color: AppColors.textMuted, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.vehiclePlate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${r.userName} · Place ${r.spotNumber}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ])),
                            StatusBadge(
                              label: r.status == ReservationStatus.active ? 'En cours' : 'À venir',
                              color: r.status == ReservationStatus.active ? AppColors.green : AppColors.blue2,
                            ),
                          ])),
                        )).toList(),
                      ),
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
                    : Column(
                        children: logs.take(20).map<Widget>((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ParkCard(padding: const EdgeInsets.all(12), child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: (l.type == LogType.entry ? AppColors.green : AppColors.red).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                l.type == LogType.entry ? Icons.login : Icons.logout,
                                color: l.type == LogType.entry ? AppColors.green : AppColors.red,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.plate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                              Text(l.ownerName, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ])),
                            Text(timeago.format(l.timestamp, locale: 'fr'),
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          ])),
                        )).toList(),
                      ),
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

  @override
  void dispose() {
    _plateCtrl.dispose(); _ownerCtrl.dispose(); _spotCtrl.dispose();
    super.dispose();
  }

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
      final zones = ref.read(zonesProvider).asData?.value ?? <ParkingZone>[];
      final zone  = zones.firstWhere((z) => z.id == _selectedZoneId);
      await ref.read(parkingServiceProvider).logVehicle(
        plate: _plateCtrl.text.trim().toUpperCase(),
        ownerName: _ownerCtrl.text.trim().isEmpty ? 'Inconnu' : _ownerCtrl.text.trim(),
        zone: zone, spot: _spotCtrl.text.trim().isEmpty ? '—' : _spotCtrl.text.trim(),
        type: type, resp: user,
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
      appBar: AppBar(
        title: const Text('Contrôle véhicules'),
        actions: [
          GestureDetector(
            onTap: () => context.push('/resp/scanner/qr'),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue.withOpacity(0.8), AppColors.cyan.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Scanner QR', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('ZONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        zonesAsync.when(
          data: (zones) => DropdownButtonFormField<String>(
            value: _selectedZoneId,
            decoration: const InputDecoration(hintText: 'Sélectionner une zone'),
            dropdownColor: AppColors.card,
            style: const TextStyle(color: AppColors.textPri, fontSize: 14),
            items: zones.map<DropdownMenuItem<String>>((z) => DropdownMenuItem<String>(
              value: z.id,
              child: Text('${z.name} · ${z.freeSpots} libres'),
            )).toList(),
            onChanged: (v) => setState(() => _selectedZoneId = v),
          ),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 20),

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
                  if (_loading) ...[const SizedBox(width: 8),
                    const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))],
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

        const SectionHeader(title: '📜 Journal récent'),
        const SizedBox(height: 12),
        logsAsync.when(
          data: (logs) => logs.isEmpty
              ? const _Empty(msg: 'Aucun mouvement pour cette zone')
              : Column(
                  children: logs.take(15).map<Widget>((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ParkCard(padding: const EdgeInsets.all(12), child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: (l.type == LogType.entry ? AppColors.green : AppColors.red).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          l.type == LogType.entry ? Icons.arrow_downward : Icons.arrow_upward,
                          color: l.type == LogType.entry ? AppColors.green : AppColors.red,
                          size: 18,
                        ),
                      ),
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
                  )).toList(),
                ),
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
    final zones = ref.watch(zonesProvider).asData?.value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: userAsync.when(
        data: (user) {
          // اسم الـ zone الحقيقي
          final zoneObj = user?.zone != null
              ? zones.where((z) => z.id == user!.zone).cast<ParkingZone?>().firstWhere((_) => true, orElse: () => null)
              : null;
          final zoneName = zoneObj?.name ?? user?.zone ?? '—';
          if (user == null) return const SizedBox();
          return ListView(padding: const EdgeInsets.all(20), children: [
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
              if (user!.zone != null) Row(children: [
                const Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text(zoneName, style: const TextStyle(fontSize: 13, color: AppColors.textSec)),
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

            ParkCard(child: Column(children: [
              _RRow(Icons.person_outline, 'Nom', user.name),
              const Divider(height: 20, color: AppColors.border),
              _RRow(Icons.email_outlined, 'Email', user.email),
              const Divider(height: 20, color: AppColors.border),
              _RRow(Icons.phone_outlined, 'Téléphone', user.phone.isEmpty ? '—' : user.phone),
              const Divider(height: 20, color: AppColors.border),
              _RRow(Icons.layers_outlined, 'Zone', zoneName),
            ])),
            const SizedBox(height: 20),

            ParkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CONTACTS URGENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              _RRow(Icons.admin_panel_settings_outlined, 'Admin', '+216 555 000 001'),
              const Divider(height: 16, color: AppColors.border),
              _RRow(Icons.emergency, 'Urgence', '197'),
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

Widget _RRow(IconData icon, String label, String value) => Row(children: [
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

// ══════════════════════════════════════════════════════
//  QR SCANNER SCREEN — للمسؤول
// ══════════════════════════════════════════════════════
class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});
  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerState();
}

class _QRScannerState extends ConsumerState<QRScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || !raw.startsWith('PARK|')) return;

    setState(() => _scanned = true);
    _ctrl.stop();

    final parts = raw.split('|');
    if (parts.length < 7) { _reset(); return; }

    final resvId   = parts[1];
    final zoneId   = parts[2];
    final zoneName = parts[3];
    final spot     = parts[4];
    final startStr = parts[5];
    final endStr   = parts[6];

    DateTime? start, end;
    try {
      start = DateTime.parse(startStr);
      end   = DateTime.parse(endStr);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0d1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.green.withOpacity(0.8), AppColors.cyan.withOpacity(0.8)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 14),
          const Text('QR Code Valide ✅',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.green)),
          const SizedBox(height: 16),

          // ── Infos réservation ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _QRInfo(Icons.local_parking, 'Zone', zoneName, AppColors.blue2),
              const Divider(height: 16, color: AppColors.border),
              _QRInfo(Icons.grid_view, 'Place', spot, AppColors.cyan),
              if (start != null) ...[
                const Divider(height: 16, color: AppColors.border),
                _QRInfo(Icons.schedule, 'Début', DateFormat('dd/MM  HH:mm').format(start), AppColors.textSec),
              ],
              if (end != null) ...[
                const Divider(height: 16, color: AppColors.border),
                _QRInfo(Icons.flag_outlined, 'Fin', DateFormat('dd/MM  HH:mm').format(end), AppColors.purple),
              ],
              const Divider(height: 16, color: AppColors.border),
              _QRInfo(Icons.confirmation_number_outlined, 'ID', resvId.substring(0, 8).toUpperCase(), AppColors.textMuted),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Actions ──
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final user = ref.read(currentUserProvider).asData?.value;
                if (user == null) return;
                final zones = ref.read(zonesProvider).asData?.value ?? <ParkingZone>[];
                final zone  = zones.where((z) => z.id == zoneId).cast<ParkingZone?>().firstWhere((_) => true, orElse: () => null);
                if (zone == null) return;
                await ref.read(parkingServiceProvider).logVehicle(
                  plate: spot, ownerName: 'Via QR',
                  zone: zone, spot: spot,
                  type: LogType.entry, resp: user,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ Entrée enregistrée'),
                    backgroundColor: AppColors.green,
                  ));
                }
                _reset();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGrad,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.login, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Entrée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final user = ref.read(currentUserProvider).asData?.value;
                if (user == null) return;
                final zones = ref.read(zonesProvider).asData?.value ?? <ParkingZone>[];
                final zone  = zones.where((z) => z.id == zoneId).cast<ParkingZone?>().firstWhere((_) => true, orElse: () => null);
                if (zone == null) return;
                await ref.read(parkingServiceProvider).logVehicle(
                  plate: spot, ownerName: 'Via QR',
                  zone: zone, spot: spot,
                  type: LogType.exit, resp: user,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ Sortie enregistrée'),
                    backgroundColor: AppColors.red,
                  ));
                }
                _reset();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red.withOpacity(0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout, color: AppColors.red, size: 18),
                  SizedBox(width: 6),
                  Text('Sortie', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () { Navigator.pop(context); _reset(); },
            child: const Text('Scanner un autre code',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
        ]),
      ),
    ).whenComplete(_reset);
  }

  void _reset() {
    if (mounted) {
      setState(() => _scanned = false);
      _ctrl.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scanner QR Client'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(children: [
        // ── Camera ──
        MobileScanner(controller: _ctrl, onDetect: _onDetect),

        // ── Overlay ──
        Center(child: Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cyan, width: 2.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(children: [
            // Coins colorés
            Positioned(top: 0, left: 0, child: _Corner(true, true)),
            Positioned(top: 0, right: 0, child: _Corner(true, false)),
            Positioned(bottom: 0, left: 0, child: _Corner(false, true)),
            Positioned(bottom: 0, right: 0, child: _Corner(false, false)),
          ]),
        )),

        // ── Texte guide ──
        Positioned(
          bottom: 80, left: 0, right: 0,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Placez le QR Code du client dans le cadre',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )),
        ),
      ]),
    );
  }
}

Widget _Corner(bool top, bool left) => Container(
  width: 24, height: 24,
  decoration: BoxDecoration(
    border: Border(
      top: top    ? const BorderSide(color: AppColors.cyan, width: 4) : BorderSide.none,
      bottom: !top ? const BorderSide(color: AppColors.cyan, width: 4) : BorderSide.none,
      left: left   ? const BorderSide(color: AppColors.cyan, width: 4) : BorderSide.none,
      right: !left ? const BorderSide(color: AppColors.cyan, width: 4) : BorderSide.none,
    ),
  ),
);

Widget _QRInfo(IconData icon, String label, String value, Color color) => Row(children: [
  Icon(icon, size: 15, color: color),
  const SizedBox(width: 8),
  Text('$label : ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
  Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      overflow: TextOverflow.ellipsis)),
]);

// ══════════════════════════════════════════════════════
//  PARKING MAP SCREEN — خريطة بصرية للـ parking
// ══════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════
//  RESP PARKING MAP — الواجهة الرئيسية للـ responsable
// ══════════════════════════════════════════════════════
class _RespParkingMap extends ConsumerWidget {
  final ParkingZone zone;
  const _RespParkingMap({required this.zone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resvAsync = ref.watch(zoneActiveResvProvider(zone.id));
    final logsAsync = ref.watch(zoneLogsProvider(zone.id));

    return Scaffold(
      body: SafeArea(child: resvAsync.when(
        data: (reservations) {
          final occupied = reservations.map((r) => r.spotNumber).toSet();
          final total    = zone.totalSpots;
          final free     = total - occupied.length;

          // نبني قائمة الأماكن مع نوعها
          final spots = List.generate(total, (i) {
            final num    = i + 1;
            final spotId = 'P-$num';
            final isOcc  = occupied.contains(spotId);
            // نوع المكان حسب الرقم
            final type = num <= (total * 0.1).ceil()
                ? 'pmr'
                : num <= (total * 0.2).ceil()
                    ? 'moto'
                    : num <= (total * 0.4).ceil()
                        ? 'vip'
                        : 'standard';
            final resv = isOcc
                ? reservations.cast<Reservation?>().firstWhere(
                    (r) => r?.spotNumber == spotId, orElse: () => null)
                : null;
            // هل بقيت أقل من 30 دقيقة؟
            final bientot = isOcc && resv?.endTime != null &&
                resv!.endTime!.difference(DateTime.now()).inMinutes < 30 &&
                resv.endTime!.isAfter(DateTime.now());
            return _SpotInfo(
              id: spotId, num: num, type: type,
              isOccupied: isOcc, bientotLibre: bientot, reservation: resv,
            );
          });

          return CustomScrollView(slivers: [
            // ── Header ──
            SliverToBoxAdapter(child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(gradient: AppColors.greenGrad, shape: BoxShape.circle),
                    child: const Icon(Icons.shield, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(zone.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Row(children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('En service', style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
                    ]),
                  ])),
                  // زر Scanner QR
                  GestureDetector(
                    onTap: () => context.push('/resp/scanner/qr'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.blue.withOpacity(0.8), AppColors.cyan.withOpacity(0.8)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text('Scanner', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Stats rapides
                Row(children: [
                  _QuickStat('$free', 'Libres', AppColors.green),
                  _QuickStat('${occupied.length}', 'Occupées', AppColors.red),
                  _QuickStat('$total', 'Total', AppColors.blue2),
                  _QuickStat('${total > 0 ? (occupied.length / total * 100).toInt() : 0}%', 'Taux', AppColors.cyan),
                ]),
                const SizedBox(height: 10),
                OccBar(value: total > 0 ? occupied.length / total : 0, height: 8),
              ]),
            )),

            // ── Légende ──
            SliverToBoxAdapter(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _Leg(AppColors.green,  '🚗 Standard'),
                  _Leg(AppColors.blue2,  '⭐ VIP'),
                  _Leg(AppColors.purple, '♿ PMR'),
                  _Leg(const Color(0xFFf97316), '🏍 Moto'),
                  _Leg(AppColors.yellow, '⏱ Bientôt libre'),
                  _Leg(AppColors.red,    '🔴 Occupée'),
                ]),
              ),
            )),

            // ── Grille des places ──
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _SpotTile(
                    spot: spots[i],
                    onTap: spots[i].isOccupied ? () => _showSpotDetail(context, spots[i]) : null,
                  ),
                  childCount: spots.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.82,
                ),
              ),
            ),

            // ── Journal récent ──
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: SectionHeader(
                title: '📜 Activité récente',
                action: 'Tout voir',
                onAction: () => context.push('/resp/dashboard/zone/${zone.id}'),
              ),
            )),
            SliverToBoxAdapter(child: logsAsync.when(
              data: (logs) => logs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('Aucune activité', style: TextStyle(color: AppColors.textMuted))),
                    )
                  : Column(
                      children: logs.take(5).map<Widget>((l) => Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: ParkCard(padding: const EdgeInsets.all(12), child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: (l.type == LogType.entry ? AppColors.green : AppColors.red).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              l.type == LogType.entry ? Icons.login : Icons.logout,
                              color: l.type == LogType.entry ? AppColors.green : AppColors.red,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(l.plate,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                          Text(timeago.format(l.timestamp, locale: 'fr'),
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ])),
                      )).toList(),
                    ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.green))),
        error: (e, _) => ErrorBox(message: e.toString()),
      )),
    );
  }

  void _showSpotDetail(BuildContext context, _SpotInfo spot) {
    final r = spot.reservation;
    if (r == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0d1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.directions_car, color: AppColors.red, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.vehiclePlate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              Text(r.userName, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ])),
            StatusBadge(
              label: spot.bientotLibre ? '⏱ Bientôt libre' : r.status == ReservationStatus.active ? 'En cours' : 'À venir',
              color: spot.bientotLibre ? AppColors.yellow : r.status == ReservationStatus.active ? AppColors.green : AppColors.blue2,
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              _QRInfo(Icons.grid_view, 'Place', spot.id, AppColors.cyan),
              const Divider(height: 14, color: AppColors.border),
              _QRInfo(Icons.schedule, 'Début', DateFormat('dd/MM HH:mm').format(r.startTime), AppColors.textSec),
              if (r.endTime != null) ...[
                const Divider(height: 14, color: AppColors.border),
                _QRInfo(Icons.flag_outlined, 'Fin', DateFormat('dd/MM HH:mm').format(r.endTime!), AppColors.purple),
              ],
              const Divider(height: 14, color: AppColors.border),
              _QRInfo(Icons.payments_outlined, 'Prix/h', '${r.pricePerHour.toStringAsFixed(1)} DT', AppColors.green),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers ──
class _SpotInfo {
  final String id, type;
  final int num;
  final bool isOccupied, bientotLibre;
  final Reservation? reservation;
  const _SpotInfo({required this.id, required this.num, required this.type,
      required this.isOccupied, required this.bientotLibre, this.reservation});
}

class _SpotTile extends StatelessWidget {
  final _SpotInfo spot;
  final VoidCallback? onTap;
  const _SpotTile({required this.spot, this.onTap});

  Color get _color {
    if (spot.isOccupied) return spot.bientotLibre ? AppColors.yellow : AppColors.red;
    return switch (spot.type) {
      'vip'      => AppColors.blue2,
      'pmr'      => AppColors.purple,
      'moto'     => const Color(0xFFf97316),
      _          => AppColors.green,
    };
  }

  String get _icon => spot.isOccupied ? '🚗' : switch (spot.type) {
    'vip'  => '⭐',
    'pmr'  => '♿',
    'moto' => '🏍',
    _      => '🅿️',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _color.withOpacity(spot.isOccupied ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withOpacity(spot.isOccupied ? 0.7 : 0.35), width: spot.isOccupied ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text('P-${spot.num}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _color)),
          if (spot.isOccupied)
            Container(margin: const EdgeInsets.only(top: 2), width: 5, height: 5,
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}

Widget _QuickStat(String value, String label, Color color) => Expanded(child: Column(children: [
  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
  Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
]));

Widget _Leg(Color color, String label) => Padding(
  padding: const EdgeInsets.only(right: 12),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSec)),
  ]),
);

class ParkingMapScreen extends ConsumerWidget {
  final String zoneId;
  const ParkingMapScreen({super.key, required this.zoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(zonesProvider);
    final resvAsync  = ref.watch(zoneActiveResvProvider(zoneId));

    final zone = zonesAsync.asData?.value
        .where((z) => z.id == zoneId)
        .cast<ParkingZone?>()
        .firstWhere((_) => true, orElse: () => null);

    if (zone == null) return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('🗺️ ${zone.name}'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: resvAsync.when(
        data: (reservations) {
          // جمع أرقام الأماكن المحجوزة
          final occupied = reservations.map((r) => r.spotNumber).toSet();
          final total = zone.totalSpots;

          // بناء قائمة الأماكن
          final spots = List.generate(total, (i) {
            final num = i + 1;
            final spotId = 'P-$num';
            final isOccupied = occupied.contains(spotId);
            final resv = isOccupied
                ? reservations.firstWhere((r) => r.spotNumber == spotId)
                : null;
            return _SpotData(spotId: spotId, isOccupied: isOccupied, reservation: resv, index: num);
          });

          return Column(children: [
            // ── Légende ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _LegendItem(color: AppColors.green, label: 'Libre (${total - occupied.length})'),
                _LegendItem(color: AppColors.red, label: 'Occupée (${occupied.length})'),
                _LegendItem(color: AppColors.yellow, label: 'Bientôt libre'),
              ]),
            ),

            // ── Stats rapides ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: _MiniStat(
                  value: '${total - occupied.length}',
                  label: 'Libres',
                  color: AppColors.green,
                  icon: Icons.check_circle_outline,
                )),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(
                  value: '${occupied.length}',
                  label: 'Occupées',
                  color: AppColors.red,
                  icon: Icons.directions_car,
                )),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(
                  value: '${total > 0 ? (occupied.length / total * 100).toInt() : 0}%',
                  label: 'Taux',
                  color: AppColors.cyan,
                  icon: Icons.pie_chart_outline,
                )),
              ]),
            ),

            // ── Grille des places ──
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: spots.length,
                itemBuilder: (ctx, i) => _SpotCard(spot: spots[i]),
              ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBox(message: e.toString()),
      ),
    );
  }
}

class _SpotData {
  final String spotId;
  final bool isOccupied;
  final Reservation? reservation;
  final int index;
  const _SpotData({required this.spotId, required this.isOccupied, this.reservation, required this.index});
}

class _SpotCard extends StatelessWidget {
  final _SpotData spot;
  const _SpotCard({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    final color = spot.isOccupied ? AppColors.red : AppColors.green;
    return GestureDetector(
      onTap: spot.isOccupied && spot.reservation != null ? () => _showDetail(context) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            spot.isOccupied ? Icons.directions_car : Icons.local_parking,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            'P-${spot.index}',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
          if (spot.isOccupied)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final r = spot.reservation!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car, color: AppColors.red, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.vehiclePlate, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              Text(r.userName, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ])),
            StatusBadge(
              label: r.status == ReservationStatus.active ? 'En cours' : 'À venir',
              color: r.status == ReservationStatus.active ? AppColors.green : AppColors.blue2,
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _QRInfo(Icons.grid_view, 'Place', spot.spotId, AppColors.cyan),
              const Divider(height: 14, color: AppColors.border),
              _QRInfo(Icons.schedule, 'Début', DateFormat('dd/MM HH:mm').format(r.startTime), AppColors.textSec),
              if (r.endTime != null) ...[
                const Divider(height: 14, color: AppColors.border),
                _QRInfo(Icons.flag_outlined, 'Fin', DateFormat('dd/MM HH:mm').format(r.endTime!), AppColors.purple),
              ],
              const Divider(height: 14, color: AppColors.border),
              _QRInfo(Icons.payments_outlined, 'Prix/h', '${r.pricePerHour.toStringAsFixed(1)} DT', AppColors.green),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color; final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
  ]);
}

class _MiniStat extends StatelessWidget {
  final String value, label; final Color color; final IconData icon;
  const _MiniStat({required this.value, required this.label, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
    ]),
  );
}

// ══════════════════════════════════════════════════════
//  ZONE RESERVATIONS LIST — كل حجوزات الـ zone
// ══════════════════════════════════════════════════════
class ZoneReservationsScreen extends ConsumerWidget {
  final String zoneId;
  const ZoneReservationsScreen({super.key, required this.zoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resvAsync = ref.watch(zoneAllResvProvider(zoneId));
    final zonesAsync = ref.watch(zonesProvider);
    final zone = zonesAsync.asData?.value
        .where((z) => z.id == zoneId)
        .cast<ParkingZone?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Text('📋 ${zone?.name ?? 'Réservations'}'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: resvAsync.when(
        data: (list) {
          if (list.isEmpty) return const Center(
            child: Text('Aucune réservation', style: TextStyle(color: AppColors.textMuted)),
          );

          // Stats rapides
          final active    = list.where((r) => r.status == ReservationStatus.active).length;
          final upcoming  = list.where((r) => r.status == ReservationStatus.upcoming).length;
          final completed = list.where((r) => r.status == ReservationStatus.completed).length;
          final revenue   = list.where((r) => r.totalAmount != null).fold<double>(0, (s, r) => s + r.totalAmount!);

          return Column(children: [
            // ── Stats ──
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Row(children: [
                _RsvStat('En cours', '$active', AppColors.green),
                _RsvStat('À venir', '$upcoming', AppColors.blue2),
                _RsvStat('Terminées', '$completed', AppColors.textMuted),
                _RsvStat('Revenus', '${revenue.toStringAsFixed(0)} DT', AppColors.cyan),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),

            // ── Liste ──
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final r = list[i];
                  final statusColor = switch (r.status) {
                    ReservationStatus.active    => AppColors.green,
                    ReservationStatus.upcoming  => AppColors.blue2,
                    ReservationStatus.completed => AppColors.textMuted,
                    ReservationStatus.cancelled => AppColors.red,
                  };
                  final statusLabel = switch (r.status) {
                    ReservationStatus.active    => 'En cours',
                    ReservationStatus.upcoming  => 'À venir',
                    ReservationStatus.completed => 'Terminée',
                    ReservationStatus.cancelled => 'Annulée',
                  };
                  return ParkCard(
                    borderColor: statusColor.withOpacity(0.2),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.directions_car, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.vehiclePlate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                        Text('${r.userName} · Place ${r.spotNumber}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(DateFormat('dd/MM HH:mm').format(r.startTime),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        StatusBadge(label: statusLabel, color: statusColor),
                        if (r.totalAmount != null) ...[
                          const SizedBox(height: 4),
                          Text('${r.totalAmount!.toStringAsFixed(1)} DT',
                              style: const TextStyle(fontSize: 11, color: AppColors.cyan, fontWeight: FontWeight.w700)),
                        ],
                      ]),
                    ]),
                  );
                },
              ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBox(message: e.toString()),
      ),
    );
  }
}

Widget _RsvStat(String label, String value, Color color) => Expanded(
  child: Column(children: [
    Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
  ]),
);

// ══════════════════════════════════════════════════════
//  STATISTIQUES SCREEN — إحصائيات الـ zone
// ══════════════════════════════════════════════════════
class ZoneStatsScreen extends ConsumerWidget {
  final String zoneId;
  const ZoneStatsScreen({super.key, required this.zoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resvAsync  = ref.watch(zoneAllResvProvider(zoneId));
    final logsAsync  = ref.watch(zoneLogsProvider(zoneId));
    final zonesAsync = ref.watch(zonesProvider);
    final zone = zonesAsync.asData?.value
        .where((z) => z.id == zoneId)
        .cast<ParkingZone?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Text('📊 Stats · ${zone?.name ?? ''}'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: resvAsync.when(
        data: (list) {
          final revenue    = list.where((r) => r.totalAmount != null).fold<double>(0, (s, r) => s + r.totalAmount!);
          final completed  = list.where((r) => r.status == ReservationStatus.completed).length;
          final cancelled  = list.where((r) => r.status == ReservationStatus.cancelled).length;
          final active     = list.where((r) => r.status == ReservationStatus.active).length;
          final avgDur     = list.isNotEmpty
              ? list.fold<double>(0, (s, r) => s + r.elapsed.inMinutes) / list.length
              : 0.0;

          // Revenus par jour (7 derniers jours)
          final now = DateTime.now();
          final days = List.generate(7, (i) {
            final day = now.subtract(Duration(days: 6 - i));
            final dayRevenu = list
                .where((r) => r.totalAmount != null &&
                    r.createdAt.day == day.day &&
                    r.createdAt.month == day.month)
                .fold<double>(0, (s, r) => s + r.totalAmount!);
            return _DayRevenu(DateFormat('E', 'fr').format(day), dayRevenu);
          });
          final maxRevenu = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);

          return ListView(padding: const EdgeInsets.all(16), children: [
            // ── KPIs ──
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
              children: [
                StatCard(value: '${revenue.toStringAsFixed(1)} DT', label: 'Revenus totaux', icon: Icons.payments_outlined, accent: AppColors.cyan),
                StatCard(value: '${list.length}', label: 'Total réservations', icon: Icons.bookmark_outline, accent: AppColors.blue2),
                StatCard(value: '$completed', label: 'Terminées', icon: Icons.check_circle_outline, accent: AppColors.green),
                StatCard(value: '${avgDur.toInt()} min', label: 'Durée moyenne', icon: Icons.timer_outlined, accent: AppColors.purple),
              ],
            ),
            const SizedBox(height: 20),

            // ── Revenus 7 jours ──
            const SectionHeader(title: '📈 Revenus (7 derniers jours)'),
            const SizedBox(height: 12),
            ParkCard(child: Column(children: [
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days.map((d) {
                    final h = maxRevenu > 0 ? (d.amount / maxRevenu * 120) : 0.0;
                    return Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.amount > 0)
                          Text('${d.amount.toInt()}', style: const TextStyle(fontSize: 8, color: AppColors.cyan)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: h.toDouble(),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [AppColors.cyan.withOpacity(0.9), AppColors.blue.withOpacity(0.6)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(d.day, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ));
                  }).toList(),
                ),
              ),
            ])),
            const SizedBox(height: 20),

            // ── Répartition statuts ──
            const SectionHeader(title: '🥧 Répartition'),
            const SizedBox(height: 12),
            ParkCard(child: Column(children: [
              _StatBar('Terminées', completed, list.length, AppColors.green),
              const SizedBox(height: 10),
              _StatBar('En cours', active, list.length, AppColors.blue2),
              const SizedBox(height: 10),
              _StatBar('Annulées', cancelled, list.length, AppColors.red),
            ])),
            const SizedBox(height: 20),

            // ── Activité récente ──
            const SectionHeader(title: '🚗 Activité récente'),
            const SizedBox(height: 12),
            logsAsync.when(
              data: (logs) => logs.isEmpty
                  ? const _Empty(msg: 'Aucune activité')
                  : Column(
                      children: logs.take(10).map<Widget>((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ParkCard(padding: const EdgeInsets.all(12), child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: (l.type == LogType.entry ? AppColors.green : AppColors.red).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              l.type == LogType.entry ? Icons.login : Icons.logout,
                              color: l.type == LogType.entry ? AppColors.green : AppColors.red,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(l.plate,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                          Text(timeago.format(l.timestamp, locale: 'fr'),
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ])),
                      )).toList(),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => ErrorBox(message: e.toString()),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBox(message: e.toString()),
      ),
    );
  }
}

class _DayRevenu { final String day; final double amount; const _DayRevenu(this.day, this.amount); }

Widget _StatBar(String label, int value, int total, Color color) {
  final pct = total > 0 ? value / total : 0.0;
  return Row(children: [
    SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: pct, minHeight: 8,
        backgroundColor: color.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    )),
    const SizedBox(width: 8),
    Text('$value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  ]);
}

// ══════════════════════════════════════════════════════
//  VIRTUAL 3D PARKING SCREEN
// ══════════════════════════════════════════════════════
class Virtual3DParkingScreen extends ConsumerWidget {
  final String zoneId;
  const Virtual3DParkingScreen({super.key, required this.zoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(zonesProvider);
    final resvAsync  = ref.watch(zoneActiveResvProvider(zoneId));

    final zone = zonesAsync.asData?.value
        .where((z) => z.id == zoneId)
        .cast<ParkingZone?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        title: Text('🏗️ Vue 3D — ${zone?.name ?? ''}',
            style: const TextStyle(color: Colors.white)),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
        ),
      ),
      body: resvAsync.when(
        data: (reservations) {
          final occupied = reservations.map((r) => r.spotNumber).toSet();
          final total    = zone?.totalSpots ?? 20;

          return Column(children: [
            // ── Légende ──
            Container(
              color: const Color(0xFF16213e),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _3DLeg(const Color(0xFF4ade80), '🚗 Libre'),
                _3DLeg(const Color(0xFFf87171), '🔴 Occupée'),
                _3DLeg(const Color(0xFFfbbf24), '⭐ VIP'),
                _3DLeg(const Color(0xFFa78bfa), '♿ PMR'),
              ]),
            ),

            // ── Stats ──
            Container(
              color: const Color(0xFF0f3460),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _3DStat('${total - occupied.length}', 'Libres', const Color(0xFF4ade80)),
                _3DStat('${occupied.length}', 'Occupées', const Color(0xFFf87171)),
                _3DStat('$total', 'Total', const Color(0xFF60a5fa)),
                _3DStat('${total > 0 ? (occupied.length / total * 100).toInt() : 0}%', 'Taux', const Color(0xFFfbbf24)),
              ]),
            ),

            // ── Vue 3D ──
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Center(
                  child: CustomPaint(
                    size: Size(
                      MediaQuery.of(context).size.width - 20,
                      MediaQuery.of(context).size.height * 0.65,
                    ),
                    painter: _Parking3DPainter(
                      totalSpots: total,
                      occupiedSpots: occupied,
                    ),
                  ),
                ),
              ),
            ),

            // ── Info ──
            Container(
              color: const Color(0xFF16213e),
              padding: const EdgeInsets.all(10),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.pinch, color: Colors.white38, size: 14),
                SizedBox(width: 6),
                Text('Pincez pour zoomer · Faites glisser pour naviguer',
                    style: TextStyle(fontSize: 11, color: Colors.white38)),
              ]),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4ade80))),
        error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }
}

// ── 3D Parking Painter ──────────────────────────────
class _Parking3DPainter extends CustomPainter {
  final int totalSpots;
  final Set<String> occupiedSpots;

  const _Parking3DPainter({required this.totalSpots, required this.occupiedSpots});

  @override
  void paint(Canvas canvas, Size size) {
    final cols = 5;
    final rows = (totalSpots / cols).ceil();

    // حجم كل مكان
    final spotW = (size.width - 40) / cols;
    final spotH = (size.height - 60) / rows;

    // رسم الأرضية
    final floorPaint = Paint()..color = const Color(0xFF0d1b2a);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), floorPaint);

    // رسم الخطوط الأرضية
    final linePaint = Paint()
      ..color = const Color(0xFF1e3a5f)
      ..strokeWidth = 1.0;
    for (int i = 0; i <= cols; i++) {
      canvas.drawLine(
        Offset(20 + i * spotW, 20),
        Offset(20 + i * spotW, size.height - 20),
        linePaint,
      );
    }
    for (int j = 0; j <= rows; j++) {
      canvas.drawLine(
        Offset(20, 20 + j * spotH),
        Offset(size.width - 20, 20 + j * spotH),
        linePaint,
      );
    }

    // رسم كل مكان
    for (int i = 0; i < totalSpots; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final spotId = 'P-${i + 1}';
      final isOcc  = occupiedSpots.contains(spotId);

      // نوع المكان
      final type = i < (totalSpots * 0.1).ceil()
          ? 'pmr'
          : i < (totalSpots * 0.2).ceil()
              ? 'moto'
              : i < (totalSpots * 0.4).ceil()
                  ? 'vip'
                  : 'standard';

      final baseColor = isOcc
          ? const Color(0xFFf87171)
          : type == 'vip'
              ? const Color(0xFFfbbf24)
              : type == 'pmr'
                  ? const Color(0xFFa78bfa)
                  : type == 'moto'
                      ? const Color(0xFFfb923c)
                      : const Color(0xFF4ade80);

      final x = 20 + col * spotW;
      final y = 20 + row * spotH;
      final padding = 4.0;

      // ── رسم الجانب الأيسر (3D effect) ──
      final sidePaint = Paint()..color = baseColor.withOpacity(0.3);
      final sideDepth = 8.0;
      final sidePath = Path()
        ..moveTo(x + padding, y + spotH - padding)
        ..lineTo(x + padding - sideDepth, y + spotH - padding + sideDepth)
        ..lineTo(x + padding - sideDepth, y + padding + sideDepth)
        ..lineTo(x + padding, y + padding)
        ..close();
      canvas.drawPath(sidePath, sidePaint);

      // ── رسم الجانب السفلي (3D effect) ──
      final bottomPaint = Paint()..color = baseColor.withOpacity(0.2);
      final bottomPath = Path()
        ..moveTo(x + padding, y + spotH - padding)
        ..lineTo(x + spotW - padding, y + spotH - padding)
        ..lineTo(x + spotW - padding - sideDepth, y + spotH - padding + sideDepth)
        ..lineTo(x + padding - sideDepth, y + spotH - padding + sideDepth)
        ..close();
      canvas.drawPath(bottomPath, bottomPaint);

      // ── رسم السطح العلوي ──
      final topPaint = Paint()
        ..color = isOcc ? baseColor.withOpacity(0.85) : baseColor.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      final topBorderPaint = Paint()
        ..color = baseColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final topRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + padding, y + padding, spotW - padding * 2, spotH - padding * 2),
        const Radius.circular(4),
      );
      canvas.drawRRect(topRect, topPaint);
      canvas.drawRRect(topRect, topBorderPaint);

      // ── رقم المكان ──
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: isOcc ? Colors.white : baseColor,
            fontSize: spotW < 50 ? 8 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + spotW / 2 - textPainter.width / 2,
          y + spotH / 2 - textPainter.height / 2,
        ),
      );

      // ── سيارة إذا مشغول ──
      if (isOcc) {
        final carPainter = TextPainter(
          text: const TextSpan(text: '🚗', style: TextStyle(fontSize: 14)),
          textDirection: ui.TextDirection.ltr,
        );
        carPainter.layout();
        carPainter.paint(
          canvas,
          Offset(
            x + spotW / 2 - carPainter.width / 2,
            y + spotH / 2 - carPainter.height - 2,
          ),
        );
      }
    }

    // ── رسم مدخل الـ parking ──
    final entrancePaint = Paint()..color = const Color(0xFF38bdf8);
    final entranceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - 30, size.height - 18, 60, 10),
      const Radius.circular(3),
    );
    canvas.drawRRect(entranceRect, entrancePaint);

    final entranceText = TextPainter(
      text: const TextSpan(
        text: '🚪 ENTRÉE',
        style: TextStyle(color: Color(0xFF38bdf8), fontSize: 9, fontWeight: FontWeight.bold),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    entranceText.layout();
    entranceText.paint(canvas, Offset(size.width / 2 - entranceText.width / 2, size.height - 16));
  }

  @override
  bool shouldRepaint(covariant _Parking3DPainter oldDelegate) =>
      oldDelegate.occupiedSpots != occupiedSpots || oldDelegate.totalSpots != totalSpots;
}

Widget _3DLeg(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
  const SizedBox(width: 4),
  Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
]);

Widget _3DStat(String value, String label, Color color) => Column(children: [
  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
  Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54)),
]);

// ══════════════════════════════════════════════════════
//  PARKING LIVE VIEW SCREEN
// ══════════════════════════════════════════════════════
class ParkingLiveScreen extends ConsumerStatefulWidget {
  final String zoneId;
  const ParkingLiveScreen({super.key, required this.zoneId});
  @override
  ConsumerState<ParkingLiveScreen> createState() => _ParkingLiveState();
}

class _ParkingLiveState extends ConsumerState<ParkingLiveScreen> {
  YoutubePlayerController? _ytCtrl;
  final _urlCtrl = TextEditingController();
  bool _editing  = false;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedUrl());
  }

  Future<void> _loadSavedUrl() async {
    final doc = await FirebaseFirestore.instance.collection('zones').doc(widget.zoneId).get();
    final url = doc.data()?['cameraUrl'] as String?;
    if (url != null && url.isNotEmpty) _initPlayer(url);
  }

  void _initPlayer(String url) {
    // نستخرج الـ video ID من الـ URL
    final videoId = _extractVideoId(url);
    if (videoId == null) return;
    _ytCtrl?.close();
    final ctrl = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(loop: true, showControls: true, showFullscreenButton: true),
    );
    setState(() { _ytCtrl = ctrl; _currentUrl = url; });
  }

  String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
    if (uri.pathSegments.isNotEmpty) return uri.pathSegments.last;
    return null;
  }

  Future<void> _saveUrl(String url) async {
    await FirebaseFirestore.instance.collection('zones').doc(widget.zoneId).update({'cameraUrl': url});
    _initPlayer(url);
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    _ytCtrl?.close();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resvAsync  = ref.watch(zoneActiveResvProvider(widget.zoneId));
    final zonesAsync = ref.watch(zonesProvider);
    final zone = zonesAsync.asData?.value
        .where((z) => z.id == widget.zoneId)
        .cast<ParkingZone?>()
        .firstWhere((_) => true, orElse: () => null);

    final occupied = resvAsync.asData?.value.length ?? 0;
    final total    = zone?.totalSpots ?? 0;
    final free     = total - occupied;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1117),
        title: Row(children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFF4ade80), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(zone?.name ?? 'Live View',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: Colors.red, size: 8),
              SizedBox(width: 4),
              Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
            onPressed: () => setState(() { _editing = !_editing; _urlCtrl.text = _currentUrl ?? ''; }),
          ),
        ],
      ),
      body: Column(children: [

        // ── Video Player ──
        if (_editing) ...[
          Container(
            color: const Color(0xFF161b22),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lien YouTube (parking simulé)',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0d1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                )),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _saveUrl(_urlCtrl.text.trim()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ade80).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4ade80).withOpacity(0.5)),
                    ),
                    child: const Text('OK', style: TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              const Text('💡 Cherchez "parking lot timelapse" sur YouTube pour un bon exemple',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
          ),
        ] else if (_ytCtrl != null) ...[
          SizedBox(
            height: 220,
            child: YoutubePlayer(controller: _ytCtrl!),
          ),
        ] else ...[
          Container(
            height: 220,
            color: const Color(0xFF0d1117),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.videocam_off, color: Colors.white24, size: 48),
              const SizedBox(height: 12),
              const Text('Aucune caméra configurée',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ade80).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4ade80).withOpacity(0.4)),
                  ),
                  child: const Text('+ Ajouter un lien vidéo',
                      style: TextStyle(color: Color(0xFF4ade80), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          ),
        ],

        // ── Stats overlay ──
        Container(
          color: const Color(0xFF0d1117),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            _LiveStat('$free', 'Libres', const Color(0xFF4ade80), Icons.check_circle_outline),
            _LiveStat('$occupied', 'Occupées', const Color(0xFFf87171), Icons.directions_car),
            _LiveStat('$total', 'Total', const Color(0xFF60a5fa), Icons.local_parking),
            _LiveStat(
              '${total > 0 ? (occupied / total * 100).toInt() : 0}%',
              'Taux',
              const Color(0xFFfbbf24),
              Icons.pie_chart_outline,
            ),
          ]),
        ),

        // ── Mini carte des places ──
        Expanded(child: Container(
          color: const Color(0xFF0d1117),
          child: resvAsync.when(
            data: (resvs) {
              final occupiedSpots = resvs.map((r) => r.spotNumber).toSet();
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1,
                ),
                itemCount: total,
                itemBuilder: (ctx, i) {
                  final spotId = 'P-${i + 1}';
                  final isOcc  = occupiedSpots.contains(spotId);
                  final color  = isOcc ? const Color(0xFFf87171) : const Color(0xFF4ade80);
                  return Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(isOcc ? Icons.directions_car : Icons.local_parking, color: color, size: 14),
                      Text('${i+1}', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
                    ]),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4ade80))),
            error: (_, __) => const SizedBox(),
          ),
        )),
      ]),
    );
  }
}

Widget _LiveStat(String value, String label, Color color, IconData icon) => Expanded(
  child: Column(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54)),
  ]),
);