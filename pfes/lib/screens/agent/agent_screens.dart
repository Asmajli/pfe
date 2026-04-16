// ══════════════════════════════════════════════════════
//  AGENT DE PARKING — SCREENS COMPLETS
//  Remplace complètement l'ancien "Responsable"
//
//  Flow principal :
//    1. Agent scanne QR d'entrée du client
//    2. Système enregistre l'entrée + calcule retard éventuel
//    3. QR de sortie généré automatiquement et affiché
//    4. À la sortie : agent scanne QR sortie → facture retard
// ══════════════════════════════════════════════════════

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ══════════════════════════════════════════════════════
//  AGENT SHELL
// ══════════════════════════════════════════════════════
class AgentShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AgentShell({super.key, required this.shell});

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
          selectedItemColor: AppColors.orange,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_outlined),
              activeIcon: Icon(Icons.qr_code_scanner),
              label: 'Scanner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  AGENT SCAN SCREEN — écran principal scanner
// ══════════════════════════════════════════════════════
class AgentScanScreen extends ConsumerStatefulWidget {
  const AgentScanScreen({super.key});
  @override
  ConsumerState<AgentScanScreen> createState() => _AgentScanState();
}

class _AgentScanState extends ConsumerState<AgentScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;
  // mode: 'entry' = scan QR réservation client (entrée)
  //       'exit'  = scan QR sortie généré par l'agent
  String _mode = 'entry';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    // QR entrée client : PARK|resvId|zoneId|...
    if (_mode == 'entry' && raw.startsWith('PARK|')) {
      setState(() => _scanned = true);
      _ctrl.stop();
      _handleEntryQR(raw);
      return;
    }

    // QR sortie généré par l'agent : EXIT|resvId|zoneId|...
    if (_mode == 'exit' && raw.startsWith('EXIT|')) {
      setState(() => _scanned = true);
      _ctrl.stop();
      _handleExitQR(raw);
      return;
    }
  }

  // ── Traitement QR entrée ──────────────────────────
  void _handleEntryQR(String raw) {
    final parts = raw.split('|');
    if (parts.length < 7) { _reset(); return; }

    DateTime? start, end;
    try { start = DateTime.parse(parts[5]); } catch (_) {}
    try { end   = DateTime.parse(parts[6]); } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => _EntrySheet(
        resvId: parts[1], zoneId: parts[2],
        zoneName: parts[3], spot: parts[4],
        start: start, end: end,
        onDone: _reset,
      ),
    ).whenComplete(_reset);
  }

  // ── Traitement QR sortie ──────────────────────────
  void _handleExitQR(String raw) {
    final parts = raw.split('|');
    // EXIT|resvId|zoneId|zoneName|spot|entryTime|scheduledEnd|retardAmount
    if (parts.length < 8) { _reset(); return; }

    DateTime? entryTime, scheduledEnd;
    try { entryTime    = DateTime.parse(parts[5]); } catch (_) {}
    try { scheduledEnd = DateTime.parse(parts[6]); } catch (_) {}
    final retardAmount = double.tryParse(parts[7]) ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => _ExitSheet(
        resvId: parts[1], zoneId: parts[2],
        zoneName: parts[3], spot: parts[4],
        entryTime: entryTime, scheduledEnd: scheduledEnd,
        retardAmount: retardAmount,
        onDone: _reset,
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
    final user = ref.watch(currentUserProvider).asData?.value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [

        // ── Header agent ────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          color: const Color(0xFF0d1220),
          child: Column(children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.orange.withOpacity(0.4)),
                ),
                child: const Icon(Icons.badge, color: AppColors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.name ?? 'Agent', style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(user?.zone != null ? '📍 Zone assignée' : '📍 Entrée parking',
                    style: const TextStyle(fontSize: 10, color: AppColors.orange)),
              ])),
              // Indicateur LIVE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: Colors.red, size: 8),
                  SizedBox(width: 5),
                  Text('LIVE', style: TextStyle(
                      color: Colors.red, fontSize: 10, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Toggle Entrée / Sortie ───────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2235),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                _ModeBtn(
                  label: '🚗 Entrée client',
                  active: _mode == 'entry',
                  color: AppColors.green,
                  onTap: () => setState(() => _mode = 'entry'),
                ),
                const SizedBox(width: 4),
                _ModeBtn(
                  label: '🚪 Sortie client',
                  active: _mode == 'exit',
                  color: AppColors.red,
                  onTap: () => setState(() => _mode = 'exit'),
                ),
              ]),
            ),
          ]),
        ),

        // ── Caméra ──────────────────────────────────
        Expanded(child: Stack(children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),

          // Cadre + instructions
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Cadre scan avec coins colorés
            Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _mode == 'entry' ? AppColors.green : AppColors.red,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(children: [
                Positioned(top: 0,    left: 0,  child: _ScanCorner(_mode == 'entry' ? AppColors.green : AppColors.red, true,  true)),
                Positioned(top: 0,    right: 0, child: _ScanCorner(_mode == 'entry' ? AppColors.green : AppColors.red, true,  false)),
                Positioned(bottom: 0, left: 0,  child: _ScanCorner(_mode == 'entry' ? AppColors.green : AppColors.red, false, true)),
                Positioned(bottom: 0, right: 0, child: _ScanCorner(_mode == 'entry' ? AppColors.green : AppColors.red, false, false)),
                // Ligne de scan animée
                const _ScanLine(),
              ]),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                Icon(
                  _mode == 'entry' ? Icons.qr_code_2 : Icons.exit_to_app,
                  color: _mode == 'entry' ? AppColors.green : AppColors.red,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  _mode == 'entry'
                      ? 'Scannez le QR d\'entrée du client'
                      : 'Scannez le QR de sortie du client',
                  style: TextStyle(
                    color: _mode == 'entry' ? AppColors.green : AppColors.red,
                    fontSize: 13, fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _mode == 'entry'
                      ? 'Un QR de sortie sera généré automatiquement'
                      : 'Vérification et facturation du retard',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ])),

          // Bouton torche
          Positioned(top: 16, right: 16,
            child: GestureDetector(
              onTap: () => _ctrl.toggleTorch(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
              ),
            ),
          ),
        ])),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════
