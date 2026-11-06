import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Email sign-in / sign-up with labelled demo social buttons.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? v) {
    if ((v ?? '').isEmpty) return 'Enter your password.';
    if (_register) {
      final weak = PasswordStrength.check(v!);
      if (weak != null) return weak;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final state = AppStateScope.read(context);
    try {
      if (_register) {
        await state.register(name: _name.text.trim(), email: _email.text.trim(), password: _password.text);
      } else {
        await state.login(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      showToast(context, _register ? 'Welcome to Shelf!' : 'Welcome back!');
      Navigator.of(context).maybePop(true);
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _social(String provider) async {
    setState(() => _busy = true);
    final state = AppStateScope.read(context);
    try {
      await state.socialLogin(provider);
      if (!mounted) return;
      showToast(context, 'Signed in with $provider (demo).');
      Navigator.of(context).maybePop(true);
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Demo sign-in failed. Try email instead.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: _register ? 'Create account' : 'Welcome back',
      kicker: 'Shelf',
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(_register ? 'Join the shop and start your reading list.' : 'Sign in to your cart, orders and reading list.', style: FolioText.italic(context)),
            const SizedBox(height: 24),
            if (_register) ...[
              FolioField(controller: _name, label: 'Full name', hint: 'Your name', prefixIcon: Icons.person_outline, validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name.' : null),
              const SizedBox(height: 18),
            ],
            FolioField(controller: _email, label: 'Email', hint: 'you@example.com', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline, autofillHints: const [AutofillHints.email], validator: _emailValidator),
            const SizedBox(height: 18),
            FolioField(
              controller: _password,
              label: 'Password',
              hint: _register ? 'At least 8 characters, a letter and a number' : 'Your password',
              obscure: _obscure,
              prefixIcon: Icons.lock_outline,
              autofillHints: _register ? const [AutofillHints.newPassword] : const [AutofillHints.password],
              validator: _passwordValidator,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: f.muted, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            if (!_register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => pushPage(context, const ForgotPasswordPage()),
                  child: Text('Forgot password?', style: TextStyle(color: f.accent)),
                ),
              ),
            const SizedBox(height: 8),
            FolioButton(label: _busy ? 'Please wait…' : (_register ? 'Create account' : 'Sign in'), style: FolioButtonStyle.accent, expand: true, onPressed: _busy ? null : _submit),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _register = !_register),
                child: Text(_register ? 'Already have an account? Sign in' : 'New here? Create an account', style: TextStyle(color: f.ink)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Container(height: 1, color: f.rule)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: FolioText.label(context))),
              Expanded(child: Container(height: 1, color: f.rule)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FolioButton(label: 'Google', icon: Icons.g_mobiledata, style: FolioButtonStyle.outline, onPressed: _busy ? null : () => _social('google'))),
              const SizedBox(width: 12),
              Expanded(child: FolioButton(label: 'Facebook', icon: Icons.facebook, style: FolioButtonStyle.outline, onPressed: _busy ? null : () => _social('facebook'))),
            ]),
            const SizedBox(height: 12),
            Text('Google and Facebook sign-in are demos — no real account is contacted.', style: FolioText.caption(context), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PaperCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TRY THE DEMO', style: FolioText.label(context)),
                const SizedBox(height: 8),
                Text('Customer: demo@bookstore.com / Demo@1234', style: FolioText.bodySmall(context)),
                Text('Admin: admin@bookstore.com / Admin@123', style: FolioText.bodySmall(context)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small helper mirroring the repo strength rule for inline form validation.
class PasswordStrength {
  static String? check(String p) {
    if (p.length < 8) return 'Use at least 8 characters.';
    if (!p.contains(RegExp(r'[A-Za-z]'))) return 'Include at least one letter.';
    if (!p.contains(RegExp(r'[0-9]'))) return 'Include at least one number.';
    return null;
  }
}

/// Request a one-time reset code (shown on screen — no email is sent).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _code;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final t = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      showToast(context, 'Enter a valid email address.');
      return;
    }
    setState(() => _busy = true);
    try {
      final code = await AppStateScope.read(context).repo.createResetToken(t);
      if (!mounted) return;
      setState(() => _code = code);
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return FolioPage(
      title: 'Reset password',
      kicker: 'Account',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enter your email and we’ll generate a one-time reset code. In this demo the code appears on screen instead of being emailed.', style: FolioText.body(context)),
        const SizedBox(height: 24),
        FolioField(controller: _email, label: 'Email', hint: 'you@example.com', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline),
        const SizedBox(height: 20),
        FolioButton(label: _busy ? 'Generating…' : 'Generate reset code', style: FolioButtonStyle.accent, expand: true, onPressed: _busy ? null : _request),
        if (_code != null) ...[
          const SizedBox(height: 24),
          PaperCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR RESET CODE', style: FolioText.label(context)),
              const SizedBox(height: 8),
              Text(_code!, style: FolioText.display(context).copyWith(fontSize: 32, letterSpacing: 4, color: f.accent)),
              const SizedBox(height: 8),
              Text('Valid for 30 minutes, single use.', style: FolioText.caption(context)),
              const SizedBox(height: 16),
              FolioButton(label: 'Enter code', style: FolioButtonStyle.ink, expand: true, onPressed: () => pushPage(context, ResetPasswordPage(initialCode: _code!))),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Set a new password using a reset code.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.initialCode = ''});
  final String initialCode;
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late final _code = TextEditingController(text: widget.initialCode);
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final weak = PasswordStrength.check(_password.text);
    if (weak != null) {
      showToast(context, weak);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppStateScope.read(context).repo.resetPassword(_code.text.trim(), _password.text);
      if (!mounted) return;
      showToast(context, 'Password updated. You can sign in now.');
      Navigator.of(context).maybePop(true);
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FolioPage(
      title: 'New password',
      kicker: 'Account',
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FolioField(controller: _code, label: 'Reset code', hint: '8-character code', prefixIcon: Icons.key_outlined),
        const SizedBox(height: 18),
        FolioField(controller: _password, label: 'New password', hint: 'At least 8 characters, a letter and a number', obscure: true, prefixIcon: Icons.lock_outline),
        const SizedBox(height: 24),
        FolioButton(label: _busy ? 'Updating…' : 'Update password', style: FolioButtonStyle.accent, expand: true, onPressed: _busy ? null : _reset),
      ]),
    );
  }
}
