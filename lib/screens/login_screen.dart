import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/rig_feedback.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runSignIn(Future<void> Function() signIn) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await signIn();
      // Navigation is handled by auth state listener in main.dart
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await _runSignIn(
      () => ref
          .read(authServiceProvider)
          .signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          ),
    );
  }

  Future<void> _handleGoogleSignIn() =>
      _runSignIn(() => ref.read(authServiceProvider).signInWithGoogle());

  void _showPasswordReset() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PasswordResetSheet(
        initialEmail: _emailController.text.trim(),
        onSend: ref.read(authServiceProvider).sendPasswordResetEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue building your PC.',
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: Space.lg),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: Space.md),
              PasswordField(
                controller: _passwordController,
                label: 'Password',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your password'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showPasswordReset,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: Space.sm),
              FilledButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: LoadingLabel(loading: _isLoading, label: 'Sign In'),
              ),
              const SizedBox(height: Space.xl),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Text('or', style: context.text.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: Space.xl),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: Image.network(
                  'https://www.google.com/favicon.ico',
                  height: 20,
                  width: 20,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.g_mobiledata, color: c.textPrimary, size: 24),
                ),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: Space.xl),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: context.text.bodyMedium!.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    ),
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordResetSheet extends StatefulWidget {
  final String initialEmail;
  final Future<void> Function(String email) onSend;

  const _PasswordResetSheet({required this.initialEmail, required this.onSend});

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(_controller.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.xxl,
        0,
        Space.xxl,
        Space.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reset your password', style: context.text.titleLarge),
            const SizedBox(height: Space.sm),
            Text(
              "We'll email you a link to choose a new one.",
              style: context.text.bodyMedium!.copyWith(
                color: context.rig.textSecondary,
              ),
            ),
            const SizedBox(height: Space.lg),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: Space.md),
            ],
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: LoadingLabel(loading: _sending, label: 'Send reset link'),
            ),
          ],
        ),
      ),
    );
  }
}
