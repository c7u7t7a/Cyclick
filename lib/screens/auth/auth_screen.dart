import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException, AuthState;
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Entry-point screen — toggles between Login and Sign Up.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _showLogin = true;
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    _animCtrl.reverse().then((_) {
      setState(() => _showLogin = !_showLogin);
      _animCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Show snackbar on error.
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      next.whenOrNull(
        error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString()),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
          ),
        ),
      );
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // ── Brand header ──────────────────────────────────────────────
              _BrandHeader(),
              const SizedBox(height: 40),
              // ── Form (animated cross-fade) ────────────────────────────────
              FadeTransition(
                opacity: _fade,
                child: _showLogin
                    ? _LoginForm(onToggle: _toggle)
                    : _SignUpForm(onToggle: _toggle),
              ),
              const SizedBox(height: 24),
              if (authState.isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Brand Header ─────────────────────────────────────────────────────────────
class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/login_logo.png',
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bike_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cyclick',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mobility & Safety in Sector 2',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.subtleText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Login Form ───────────────────────────────────────────────────────────────
class _LoginForm extends ConsumerStatefulWidget {
  final VoidCallback onToggle;
  const _LoginForm({required this.onToggle});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authStateProvider.notifier)
        .signIn(_emailCtrl.text.trim(), _passCtrl.text);
  }

  void _showForgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false;
    bool sent = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: sent
              ? const Text(
                  'Check your email for the password reset link.',
                  style: TextStyle(color: AppTheme.subtleText),
                )
              : TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
            if (!sent)
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (emailCtrl.text.trim().isEmpty) return;
                        setState(() => sending = true);
                        try {
                          await Supabase.instance.client.auth
                              .resetPasswordForEmail(emailCtrl.text.trim());
                          setState(() {
                            sent = true;
                            sending = false;
                          });
                        } catch (_) {
                          setState(() => sending = false);
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send link'),
              ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Log in to your Cyclick account',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.subtleText),
          ),
          const SizedBox(height: 28),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email',
            hint: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Enter a valid email'
                : null,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _passCtrl,
            label: 'Password',
            hint: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppTheme.subtleText,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 8),
          // ── Remember me + Forgot password ─────────────────────────────
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? true),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Text('Remember me',
                  style: TextStyle(fontSize: 13, color: AppTheme.subtleText)),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: _showForgotPassword,
                child: const Text('Forgot password?',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Log In',
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(color: AppTheme.subtleText),
              ),
              TextButton(
                onPressed: widget.onToggle,
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sign-Up Form ─────────────────────────────────────────────────────────────
class _SignUpForm extends ConsumerStatefulWidget {
  final VoidCallback onToggle;
  const _SignUpForm({required this.onToggle});

  @override
  ConsumerState<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<_SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider.notifier).signUp(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Account',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join the Cyclick community in Sector 2',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.subtleText),
          ),
          const SizedBox(height: 28),
          AppTextField(
            controller: _nameCtrl,
            label: 'Full Name',
            hint: 'Alexandru Popescu',
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email',
            hint: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Enter a valid email'
                : null,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _passCtrl,
            label: 'Password',
            hint: 'At least 6 characters',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppTheme.subtleText,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) => (v == null || v.length < 6)
                ? 'Minimum 6 characters'
                : null,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Create Account',
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(color: AppTheme.subtleText),
              ),
              TextButton(
                onPressed: widget.onToggle,
                child: const Text('Log In'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