//  ENTRY SHEET — confirme entrée + génère QR sortie
// ══════════════════════════════════════════════════════
class _EntrySheet extends ConsumerStatefulWidget {
  final String resvId, zoneId, zoneName, spot;
  final DateTime? start, end;
  final VoidCallback onDone;
  const _EntrySheet({
    required this.resvId, required this.zoneId,
    required this.zoneName, required this.spot,
    required this.start, required this.end,
    required this.onDone,
  });
  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  bool _loading = false;
  bool _done = false;
  String? _exitQrData;
  double _retardMin = 0;
  double _retardAmount = 0;
  double _pricePerHour = 2.5;
  DateTime? _entryTime;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reservations').doc(widget.resvId).get();
      if (doc.exists) {
        final p = doc.data()?['pricePerHour'];
        if (p != null) setState(() => _pricePerHour = (p as num).toDouble());
      }
    } catch (_) {}
  }

  // Calcule retard : temps actuel > heure de fin réservée
  void _calcRetard(DateTime now) {
    if (widget.end == null) return;
    final diff = now.difference(widget.end!).inMinutes;
    if (diff > 0) {
      _retardMin    = diff.toDouble();
      _retardAmount = (diff / 60.0) * _pricePerHour;
    }
  }

  Future<void> _confirmEntry() async {
    setState(() => _loading = true);
    try {
      final agent = ref.read(currentUserProvider).asData?.value;
      if (agent == null) throw Exception('Agent non connecté');

      final now = DateTime.now();
      _calcRetard(now);
      _entryTime = now;

      // Enregistrer log d'entrée dans Firestore
      await FirebaseFirestore.instance.collection('vehicle_logs').add({
        'resvId':          widget.resvId,
        'zoneId':          widget.zoneId,
        'zoneName':        widget.zoneName,
        'plate':           widget.spot,
        'ownerName':       'Via QR',
        'spotNumber':      widget.spot,
        'type':            'entry',
        'timestamp':       FieldValue.serverTimestamp(),
        'agentId':         agent.uid,
        'agentName':       agent.name,
        'entryTime':       now.toIso8601String(),
        'scheduledEnd':    widget.end?.toIso8601String(),
        'retardMinutes':   _retardMin,
        'retardAmount':    _retardAmount,
      });

      // Mettre à jour statut réservation → active
      await FirebaseFirestore.instance
          .collection('reservations').doc(widget.resvId)
          .update({
        'status':    'active',
        'entryTime': now.toIso8601String(),
        'agentId':   agent.uid,
      });

      // Générer QR de sortie
      // Format : EXIT|resvId|zoneId|zoneName|spot|entryTime|scheduledEnd|retardAmount
      final exitQr =
          'EXIT|${widget.resvId}|${widget.zoneId}|${widget.zoneName}|${widget.spot}'
          '|${now.toIso8601String()}'
          '|${widget.end?.toIso8601String() ?? ''}'
          '|${_retardAmount.toStringAsFixed(2)}';

      // Sauvegarder le QR de sortie dans Firestore (pour l'admin aussi)
      await FirebaseFirestore.instance
          .collection('reservations').doc(widget.resvId)
          .update({'exitQrData': exitQr});

      if (!mounted) return;
      setState(() { _done = true; _exitQrData = exitQr; _loading = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _done ? 0.85 : 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0d1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: _done ? _buildDone(ctrl) : _buildConfirm(ctrl),
      ),
    );
  }

  // ── Vue avant confirmation ──────────────────────
  Widget _buildConfirm(ScrollController ctrl) {
    final now = DateTime.now();
    _calcRetard(now); // prévisualisation retard
    final hasRetard = _retardMin > 0;

    return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(24, 12, 24, 32), children: [
      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),

      // Titre
      Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.green.withOpacity(0.4)),
          ),
          child: const Icon(Icons.qr_code_scanner, color: AppColors.green, size: 24)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('QR Entrée Valide ✅', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.green)),
          Text('Confirmez l\'entrée du client', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
      ]),
      const SizedBox(height: 20),

      // Infos réservation
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          _InfoRow(Icons.local_parking, 'Zone', widget.zoneName, AppColors.blue2),
          const Divider(height: 16, color: AppColors.border),
          _InfoRow(Icons.grid_view, 'Place', widget.spot, AppColors.cyan),
          if (widget.start != null) ...[
            const Divider(height: 16, color: AppColors.border),
            _InfoRow(Icons.play_circle_outline, 'Début réservé',
                DateFormat('dd/MM  HH:mm').format(widget.start!), AppColors.green),
          ],
          if (widget.end != null) ...[
            const Divider(height: 16, color: AppColors.border),
            _InfoRow(Icons.stop_circle_outlined, 'Fin réservée',
                DateFormat('dd/MM  HH:mm').format(widget.end!), AppColors.purple),
          ],
        ]),
      ),
      const SizedBox(height: 14),

      // Alerte retard si applicable
      if (hasRetard) Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red.withOpacity(0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚠️ Retard détecté', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.red)),
            Text('${_retardMin.toInt()} min de retard → +${_retardAmount.toStringAsFixed(2)} DT à facturer',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ])),
        ]),
      ),
      const SizedBox(height: 20),

      // Bouton confirmer
      GestureDetector(
        onTap: _loading ? null : _confirmEntry,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.green.withOpacity(0.9), AppColors.cyan.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_loading)
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
            else ...[
              const Icon(Icons.login, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Confirmer l\'entrée + Générer QR Sortie',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () { Navigator.pop(context); widget.onDone(); },
        child: const Center(child: Text('Annuler', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
      ),
    ]);
  }

  // ── Vue après confirmation : affiche QR de sortie ──
  Widget _buildDone(ScrollController ctrl) {
    return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(24, 12, 24, 36), children: [
      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),

      // Header succès
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.green.withOpacity(0.8), AppColors.cyan.withOpacity(0.8)]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Entrée enregistrée !', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.green)),
          Text('QR de sortie généré automatiquement ✅',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ])),
      ]),
      const SizedBox(height: 22),

      // ── QR DE SORTIE ──────────────────────────────
      const Center(child: Text('QR CODE DE SORTIE',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.orange, letterSpacing: 1.2))),
      const SizedBox(height: 12),
      Center(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(0.3), blurRadius: 20)],
        ),
        child: SizedBox(
          width: 210, height: 210,
          child: QrImageView(
            data: _exitQrData ?? '',
            version: QrVersions.auto,
            size: 210,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0d1220)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0d1220)),
          ),
        ),
      )),
      const SizedBox(height: 12),
      const Center(child: Text('Donnez ce QR au client pour la sortie',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
      const SizedBox(height: 18),

      // Infos retard si applicable
      if (_retardMin > 0) Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red.withOpacity(0.3)),
        ),
        child: Column(children: [
          const Row(children: [
            Icon(Icons.timer_off_outlined, color: AppColors.red, size: 18),
            SizedBox(width: 8),
            Text('Retard à facturer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.red)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _StatChip('${_retardMin.toInt()} min', 'Retard', AppColors.red),
            const SizedBox(width: 10),
            _StatChip('${_retardAmount.toStringAsFixed(2)} DT', 'Supplément', AppColors.orange),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      // Récap entrée
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          _InfoRow(Icons.local_parking, 'Zone', widget.zoneName, AppColors.blue2),
          const Divider(height: 14, color: AppColors.border),
          _InfoRow(Icons.grid_view, 'Place', widget.spot, AppColors.cyan),
          if (_entryTime != null) ...[
            const Divider(height: 14, color: AppColors.border),
            _InfoRow(Icons.login, 'Heure entrée', DateFormat('HH:mm').format(_entryTime!), AppColors.green),
          ],
          if (widget.end != null) ...[
            const Divider(height: 14, color: AppColors.border),
            _InfoRow(Icons.flag_outlined, 'Fin prévue', DateFormat('HH:mm').format(widget.end!), AppColors.purple),
          ],
        ]),
      ),
      const SizedBox(height: 20),

      // Bouton fermer
      GestureDetector(
        onTap: () { Navigator.pop(context); widget.onDone(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.orange.withOpacity(0.35)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.qr_code_scanner, color: AppColors.orange, size: 18),
            SizedBox(width: 8),
            Text('Scanner un autre QR', style: TextStyle(color: AppColors.orange, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════
//  EXIT SHEET — vérifie QR sortie + facture retard
// ══════════════════════════════════════════════════════
class _ExitSheet extends ConsumerStatefulWidget {
  final String resvId, zoneId, zoneName, spot;
  final DateTime? entryTime, scheduledEnd;
  final double retardAmount;
  final VoidCallback onDone;
  const _ExitSheet({
    required this.resvId, required this.zoneId,
    required this.zoneName, required this.spot,
    required this.entryTime, required this.scheduledEnd,
    required this.retardAmount, required this.onDone,
  });
  @override
  ConsumerState<_ExitSheet> createState() => _ExitSheetState();
}

class _ExitSheetState extends ConsumerState<_ExitSheet> {
  bool _loading = false;
  bool _done = false;
  double _finalRetardAmount = 0;
  double _finalRetardMin = 0;
  double _pricePerHour = 2.5;

  @override
  void initState() {
    super.initState();
    _calcFinalRetard();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reservations').doc(widget.resvId).get();
      if (doc.exists) {
        final p = doc.data()?['pricePerHour'];
        if (p != null) {
          setState(() => _pricePerHour = (p as num).toDouble());
          _calcFinalRetard();
        }
      }
    } catch (_) {}
  }

  void _calcFinalRetard() {
    // Calcule le retard réel au moment de la sortie
    if (widget.scheduledEnd == null) {
      _finalRetardAmount = widget.retardAmount;
      return;
    }
    final now  = DateTime.now();
    final diff = now.difference(widget.scheduledEnd!).inMinutes;
    if (diff > 0) {
      _finalRetardMin    = diff.toDouble();
      _finalRetardAmount = (diff / 60.0) * _pricePerHour;
    } else {
      _finalRetardMin    = 0;
      _finalRetardAmount = 0;
    }
  }

  Future<void> _confirmExit() async {
    setState(() => _loading = true);
    try {
      final agent = ref.read(currentUserProvider).asData?.value;
      if (agent == null) throw Exception('Agent non connecté');

      final now = DateTime.now();
      _calcFinalRetard();

      // Log sortie
      await FirebaseFirestore.instance.collection('vehicle_logs').add({
        'resvId':         widget.resvId,
        'zoneId':         widget.zoneId,
        'zoneName':       widget.zoneName,
        'plate':          widget.spot,
        'ownerName':      'Via QR Sortie',
        'spotNumber':     widget.spot,
        'type':           'exit',
        'timestamp':      FieldValue.serverTimestamp(),
        'agentId':        agent.uid,
        'agentName':      agent.name,
        'exitTime':       now.toIso8601String(),
        'retardMinutes':  _finalRetardMin,
        'retardAmount':   _finalRetardAmount,
      });

      // Clôturer la réservation
      await FirebaseFirestore.instance
          .collection('reservations').doc(widget.resvId)
          .update({
        'status':          'completed',
        'exitTime':        now.toIso8601String(),
        'agentExit':       agent.uid,
        'retardAmount':    _finalRetardAmount,
        'finalTotalAmount': FieldValue.increment(_finalRetardAmount), 
      });

      if (!mounted) return;
      setState(() { _done = true; _loading = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _calcFinalRetard(); // refresh

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0d1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(24, 12, 24, 36), children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),

          if (_done) ...[
            // ── Succès sortie ──────────────────────
            const Center(child: Text('🎉', style: TextStyle(fontSize: 48))),
            const SizedBox(height: 12),
            const Center(child: Text('Sortie enregistrée !',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.green))),
            const SizedBox(height: 8),
            Center(child: Text(
              _finalRetardAmount > 0
                  ? 'Supplément retard : ${_finalRetardAmount.toStringAsFixed(2)} DT'
                  : 'Aucun retard — Sortie dans les temps ✅',
              style: TextStyle(
                fontSize: 13,
                color: _finalRetardAmount > 0 ? AppColors.red : AppColors.green,
                fontWeight: FontWeight.w600,
              ),
            )),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () { Navigator.pop(context); widget.onDone(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green.withOpacity(0.35)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.green, size: 18),
                  SizedBox(width: 8),
                  Text('Scanner suivant', style: TextStyle(color: AppColors.green, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ] else ...[
            // ── Confirmation sortie ────────────────
            Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.red.withOpacity(0.3)),
                ),
                child: const Icon(Icons.logout, color: AppColors.red, size: 22)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('QR Sortie Détecté', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Confirmez la sortie et la facturation', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ])),
            ]),
            const SizedBox(height: 20),

            // Infos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
              child: Column(children: [
                _InfoRow(Icons.local_parking, 'Zone', widget.zoneName, AppColors.blue2),
                const Divider(height: 16, color: AppColors.border),
                _InfoRow(Icons.grid_view, 'Place', widget.spot, AppColors.cyan),
                if (widget.entryTime != null) ...[
                  const Divider(height: 16, color: AppColors.border),
                  _InfoRow(Icons.login, 'Entrée', DateFormat('HH:mm').format(widget.entryTime!), AppColors.green),
                ],
                if (widget.scheduledEnd != null) ...[
                  const Divider(height: 16, color: AppColors.border),
                  _InfoRow(Icons.flag_outlined, 'Fin prévue', DateFormat('HH:mm').format(widget.scheduledEnd!), AppColors.purple),
                ],
                const Divider(height: 16, color: AppColors.border),
                _InfoRow(Icons.logout, 'Sortie réelle', DateFormat('HH:mm').format(DateTime.now()), AppColors.orange),
              ]),
            ),
            const SizedBox(height: 14),

            // Facturation retard
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _finalRetardAmount > 0
                    ? AppColors.red.withOpacity(0.07)
                    : AppColors.green.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _finalRetardAmount > 0
                      ? AppColors.red.withOpacity(0.3)
                      : AppColors.green.withOpacity(0.3),
                ),
              ),
              child: _finalRetardAmount > 0
                  ? Column(children: [
                      const Row(children: [
                        Icon(Icons.timer_off_outlined, color: AppColors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Supplément retard', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.red)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _StatChip('${_finalRetardMin.toInt()} min', 'Retard', AppColors.red),
                        const SizedBox(width: 10),
                        _StatChip('${_finalRetardAmount.toStringAsFixed(2)} DT', 'À payer', AppColors.orange),
                      ]),
                    ])
                  : const Row(children: [
                      Icon(Icons.check_circle_outline, color: AppColors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Sortie dans les temps ✅ — Aucun supplément',
                          style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w700)),
                    ]),
            ),
            const SizedBox(height: 20),

            // Bouton confirmer sortie
            GestureDetector(
              onTap: _loading ? null : _confirmExit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.red.withOpacity(0.4)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_loading)
                    const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.red)))
                  else ...[
                    const Icon(Icons.logout, color: AppColors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _finalRetardAmount > 0
                          ? 'Confirmer sortie + Facturer ${_finalRetardAmount.toStringAsFixed(2)} DT'
                          : 'Confirmer la sortie',
                      style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () { Navigator.pop(context); widget.onDone(); },
              child: const Center(child: Text('Annuler', style: TextStyle(color: AppColors.textMuted))),
            ),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  JOURNAL SCREEN — historique des entrées/sorties
// ══════════════════════════════════════════════════════
class AgentJournalScreen extends ConsumerWidget {
  const AgentJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync  = ref.watch(currentUserProvider);
    final zonesAsync = ref.watch(zonesProvider);
    final user = userAsync.asData?.value;

    // Récupère les logs de la zone de l'agent (ou tous si pas de zone)
    final zoneId = user?.zone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des passages'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.orange.withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.badge, color: AppColors.orange, size: 14),
                SizedBox(width: 5),
                Text('Agent', style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildLogsStream(zoneId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.orange)));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('📋', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('Aucun passage enregistré', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Les entrées/sorties scannées apparaîtront ici',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]));
          }

          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final isEntry = d['type'] == 'entry';
              final ts = d['timestamp'] as Timestamp?;
              final time = ts != null ? ts.toDate() : DateTime.now();
              final retard = (d['retardAmount'] ?? 0.0) as double;

              return ParkCard(
                borderColor: (isEntry ? AppColors.green : AppColors.red).withOpacity(0.25),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: (isEntry ? AppColors.green : AppColors.red).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEntry ? Icons.login : Icons.logout,
                      color: isEntry ? AppColors.green : AppColors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      d['spotNumber'] ?? d['plate'] ?? '—',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                    ),
                    Text(
                      '${d['zoneName'] ?? ''} · ${isEntry ? "Entrée" : "Sortie"}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    if (retard > 0) Text(
                      '⚠️ Retard: +${retard.toStringAsFixed(2)} DT',
                      style: const TextStyle(fontSize: 10, color: AppColors.red, fontWeight: FontWeight.w700),
                    ),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      DateFormat('HH:mm').format(time),
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: isEntry ? AppColors.green : AppColors.red,
                      ),
                    ),
                    Text(
                      timeago.format(time, locale: 'fr'),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ]),
                ]),
              ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.04);
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _buildLogsStream(String? zoneId) {
    var q = FirebaseFirestore.instance
        .collection('vehicle_logs')
        .orderBy('timestamp', descending: true)
        .limit(50);
    if (zoneId != null) {
      return FirebaseFirestore.instance
          .collection('vehicle_logs')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();
    }
    return q.snapshots();
  }
}

