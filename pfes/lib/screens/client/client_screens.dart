import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ══════════════════════════════════════════════════════
//  CLIENT SHELL
// ══════════════════════════════════════════════════════
class ClientShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ClientShell({super.key, required this.shell});

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
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), activeIcon: Icon(Icons.bookmark), label: 'Réservations'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  HOME SCREEN
// ══════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen> {
  final MapController _mapCtrl = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  double? _userLat, _userLng;
  String? _gpsError;
  ParkingZone? _selectedZone;
  List<_SearchResult> _suggestions = [];
  bool _searching = false;
  bool _showSuggestions = false;
  Timer? _debounce;

  static const double _defLat = 34.7406;
  static const double _defLng = 10.7603;

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  Future<void> _initGPS() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) { setState(() => _gpsError = 'GPS désactivé'); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _gpsError = 'Permission refusée'); return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() { _userLat = pos.latitude; _userLng = pos.longitude; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(ll.LatLng(pos.latitude, pos.longitude), 14);
      });
    } catch (_) {
      if (mounted) setState(() => _gpsError = 'Position indisponible');
    }
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _searchCtrl.dispose();
    _sheetCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _goToUser() {
    if (_userLat != null && _userLng != null) {
      _mapCtrl.move(ll.LatLng(_userLat!, _userLng!), 15);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _searching = true);
    try {
      final encoded = Uri.encodeComponent(q);
      http.Response res;
      String apiType = 'nominatim';
      try {
        final nominatimUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=5&accept-language=fr',
        );
        res = await http.get(nominatimUrl, headers: {'User-Agent': 'ParkApp/1.0'})
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        apiType = 'photon';
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=$encoded&limit=5&lang=fr',
        );
        res = await http.get(photonUrl).timeout(const Duration(seconds: 8));
      }
      if (!mounted) return;
      if (res.statusCode != 200) return;
      final raw = jsonDecode(res.body);
      if (!mounted) return;
      final List items = apiType == 'nominatim' ? (raw as List) : (raw['features'] as List? ?? []);
      setState(() {
        _suggestions = items.map((item) {
          if (apiType == 'nominatim') {
            return _SearchResult(
              item['place_id'].toString(),
              item['display_name'].toString(),
              double.tryParse(item['lat'].toString()) ?? 0,
              double.tryParse(item['lon'].toString()) ?? 0,
            );
          } else {
            final props = item['properties'] as Map? ?? {};
            final coords = item['geometry']?['coordinates'] as List? ?? [0, 0];
            final parts = <String>[];
            if (props['name'] != null) parts.add(props['name'].toString());
            final city = props['city'] ?? props['town'] ?? props['village'];
            if (city != null) parts.add(city.toString());
            if (props['country'] != null) parts.add(props['country'].toString());
            return _SearchResult(
              (props['osm_id'] ?? DateTime.now().millisecondsSinceEpoch).toString(),
              parts.isNotEmpty ? parts.join(', ') : q,
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            );
          }
        }).toList();
        _showSuggestions = _suggestions.isNotEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => _gpsError = null);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSuggestion(_SearchResult r) {
    _searchCtrl.text = r.description;
    setState(() { _showSuggestions = false; _suggestions = []; });
    FocusScope.of(context).unfocus();
    _mapCtrl.move(ll.LatLng(r.lat, r.lng), 15);
  }

  ll.LatLng _zoneLatLng(ParkingZone z) {
    // استخدم الإحداثيات الحقيقية إذا موجودة في Firestore
    if (z.latitude != null && z.longitude != null) {
      return ll.LatLng(z.latitude!, z.longitude!);
    }
    const fallbacks = [
      (34.7406, 10.7603), (34.7450, 10.7650), (34.7380, 10.7560),
      (34.7470, 10.7580), (34.7360, 10.7630),
    ];
    final idx = z.name.hashCode.abs() % fallbacks.length;
    return ll.LatLng(fallbacks[idx].$1, fallbacks[idx].$2);
  }

  String _distance(ParkingZone z) {
    if (_userLat == null || _userLng == null) return '';
    final target = _zoneLatLng(z);
    final dist = const ll.Distance().distance(
      ll.LatLng(_userLat!, _userLng!), target);
    return dist < 1000 ? '${dist.toInt()} m' : '${(dist / 1000).toStringAsFixed(1)} km';
  }

  Color _markerColor(ParkingZone z) => !z.isOpen || z.isFull
      ? AppColors.red
      : z.freeSpots <= 5 ? AppColors.yellow : AppColors.green;

  @override
  Widget build(BuildContext context) {
    final userAsync  = ref.watch(currentUserProvider);
    final zonesAsync = ref.watch(zonesProvider);
    final zones = zonesAsync.asData?.value ?? [];

    return Scaffold(
      body: SafeArea(child: Stack(children: [

        // ══ CARTE flutter_map ════════════════════════════
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: ll.LatLng(_defLat, _defLng),
            initialZoom: 13,
            backgroundColor: const Color(0xFF0d1220),
            onTap: (_, __) {
              FocusScope.of(context).unfocus();
              setState(() => _showSuggestions = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.parkapp',
            ),
            if (_userLat != null)
              MarkerLayer(markers: [
                Marker(
                  point: ll.LatLng(_userLat!, _userLng!),
                  width: 20, height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.blue2, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: AppColors.blue2.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                ),
              ]),
            MarkerLayer(
              markers: zones.map((z) {
                final color = _markerColor(z);
                return Marker(
                  point: _zoneLatLng(z),
                  width: 44, height: 52,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedZone = z);
                      _mapCtrl.move(_zoneLatLng(z), 16);
                      _sheetCtrl.animateTo(0.45,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut);
                    },
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
                        ),
                        child: const Center(child: Text('🅿️', style: TextStyle(fontSize: 17))),
                      ),
                      Container(width: 2, height: 8, color: color),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // ══ HEADER ══════════════════════════════════════
        Positioned(top: 0, left: 0, right: 0,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.97),
                border: const Border(bottom: BorderSide(color: AppColors.border)),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
              ),
              child: Row(children: [
                userAsync.when(
                  data: (user) => Row(children: [
                    Container(width: 36, height: 36,
                      decoration: const BoxDecoration(gradient: AppColors.blueGrad, shape: BoxShape.circle),
                      child: Center(child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'C',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ))),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting(), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(user?.name ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                  loading: () => const SizedBox(width: 100),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(width: 12),
                Expanded(child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.card, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 10),
                    const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un lieu...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                      ),
                    )),
                    if (_searching)
                      const Padding(padding: EdgeInsets.only(right: 8),
                        child: SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.blue2)))),
                    if (_searchCtrl.text.isNotEmpty && !_searching)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() { _suggestions = []; _showSuggestions = false; });
                        },
                        child: const Padding(padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.close, color: AppColors.textMuted, size: 16))),
                  ]),
                )),
              ]),
            ),
          ]),
        ),

        // ══ Suggestions ══════════════════════════════════
        if (_showSuggestions && _suggestions.isNotEmpty)
          Positioned(top: 74, left: 16, right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
                ),
                child: Column(children: _suggestions.map((r) => InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectSuggestion(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.blue2, size: 16),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.description, style: const TextStyle(fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                )).toList()),
              ),
            ),
          ),

        // ══ FAB ══════════════════════════════════════════
        Positioned(right: 14, bottom: MediaQuery.of(context).size.height * 0.36,
          child: _MapFab(icon: Icons.my_location, onTap: _goToUser)),

        // ══ Légende ══════════════════════════════════════
        Positioned(left: 14, bottom: MediaQuery.of(context).size.height * 0.36,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.93),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Legend(color: AppColors.green, label: 'Disponible'),
              const SizedBox(height: 4),
              _Legend(color: AppColors.yellow, label: '≤ 5 places'),
              const SizedBox(height: 4),
              _Legend(color: AppColors.red, label: 'Complet'),
            ]),
          ),
        ),

        // ══ GPS error ════════════════════════════════════
        if (_gpsError != null)
          Positioned(left: 14, right: 80, bottom: MediaQuery.of(context).size.height * 0.36 + 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.yellow.withOpacity(0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_off, color: AppColors.yellow, size: 13),
                const SizedBox(width: 5),
                Text(_gpsError!, style: const TextStyle(fontSize: 10, color: AppColors.yellow)),
              ]),
            ),
          ),

        // ══ Banner réservation active ════════════════════
        Positioned(top: 76, left: 0, right: 0,
          child: userAsync.when(
            data: (user) => user != null ? _ActiveResvBanner(userId: user.uid) : const SizedBox(),
            loading: () => const SizedBox(), error: (_, __) => const SizedBox(),
          ),
        ),

        // ══ BOTTOM SHEET ═════════════════════════════════
        DraggableScrollableSheet(
          controller: _sheetCtrl,
          initialChildSize: 0.28, minChildSize: 0.09,
          maxChildSize: 0.88, snap: true,
          snapSizes: const [0.09, 0.28, 0.52, 0.88],
          builder: (ctx, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, -4))],
            ),
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(child: Text(
                    _selectedZone != null ? '  ${_selectedZone!.name}' : '  Parkings disponibles',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  )),
                  if (_selectedZone != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedZone = null),
                      child: Container(padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.close, size: 14, color: AppColors.textMuted)))
                  else
                    Text('${zones.length} zones', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: _selectedZone != null
                    ? _ZoneDetailCard(zone: _selectedZone!, dist: _distance(_selectedZone!), scrollCtrl: scrollCtrl)
                    : _ZoneList(zones: zones, scrollCtrl: scrollCtrl, distance: _distance,
                        onTap: (z) {
                          setState(() => _selectedZone = z);
                          _mapCtrl.move(_zoneLatLng(z), 16);
                        }),
              ),
            ]),
          ),
        ),
      ])),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour ';
    if (h < 18) return 'Bon après-midi ';
    return 'Bonsoir ';
  }
}

