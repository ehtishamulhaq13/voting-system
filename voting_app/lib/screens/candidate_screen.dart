import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../voting_http.dart';
import '../widgets/candidate_symbol_avatar.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import 'admin_screen.dart';
import 'result_screen.dart';
import 'vote_list_screen.dart';
import 'winner_screen.dart';

class CandidateScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CandidateScreen({super.key, required this.user});

  @override
  State<CandidateScreen> createState() => _CandidateScreenState();
}

class _CandidateScreenState extends State<CandidateScreen> {
  List<dynamic> candidates = [];

  DateTime? startTimeUtc;
  DateTime? endTimeUtc;
  DateTime nowTimeUtc = DateTime.now().toUtc();
  Timer? clockTimer;
  Timer? refreshTimer;
  bool isLoadingCandidates = true;
  String? loadError;
  int navIndex = 0;

  bool get isAdmin {
    final role = widget.user['role']?.toString().toLowerCase();
    return role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    refreshData();
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        nowTimeUtc = DateTime.now().toUtc();
      });
    });
    refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      refreshData(showLoader: false);
    });
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshData({bool showLoader = true}) async {
    await Future.wait([
      fetchCandidates(showLoader: showLoader),
      fetchTime(),
    ]);
  }

  Future<void> fetchCandidates({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        isLoadingCandidates = true;
        loadError = null;
      });
    }

    try {
      final res = await VotingHttp.get('/api/candidates');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        setState(() {
          candidates = decoded is List ? decoded : <dynamic>[];
          isLoadingCandidates = false;
          loadError = null;
        });
      } else {
        setState(() {
          candidates = [];
          isLoadingCandidates = false;
          loadError = 'Could not load candidates (${res.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        candidates = [];
        isLoadingCandidates = false;
        loadError = 'Network error loading candidates';
      });
    }
  }

  Future<void> fetchTime() async {
    try {
      final res = await VotingHttp.get('/api/get-voting-time');
      final data = jsonDecode(res.body);

      if (!mounted) return;

      setState(() {
        startTimeUtc = data['start_time'] != null
            ? DateTime.parse(data['start_time'] as String).toUtc()
            : null;
        endTimeUtc = data['end_time'] != null
            ? DateTime.parse(data['end_time'] as String).toUtc()
            : null;
      });
    } catch (e) {
      debugPrint('Time fetch error: $e');
    }
  }

  String formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    int hour = local.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String get votingStatus {
    if (startTimeUtc == null || endTimeUtc == null) {
      return 'Timer not configured';
    }
    if (nowTimeUtc.isBefore(startTimeUtc!)) {
      return 'Not started';
    }
    if (nowTimeUtc.isAfter(endTimeUtc!)) {
      return 'Voting ended';
    }
    return 'Live now';
  }

  bool get canVoteNow {
    if (startTimeUtc == null || endTimeUtc == null) return false;
    return !nowTimeUtc.isBefore(startTimeUtc!) &&
        !nowTimeUtc.isAfter(endTimeUtc!);
  }

  String get remainingLabel {
    if (startTimeUtc == null || endTimeUtc == null) {
      return 'The election timer has not been set yet.';
    }
    if (nowTimeUtc.isBefore(startTimeUtc!)) {
      return 'Starts in ${formatDuration(startTimeUtc!.difference(nowTimeUtc))}';
    }
    if (nowTimeUtc.isAfter(endTimeUtc!)) {
      return 'Election window is closed.';
    }
    return 'Time left: ${formatDuration(endTimeUtc!.difference(nowTimeUtc))}';
  }

  /// 0–1 progress for circular indicator (live = remaining fraction).
  double get timerRingPercent {
    if (startTimeUtc == null || endTimeUtc == null) return 0;
    final total = endTimeUtc!.difference(startTimeUtc!).inSeconds;
    if (total <= 0) return 0;
    if (nowTimeUtc.isBefore(startTimeUtc!)) return 0;
    if (nowTimeUtc.isAfter(endTimeUtc!)) return 1;
    final left = endTimeUtc!.difference(nowTimeUtc).inSeconds;
    return (left / total).clamp(0.0, 1.0);
  }

  Color get timerRingColor {
    if (canVoteNow) return AppColors.success;
    if (startTimeUtc != null && nowTimeUtc.isBefore(startTimeUtc!)) {
      return AppColors.warning;
    }
    return AppColors.textSecondary;
  }

  String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return '0s';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  Future<void> vote(dynamic id) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    try {
      final res = await VotingHttp.post(
        '/api/vote',
        body: {
          'user_id': widget.user['id'].toString(),
          'candidate_id': id.toString(),
        },
      );

      final data = jsonDecode(res.body);

      if (!mounted) return;

      showVotingSnack(
        context,
        data['message']?.toString() ?? 'Done',
        error: res.statusCode != 200,
      );

      refreshData(showLoader: false);
    } catch (_) {
      if (mounted) {
        showVotingSnack(context, 'Could not submit vote.', error: true);
      }
    }
  }

  Future<void> _openSecondary(Widget screen) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
    if (mounted) setState(() => navIndex = 0);
  }

  int _crossAxisCount(double width) {
    if (width >= 1100) return 5;
    if (width >= 820) return 4;
    if (width >= 560) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name']?.toString() ?? 'Voter';

    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.accentSecondary,
            backgroundColor: AppColors.bgSecondary,
            onRefresh: refreshData,
            child: AnimationLimiter(
              child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(name)),
              SliverToBoxAdapter(child: _buildTimerCard()),
              if (loadError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_outlined,
                              color: AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              loadError!,
                              style: GoogleFonts.poppins(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => refreshData(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (isLoadingCandidates)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _crossAxisCount(
                        MediaQuery.sizeOf(context).width,
                      ),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Shimmer.fromColors(
                        baseColor: AppColors.bgSecondary,
                        highlightColor:
                            AppColors.bgSecondary.withValues(alpha: 0.5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      childCount: 6,
                    ),
                  ),
                )
              else if (candidates.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No candidates yet',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _crossAxisCount(
                        MediaQuery.sizeOf(context).width,
                      ),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final c = candidates[i] as Map<String, dynamic>;
                        final id = c['id'];
                        final sym = c['symbol']?.toString();

                        return AnimationConfiguration.staggeredGrid(
                          position: i,
                          duration: const Duration(milliseconds: 450),
                          columnCount: _crossAxisCount(
                            MediaQuery.sizeOf(context).width,
                          ),
                          child: ScaleAnimation(
                            child: FadeInAnimation(
                              child: _CandidateVoteCard(
                                name: c['name']?.toString() ?? '',
                                position: c['position']?.toString() ?? '',
                                symbol: sym,
                                heroTag: 'candidate_$id',
                                canVote: canVoteNow,
                                onVote: () => vote(id),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: candidates.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentSecondary.withValues(alpha: 0.55),
              blurRadius: 22,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => refreshData(),
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.refresh_rounded),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: AppColors.bgSecondary.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.accentPrimary.withValues(alpha: 0.22),
        elevation: 12,
        indicatorColor: AppColors.accentPrimary.withValues(alpha: 0.35),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: navIndex,
        onDestinationSelected: (i) async {
          setState(() => navIndex = i);
          HapticFeedback.selectionClick();
          switch (i) {
            case 0:
              break;
            case 1:
              await _openSecondary(ResultScreen());
              break;
            case 2:
              await _openSecondary(VoteListScreen());
              break;
            case 3:
              await _openSecondary(WinnerScreen());
              break;
            case 4:
              if (!mounted) return;
              await showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _MoreSheet(
                  isAdmin: isAdmin,
                  onAdmin: () async {
                    Navigator.pop(ctx);
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminScreen(user: widget.user),
                      ),
                    );
                    refreshData(showLoader: false);
                  },
                ),
              );
              if (mounted) setState(() => navIndex = 0);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Vote',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Results',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: Icon(Icons.format_list_bulleted_rounded),
            label: 'Votes',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Winner',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Hero(
            tag: 'app_logo',
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.heroGradient,
              ),
              child: const Icon(Icons.how_to_vote_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Cast your ballot securely',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.04, end: 0);
  }

  Widget _buildTimerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 52,
              lineWidth: 9,
              percent: timerRingPercent,
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: timerRingColor,
              backgroundColor: AppColors.bgPrimary.withValues(alpha: 0.6),
              center: Text(
                votingStatus.split(' ').first,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: AppColors.heroGradient,
                    ),
                    child: Text(
                      votingStatus.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    remainingLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (startTimeUtc != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Opens ${formatDateTime(startTimeUtc!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  if (endTimeUtc != null) ...[
                    Text(
                      'Closes ${formatDateTime(endTimeUtc!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 120.ms, duration: 500.ms);
  }
}

class _CandidateVoteCard extends StatefulWidget {
  const _CandidateVoteCard({
    required this.name,
    required this.position,
    required this.symbol,
    required this.heroTag,
    required this.canVote,
    required this.onVote,
  });

  final String name;
  final String position;
  final String? symbol;
  final Object heroTag;
  final bool canVote;
  final VoidCallback onVote;

  @override
  State<_CandidateVoteCard> createState() => _CandidateVoteCardState();
}

class _CandidateVoteCardState extends State<_CandidateVoteCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CandidateSymbolAvatar(
                heroTag: widget.heroTag,
                symbol: widget.symbol,
                radius: 34,
              ),
              const SizedBox(height: 10),
              Text(
                widget.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.position,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.canVote ? widget.onVote : null,
                  borderRadius: BorderRadius.circular(14),
                  splashColor: AppColors.accentSecondary.withValues(alpha: 0.35),
                  highlightColor:
                      AppColors.accentPrimary.withValues(alpha: 0.2),
                  child: Ink(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: widget.canVote ? AppColors.heroGradient : null,
                      color: widget.canVote
                          ? null
                          : AppColors.textSecondary.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Text(
                        'Vote',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: widget.canVote
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
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

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.isAdmin, required this.onAdmin});

  final bool isAdmin;
  final VoidCallback onAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined,
                    color: AppColors.accentSecondary),
                title: Text(
                  'Admin dashboard',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Manage candidates & election timer',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: onAdmin,
              ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: Text(
                'Close',
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
