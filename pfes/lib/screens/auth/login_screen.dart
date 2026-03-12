import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _State();
}

class _State extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw    = TextEditingController();
  bool _hide = true, _loading = false;
  String? _err;

  @override void dispose() { _email.dispose(); _pw.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _err = null; });
    try {
      final user = await ref.read(authServiceProvider).login(_email.text, _pw.text);
      if (!mounted) return;
      context.go(user.role == UserRole.responsable ? '/resp/dashboard' : '/client/home');
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(key: _form, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Center(child: ParkLogo(size: 60))
                  .animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
              const SizedBox(height: 48),

              // ── Title
              const Text('Connexion', style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5))
                  .animate().fadeIn(delay: 150.ms).slideX(begin: -0.1),

              const SizedBox(height: 28),

              // ── Email
              ParkField(
                label: 'Email', hint: 'votre@email.com',
                controller: _email, keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 20),
                validator: (v) => v!.contains('@') ? null : 'Email invalide',
              ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),

              // ── Password
              ParkField(
                label: 'Mot de passe', hint: '••••••••',
                controller: _pw, obscure: _hide,
                prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                suffix: GestureDetector(
                  onTap: () => setState(() => _hide = !_hide),
                  child: Icon(_hide ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted, size: 20),
                ),
                validator: (v) => v!.length >= 6 ? null : 'Min. 6 caractères',
              ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
              const SizedBox(height: 10),

              // ── Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _forgotSheet,
                  child: const Text('Mot de passe oublié ?',
                      style: TextStyle(fontSize: 12, color: AppColors.cyan, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),

              // ── Error
              if (_err != null) ...[
                ErrorBox(message: _err!).animate().shake(),
                const SizedBox(height: 16),
              ],

              // ── Login button
              ParkButton(label: 'Se connecter', icon: Icons.login,
                  loading: _loading, onTap: _login)
                  .animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),
              const SizedBox(height: 18),

              // ── Register link
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Pas de compte ? ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                GestureDetector(
                  onTap: () => context.push('/register'),
                  child: const Text('Créer un compte', style: TextStyle(
                      color: AppColors.cyan, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 40),

              // ── Security note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card, borderRadius: BorderRadius.circular(12),
                  border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
                ),
                child: const Row(children: [
                  Icon(Icons.security, color: AppColors.green, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Connexion sécurisée par Firebase Authentication',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
                ]),
              ).animate().fadeIn(delay: 450.ms),
            ],
          )),
        ),
      ),
    );
  }

  void _forgotSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Text('Réinitialiser le mot de passe',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Un lien de réinitialisation sera envoyé à votre email.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          ParkField(label: 'Email', hint: 'votre@email.com',
              controller: ctrl, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 20),
          ParkButton(
            label: 'Envoyer le lien', icon: Icons.send,
            onTap: () async {
              try {
                await ref.read(authServiceProvider).resetPassword(ctrl.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Email envoyé !')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
              }
            },
          ),
        ]),
      ),
    );
  }
}