// ── Search result ─────────────────────────────────────
class _SearchResult {
  final String placeId, description;
  final double lat, lng;
  const _SearchResult(this.placeId, this.description, this.lat, this.lng);
}

// ── Zone detail card ──────────────────────────────────
class _ZoneDetailCard extends ConsumerWidget {
  final ParkingZone zone; final String dist; final ScrollController scrollCtrl;
  const _ZoneDetailCard({required this.zone, required this.dist, required this.scrollCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = !zone.isOpen ? AppColors.textMuted
        : zone.isFull ? AppColors.red
        : zone.freeSpots <= 5 ? AppColors.yellow
        : AppColors.green;

    return ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(18, 10, 18, 24), children: [
      Row(children: [
        Text(_icon(zone.type), style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(zone.address, style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Row(children: [
            StatusBadge(label: !zone.isOpen ? 'Fermé' : zone.isFull ? 'Complet' : '${zone.freeSpots} libres', color: accent),
            if (dist.isNotEmpty) ...[const SizedBox(width: 8),
              Row(children: [const Icon(Icons.near_me, size: 12, color: AppColors.textMuted), const SizedBox(width: 3),
                Text(dist, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))])],
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${zone.pricePerHour.toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.cyan)),
          const Text('DT/h', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ]),
      ]),
      const SizedBox(height: 14),
      OccBar(value: zone.rate, height: 10),
      const SizedBox(height: 6),
      Row(children: [
        Text('${(zone.rate * 100).toInt()}% occupé', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const Spacer(),
        Text(zone.openHours, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _QStat('Total', '${zone.totalSpots}', AppColors.blue2),
        const SizedBox(width: 8),
        _QStat('Libres', '${zone.freeSpots}', AppColors.green),
        const SizedBox(width: 8),
        _QStat('Occupées', '${zone.occupiedSpots}', AppColors.red),
      ]),
      const SizedBox(height: 18),
      ParkButton(
        label: zone.isFull ? 'Zone complète' : 'Réserver une place',
        icon: zone.isFull ? Icons.block : Icons.check_circle_outline,
        onTap: zone.isOpen && !zone.isFull ? () => context.push('/client/home/booking/${zone.id}') : null,
        colors: zone.isFull ? [AppColors.textMuted, AppColors.textMuted] : [AppColors.blue, AppColors.cyan],
      ),
    ]);
  }
  String _icon(String t) => {'vip':'⭐','couvert':'🏗️','souterrain':'🔽','pmr':'♿'}[t] ?? '🅿️';
}

// ── Zone list ─────────────────────────────────────────
class _ZoneList extends StatelessWidget {
  final List<ParkingZone> zones;
  final ScrollController scrollCtrl;
  final String Function(ParkingZone) distance;
  final Function(ParkingZone) onTap;
  const _ZoneList({required this.zones, required this.scrollCtrl, required this.distance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty) return const Center(child: Padding(
      padding: EdgeInsets.all(20),
      child: Text('Aucun parking enregistré', style: TextStyle(color: AppColors.textMuted))));
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: zones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _ZoneRow(zone: zones[i], dist: distance(zones[i]), onTap: () => onTap(zones[i]))
          .animate(delay: (i * 50).ms).fadeIn().slideY(begin: 0.05),
    );
  }
}

// ── Zone row ──────────────────────────────────────────
class _ZoneRow extends StatelessWidget {
  final ParkingZone zone; final String dist; final VoidCallback onTap;
  const _ZoneRow({required this.zone, required this.dist, required this.onTap});
  Color get _accent => !zone.isOpen ? AppColors.textMuted : zone.isFull ? AppColors.red
      : zone.freeSpots <= 5 ? AppColors.yellow : AppColors.green;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.22))),
      child: Row(children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_icon(zone.type), style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 5),
          SizedBox(width: 24, height: 4, child: ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: zone.rate, minHeight: 4,
              backgroundColor: _accent.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(_accent)))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(zone.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(zone.address, style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Row(children: [
            StatusBadge(label: !zone.isOpen ? 'Fermé' : zone.isFull ? 'Complet' : '${zone.freeSpots} libres', color: _accent),
            if (dist.isNotEmpty) ...[const SizedBox(width: 8),
              Row(children: [const Icon(Icons.near_me, size: 11, color: AppColors.textMuted), const SizedBox(width: 2),
                Text(dist, style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])],
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${zone.pricePerHour.toInt()} DT', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.cyan)),
          const Text('/h', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.blue2),
        ]),
      ]),
    ));
  }
  String _icon(String t) => {'vip':'⭐','couvert':'🏗️','souterrain':'🔽','pmr':'♿'}[t] ?? '🅿️';
}

