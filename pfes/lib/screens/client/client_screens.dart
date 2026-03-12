import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/models.dart';
import '../../services/firebase_service.dart';
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

  // Centre par défaut — Sfax
  static const double _defLat = 34.7406;
  static const double _defLng = 10.7603;

  static const String _placesKey = 'YOUR_GOOGLE_PLACES_API_KEY';

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

  // ── Search ───────────────────────────────────────────
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
      // Try Nominatim first, fallback to Photon
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
      if (mounted) setState(() => _gpsError = null); // silently fail
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

  // ── Zone coords ──────────────────────────────────────
  ll.LatLng _zoneLatLng(ParkingZone z) {
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

        // ══ CARTE flutter_map ═══════════════════════════
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
            // Position utilisateur
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
            // Markers zones
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

        // ══ Suggestions — overlay flottant ══════════════
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

        // ══ FAB ═════════════════════════════════════════
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
//  BOOKING SCREEN
// ══════════════════════════════════════════════════════
class BookingScreen extends ConsumerStatefulWidget {
  final String zoneId;
  const BookingScreen({super.key, required this.zoneId});
  @override ConsumerState<BookingScreen> createState() => _BookState();
}

class _BookState extends ConsumerState<BookingScreen> {
  DateTime _start = DateTime.now();
  DateTime _end   = DateTime.now().add(const Duration(hours: 2));
  bool _loading   = false;

  Future<void> _book(AppUser user, ParkingZone zone) async {
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Date de fin invalide')));
      return;
    }
    setState(() => _loading = true);
    try {
      final spot = 'A-${(DateTime.now().millisecondsSinceEpoch % 80) + 1}';
      await ref.read(parkingServiceProvider).createReservation(
          user: user, zone: zone, start: _start, end: _end, spot: spot);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Réservation confirmée !')));
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync  = ref.watch(currentUserProvider);
    final zonesAsync = ref.watch(zonesProvider);
    final zone = zonesAsync.asData?.value.firstWhere((z) => z.id == widget.zoneId,
        orElse: () => const ParkingZone(id: '', name: '...', type: '', address: '', totalSpots: 0, occupiedSpots: 0, pricePerHour: 0));
    final hours = _end.difference(_start).inMinutes / 60.0;
    final total = (zone?.pricePerHour ?? 0) * hours;

    return Scaffold(
      appBar: AppBar(title: const Text('Réserver une place'),
          leading: GestureDetector(onTap: () => context.pop(), child: const Icon(Icons.arrow_back_ios_new, size: 18))),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        if (zone != null && zone.id.isNotEmpty) ...[
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
              StatusBadge(label: zone.isFull ? 'Complet' : '${zone.freeSpots} places libres',
                  color: zone.isFull ? AppColors.red : AppColors.green),
              const Spacer(),
              Text('${zone.pricePerHour.toInt()} DT/h',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.cyan)),
            ]),
          ])),
          const SizedBox(height: 20),
          const Text('CRÉNEAU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DateTile(label: 'Début', dt: _start, onTap: () => _pickDate(true))),
            const SizedBox(width: 10),
            Expanded(child: _DateTile(label: 'Fin', dt: _end, onTap: () => _pickDate(false))),
          ]),
          const SizedBox(height: 20),
          ParkCard(bgColor: AppColors.blue.withOpacity(0.07), borderColor: AppColors.blue2.withOpacity(0.25),
            child: Column(children: [
              _Row('Durée', '${hours.toStringAsFixed(1)}h'),
              const Divider(height: 20, color: AppColors.border),
              _Row('Tarif', '${zone.pricePerHour.toInt()} DT/h'),
              const Divider(height: 20, color: AppColors.border),
              Row(children: [
                const Text('Total estimé', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${total.toInt()} DT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.cyan)),
              ]),
            ]),
          ),
          const SizedBox(height: 28),
          userAsync.when(
            data: (user) => zone.isFull
                ? const Center(child: Text('⚠️ Zone complète', style: TextStyle(color: AppColors.red)))
                : ParkButton(label: 'Confirmer la réservation', icon: Icons.check_circle_outline,
                    loading: _loading, onTap: user != null ? () => _book(user, zone!) : null),
            loading: () => const SizedBox(), error: (_, __) => const SizedBox(),
          ),
        ],
      ])),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDateTimePicker(context, isStart ? _start : _end);
    if (picked != null) setState(() { if (isStart) _start = picked; else _end = picked; });
  }
  String _typeIcon(String t) => {'vip':'⭐','couvert':'🏗️','souterrain':'🔽','pmr':'♿'}[t] ?? '🅿️';
}

Future<DateTime?> showDateTimePicker(BuildContext context, DateTime init) async {
  final date = await showDatePicker(context: context, initialDate: init,
    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)),
    builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: AppColors.blue2, surface: AppColors.card)), child: child!));
  if (date == null) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init),
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
//  RESERVATIONS SCREEN
// ══════════════════════════════════════════════════════
class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        GestureDetector(
          onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
              backgroundColor: AppColors.card,
              title: const Text('Annuler la réservation ?'),
              content: const Text('Cette action est irréversible.', style: TextStyle(color: AppColors.textMuted)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non', style: TextStyle(color: AppColors.textMuted))),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui', style: TextStyle(color: AppColors.red))),
              ],
            ));
            if (ok == true) {
              await ref.read(parkingServiceProvider).cancelReservation(r.id);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation annulée')));
            }
          },
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.red.withOpacity(0.2))),
            child: const Center(child: Text('Annuler', style: TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w600)))),
        ),
      ],
      if (r.totalAmount != null) ...[const SizedBox(height: 8),
        _Info(Icons.payments_outlined, '${r.totalAmount!.toInt()} DT', color: AppColors.green)],
    ]));
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
      appBar: AppBar(title: const Text('Mon profil')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          return ListView(padding: const EdgeInsets.all(20), children: [
            ParkCard(bgColor: AppColors.blue.withOpacity(0.1), borderColor: AppColors.blue2.withOpacity(0.25),
              child: Row(children: [
                Container(width: 58, height: 58,
                  decoration: const BoxDecoration(gradient: AppColors.blueGrad, shape: BoxShape.circle),
                  child: Center(child: Text(user.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)))),
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

Widget _PRow(IconData icon, String label, String value) => Row(children: [
  Icon(icon, color: AppColors.textMuted, size: 18), const SizedBox(width: 12),
  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)), const Spacer(),
  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
]);