import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../voting_http.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<dynamic> results = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchResults();
  }

  Future<void> fetchResults() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await VotingHttp.get('/api/results');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        setState(() {
          results = decoded is List ? decoded : <dynamic>[];
          loading = false;
        });
      } else {
        setState(() {
          results = [];
          loading = false;
          error = 'Failed to load (${res.statusCode})';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        results = [];
        loading = false;
        error = 'Network error';
      });
    }
  }

  int get _totalVotes {
    var t = 0;
    for (final r in results) {
      final m = r as Map<String, dynamic>;
      t += (m['votes'] as num?)?.toInt() ?? 0;
    }
    return t;
  }

  List<Map<String, dynamic>> get _sorted {
    final list = results
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.sort(
      (a, b) => ((b['votes'] as num?) ?? 0).compareTo((a['votes'] as num?) ?? 0),
    );
    return list;
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
                        'Live results',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: fetchResults,
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
                  onRefresh: fetchResults,
                  child: loading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: List.generate(
                            5,
                            (i) => Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Shimmer.fromColors(
                                baseColor: AppColors.bgSecondary,
                                highlightColor: AppColors.bgSecondary
                                    .withValues(alpha: 0.45),
                                child: Container(
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
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
                          : results.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 120),
                                    Center(
                                      child: Text(
                                        'No results yet',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 24),
                                  children: [
                                    if (_sorted.isNotEmpty)
                                      GlassCard(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Leaderboard',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Total votes: $_totalVotes',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            SizedBox(
                                              height: 200,
                                              child: PieChart(
                                                PieChartData(
                                                  sectionsSpace: 2,
                                                  centerSpaceRadius: 44,
                                                  sections: _pieSections(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(duration: 450.ms),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Vote share',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GlassCard(
                                      padding: const EdgeInsets.fromLTRB(
                                          8, 16, 8, 8),
                                      child: SizedBox(
                                        height: math.min(220.0,
                                            40.0 + _sorted.length * 36.0),
                                        child: BarChart(
                                          BarChartData(
                                            alignment: BarChartAlignment
                                                .spaceAround,
                                            maxY: _totalVotes > 0
                                                ? _totalVotes.toDouble()
                                                : 1,
                                            gridData: const FlGridData(show: false),
                                            borderData: FlBorderData(show: false),
                                            titlesData: FlTitlesData(
                                              topTitles: const AxisTitles(
                                                sideTitles:
                                                    SideTitles(showTitles: false),
                                              ),
                                              rightTitles: const AxisTitles(
                                                sideTitles:
                                                    SideTitles(showTitles: false),
                                              ),
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 28,
                                                  getTitlesWidget: (v, m) {
                                                    return Text(
                                                      v.toInt().toString(),
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget: (v, m) {
                                                    final i = v.toInt();
                                                    if (i < 0 ||
                                                        i >= _sorted.length) {
                                                      return const SizedBox();
                                                    }
                                                    final short = _sorted[i]
                                                            ['name']
                                                        ?.toString() ??
                                                        '';
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 6),
                                                      child: Text(
                                                        short.length > 6
                                                            ? '${short.substring(0, 6)}…'
                                                            : short,
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 9,
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            barGroups: [
                                              for (var i = 0;
                                                  i < _sorted.length;
                                                  i++)
                                                BarChartGroupData(
                                                  x: i,
                                                  barRods: [
                                                    BarChartRodData(
                                                      toY: ((_sorted[i]['votes']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0),
                                                      width: 14,
                                                      borderRadius:
                                                          const BorderRadius
                                                              .vertical(
                                                        top: Radius.circular(8),
                                                      ),
                                                      gradient:
                                                          const LinearGradient(
                                                        colors: [
                                                          AppColors
                                                              .accentPrimary,
                                                          AppColors
                                                              .accentSecondary,
                                                        ],
                                                        begin: Alignment.bottomCenter,
                                                        end: Alignment.topCenter,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ...List.generate(_sorted.length, (i) {
                                      final c = _sorted[i];
                                      final votes =
                                          (c['votes'] as num?)?.toInt() ?? 0;
                                      final pct = _totalVotes > 0
                                          ? votes / _totalVotes
                                          : 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: GlassCard(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      gradient: i == 0
                                                          ? AppColors.heroGradient
                                                          : null,
                                                      color: i == 0
                                                          ? null
                                                          : AppColors.bgPrimary,
                                                    ),
                                                    child: Text(
                                                      '${i + 1}',
                                                      style: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          c['name']?.toString() ??
                                                              '',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .textPrimary,
                                                          ),
                                                        ),
                                                        Text(
                                                          c['position']
                                                                  ?.toString() ??
                                                              '',
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
                                                  Text(
                                                    '$votes',
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w700,
                                                      color:
                                                          AppColors.accentSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              LinearPercentIndicator(
                                                lineHeight: 8,
                                                percent: pct.clamp(0.0, 1.0),
                                                backgroundColor: AppColors.bgPrimary
                                                    .withValues(alpha: 0.5),
                                                progressColor: AppColors
                                                    .accentPrimary
                                                    .withValues(alpha: 0.9),
                                                barRadius: const Radius.circular(8),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ).animate().fadeIn(
                                            delay: (40 * i).ms,
                                            duration: 400.ms,
                                          );
                                    }),
                                  ],
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _pieSections() {
    final total = _totalVotes;
    if (total <= 0) {
      return [
        PieChartSectionData(
          color: AppColors.textSecondary.withValues(alpha: 0.3),
          value: 1,
          title: '',
          radius: 52,
        ),
      ];
    }
    const colors = [
      AppColors.accentPrimary,
      AppColors.accentSecondary,
      AppColors.success,
      AppColors.warning,
      Color(0xFFE040FB),
      Color(0xFFFF6E40),
    ];
    return List.generate(_sorted.length, (i) {
      final c = _sorted[i];
      final v = (c['votes'] as num?)?.toDouble() ?? 0;
      final pct = (v / total * 100).clamp(0, 100);
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: v,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 52,
        titleStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    });
  }
}
