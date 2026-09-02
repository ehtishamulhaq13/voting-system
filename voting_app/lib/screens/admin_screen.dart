import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../theme/app_colors.dart';
import '../voting_http.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import 'candidate_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.user});

  final Map<String, dynamic>? user;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController position = TextEditingController();

  DateTime? start;
  DateTime? end;
  DateTime? savedStart;
  DateTime? savedEnd;

  XFile? image;
  final ImagePicker picker = ImagePicker();
  Uint8List? imageBytes;
  bool isSubmittingCandidate = false;
  bool isSavingTime = false;
  bool isClearingElection = false;
  bool isLoadingSavedTime = false;

  @override
  void initState() {
    super.initState();
    fetchSavedTime();
  }

  Future<void> fetchSavedTime() async {
    setState(() => isLoadingSavedTime = true);

    try {
      final res = await VotingHttp.get('/api/get-voting-time');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (!mounted) return;

      final parsedStart = data['start_time'] != null
          ? DateTime.parse(data['start_time'] as String).toLocal()
          : null;
      final parsedEnd = data['end_time'] != null
          ? DateTime.parse(data['end_time'] as String).toLocal()
          : null;

      setState(() {
        savedStart = parsedStart;
        savedEnd = parsedEnd;
        start ??= parsedStart;
        end ??= parsedEnd;
      });
    } catch (e) {
      if (!mounted) return;
      showVotingSnack(context, 'Failed to load saved time: $e', error: true);
    } finally {
      if (mounted) setState(() => isLoadingSavedTime = false);
    }
  }

  String formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    int hour = local.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day-$month-$year  $hour:$minute $period';
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        image = picked;
        imageBytes = bytes;
      });
    }
  }

  void clearImage() {
    setState(() {
      image = null;
      imageBytes = null;
    });
  }

  Future<void> addCandidate() async {
    if (name.text.isEmpty || position.text.isEmpty) {
      showVotingSnack(context, 'Fill all fields', error: true);
      return;
    }

    setState(() => isSubmittingCandidate = true);

    try {
      final request = http.MultipartRequest('POST', Api.uri('/api/candidates'));

      request.fields['name'] = name.text;
      request.fields['position'] = position.text;

      if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'symbol',
            imageBytes!,
            filename: image?.name ?? 'candidate-symbol.png',
          ),
        );
      }

      final response = await VotingHttp.sendMultipart(request);
      final body = await response.stream.bytesToString();

      debugPrint(body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        showVotingSnack(context, 'Candidate added');
        name.clear();
        position.clear();
        clearImage();
      } else {
        showVotingSnack(context, 'Error: $body', error: true);
      }
    } catch (e) {
      if (mounted) {
        showVotingSnack(context, 'Exception: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => isSubmittingCandidate = false);
    }
  }

  Future<void> saveTime() async {
    if (start == null || end == null) {
      showVotingSnack(context, 'Select both date & time', error: true);
      return;
    }

    if (!end!.isAfter(start!)) {
      showVotingSnack(context, 'End time must be after start time', error: true);
      return;
    }

    setState(() => isSavingTime = true);

    try {
      await VotingHttp.post(
        '/api/set-voting-time',
        body: {
          'start_time': start!.toIso8601String(),
          'end_time': end!.toIso8601String(),
        },
      );

      if (!mounted) return;

      showVotingSnack(context, 'Time saved');
      await fetchSavedTime();
    } finally {
      if (mounted) setState(() => isSavingTime = false);
    }
  }

  Future<void> clearElection() async {
    final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear election data?'),
            content: const Text(
              'This will remove all candidates, uploaded icons, votes, and the saved timer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldClear) return;

    setState(() => isClearingElection = true);

    try {
      final response = await VotingHttp.post('/api/clear-election');
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (response.statusCode == 200) {
        name.clear();
        position.clear();
        clearImage();

        setState(() {
          start = null;
          end = null;
        });

        showVotingSnack(context, data['message']?.toString() ?? 'Election cleared');
      } else {
        showVotingSnack(
          context,
          data['message']?.toString() ?? 'Unable to clear election',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showVotingSnack(context, 'Exception: $e', error: true);
    } finally {
      if (mounted) setState(() => isClearingElection = false);
    }
  }

  Future<void> pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (date != null) {
      if (!mounted) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          start = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (date != null) {
      if (!mounted) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          end = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _openVoterHome() async {
    final u = widget.user;
    if (u == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CandidateScreen(user: u),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminName = widget.user?['name']?.toString() ?? 'Administrator';

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppColors.textPrimary),
                        ),
                      Expanded(
                        child: Text(
                          'Control center',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (widget.user != null)
                        IconButton(
                          tooltip: 'Voter home',
                          onPressed: _openVoterHome,
                          icon: const Icon(Icons.how_to_vote_outlined,
                              color: AppColors.textPrimary),
                        ),
                      IconButton(
                        tooltip: 'Refresh timer',
                        onPressed: isLoadingSavedTime ? null : fetchSavedTime,
                        icon: isLoadingSavedTime
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded,
                                color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppColors.heroGradient,
                          ),
                          child: const Icon(Icons.insights_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adminName,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Configure candidates and election timing',
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
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Text(
                      'Candidates',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add candidate',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter details and upload an icon image.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: name,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: position,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Position',
                              prefixIcon: Icon(Icons.how_to_vote_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor:
                                      AppColors.bgPrimary.withValues(alpha: 0.6),
                                  backgroundImage: imageBytes != null
                                      ? MemoryImage(imageBytes!)
                                      : null,
                                  child: imageBytes == null
                                      ? const Icon(Icons.person,
                                          size: 44, color: AppColors.textSecondary)
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  image == null
                                      ? 'No icon selected'
                                      : image!.name,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    FilledButton.icon(
                                      onPressed:
                                          isSubmittingCandidate ? null : pickImage,
                                      icon: const Icon(Icons.add_photo_alternate_outlined),
                                      label: Text(
                                        image == null ? 'Add icon' : 'Change icon',
                                      ),
                                    ),
                                    if (image != null)
                                      OutlinedButton.icon(
                                        onPressed: isSubmittingCandidate
                                            ? null
                                            : clearImage,
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Remove'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  isSubmittingCandidate ? null : addCandidate,
                              icon: isSubmittingCandidate
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                isSubmittingCandidate
                                    ? 'Adding...'
                                    : 'Add candidate',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Election timing',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Saved on server',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            savedStart == null || savedEnd == null
                                ? 'Not set yet'
                                : '${formatDateTime(savedStart!)}  →  ${formatDateTime(savedEnd!)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: pickStart,
                              child: Text(
                                start == null
                                    ? 'Select start date & time'
                                    : formatDateTime(start!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: pickEnd,
                              child: Text(
                                end == null
                                    ? 'Select end date & time'
                                    : formatDateTime(end!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isSavingTime ? null : saveTime,
                              child: Text(isSavingTime ? 'Saving...' : 'Save time'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isClearingElection ? null : clearElection,
                              icon: isClearingElection
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.delete_forever_outlined),
                              label: Text(
                                isClearingElection
                                    ? 'Clearing...'
                                    : 'Clear all candidates and votes',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
