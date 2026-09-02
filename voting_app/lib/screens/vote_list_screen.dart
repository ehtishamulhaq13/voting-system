import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../voting_http.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';

class VoteListScreen extends StatefulWidget {
  const VoteListScreen({super.key});

  @override
  State<VoteListScreen> createState() => _VoteListScreenState();
}

class _VoteListScreenState extends State<VoteListScreen> {
  List<dynamic> votes = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchVotes();
  }

  Future<void> fetchVotes() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await VotingHttp.get('/api/votes');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        setState(() {
          votes = decoded is List ? decoded : <dynamic>[];
          loading = false;
        });
      } else {
        setState(() {
          votes = [];
          loading = false;
          error = 'Failed (${res.statusCode})';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        votes = [];
        loading = false;
        error = 'Network error';
      });
    }
  }

  String _voterName(Map<String, dynamic> v) {
    final u = v['user'];
    if (u is Map<String, dynamic>) {
      return u['name']?.toString() ?? 'Unknown voter';
    }
    return 'Unknown voter';
  }

  String _candidateName(Map<String, dynamic> v) {
    final c = v['candidate'];
    if (c is Map<String, dynamic>) {
      return c['name']?.toString() ?? 'Unknown candidate';
    }
    return 'Unknown candidate';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        'Vote history',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: fetchVotes,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accentSecondary,
                  backgroundColor: AppColors.bgSecondary,
                  onRefresh: fetchVotes,
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentSecondary,
                          ),
                        )
                      : error != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    error!,
                                    style: GoogleFonts.poppins(
                                        color: AppColors.warning),
                                  ),
                                ),
                              ],
                            )
                          : votes.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 120),
                                    Center(
                                      child: Text(
                                        'No votes recorded',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : AnimationLimiter(
                                  child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 24),
                                    itemCount: votes.length,
                                    itemBuilder: (context, i) {
                                      final v = Map<String, dynamic>.from(
                                        votes[i] as Map,
                                      );
                                      return AnimationConfiguration
                                          .staggeredList(
                                        position: i,
                                        duration:
                                            const Duration(milliseconds: 420),
                                        child: SlideAnimation(
                                          verticalOffset: 36,
                                          child: FadeInAnimation(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12),
                                              child: GlassCard(
                                                padding: const EdgeInsets.all(
                                                    14),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 26,
                                                      backgroundColor: AppColors
                                                          .accentPrimary
                                                          .withValues(
                                                              alpha: 0.25),
                                                      child: Text(
                                                        () {
                                                          final n = _voterName(v);
                                                          if (n.isEmpty) {
                                                            return '?';
                                                          }
                                                          return n
                                                              .substring(0, 1)
                                                              .toUpperCase();
                                                        }(),
                                                        style: GoogleFonts
                                                            .poppins(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            _voterName(v),
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: AppColors
                                                                  .textPrimary,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            'Voted for ${_candidateName(v)}',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 12,
                                                              color: AppColors
                                                                  .textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons
                                                          .arrow_forward_ios_rounded,
                                                      size: 14,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