// ── Utilities ─────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))]),
    child: Icon(icon, size: 20, color: AppColors.blue2),
  ));
}

class _Legend extends StatelessWidget {
  final Color color; final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSec)),
  ]);
}

Widget _QStat(String label, String value, Color color) => Expanded(child: Container(
  padding: const EdgeInsets.symmetric(vertical: 10),
  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
    border: Border.all(color: color.withOpacity(0.2))),
  child: Column(children: [
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
  ]),
));

// ══════════════════════════════════════════════════════
//  BANNER RÉSERVATION ACTIVE
// ══════════════════════════════════════════════════════
class _ActiveResvBanner extends ConsumerWidget {
  final String userId;
  const _ActiveResvBanner({required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resvAsync = ref.watch(activeReservationsProvider(userId));
    return resvAsync.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox();
        final r = list.first;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.blue.withOpacity(0.2), AppColors.cyan.withOpacity(0.1)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.blue2.withOpacity(0.3)),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(gradient: AppColors.blueGrad, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_car, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Réservation active', style: TextStyle(fontSize: 10, color: AppColors.blue2, fontWeight: FontWeight.w600)),
              Text(r.zoneName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Place ${r.spotNumber} · ${r.vehiclePlate}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ])),
            StatusBadge(
              label: r.status == ReservationStatus.active ? 'En cours' : 'À venir',
              color: r.status == ReservationStatus.active ? AppColors.green : AppColors.blue2,
            ),
          ]),
        );
      },
      loading: () => const SizedBox(), error: (_, __) => const SizedBox(),
    );
  }
}

// ══════════════════════════════════════════════════════
//  BOOKING SCREEN — avec Stripe
// ══════════════════════════════════════════════════════
class BookingScreen extends ConsumerStatefulWidget {
  final String zoneId;
  const BookingScreen({super.key, required this.zoneId});
  @override
  ConsumerState<BookingScreen> createState() => _BookState();
}

class _BookState extends ConsumerState<BookingScreen> {
  DateTime _start = DateTime.now().add(const Duration(minutes: 5));
  DateTime _end   = DateTime.now().add(const Duration(hours: 2, minutes: 5));
  bool _loading = false;

  String _formatDuration(Duration d) {
    if (d.isNegative || d.inMinutes == 0) return '—';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m} min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  // ── نوع المكان المختار ───────────────────────────────
  String _selectedSpotType  = 'Standard';
  double _selectedSpotPrice = 2.5;

  static const List<Map<String, dynamic>> _spotTypes = [
    {'icon': '🚗', 'label': 'Standard', 'price': 2.5,  'colorVal': 0xFF6366f1},
    {'icon': '⭐', 'label': 'VIP',      'price': 4.0,  'colorVal': 0xFFf59e0b},
    {'icon': '♿', 'label': 'PMR',       'price': 1.0,  'colorVal': 0xFF22c55e},
    {'icon': '🏍', 'label': 'Moto',     'price': 1.5,  'colorVal': 0xFF8b5cf6},
  ];

  // ── Clés Stripe TEST ────────────────────────────────
  // (désactivé pour démo PFE — paiement simulé)

