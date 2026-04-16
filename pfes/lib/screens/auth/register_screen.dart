import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override ConsumerState<RegisterScreen> createState() => _State();
}

class _State extends ConsumerState<RegisterScreen> {
  final _form  = GlobalKey<FormState>();
  final _name  = TextEditingController();
  final _email = TextEditingController();
  final _pw    = TextEditingController();
  final _pw2   = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();

  bool _hide1 = true, _hide2 = true;
  bool _loading = false;
  bool _checkingEmail = false;
  String? _err;
  String? _emailHint;

  @override
  void dispose() {
    _name.dispose(); _email.dispose();
    _pw.dispose(); _pw2.dispose();
    _phone.dispose(); _plate.dispose();
    super.dispose();
  }

  Future<void> _checkEmailExists(String email) async {
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailHint = null);
      return;
    }
    setState(() { _checkingEmail = true; _emailHint = null; });
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email.trim());
      if (!mounted) return;
      setState(() {
        _checkingEmail = false;
        _emailHint = methods.isNotEmpty ? 'already_exists' : 'available';
      });
    } catch (_) {
      if (mounted) setState(() { _checkingEmail = false; _emailHint = null; });
    }
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    if (_emailHint == 'already_exists') {
      setState(() => _err = 'Un compte existe déjà avec cet email.');
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      // ── role est toujours client pour l'inscription publique ──
      await ref.read(authServiceProvider).register(
        name:         _name.text.trim(),
        email:        _email.text.trim(),
        password:     _pw.text,
        phone:        _phone.text.trim(),
        vehiclePlate: _plate.text.trim().isNotEmpty ? _plate.text.trim() : null,
      );
      if (!mounted) return;
      context.go('/client/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _err = switch (e.code) {
        'email-already-in-use' => 'Un compte existe déjà avec cet email',
        'invalid-email'        => 'Adresse email invalide',
        'weak-password'        => 'Mot de passe trop faible (min. 6 caractères)',
        'network-request-failed' => 'Vérifiez votre connexion internet',
        _                      => 'Erreur lors de la création du compte',
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(key: _form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            const Text('INFORMATIONS PERSONNELLES', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 14),

            ParkField(
              label: 'Nom complet', hint: 'Votre nom',
              controller: _name,
              prefix: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 18),
              validator: (v) => v!.trim().length >= 2 ? null : 'Nom trop court',
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 14),

            // Email + vérification temps réel
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ParkField(
                label: 'Email', hint: 'votre@email.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 18),
                suffix: _checkingEmail
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.blue2)))
                    : _emailHint == 'available'
                        ? const Icon(Icons.check_circle, color: AppColors.green, size: 20)
                        : _emailHint == 'already_exists'
                            ? const Icon(Icons.cancel, color: AppColors.red, size: 20)
                            : null,
                onChanged: (v) {
                  if (v.length > 5) _checkEmailExists(v);
                  else setState(() => _emailHint = null);
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email obligatoire';
                  if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                  return null;
                },
              ),
              if (_emailHint != null) Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: _emailHint == 'already_exists'
                    ? Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.red, size: 14),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('Un compte existe déjà avec cet email',
                            style: TextStyle(fontSize: 11, color: AppColors.red))),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: const Text('Se connecter →',
                              style: TextStyle(fontSize: 11, color: AppColors.cyan, fontWeight: FontWeight.w700)),
                        ),
                      ])
                    : const Row(children: [
                        Icon(Icons.check_circle_outline, color: AppColors.green, size: 14),
                        SizedBox(width: 6),
                        Text('Email disponible ✓', style: TextStyle(fontSize: 11, color: AppColors.green)),
                      ]),
              ),
            ]).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 14),

            ParkField(
              label: 'Téléphone', hint: '+216 XX XXX XXX',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefix: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 18),
              validator: (v) => v!.trim().length >= 8 ? null : 'Numéro invalide',
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),

            const Text('SÉCURITÉ', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 14),

            ParkField(
              label: 'Mot de passe', hint: 'Min. 6 caractères',
              controller: _pw, obscure: _hide1,
              prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
              suffix: GestureDetector(
                onTap: () => setState(() => _hide1 = !_hide1),
                child: Icon(_hide1 ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted, size: 18),
              ),
              validator: (v) => v!.length >= 6 ? null : 'Min. 6 caractères',
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 14),

            ParkField(
              label: 'Confirmer le mot de passe', hint: 'Répétez le mot de passe',
              controller: _pw2, obscure: _hide2,
              prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
              suffix: GestureDetector(
                onTap: () => setState(() => _hide2 = !_hide2),
                child: Icon(_hide2 ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted, size: 18),
              ),
              validator: (v) => v == _pw.text ? null : 'Les mots de passe ne correspondent pas',
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 24),

            const Text('VÉHICULE (optionnel)', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 14),

            ParkField(
              label: 'Plaque d\'immatriculation', hint: 'ex: 16-12345-A',
              controller: _plate,
              prefix: const Icon(Icons.directions_car_outlined, color: AppColors.textMuted, size: 18),
            ).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: 24),

            if (_err != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_err!, style: const TextStyle(fontSize: 12, color: AppColors.red))),
                ]),
              ).animate().shake(),
              const SizedBox(height: 16),
            ],

            ParkButton(
              label: 'Créer mon compte',
              icon: Icons.person_add_outlined,
              loading: _loading,
              onTap: _emailHint == 'already_exists' ? null : _register,
              colors: [AppColors.blue, AppColors.cyan],
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
            const SizedBox(height: 16),

            Center(child: GestureDetector(
              onTap: () => context.pop(),
              child: const Text('Déjà un compte ? Se connecter',
                  style: TextStyle(fontSize: 13, color: AppColors.cyan, fontWeight: FontWeight.w600)),
            )).animate().fadeIn(delay: 450.ms),

            const SizedBox(height: 32),
          ],
        )),
      )),
    );
  }
}