import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import 'admin_screen.dart';
import 'candidate_screen.dart';
import '../api.dart';
import '../auth_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool isLogin = true;
  bool obscurePassword = true;
  bool isSubmitting = false;
  int registerStep = 0;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (isSubmitting) return;

    final emailOk = email.text.trim().isNotEmpty;
    final passOk = password.text.trim().isNotEmpty;
    final nameOk = isLogin || name.text.trim().isNotEmpty;

    if (!emailOk || !passOk || !nameOk) {
      showVotingSnack(context, 'Please fill in all required fields.', error: true);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final body = <String, String>{
        'email': email.text.trim(),
        'password': password.text,
      };
      if (!isLogin) body['name'] = name.text.trim();

      final uri = isLogin ? Api.uri('/api/login') : Api.uri('/api/register');
      final res = await http.post(uri, body: body);

      if (!mounted) return;

      final dynamic raw = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      final Map<String, dynamic> data =
          raw is Map<String, dynamic> ? raw : <String, dynamic>{};

      final ok = res.statusCode == 200 || res.statusCode == 201;

      if (ok) {
        final user = data['user'];
        final Map<String, dynamic> userMap = user is Map<String, dynamic>
            ? user
            : <String, dynamic>{};

        final token = data['token']?.toString();
        await AuthSession.saveSession(token: token, user: userMap);

        final role = (userMap['role'] ?? 'user').toString().toLowerCase();

        if (!mounted) return;

        if (role == 'admin') {
          await Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => AdminScreen(user: userMap),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        } else {
          await Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => CandidateScreen(user: userMap),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        }
      } else {
        final msg = data['message']?.toString() ?? 'Something went wrong.';
        showVotingSnack(context, msg, error: true);
      }
    } catch (e) {
      if (mounted) {
        showVotingSnack(context, 'Network error. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final cardWidth = size.width.clamp(320.0, 440.0);
    final cardHeight = (size.height * 0.78 - inset * 0.35).clamp(380.0, 720.0);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: FadeInUp(
                duration: const Duration(milliseconds: 700),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Hero(
                      tag: 'app_logo',
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.heroGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentPrimary.withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.how_to_vote_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .shimmer(
                          delay: 800.ms,
                          duration: 2400.ms,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                    const SizedBox(height: 20),
                    Text(
                      'NovaVote',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isLogin ? 'Secure sign in' : 'Create your account',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlassmorphicContainer(
                      width: cardWidth,
                      height: cardHeight,
                      borderRadius: 28,
                      blur: 22,
                      alignment: Alignment.topCenter,
                      border: 1.6,
                      linearGradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      borderGradient: LinearGradient(
                        colors: [
                          AppColors.accentSecondary.withValues(alpha: 0.55),
                          AppColors.accentPrimary.withValues(alpha: 0.45),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isLogin ? 'Welcome back' : 'Join the election',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: AppColors.heroGradient,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      isLogin ? 'LOGIN' : 'REGISTER',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (!isLogin) ...[
                              Row(
                                children: [
                                  _stepDot(0),
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      color: registerStep >= 1
                                          ? AppColors.accentPrimary
                                          : AppColors.textSecondary.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  _stepDot(1),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],
                            Expanded(
                              child: !isLogin
                                  ? IndexedStack(
                                      index: registerStep,
                                      children: [
                                        _buildNameEmailStep(),
                                        _buildPasswordStep(),
                                      ],
                                    )
                                  : _buildLoginFields(),
                            ),
                            const SizedBox(height: 8),
                            _gradientButton(
                              label: isLogin
                                  ? 'Sign in'
                                  : (registerStep == 0 ? 'Continue' : 'Create account'),
                              loading: isSubmitting,
                              onTap: () async {
                                if (!isLogin && registerStep == 0) {
                                  if (name.text.trim().isEmpty ||
                                      email.text.trim().isEmpty) {
                                    showVotingSnack(
                                      context,
                                      'Enter name and email to continue.',
                                      error: true,
                                    );
                                    return;
                                  }
                                  setState(() => registerStep = 1);
                                  return;
                                }
                                await submit();
                              },
                            ),
                            if (!isLogin && registerStep == 1)
                              TextButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => setState(() {
                                          registerStep = 0;
                                        }),
                                child: Text(
                                  'Back',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.accentSecondary,
                                  ),
                                ),
                              ),
                            TextButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        isLogin = !isLogin;
                                        registerStep = 0;
                                        obscurePassword = true;
                                      });
                                    },
                              child: Text(
                                isLogin
                                    ? "Don't have an account? Register"
                                    : 'Already have an account? Sign in',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepDot(int step) {
    final active = registerStep >= step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 26 : 10,
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: active ? AppColors.heroGradient : null,
        color: active ? null : AppColors.textSecondary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildLoginFields() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: password,
            obscureText: obscurePassword,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => obscurePassword = !obscurePassword),
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameEmailStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          TextField(
            controller: password,
            obscureText: obscurePassword,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => obscurePassword = !obscurePassword),
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppColors.heroGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