  Future<void> _book(AppUser user, ParkingZone zone) async {
    setState(() => _loading = true);
    try {
      final hours = _end.difference(_start).inMinutes / 60.0;
      final total = _selectedSpotPrice * (hours > 0 ? hours : 0);

      // ── Dialog confirmation paiement (mode démo PFE) ──
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF1a2235),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.blue.withOpacity(0.8), AppColors.cyan.withOpacity(0.8)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.credit_card, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Confirmer le paiement',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${total.toStringAsFixed(2)} DT',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.cyan)),
              const SizedBox(height: 4),
              Text('$_selectedSpotType · ${zone.name}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(
                '${_formatDuration(_end.difference(_start))} · '
                '${DateFormat('HH:mm').format(_start)} → ${DateFormat('HH:mm').format(_end)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              // Carte test
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.yellow.withOpacity(0.25)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline, color: AppColors.yellow, size: 14),
                  SizedBox(width: 6),
                  Text('4242 4242 4242 4242 · 12/34 · 123',
                      style: TextStyle(fontSize: 11, color: AppColors.yellow)),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(_, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('Annuler',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(_, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.blue, AppColors.cyan]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('Payer',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      );

      if (confirmed != true) {
        setState(() => _loading = false);
        return;
      }

      // ── Simulation paiement ──
      await Future.delayed(const Duration(milliseconds: 800));

      final spot = 'P-${(DateTime.now().millisecondsSinceEpoch % 80) + 1}';
      final resv = await ref.read(parkingServiceProvider).createReservation(
        user: user, zone: zone, start: _start, end: _end, spot: spot,
        totalAmount: total,
      );

      // ── Planifier les rappels ──
      ref.read(reminderServiceProvider).scheduleReminders(resv, user.uid);

      if (!mounted) return;
      _showSuccessSheet(zone, total, spot, resv.id);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessSheet(ParkingZone zone, double total, String spot, String resvId) {
    // QR data: JSON مضغوط يحتوي كل المعلومات
    final qrData = 'PARK|$resvId|${zone.id}|${zone.name}|$spot|${_start.toIso8601String()}|${_end.toIso8601String()}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0d1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.green.withOpacity(0.8), AppColors.cyan.withOpacity(0.8)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Réservation confirmée !',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('Paiement effectué ✅',
                  style: TextStyle(fontSize: 12, color: AppColors.green)),
            ]),
          ]),
          const SizedBox(height: 20),

          // ── QR Code ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 200, height: 200,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0d1220),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0d1220),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Présentez ce QR à l\'entrée du parking',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),

          // ── Infos ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _InfoRow(Icons.local_parking, zone.name, AppColors.blue2),
              const Divider(height: 14, color: AppColors.border),
              _InfoRow(Icons.grid_view, 'Place $spot', AppColors.cyan),
              const Divider(height: 14, color: AppColors.border),
              _InfoRow(Icons.schedule, '${DateFormat('HH:mm').format(_start)} → ${DateFormat('HH:mm').format(_end)}', AppColors.textSec),
              const Divider(height: 14, color: AppColors.border),
              _InfoRow(Icons.payments_outlined, '${total.toStringAsFixed(2)} DT', AppColors.green),
            ]),
          ),
          const SizedBox(height: 20),

          ParkButton(
            label: 'Voir mes réservations',
            icon: Icons.bookmark_outline,
            onTap: () { Navigator.pop(context); context.go('/client/reservations'); },
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () { Navigator.pop(context); context.pop(); },
            child: const Text("Retour à l'accueil",
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }

  Widget _InfoRow(IconData icon, String text, Color color) => Row(children: [
    Icon(icon, size: 15, color: color),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
  ]);

  @override
  Widget build(BuildContext context) {
    final userAsync  = ref.watch(currentUserProvider);
    final zonesAsync = ref.watch(zonesProvider);
    final zone = zonesAsync.asData?.value.firstWhere(
      (z) => z.id == widget.zoneId,
      orElse: () => const ParkingZone(
          id: '', name: '...', type: '', address: '',
          totalSpots: 0, occupiedSpots: 0, pricePerHour: 0),
    );
    final hours = _end.difference(_start).inMinutes / 60.0;
    final total = _selectedSpotPrice * (hours > 0 ? hours : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réserver une place'),
        leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new, size: 18)),
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        if (zone != null && zone.id.isNotEmpty) ...[

          // ── Info zone ──
          ParkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_typeIcon(zone.type), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(zone.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(zone.address, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ])),
            ]),
            const SizedBox(height: 14),
            OccBar(value: zone.rate),
            const SizedBox(height: 8),
            Row(children: [
              StatusBadge(
                label: zone.isFull ? 'Complet' : '${zone.freeSpots} places libres',
                color: zone.isFull ? AppColors.red : AppColors.green,
              ),
              const Spacer(),
              Text('${zone.pricePerHour.toInt()} DT/h',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.cyan)),
            ]),
          ])),

          // ── Types de places ──
          const SizedBox(height: 16),
          const Text('TYPE DE PLACE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _spotTypes.map((t) {
                final color = Color(t['colorVal'] as int);
                final isSelected = _selectedSpotType == t['label'];
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedSpotType  = t['label'] as String;
                    _selectedSpotPrice = t['price'] as double;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : color.withOpacity(0.25),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)] : [],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(t['icon'] as String, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(t['label'] as String,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: isSelected ? color : AppColors.textPri)),
                      Text('${(t['price'] as double).toStringAsFixed(1)} DT/h',
                          style: TextStyle(fontSize: 10, color: color)),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Container(width: 6, height: 6,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Créneau ──
          const SizedBox(height: 20),
          const Text('CRÉNEAU',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ParkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Début ──
            Row(children: [
              const Icon(Icons.play_circle_outline, color: AppColors.green, size: 18),
              const SizedBox(width: 8),
              const Text('Début', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final picked = await showDateTimePicker(context, _start);
                  if (picked != null) {
                    if (picked.isBefore(DateTime.now())) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Impossible de choisir une heure dans le passé'), backgroundColor: Colors.orange));
                      return;
                    }
                    setState(() {
                      _start = picked;
                      if (_end.isBefore(_start)) {
                        _end = _start.add(const Duration(hours: 1));
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.green.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_calendar_outlined, color: AppColors.green, size: 14),
                    const SizedBox(width: 6),
                    Text(DateFormat('dd/MM  HH:mm').format(_start),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),

            // ── Fin ──
            Row(children: [
              const Icon(Icons.stop_circle_outlined, color: AppColors.red, size: 18),
              const SizedBox(width: 8),
              const Text('Fin', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final picked = await showDateTimePicker(context, _end);
                  if (picked != null) {
                    if (picked.isBefore(_start)) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ La fin doit être après le début'), backgroundColor: Colors.orange));
                      return;
                    }
                    if (picked.isBefore(DateTime.now())) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Impossible de choisir une heure dans le passé'), backgroundColor: Colors.orange));
                      return;
                    }
                    setState(() => _end = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_calendar_outlined, color: AppColors.red, size: 14),
                    const SizedBox(width: 6),
                    Text(DateFormat('dd/MM  HH:mm').format(_end),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),

            // ── Durée calculée ──
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.schedule, color: AppColors.cyan, size: 15),
              const SizedBox(width: 6),
              Text('Durée : ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Text(
                _formatDuration(_end.difference(_start)),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.cyan),
              ),
            ]),
          ])),

          // ── Récap prix ──
          const SizedBox(height: 20),
          ParkCard(
            bgColor: AppColors.blue.withOpacity(0.07),
            borderColor: AppColors.blue2.withOpacity(0.25),
            child: Column(children: [
              _Row('Durée', _formatDuration(_end.difference(_start))),
              const Divider(height: 20, color: AppColors.border),
              _Row('Tarif', '${_selectedSpotPrice.toStringAsFixed(1)} DT/h ($_selectedSpotType)'),
              const Divider(height: 20, color: AppColors.border),
              Row(children: [
                const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${total.toStringAsFixed(1)} DT',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.cyan)),
              ]),
            ]),
          ),

          // ── Info carte test ──
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.yellow.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.yellow.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.credit_card, color: AppColors.yellow, size: 15),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                'Test : 4242 4242 4242 4242  ·  12/34  ·  123',
                style: TextStyle(fontSize: 11, color: AppColors.yellow),
              )),
            ]),
          ),

          // ── Bouton payer ──
          const SizedBox(height: 24),
          userAsync.when(
            data: (user) => zone.isFull
                ? const Center(child: Text('⚠️ Zone complète', style: TextStyle(color: AppColors.red)))
                : ParkButton(
                    label: 'Payer ${total.toStringAsFixed(1)} DT',
                    icon: Icons.credit_card_outlined,
                    loading: _loading,
                    onTap: user != null ? () => _book(user, zone!) : null,
                    colors: [AppColors.blue, AppColors.cyan],
                  ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ])),
    );
  }

  String _typeIcon(String t) =>
      {'vip': '⭐', 'couvert': '🏗️', 'souterrain': '🔽', 'pmr': '♿'}[t] ?? '🅿️';
}

