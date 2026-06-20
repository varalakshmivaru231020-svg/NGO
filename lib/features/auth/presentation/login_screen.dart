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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B6E5D),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 52),
          _buildLogo(),
          const SizedBox(height: 40),
          Expanded(child: _buildCard()),
        ]),
      ),
    );
  }

  Widget _buildLogo() => Column(children: [
    Container(
      width: 80, height: 80,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(22)),
      child: const Icon(Icons.volunteer_activism, size: 42, color: Colors.white),
    ),
    const SizedBox(height: 16),
    const Text('Saksham Foundation', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
    const SizedBox(height: 4),
    Text('NGO Management System', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
  ]);

  Widget _buildCard() => Container(
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
    child: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Welcome Back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A2A24))),
        const SizedBox(height: 4),
        const Text('Sign in with admin credentials or your role name & password',
            style: TextStyle(fontSize: 13, color: Color(0xFF5A7068))),
        const SizedBox(height: 28),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEECEB), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFF2685E), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Name / Email field
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Email or Role Name',
            hintText: 'admin@saksham.org  or  Donations Manager',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // Password
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 28),

        ElevatedButton(
          onPressed: _loading ? null : _login,
          child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Sign In'),
        ),
        const SizedBox(height: 16),

        // Hint box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF4F7F6), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Admin login:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF5A7068))),
            const Text('admin@saksham.org  /  Admin@1234', style: TextStyle(fontSize: 11, color: Color(0xFF5A7068))),
            const SizedBox(height: 6),
            const Text('Role logins (examples):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF5A7068))),
            const Text('Donations Manager  /  don123', style: TextStyle(fontSize: 11, color: Color(0xFF5A7068))),
            const Text('Donor Manager  /  donor123', style: TextStyle(fontSize: 11, color: Color(0xFF5A7068))),
            const Text('Children Manager  /  child123', style: TextStyle(fontSize: 11, color: Color(0xFF5A7068))),
          ]),
        ),
      ]),
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

    // 1. Check admin credentials
    if (name == _adminEmail && password == _adminPassword) {
      currentLoggedInRole = null; // admin — sees everything
      if (mounted) context.go('/dashboard');
      return;
    }

    // 2. Check role credentials (case-insensitive name match)
    final role = appRoles.where(
      (r) => r.name.toLowerCase() == name.toLowerCase() && r.password == password,
    ).firstOrNull;

    if (role != null) {
      currentLoggedInRole = role;
      // Navigate to the first module the role can access
      final firstRoute = role.modules.isNotEmpty
          ? (moduleToRoute[role.modules.first] ?? '/dashboard')
          : '/dashboard';
      if (mounted) context.go(firstRoute);
      return;
    }

    // 3. Try API login
    try {
      final response = await apiClient.post('/auth/login', {'email': name, 'password': password});
      final data = response['data'] as Map<String, dynamic>;
      await apiClient.saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
      currentLoggedInRole = null;
      if (mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Invalid credentials. Check admin login or role name & password.';
      });
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }
}
