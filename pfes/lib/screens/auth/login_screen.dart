import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _State();
}

class _State extends ConsumerState<LoginScreen> {
  final _form  = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw    = TextEditingController();
  bool _hide = true, _loading = false;
  String? _err;
  String? _resetSuccess;

  @override void dispose() { _email.dispose(); _pw.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _err = null; _resetSuccess = null; });
    try {
      final user = await ref.read(authServiceProvider).login(
          _email.text.trim(), _pw.text);
      if (!mounted) return;

      // ── ربط OneSignal بـ userId بعد login ──
      OneSignal.login(user.uid);

      context.go(user.role == UserRole.agent ? '/agent/scan' : '/client/home');
    } catch (e) {
      setState(() => _err = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(String e) {
    if (e.contains('user-not-found') || e.contains('invalid-credential'))
      return 'Email ou mot de passe incorrect';
    if (e.contains('wrong-password'))    return 'Mot de passe incorrect';
    if (e.contains('invalid-email'))     return 'Adresse email invalide';
    if (e.contains('too-many-requests')) return 'Trop de tentatives, réessayez plus tard';
    if (e.contains('network'))           return 'Vérifiez votre connexion internet';
    return 'Email ou mot de passe incorrect';
  }

  void _forgotSheet() {
    final ctrl   = TextEditingController();
    bool loading = false;
    bool sent    = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 36,
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),

              if (sent) ...[
                Center(child: Container(width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.12), shape: BoxShape.circle,
                    border: Border.all(color: AppColors.green.withOpacity(0.35))),
                  child: const Icon(Icons.mark_email_read_outlined, color: AppColors.green, size: 34))),
                const SizedBox(height: 16),
                const Center(child: Text('Email envoyé !',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                const SizedBox(height: 8),
                Center(child: Text(
                  'Un lien envoyé à ${ctrl.text.trim()}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                  textAlign: TextAlign.center)),
                const SizedBox(height: 6),
                const Center(child: Text('Vérifiez aussi vos spams',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
                const SizedBox(height: 24),
                ParkButton(
                  label: 'Retour à la connexion', icon: Icons.login,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setState(() => _resetSuccess =
                        'Lien envoyé à ${ctrl.text.trim()} — Vérifiez votre boîte mail');
                  },
                  colors: [AppColors.blue, AppColors.cyan],
                ),
              ] else ...[
                const Text('Mot de passe oublié ?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Entrez votre email pour recevoir un lien de réinitialisation.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
                const SizedBox(height: 20),
                ParkField(
                  label: 'Email', hint: 'votre@email.com',
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  prefix: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 18),
                ),
                const SizedBox(height: 10),
                if (errorMsg != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(errorMsg!,
                        style: const TextStyle(fontSize: 12, color: AppColors.red))),
                  ])),
                const SizedBox(height: 20),
                ParkButton(
                  label: 'Envoyer le lien', icon: Icons.send_outlined,
                  loading: loading,
                  onTap: () async {
                    final email = ctrl.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      setSheet(() => errorMsg = 'Entrez une adresse email valide');
                      return;
                    }
                    setSheet(() { loading = true; errorMsg = null; });
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      setSheet(() { loading = false; sent = true; });
                    } on FirebaseAuthException catch (e) {
                      setSheet(() {
                        loading  = false;
                        errorMsg = switch (e.code) {
                          'user-not-found'         => 'Aucun compte trouvé avec cet email',
                          'invalid-email'          => 'Adresse email invalide',
                          'network-request-failed' => 'Vérifiez votre connexion internet',
                          'too-many-requests'      => 'Trop de tentatives, réessayez plus tard',
                          _                        => 'Une erreur est survenue, réessayez',
                        };
                      });
                    } catch (_) {
                      setSheet(() { loading = false; errorMsg = 'Une erreur est survenue'; });
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(key: _form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            const Center(child: ParkLogo(size: 60))
                .animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
            const SizedBox(height: 48),
            const Text('Connexion', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5))
                .animate().fadeIn(delay: 150.ms).slideX(begin: -0.1),
            const SizedBox(height: 20),

            if (_resetSuccess != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withOpacity(0.35))),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: AppColors.green, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_resetSuccess!,
                    style: const TextStyle(fontSize: 12, color: AppColors.green))),
                GestureDetector(
                  onTap: () => setState(() => _resetSuccess = null),
                  child: const Icon(Icons.close, color: AppColors.green, size: 16)),
              ])),

            ParkField(
              label: 'Email', hint: 'votre@email.com',
              controller: _email, keyboardType: TextInputType.emailAddress,
              prefix: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 20),
              validator: (v) => v!.contains('@') ? null : 'Email invalide',
            ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.1),
            const SizedBox(height: 16),

            ParkField(
              label: 'Mot de passe', hint: '••••••••',
              controller: _pw, obscure: _hide,
              prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
              suffix: GestureDetector(
                onTap: () => setState(() => _hide = !_hide),
                child: Icon(_hide ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted, size: 20)),
              validator: (v) => v!.length >= 6 ? null : 'Min. 6 caractères',
            ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
            const SizedBox(height: 10),

            Align(alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _forgotSheet,
                child: const Text('Mot de passe oublié ?',
                    style: TextStyle(fontSize: 12, color: AppColors.cyan, fontWeight: FontWeight.w600)))),
            const SizedBox(height: 24),

            if (_err != null) ...[
              ErrorBox(message: _err!).animate().shake(),
              const SizedBox(height: 16),
            ],

            ParkButton(label: 'Se connecter', icon: Icons.login, loading: _loading, onTap: _login)
                .animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),
            const SizedBox(height: 18),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Pas de compte ? ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              GestureDetector(
                onTap: () => context.push('/register'),
                child: const Text('Créer un compte', style: TextStyle(
                    color: AppColors.cyan, fontWeight: FontWeight.w700, fontSize: 13))),
            ]).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border.fromBorderSide(BorderSide(color: AppColors.border))),
              child: const Row(children: [
                Icon(Icons.security, color: AppColors.green, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Connexion sécurisée par Firebase Authentication',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
              ]),
            ).animate().fadeIn(delay: 450.ms),
          ],
        )),
      )),
    );
  }
}