// ── Types de places ───────────────────────────────────

// ══════════════════════════════════════════════════════
//  RESERVATIONS SCREEN
// ══════════════════════════════════════════════════════
class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});
  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  Timer? _reminderTimer;
  final Set<String> _notifiedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user != null) {
        await ref.read(parkingServiceProvider).syncReservationStatuses(user.uid);
      }
    });
    // نشغّل timer كل دقيقة
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkReminders());
    // نتحقق مباشرة عند الفتح
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReminders());
  }

  void _checkReminders() {
    final resvs = ref.read(userReservationsProvider(
      ref.read(currentUserProvider).asData?.value?.uid ?? ''
    )).asData?.value ?? [];

    final now = DateTime.now();
    for (final r in resvs) {
      if (r.status != ReservationStatus.active && r.status != ReservationStatus.upcoming) continue;
      if (r.endTime == null) continue;
      if (_notifiedIds.contains(r.id)) continue;

      final remaining = r.endTime!.difference(now).inMinutes;
      if (remaining <= 15 && remaining > 0) {
        _notifiedIds.add(r.id);
        _showReminderDialog(r, remaining);
        break;
      }
    }
  }

  void _showReminderDialog(Reservation r, int minutes) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.yellow.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.yellow.withOpacity(0.4)),
              ),
              child: const Icon(Icons.timer_outlined, color: AppColors.yellow, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('⏰ Rappel de réservation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Votre réservation à ${r.zoneName} expire dans $minutes minutes.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Place ${r.spotNumber} · Fin : ${DateFormat('HH:mm').format(r.endTime!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.cyan, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // ── Prolongation options ──
            const Text('PROLONGER DE :', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Row(children: [
              ...[
                {'label': '+30 min', 'minutes': 30},
                {'label': '+1h',     'minutes': 60},
                {'label': '+2h',     'minutes': 120},
              ].map((opt) {
                final mins  = opt['minutes'] as int;
                final label = opt['label'] as String;
                final cost  = (mins / 60.0) * r.pricePerHour;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      try {
                        final newEnd = await ref.read(prolongationServiceProvider).prolonger(
                          reservationId: r.id,
                          extraMinutes: mins,
                          pricePerHour: r.pricePerHour,
                        );
                        final updatedR = Reservation(
                          id: r.id, userId: r.userId, userName: r.userName,
                          zoneId: r.zoneId, zoneName: r.zoneName,
                          spotNumber: r.spotNumber, vehiclePlate: r.vehiclePlate,
                          startTime: r.startTime, endTime: newEnd,
                          pricePerHour: r.pricePerHour, status: r.status,
                          createdAt: r.createdAt,
                        );
                        ref.read(reminderServiceProvider).scheduleReminders(updatedR, r.userId);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Prolongé de $label'),
                              backgroundColor: AppColors.green));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ $e')));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.blue2.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.blue2.withOpacity(0.25)),
                      ),
                      child: Column(children: [
                        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('+${cost.toStringAsFixed(2)} DT',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ]),
                    ),
                  ),
                ));
              }),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              child: const Text('Non merci, je vais partir',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          final resvAsync = ref.watch(userReservationsProvider(user.uid));
          return resvAsync.when(
            data: (list) {
              if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🅿️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Aucune réservation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Réservez une place depuis l\'accueil', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 20),
                ParkButton(label: 'Réserver maintenant', icon: Icons.add, onTap: () => context.go('/client/home'), height: 46),
              ]));
              return ListView.separated(
                padding: const EdgeInsets.all(20), itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) => _ResvCard(r: list[i], ref: ref)
                    .animate(delay: (i * 50).ms).fadeIn().slideY(begin: 0.05),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.blue2))),
            error: (e, _) => ErrorBox(message: e.toString()),
          );
        },
        loading: () => const SizedBox(), error: (_, __) => const SizedBox(),
      ),
    );
  }
}

