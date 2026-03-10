import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/ride_history_model.dart';
import '../../providers/history_provider.dart';

/// Automatically shown after every ride finishes.
/// Collects safety rating, feedback tags, and optional City Hall message.
class PostRideFeedbackScreen extends ConsumerStatefulWidget {
  final RideHistoryModel? completedRide;

  const PostRideFeedbackScreen({super.key, this.completedRide});

  @override
  ConsumerState<PostRideFeedbackScreen> createState() =>
      _PostRideFeedbackScreenState();
}

class _PostRideFeedbackScreenState
    extends ConsumerState<PostRideFeedbackScreen> {
  double _starRating = 0;
  final Set<String> _selectedTags = {};
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ride = widget.completedRide;
    if (ride == null) {
      context.go('/home');
      return;
    }

    setState(() => _submitting = true);

    final updated = ride.copyWith(
      safetyRating: _starRating > 0 ? _starRating : null,
      feedbackTags: _selectedTags.toList(),
      cityHallMessage: _messageCtrl.text.trim().isNotEmpty
          ? _messageCtrl.text.trim()
          : null,
    );

    // Persist to Supabase (optimistic local update inside addRide)
    await ref.read(historyProvider.notifier).addRide(updated);

    if (mounted) {
      setState(() => _submitting = false);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.completedRide;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // ── Celebration header ────────────────────────────────────────
              _RideCompleteHeader(),
              const SizedBox(height: 28),

              // ── Ride summary card ─────────────────────────────────────────
              if (ride != null) _RideSummaryCard(ride: ride),
              const SizedBox(height: 24),

              // ── Safety rating ─────────────────────────────────────────────
              _SectionTitle('How safe did this route feel?'),
              const SizedBox(height: 12),
              _StarRatingInput(
                rating: _starRating,
                onRatingChanged: (r) => setState(() => _starRating = r),
              ),
              const SizedBox(height: 24),

              // ── Quick feedback chips ──────────────────────────────────────
              _SectionTitle('Tell us more (select all that apply)'),
              const SizedBox(height: 12),
              _FeedbackChips(
                selected: _selectedTags,
                onToggle: (tag) => setState(() {
                  if (_selectedTags.contains(tag)) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                }),
              ),
              const SizedBox(height: 24),

              // ── City Hall message ─────────────────────────────────────────
              _SectionTitle('Message to City Hall (optional)'),
              const SizedBox(height: 4),
              Text(
                'Share infrastructure suggestions directly with Sector 2 authorities.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.subtleText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText:
                      'e.g. "The bike lane on Bd. Colentina is blocked by parked cars near no. 45…"',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.account_balance_outlined,
                        color: AppTheme.primary),
                  ),
                  counterStyle: const TextStyle(color: AppTheme.subtleText),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 28),

              // ── Submit button ─────────────────────────────────────────────
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Submit & Finish'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Skip for now'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Components ───────────────────────────────────────────────────────────────

class _RideCompleteHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        Text(
          'Ride Complete!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Great job! Help us make Sector 2 better.',
          style: TextStyle(color: AppTheme.subtleText, fontSize: 14),
        ),
      ],
    );
  }
}

class _RideSummaryCard extends StatelessWidget {
  final RideHistoryModel ride;
  const _RideSummaryCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(70),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryStat(
            icon: Icons.straighten_rounded,
            value: '${ride.distanceKm.toStringAsFixed(2)} km',
            label: 'Distance',
          ),
          _VerticalDivider(),
          _SummaryStat(
            icon: Icons.timer_outlined,
            value: ride.formattedDuration,
            label: 'Duration',
          ),
          _VerticalDivider(),
          _SummaryStat(
            icon: Icons.eco_rounded,
            value: ride.formattedCo2,
            label: 'CO₂ Saved',
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: Colors.white24,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
    );
  }
}

// ─── Star Rating Input ────────────────────────────────────────────────────────
class _StarRatingInput extends StatelessWidget {
  final double rating;
  final void Function(double) onRatingChanged;

  const _StarRatingInput(
      {required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starValue = (i + 1).toDouble();
        return GestureDetector(
          onTap: () => onRatingChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              rating >= starValue
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 40,
              color: rating >= starValue
                  ? Colors.amber
                  : AppTheme.dividerColor,
            ),
          ),
        );
      }),
    );
  }
}

// ─── Feedback Chips ───────────────────────────────────────────────────────────
class _FeedbackChips extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;

  const _FeedbackChips({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FeedbackTag.all.map((tag) {
        final isSelected = selected.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (_) => onToggle(tag),
          selectedColor: AppTheme.primary.withAlpha(30),
          checkmarkColor: AppTheme.primary,
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.dividerColor,
          ),
        );
      }).toList(),
    );
  }
}