// ══════════════════════════════════════════════════════
//  AGENT PROFILE SCREEN
// ══════════════════════════════════════════════════════
class AgentProfileScreen extends ConsumerWidget {
  const AgentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync  = ref.watch(currentUserProvider);
    final zonesAsync = ref.watch(zonesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          final zones   = zonesAsync.asData?.value ?? [];
          final zoneObj = user.zone != null
              ? zones.where((z) => z.id == user.zone).cast<ParkingZone?>()
                  .firstWhere((_) => true, orElse: () => null)
              : null;
          final zoneName = zoneObj?.name ?? '—';

          return ListView(padding: const EdgeInsets.all(20), children: [

            // ── Carte identité agent ──
            ParkCard(
              bgColor: AppColors.orange.withOpacity(0.06),
              borderColor: AppColors.orange.withOpacity(0.3),
              child: Row(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.orange.withOpacity(0.9), AppColors.red.withOpacity(0.7)]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.badge, color: AppColors.orange, size: 13),
                      SizedBox(width: 5),
                      Text('Agent de Parking', style: TextStyle(
                          fontSize: 11, color: AppColors.orange, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ])),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Infos personnelles ──
            ParkCard(child: Column(children: [
              _PRow(Icons.person_outline, 'Nom', user.name),
              const Divider(height: 20, color: AppColors.border),
              _PRow(Icons.email_outlined, 'Email', user.email),
              const Divider(height: 20, color: AppColors.border),
              _PRow(Icons.phone_outlined, 'Téléphone', user.phone.isEmpty ? '—' : user.phone),
              const Divider(height: 20, color: AppColors.border),
              _PRow(Icons.layers_outlined, 'Zone assignée', zoneName),
            ])),
            const SizedBox(height: 16),

            // ── Contacts urgence ──
            ParkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CONTACTS URGENCE', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              _PRow(Icons.admin_panel_settings_outlined, 'Admin', '+216 555 000 001'),
              const Divider(height: 16, color: AppColors.border),
              _PRow(Icons.emergency, 'Urgence', '197'),
            ])),
            const SizedBox(height: 24),

            ParkButton(
              label: 'Déconnexion',
              icon: Icons.logout,
              outlined: true,
              colors: [AppColors.red],
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
}