class _ResvCard extends StatelessWidget {
  final Reservation r; final WidgetRef ref;
  const _ResvCard({required this.r, required this.ref});
  Color get _accent => switch (r.status) {
    ReservationStatus.active => AppColors.green, ReservationStatus.upcoming => AppColors.blue2,
    ReservationStatus.completed => AppColors.textMuted, ReservationStatus.cancelled => AppColors.red,
  };
  String get _label => switch (r.status) {
    ReservationStatus.active => 'En cours', ReservationStatus.upcoming => 'À venir',
    ReservationStatus.completed => 'Terminée', ReservationStatus.cancelled => 'Annulée',
  };
  @override
  Widget build(BuildContext context) {
    return ParkCard(borderColor: _accent.withOpacity(0.25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(r.zoneName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        StatusBadge(label: _label, color: _accent),
      ]),
      const SizedBox(height: 8),
      _Info(Icons.location_on_outlined, 'Place ${r.spotNumber}'),
      const SizedBox(height: 4),
      _Info(Icons.directions_car_outlined, r.vehiclePlate),
      const SizedBox(height: 4),
      _Info(Icons.schedule_outlined, '${DateFormat('dd/MM HH:mm').format(r.startTime)} → ${r.endTime != null ? DateFormat('HH:mm').format(r.endTime!) : '?'}'),
      if (r.status == ReservationStatus.active || r.status == ReservationStatus.upcoming) ...[
        const SizedBox(height: 12),
        Row(children: [
          // ── Annuler ──
          Expanded(child: GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
                backgroundColor: AppColors.card,
                title: const Text('Annuler la réservation ?'),
                content: const Text('Cette action est irréversible.', style: TextStyle(color: AppColors.textMuted)),
                actions: [
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Non', style: TextStyle(color: AppColors.textMuted))),
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Oui', style: TextStyle(color: AppColors.red))),
                ],
              ));
              if (ok == true && context.mounted) {
                await ref.read(parkingServiceProvider).cancelReservation(r.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Réservation annulée')));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red.withOpacity(0.2))),
              child: const Center(child: Text('Annuler', style: TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w600))),
            ),
          )),
          const SizedBox(width: 8),
          // ── Prolonger ──
          Expanded(child: GestureDetector(
            onTap: () => _showProlongDialog(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue.withOpacity(0.8), AppColors.cyan.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.more_time, color: Colors.white, size: 16),
                SizedBox(width: 5),
                Text('Prolonger', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ])),
            ),
          )),
        ]),
      ],
      // ── Bouton QR ──
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => _showQR(context),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.qr_code_2, color: AppColors.cyan, size: 18),
            SizedBox(width: 8),
            Text('Afficher le QR Code', style: TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      if (r.totalAmount != null) ...[const SizedBox(height: 8),
        _Info(Icons.payments_outlined, '${r.totalAmount!.toInt()} DT', color: AppColors.green)],
      // ── Bouton Avis pour les réservations terminées ──
      if (r.status == ReservationStatus.completed) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.push('/client/avis/${r.zoneId}?zoneName=${Uri.encodeComponent(r.zoneName)}'),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.yellow.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.yellow.withOpacity(0.3)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.star_outline_rounded, color: AppColors.yellow, size: 18),
              SizedBox(width: 8),
              Text('Laisser un avis', style: TextStyle(color: AppColors.yellow, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    ]));
  }

  void _showProlongDialog(BuildContext context, WidgetRef ref) {
    int selectedMinutes = 30;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⏱ Prolonger la réservation'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Place ${r.spotNumber} · ${r.zoneName}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            // Options durée
            ...[[30,'30 min'],[60,'1h'],[90,'1h30'],[120,'2h']].map((opt) {
              final mins = opt[0] as int;
              final label = opt[1] as String;
              final isSelected = selectedMinutes == mins;
              final cost = (mins / 60.0) * r.pricePerHour;
              return GestureDetector(
                onTap: () => setS(() => selectedMinutes = mins),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.blue2.withOpacity(0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? AppColors.blue2 : AppColors.border, width: isSelected ? 2 : 1),
                  ),
                  child: Row(children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? AppColors.blue2 : AppColors.textPri)),
                    const Spacer(),
                    Text('+${cost.toStringAsFixed(2)} DT', style: TextStyle(fontSize: 12, color: isSelected ? AppColors.cyan : AppColors.textMuted)),
                  ]),
                ),
              );
            }),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final newEnd = await ref.read(prolongationServiceProvider).prolonger(
                    reservationId: r.id,
                    extraMinutes: selectedMinutes,
                    pricePerHour: r.pricePerHour,
                  );
                  // نحدّث الـ reminders
                  final updatedR = Reservation(
                    id: r.id, userId: r.userId, userName: r.userName,
                    zoneId: r.zoneId, zoneName: r.zoneName,
                    spotNumber: r.spotNumber, vehiclePlate: r.vehiclePlate,
                    startTime: r.startTime, endTime: newEnd,
                    pricePerHour: r.pricePerHour, status: r.status,
                    createdAt: r.createdAt,
                  );
                  ref.read(reminderServiceProvider).scheduleReminders(updatedR, r.userId);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Prolongé de ${selectedMinutes < 60 ? "$selectedMinutes min" : "${selectedMinutes~/60}h"}'),
                        backgroundColor: AppColors.green));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ $e')));
                }
              },
              child: const Text('Confirmer', style: TextStyle(color: AppColors.blue2, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showQR(BuildContext context) {
    final qrData = 'PARK|${r.id}|${r.zoneId}|${r.zoneName}|${r.spotNumber}|${r.startTime.toIso8601String()}|${(r.endTime ?? r.startTime.add(const Duration(hours: 1))).toIso8601String()}';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0d1220),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('QR Code d\'entrée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              GestureDetector(onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: 200, height: 200,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(r.zoneName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Place ${r.spotNumber}', style: const TextStyle(fontSize: 12, color: AppColors.cyan)),
            const SizedBox(height: 6),
            Text(
              '${DateFormat('dd/MM HH:mm').format(r.startTime)} → ${r.endTime != null ? DateFormat('HH:mm').format(r.endTime!) : '?'}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            const Text('Présentez ce code au responsable',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}

Widget _Info(IconData icon, String text, {Color? color}) => Row(children: [
  Icon(icon, size: 14, color: AppColors.textMuted), const SizedBox(width: 6),
  Text(text, style: TextStyle(fontSize: 12, color: color ?? AppColors.textSec)),
]);

// ══════════════════════════════════════════════════════
//  CLIENT PROFILE SCREEN
// ══════════════════════════════════════════════════════
class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/client/profile/edit'),
            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.blue2),
            label: const Text('Modifier', style: TextStyle(color: AppColors.blue2, fontSize: 13)),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          return ListView(padding: const EdgeInsets.all(20), children: [
            // ── Avatar + infos ──
            ParkCard(
              bgColor: AppColors.blue.withOpacity(0.05),
              borderColor: AppColors.blue2.withOpacity(0.2),
              child: Row(children: [
                _AvatarWidget(user: user, size: 64),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  StatusBadge(
                    label: user.subscription == 'vip' ? '⭐ VIP' : user.subscription == 'premium' ? '🌟 Premium' : 'Standard',
                    color: user.subscription == 'vip' ? AppColors.yellow : user.subscription == 'premium' ? AppColors.purple : AppColors.blue2,
                  ),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Informations'), const SizedBox(height: 12),
            ParkCard(child: Column(children: [
              _PRow(Icons.person_outline, 'Nom', user.name),
              const Divider(height: 20, color: AppColors.border),
              _PRow(Icons.phone_outlined, 'Téléphone', user.phone.isEmpty ? '—' : user.phone),
              const Divider(height: 20, color: AppColors.border),
              _PRow(Icons.directions_car_outlined, 'Véhicule', user.vehiclePlate?.isNotEmpty == true ? user.vehiclePlate! : '—'),
            ])),
            const SizedBox(height: 20),
            ParkButton(label: 'Déconnexion', icon: Icons.logout, outlined: true, colors: [AppColors.red],
              onTap: () async {
                await ref.read(authServiceProvider).logout();
                if (context.mounted) context.go('/login');
              }),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.blue2))),
        error: (_, __) => const SizedBox(),
      ),
    );
  }
}

