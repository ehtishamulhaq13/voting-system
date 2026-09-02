import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';
import '../voting_http.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';

class WinnerScreen extends StatefulWidget {
  const WinnerScreen({super.key});

  @override
  State<WinnerScreen> createState() => _WinnerScreenState();
}

class _WinnerScreenState extends State<WinnerScreen> {
  Map<String, dynamic>? winner;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchWinner();
  }

  Future<void> fetchWinner() async {
    setState(() => loading = true);
    try {
      final res = await VotingHttp.get('/api/results');
      final data = jsonDecode(res.body);
      if (!mounted) return;

      if (data is List && data.isNotEmpty) {
        final list = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        list.sort(
          (a, b) => ((b['votes'] as num?) ?? 0).compareTo((a['votes'] as num?) ?? 0),
        );
        setState(() {
          winner = list.first;
          loading = false;
        });
      } else {
        setState(() {
          winner = null;
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        winner = null;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(
            child: SizedBox.expand(),
          ),
          if (!loading && winner != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Lottie.asset(
                  'assets/lottie/confetti.json',
                  repeat: false,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary),
                      ),
                      Expanded(
                        child: Text(
                          'Champion',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: fetchWinner,
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentSecondary,
                          ),
                        )
                      : winner == null
                          ? Center(
                              child: Text(
                                'No winner yet',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 32,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 56,
                                        color: AppColors.warning,
                                      )
                                          .animate(
                                            onPlay: (c) => c.repeat(reverse: true),
                                          )
                                          .shimmer(
                                            duration: 2000.ms,
                                            color: Colors.white
                                                .withValues(alpha: 0.35),
                                          ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'WINNER',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          letterSpacing: 4,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        winner!['name']?.toString() ?? '',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        winner!['position']?.toString() ?? '',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(30),
                                          gradient: AppColors.heroGradient,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.accentPrimary
                                                  .withValues(alpha: 0.45),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.how_to_vote_rounded,
                                                color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Votes: ${winner!['votes'] ?? 0}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
