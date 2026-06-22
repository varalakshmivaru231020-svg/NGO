import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/auth/role_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static const _adminEmail    = 'admin@saksham.org';
  static const _adminPassword = 'Admin@1234';

  static const _bg      = Color(0xFF0B6E5D);
  static const _brand   = Color(0xFF0E8C76);
  static const _text1   = Color(0xFF1A2A24);
  static const _text2   = Color(0xFF5A7068);
  static const _border  = Color(0xFFD8E5E0);
  static const _errBg   = Color(0xFFFEECEB);
  static const _errText = Color(0xFFC0392B);
  static const _errIcon = Color(0xFFF2685E);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: _bg,
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  // ── Wide / desktop: two-column ────────────────────────────────────────
  Widget _wideLayout() => Row(children: [
    // Left brand panel
    Expanded(
      flex: 4,
      child: Container(
        color: _bg,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _logoBox(96),
            const SizedBox(height: 20),
            const Text('Saksham Foundation',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text('NGO Management System',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 15)),
          ]),
        ),
      ),
    ),
    // Right form panel
    Expanded(
      flex: 5,
      child: Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _form(),
            ),
          ),
        ),
      ),
    ),
  ]);

  // ── Narrow / mobile: stacked ──────────────────────────────────────────
  Widget _narrowLayout() => SafeArea(
    child: Column(children: [
      const SizedBox(height: 44),
      _logoBox(76),
      const SizedBox(height: 14),
      const Text('Saksham Foundation',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('NGO Management System',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
      const SizedBox(height: 32),
      Expanded(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: _form(),
          ),
        ),
      ),
    ]),
  );

  Widget _logoBox(double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(size * 0.27),
    ),
    child: Icon(Icons.volunteer_activism, size: size * 0.52, color: Colors.white),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
    // brand strip — horizontal logo + name + tagline
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.volunteer_activism, size: 24, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Saksham Foundation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text1, letterSpacing: -0.3)),
        const Text('NGO Management System',
            style: TextStyle(fontSize: 12, color: _text2, fontWeight: FontWeight.w500)),
      ]),
    ]),
    const SizedBox(height: 28),

    const Text('Welcome Back',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _text1, letterSpacing: -0.3)),
    const SizedBox(height: 6),
    const Text('Sign in to your account',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, color: _text2)),
    const SizedBox(height: 28),

    if (_error != null) ...[
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: _errBg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.error_outline, color: _errIcon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: _errText, fontSize: 13))),
        ]),
      ),
      const SizedBox(height: 18),
    ],

    // Email / role name
    _inputField(
      controller: _nameCtrl,
      label: 'Email or Role Name',
      hint: 'Enter email or role name',
      prefix: Icons.person_outline_rounded,
      action: TextInputAction.next,
    ),
    const SizedBox(height: 14),

    // Password
    TextField(
      controller: _passCtrl,
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _login(),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _text1),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        labelStyle: const TextStyle(color: _text2, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: _text2.withValues(alpha: 0.5), fontSize: 13.5),
        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: _text2),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: _text2),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: const Color(0xFFF7FAF9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brand, width: 1.8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
    const SizedBox(height: 28),

    SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
      ),
    ),
  ]);

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefix,
    TextInputAction action = TextInputAction.next,
  }) => TextField(
    controller: controller,
    textInputAction: action,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _text1),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _text2, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: _text2.withValues(alpha: 0.5), fontSize: 13.5),
      prefixIcon: Icon(prefix, size: 20, color: _text2),
      filled: true,
      fillColor: const Color(0xFFF7FAF9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brand, width: 1.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );

  Future<void> _login() async {
    final name     = _nameCtrl.text.trim();
    final password = _passCtrl.text;
    if (name.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your name/email and password');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // 1. Admin credentials
    if (name == _adminEmail && password == _adminPassword) {
      currentLoggedInRole = null;
      if (mounted) context.go('/dashboard');
      return;
    }

    // 2. Role credentials (case-insensitive name)
    final role = appRoles.where(
      (r) => r.name.toLowerCase() == name.toLowerCase() && r.password == password,
    ).firstOrNull;

    if (role != null) {
      currentLoggedInRole = role;
      final firstRoute = role.modules.isNotEmpty
          ? (moduleToRoute[role.modules.first] ?? '/dashboard')
          : '/dashboard';
      if (mounted) context.go(firstRoute);
      return;
    }

    // 3. API login
    try {
      final response = await apiClient.post('/auth/login', {'email': name, 'password': password});
      final data = response['data'] as Map<String, dynamic>;
      await apiClient.saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
      currentLoggedInRole = null;
      if (mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Invalid credentials. Please try again.';
      });
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }
}