// ── Avatar Widget ─────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final AppUser user;
  final double size;
  const _AvatarWidget({required this.user, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(gradient: AppColors.blueGrad, shape: BoxShape.circle),
      child: Center(child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
        style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: Colors.white),
      )),
    );
  }
}

Widget _PRow(IconData icon, String label, String value) => Row(children: [
  Icon(icon, color: AppColors.textMuted, size: 18), const SizedBox(width: 12),
  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)), const Spacer(),
  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
]);

// ══════════════════════════════════════════════════════
//  EDIT PROFILE SCREEN
// ══════════════════════════════════════════════════════
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _plateCtrl   = TextEditingController();
  final _modelCtrl   = TextEditingController();
  bool _loading = false;
  String? _photoUrl;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user != null) {
        _nameCtrl.text  = user.name;
        _phoneCtrl.text = user.phone;
        _plateCtrl.text = user.vehiclePlate ?? '';
        _modelCtrl.text = user.vehicleModel ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _plateCtrl.dispose(); _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 512);
      if (picked == null) return;
      setState(() => _pickedImage = picked);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Text('Choisir une photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.blue2.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.blue2.withOpacity(0.2)),
                ),
                child: const Column(children: [
                  Icon(Icons.camera_alt_outlined, color: AppColors.blue2, size: 28),
                  SizedBox(height: 8),
                  Text('Caméra', style: TextStyle(color: AppColors.blue2, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green.withOpacity(0.2)),
                ),
                child: const Column(children: [
                  Icon(Icons.photo_library_outlined, color: AppColors.green, size: 28),
                  SizedBox(height: 8),
                  Text('Galerie', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Le nom est obligatoire')));
      return;
    }
    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user == null) return;

      String? photoUrl;

      // ── Upload photo si sélectionnée ──
      if (_pickedImage != null) {
        try {
          final storage = FirebaseStorage.instance;
          final ref2 = storage.ref('profiles/${user.uid}.jpg');
          final bytes = await _pickedImage!.readAsBytes();
          await ref2.putData(bytes);
          photoUrl = await ref2.getDownloadURL();
        } catch (_) {}
      }

      // ── Update Firestore ──
      final db = FirebaseFirestore.instance;
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'vehiclePlate': _plateCtrl.text.trim(),
        'vehicleModel': _modelCtrl.text.trim(),
      };
      if (photoUrl != null) data['photoUrl'] = photoUrl;

      await db.collection('users').doc(user.uid).update(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profil mis à jour'), backgroundColor: AppColors.green));
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [

        // ── Photo ──
        Center(child: GestureDetector(
          onTap: _showImagePicker,
          child: Stack(children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: _pickedImage == null ? AppColors.blueGrad : null,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.blue2.withOpacity(0.3), width: 3),
              ),
              child: _pickedImage != null
                  ? ClipOval(child: Image.file(File(_pickedImage!.path), fit: BoxFit.cover, width: 100, height: 100))
                  : Center(child: Text(
                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                    )),
            ),
            Positioned(bottom: 0, right: 0, child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.blue2,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            )),
          ]),
        )),
        const SizedBox(height: 8),
        const Center(child: Text('Appuyez pour changer la photo',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
        const SizedBox(height: 24),

        // ── Infos personnelles ──
        const Text('INFORMATIONS PERSONNELLES', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ParkField(label: 'Nom complet', hint: 'Votre nom', controller: _nameCtrl,
            prefix: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 18)),
        const SizedBox(height: 12),
        ParkField(label: 'Téléphone', hint: '+216 XX XXX XXX', controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            prefix: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 18)),
        const SizedBox(height: 24),

        // ── Véhicule ──
        const Text('VÉHICULE', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ParkField(label: 'Plaque', hint: 'ex: 16-12345-A', controller: _plateCtrl,
            prefix: const Icon(Icons.directions_car_outlined, color: AppColors.textMuted, size: 18)),
        const SizedBox(height: 12),
        ParkField(label: 'Modèle', hint: 'ex: Renault Clio', controller: _modelCtrl,
            prefix: const Icon(Icons.car_repair, color: AppColors.textMuted, size: 18)),
        const SizedBox(height: 32),

        ParkButton(
          label: 'Enregistrer les modifications',
          icon: Icons.check_rounded,
          loading: _loading,
          onTap: _save,
          colors: [AppColors.blue, AppColors.blue2],
        ),
      ])),
    );
  }
}