// ══════════════════════════════════════════════════════
//  WIDGETS HELPERS
// ══════════════════════════════════════════════════════

// Ligne scan animée
class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}
class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Positioned(
      top: _anim.value * 220,
      left: 10, right: 10,
      child: Container(height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              AppColors.orange.withOpacity(0.9),
              Colors.transparent,
            ]),
          )),
    ),
  );
}

// Coins de cadre scan
class _ScanCorner extends StatelessWidget {
  final Color color;
  final bool top, left;
  const _ScanCorner(this.color, this.top, this.left);
  @override
  Widget build(BuildContext context) => Container(
    width: 26, height: 26,
    decoration: BoxDecoration(
      border: Border(
        top:    top    ? BorderSide(color: color, width: 4) : BorderSide.none,
        bottom: !top   ? BorderSide(color: color, width: 4) : BorderSide.none,
        left:   left   ? BorderSide(color: color, width: 4) : BorderSide.none,
        right:  !left  ? BorderSide(color: color, width: 4) : BorderSide.none,
      ),
    ),
  );
}

// Toggle mode entrée/sortie
class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.active, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: active ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Center(child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? color : AppColors.textMuted))),
    ),
  ));
}

// Chip statistique
Widget _StatChip(String value, String label, Color color) => Expanded(child: Container(
  padding: const EdgeInsets.symmetric(vertical: 10),
  decoration: BoxDecoration(
    color: color.withOpacity(0.08),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: color.withOpacity(0.2)),
  ),
  child: Column(children: [
    Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
  ]),
));

// Ligne info avec icône
Widget _InfoRow(IconData icon, String label, String value, Color color) => Row(children: [
  Icon(icon, size: 15, color: color),
  const SizedBox(width: 8),
  Text('$label : ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
  Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      overflow: TextOverflow.ellipsis)),
]);

// Ligne profil
Widget _PRow(IconData icon, String label, String value) => Row(children: [
  Icon(icon, color: AppColors.textMuted, size: 18),
  const SizedBox(width: 12),
  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
  const Spacer(),
  Flexible(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
]);

// ── Ajouter AppColors.orange si pas déjà présent dans app_theme.dart ──
// static const Color orange = Color(0xFFf97316);