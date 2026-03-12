import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/models.dart';
import '../../../../services/firebase_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/common_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _State();
}

class _State extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name  = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw    = TextEditingController();
  final _plate = TextEditingController();
  String _zone = 'Zone A';
  UserRole _role = UserRole.client;
  bool _hide = true, _loading = false;
  String? _err;
  int _step = 0;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pw.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final user = await ref.read(authServiceProvider).register(
       email: _email.text,
       password: _pw.text,
       name: _name.text,
       phone: _phone.text,
       role: UserRole.client,
       vehiclePlate: _plate.text,
      zone: null,
      );

      if (!mounted) return;

      context.go('/client/home');

    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _err = 'Email déjà utilisé.';
          break;
        case 'weak-password':
          _err = 'Mot de passe trop faible.';
          break;
        case 'invalid-email':
          _err = 'Email invalide.';
          break;
        default:
          _err = 'Erreur Firebase: ${e.message}';
      }
      setState(() {});

    } catch (e, st) {
      _err = 'Erreur inattendue: ${e.toString()}';
      debugPrint('Register error: $e\n$st');
      setState(() {});

    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              // ── Top bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _step > 0 ? setState(() => _step--) : context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 15, color: AppColors.textPri),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Créer un compte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('Étape ${_step + 1}/3', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ]),
              ),

              // ── Progress
              LinearProgressIndicator(
                value: (_step + 1) / 3,
                backgroundColor: AppColors.card,
                valueColor: AlwaysStoppedAnimation(
                  _step == 0 ? AppColors.blue2 : _step == 1 ? AppColors.cyan : AppColors.green,
                ),
                minHeight: 3,
              ),

              // ── Steps
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
                        child: c,
                      ),
                    ),
                    child: switch (_step) {
                      0 => _StepRole(
                        key: const ValueKey(0),
                        selected: _role,
                        onSelect: (r) => setState(() => _role = r),
                        onNext: () => setState(() => _step = 1),
                      ),
                      1 => _StepInfo(
                        key: const ValueKey(1),
                        name: _name,
                        email: _email,
                        phone: _phone,
                        pw: _pw,
                        hide: _hide,
                        onToggle: () => setState(() => _hide = !_hide),
                        onNext: () => setState(() => _step = 2),
                      ),
                      _ => _StepDetails(
                        key: const ValueKey(2),
                        role: _role,
                        plate: _plate,
                        zone: _zone,
                        onZoneChanged: (z) => setState(() => _zone = z),
                        loading: _loading,
                        error: _err,
                        onSubmit: _register,
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 0: Role ────────────────────────────────────────
class _StepRole extends StatelessWidget {
  final UserRole selected;
  final Function(UserRole) onSelect;
  final VoidCallback onNext;

  const _StepRole({super.key, required this.selected, required this.onSelect, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Vous êtes ?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Choisissez votre rôle. L\'interface sera adaptée automatiquement.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 32),

      _RoleOption(
        icon: Icons.person,
        title: 'Client',
        desc: 'Réservez des places, gérez vos véhicules et consultez l\'historique de vos stationnements.',
        color: AppColors.blue2,
        selected: selected == UserRole.client,
        onTap: () => onSelect(UserRole.client),
      ),
      const SizedBox(height: 14),
      
      const SizedBox(height: 40),
      ParkButton(
        label: 'Continuer',
        icon: Icons.arrow_forward,
        onTap: onNext,
        colors: selected == UserRole.responsable
            ? [AppColors.green, AppColors.cyan]
            : [AppColors.blue, AppColors.cyan],
      ),
    ]);
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({required this.icon, required this.title, required this.desc,
    required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 16)] : null,
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textPri)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5)),
            ]),
          ),
          if (selected)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
        ]),
      ),
    );
  }
}

// ── Step 1: Info ────────────────────────────────────────
class _StepInfo extends StatelessWidget {
  final TextEditingController name, email, phone, pw;
  final bool hide; final VoidCallback onToggle, onNext;

  const _StepInfo({super.key, required this.name, required this.email,
      required this.phone, required this.pw, required this.hide,
      required this.onToggle, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Vos informations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Renseignez vos coordonnées personnelles.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 28),

      ParkField(label: 'Nom complet', hint: 'Votre nom', controller: name,
          prefix: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
          validator: (v) => v!.isEmpty ? 'Requis' : null),
      const SizedBox(height: 16),
      ParkField(label: 'Email', hint: 'votre@email.com', controller: email,
          keyboardType: TextInputType.emailAddress,
          prefix: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 20),
          validator: (v) => v!.contains('@') ? null : 'Email invalide'),
      const SizedBox(height: 16),
      ParkField(label: 'Téléphone', hint: '0555 123 456', controller: phone,
          keyboardType: TextInputType.phone,
          prefix: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 20),
          validator: (v) => v!.isEmpty ? 'Requis' : null),
      const SizedBox(height: 16),
      ParkField(label: 'Mot de passe', hint: 'Min. 6 caractères', controller: pw,
          obscure: hide,
          prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
          suffix: GestureDetector(onTap: onToggle,
              child: Icon(hide ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textMuted, size: 20)),
          validator: (v) => v!.length >= 6 ? null : 'Min. 6 caractères'),
      const SizedBox(height: 40),
      ParkButton(label: 'Continuer', icon: Icons.arrow_forward, onTap: onNext),
    ]);
  }
}

// ── Step 2: Details ─────────────────────────────────────
class _StepDetails extends StatelessWidget {
  final UserRole role; final TextEditingController plate;
  final String zone; final Function(String) onZoneChanged;
  final bool loading; final String? error; final VoidCallback onSubmit;

  const _StepDetails({super.key, required this.role, required this.plate,
      required this.zone, required this.onZoneChanged, required this.loading,
      this.error, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final isClient = role == UserRole.client;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isClient ? 'Votre véhicule' : 'Votre affectation',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(isClient
          ? 'Ajoutez votre véhicule pour faciliter les réservations.'
          : 'Indiquez votre zone de travail.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 28),

      if (isClient)
        ParkField(label: 'Plaque immatriculation', hint: '16-12345-A', controller: plate,
            prefix: const Icon(Icons.directions_car_outlined, color: AppColors.textMuted, size: 20),
            validator: (v) => v!.isEmpty ? 'Requis' : null)
      else ...[
        const Text('ZONE AFFECTÉE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: zone,
          decoration: const InputDecoration(hintText: 'Choisir une zone'),
          dropdownColor: AppColors.card,
          style: const TextStyle(color: AppColors.textPri, fontSize: 14),
          items: const [
            DropdownMenuItem(value: 'Zone A', child: Text('Zone A — Extérieur')),
            DropdownMenuItem(value: 'Zone B', child: Text('Zone B — Couvert')),
            DropdownMenuItem(value: 'Zone C', child: Text('Zone C — Souterrain')),
            DropdownMenuItem(value: 'Zone VIP', child: Text('Zone VIP — Premium')),
          ],
          onChanged: (v) { if (v != null) onZoneChanged(v); },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.green.withOpacity(0.2))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.green, size: 16),
            SizedBox(width: 10),
            Expanded(child: Text('Votre compte sera activé par l\'administrateur.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
          ]),
        ),
      ],

      if (error != null) ...[const SizedBox(height: 16), ErrorBox(message: error!)],
      const SizedBox(height: 40),
      ParkButton(
        label: 'Créer mon compte', icon: Icons.check,
        loading: loading, onTap: onSubmit,
        colors: isClient ? [AppColors.blue, AppColors.cyan] : [AppColors.green, AppColors.cyan],
      ),
    ]);
  }
}