// ══════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════
Future<DateTime?> showDateTimePicker(BuildContext context, DateTime init) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: init.isBefore(now) ? now : init,
    firstDate: now,  // ← لا يسمح بتاريخ قديم
    lastDate: now.add(const Duration(days: 30)),
    builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: AppColors.blue2, surface: AppColors.card)), child: child!));
  if (date == null) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(init.isBefore(now) ? now : init),
    builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: AppColors.blue2, surface: AppColors.card)), child: child!));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class _DateTile extends StatelessWidget {
  final String label; final DateTime dt; final VoidCallback onTap;
  const _DateTile({required this.label, required this.dt, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: ParkCard(
    borderColor: AppColors.blue2.withOpacity(0.2),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      Text(DateFormat('dd/MM/yy').format(dt), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      Text(DateFormat('HH:mm').format(dt), style: const TextStyle(fontSize: 12, color: AppColors.cyan)),
    ]),
  ));
}

Widget _Row(String l, String v) => Row(children: [
  Text(l, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)), const Spacer(),
  Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
]);

// ══════════════════════════════════════════════════════
//  AVIS SCREEN — تقييم الـ parking
// ══════════════════════════════════════════════════════
class AvisScreen extends ConsumerStatefulWidget {
  final String zoneId;
  final String zoneName;
  const AvisScreen({super.key, required this.zoneId, required this.zoneName});
  @override
  ConsumerState<AvisScreen> createState() => _AvisState();
}

class _AvisState extends ConsumerState<AvisScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Choisissez une note')));
      return;
    }
    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider).asData?.value;
      await ref.read(parkingServiceProvider).submitAvis(
        zoneId: widget.zoneId,
        zoneName: widget.zoneName,
        userId: user?.uid ?? '',
        userName: user?.name ?? 'Anonyme',
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laisser un avis'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: SafeArea(
        child: _submitted ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.yellow.withOpacity(0.8), AppColors.orange.withOpacity(0.8)]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 20),
        const Text('Merci pour votre avis !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Votre avis sur ${widget.zoneName} a été enregistré.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        ParkButton(
          label: 'Retour à l\'accueil',
          icon: Icons.home_outlined,
          onTap: () => context.go('/client/home'),
        ),
      ]),
    ),
  );

  Widget _buildForm() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      // ── Zone info ──
      ParkCard(
        bgColor: AppColors.blue.withOpacity(0.07),
        borderColor: AppColors.blue2.withOpacity(0.2),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.blueGrad,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_parking, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Évaluer votre expérience',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text(widget.zoneName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ])),
        ]),
      ),
      const SizedBox(height: 28),

      // ── Stars ──
      const Text('NOTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.textMuted, letterSpacing: 0.8)),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
        final filled = i < _rating;
        return GestureDetector(
          onTap: () => setState(() => _rating = i + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? AppColors.yellow : AppColors.textMuted,
              size: filled ? 44 : 38,
            ),
          ),
        );
      })),
      const SizedBox(height: 8),
      Center(child: Text(
        _rating == 0 ? 'Appuyez pour noter'
            : _rating == 1 ? '😞 Très mauvais'
            : _rating == 2 ? '😕 Mauvais'
            : _rating == 3 ? '😐 Moyen'
            : _rating == 4 ? '😊 Bien'
            : '😍 Excellent !',
        style: TextStyle(
          fontSize: 13,
          color: _rating == 0 ? AppColors.textMuted
              : _rating <= 2 ? AppColors.red
              : _rating == 3 ? AppColors.yellow
              : AppColors.green,
          fontWeight: FontWeight.w600,
        ),
      )),
      const SizedBox(height: 28),

      // ── Comment ──
      const Text('COMMENTAIRE (optionnel)', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _commentCtrl,
          maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Partagez votre expérience...',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
        ),
      ),
      const SizedBox(height: 32),

      // ── Submit ──
      ParkButton(
        label: 'Publier mon avis',
        icon: Icons.send_rounded,
        loading: _loading,
        onTap: _submit,
        colors: [AppColors.yellow, AppColors.orange],
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => context.pop(),
        child: const Center(child: Text('Passer',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted))),
      ),
    ],
  );
}