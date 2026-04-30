// ══════════════════════════════════════════════════════
//  CHANGE PASSWORD SCREEN
//  زيديه في client_screens.dart أو ملف مستقل
//  وزيدي زر فيه في صفحة Profil
// ══════════════════════════════════════════════════════
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<ChangePasswordScreen> {
  final _oldPw  = TextEditingController();
  final _newPw  = TextEditingController();
  final _confPw = TextEditingController();
  bool _hideOld = true, _hideNew = true, _hideConf = true;
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _oldPw.dispose(); _newPw.dispose(); _confPw.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() { _error = null; });

    if (_oldPw.text.isEmpty || _newPw.text.isEmpty || _confPw.text.isEmpty) {
      setState(() => _error = 'Remplissez tous les champs');
      return;
    }
    if (_newPw.text.length < 6) {
      setState(() => _error = 'Le nouveau mot de passe doit contenir au moins 6 caractères');
      return;
    }
    if (_newPw.text != _confPw.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception('Utilisateur non connecté');

      // Re-authentifier avec l'ancien mot de passe
      final cred = EmailAuthProvider.credential(
        email: user.email!, password: _oldPw.text);
      await user.reauthenticateWithCredential(cred);

      // Changer le mot de passe
      await user.updatePassword(_newPw.text);

      if (!mounted) return;
      setState(() { _success = true; _loading = false; });

    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = switch (e.code) {
          'wrong-password'         => '❌ Mot de passe actuel incorrect',
          'weak-password'          => 'Mot de passe trop faible (min. 6 caractères)',
          'requires-recent-login'  => 'Session expirée, reconnectez-vous',
          'network-request-failed' => 'Vérifiez votre connexion internet',
          _ => 'Une erreur est survenue: ${e.message}',
        };
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changer le mot de passe'),
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new, size: 18)),
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _success ? _SuccessView(onBack: () => context.pop()) : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Container(
              width: 72, height: 72,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.blue2.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.blue2.withOpacity(0.3))),
              child: const Icon(Icons.lock_reset, color: AppColors.blue2, size: 34)),

            const Text('Modifier votre mot de passe',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Entrez votre mot de passe actuel puis le nouveau.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 28),

            // Ancien mot de passe
            ParkField(
              label: 'Mot de passe actuel',
              hint: '••••••••',
              controller: _oldPw,
              obscure: _hideOld,
              prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
              suffix: GestureDetector(
                onTap: () => setState(() => _hideOld = !_hideOld),
                child: Icon(_hideOld ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted, size: 18)),
            ),
            const SizedBox(height: 16),

            // Nouveau mot de passe
            ParkField(
              label: 'Nouveau mot de passe',
              hint: '••••••••',
              controller: _newPw,
              obscure: _hideNew,
              prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
              suffix: GestureDetector(
                onTap: () => setState(() => _hideNew = !_hideNew),
                child: Icon(_hideNew ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted, size: 18)),
            ),
            const SizedBox(height: 16),

            // Confirmer mot de passe
            ParkField(
              label: 'Confirmer le nouveau mot de passe',
              hint: '••••••••',
              controller: _confPw,
              obscure: _hideConf,
              prefix: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
              suffix: GestureDetector(
                onTap: () => setState(() => _hideConf = !_hideConf),
                child: Icon(_hideConf ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted, size: 18)),
            ),
            const SizedBox(height: 20),

            // Error
            if (_error != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(fontSize: 12, color: AppColors.red))),
              ])),

            // Bouton
            ParkButton(
              label: 'Changer le mot de passe',
              icon: Icons.check_circle_outline,
              loading: _loading,
              onTap: _changePassword,
              colors: const [AppColors.blue, AppColors.cyan],
            ),
          ],
        ),
      )),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onBack;
  const _SuccessView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80, height: 80,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.green.withOpacity(0.35))),
          child: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 40)),
        const Text('Mot de passe modifié !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Votre mot de passe a été mis à jour avec succès.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        ParkButton(
          label: 'Retour au profil',
          icon: Icons.person_outline,
          onTap: onBack,
          colors: const [AppColors.blue, AppColors.cyan],
        ),
      ],
    );
  }
}