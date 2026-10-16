import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/routes.dart';
import '../../../domain/models/exercise.dart';
import '../../../domain/models/progress.dart';
import '../../../data/local/onboarding_store.dart';
import '../../../utils/exercise_name_utils.dart';
import '../../shared/providers/content_provider.dart';
import '../../shared/providers/progress_provider.dart';
import '../../shared/widgets/chunky.dart';
import '../../shared/widgets/exercise_type_style.dart';
import '../../shared/widgets/lesson_widgets.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../shared/widgets/tab_header.dart';
import 'providers/weekly_progress_provider.dart';
import 'widgets/weekly_chart.dart';
import '../../shared/widgets/voxi_mood.dart';

class AnalyzeScreen extends ConsumerWidget {
  const AnalyzeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(progressNotifierProvider);
    final totalXp = ref.watch(totalXpStateProvider);
    final completedCount = ref.watch(completedExerciseCountProvider);
    final weekly = ref.watch(weeklyProgressProvider);
    final weekXp = weekly.total;
    final todayXp = weekly.daily[ref.watch(clockProvider)().weekday - 1];
    final goalXp =
        ref.watch(onboardingProfileProvider).valueOrNull?.dailyGoalXp ??
        OnboardingProfile.defaultDailyGoalXp;
    final exercises = ref.watch(exerciseByIdProvider);
    final recent = entries.reversed.take(10).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: entries.isEmpty
            ? _EmptyAnalysis(onGoPractice: () => context.go(AppRoutes.map))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  TabHeader(
                    title: 'Tu Progreso',
                    subtitle: 'Seguí así, cada ejercicio cuenta.',
                    trailing: Bob(
                      child: Image.asset(
                        'assets/images/voxi_awake.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: EntranceAnimation(
                          child: StatTile(
                            icon: Icons.bolt_rounded,
                            color: AppColors.primary,
                            value: '$totalXp',
                            label: 'XP total',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EntranceAnimation(
                          delay: EntranceAnimation.stagger(1),
                          child: StatTile(
                            icon: Icons.check_circle_rounded,
                            color: AppColors.success,
                            value: '$completedCount',
                            label: 'Completados',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EntranceAnimation(
                          delay: EntranceAnimation.stagger(2),
                          child: StatTile(
                            icon: Icons.calendar_today_rounded,
                            color: AppColors.accentRed,
                            value: '$weekXp',
                            label: 'Esta semana',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  EntranceAnimation(
                    delay: EntranceAnimation.stagger(3),
                    child: _DailyGoalCard(todayXp: todayXp, goalXp: goalXp),
                  ),
                  const SizedBox(height: 14),
                  EntranceAnimation(
                    delay: EntranceAnimation.stagger(3),
                    child: const ChunkyCard(
                      padding: EdgeInsets.all(18),
                      child: WeeklyChart(),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Historial reciente',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkBrown,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < recent.length; i++)
                    EntranceAnimation(
                      delay: EntranceAnimation.stagger(i + 4),
                      child: _HistoryTile(
                        entry: recent[i],
                        exercise: exercises[recent[i].exerciseId],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Today's XP against the daily goal picked in the onboarding.
class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.todayXp, required this.goalXp});

  final int todayXp;
  final int goalXp;

  @override
  Widget build(BuildContext context) {
    final reached = todayXp >= goalXp;
    return ChunkyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: reached ? AppColors.gold : AppColors.idleFace,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: reached ? AppColors.goldDark : AppColors.idleLip,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              reached ? Icons.emoji_events_rounded : Icons.flag_rounded,
              color: reached ? AppColors.darkBrown : AppColors.darkBrownLight,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reached ? '¡Meta diaria cumplida!' : 'Meta diaria',
                        style: GoogleFonts.dmSans(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkBrown,
                        ),
                      ),
                    ),
                    Text(
                      '$todayXp / $goalXp XP',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkBrownLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LessonProgressBar(
                  value: goalXp == 0 ? 1 : todayXp / goalXp,
                  color: AppColors.gold,
                  height: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.exercise});

  final Progress entry;
  final Exercise? exercise;

  static String _dateLabel(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoy, $time';
    if (diff == 1) return 'Ayer, $time';
    return '${at.day}/${at.month} $time';
  }

  @override
  Widget build(BuildContext context) {
    final type = exercise?.type ?? '';
    final style = ExerciseTypeStyle.of(type);
    final name = exercise == null
        ? 'Ejercicio'
        : exercise!.name.isNotEmpty
        ? exercise!.name
        : formatExerciseType(type);
    final date = _dateLabel(entry.completedAt);
    final xp = entry.score ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ChunkyCard(
        depth: 4,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.colors.face,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: style.colors.lip,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(style.icon, color: style.colors.content, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkBrown,
                    ),
                  ),
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkBrownLight,
                      ),
                    ),
                ],
              ),
            ),
            if (xp > 0)
              ChunkyTag(
                label: '+$xp XP',
                icon: Icons.bolt_rounded,
                color: AppColors.accentRed,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis({required this.onGoPractice});

  final VoidCallback onGoPractice;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Bob(
              child: Image.asset(
                VoxiMood.sleepy.asset,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Todavía no hay datos',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.darkBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completá tu primer ejercicio y acá vas a ver '
              'tu progreso semanal y tu historial.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.darkBrown.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ChunkyButton(
              label: 'IR A APRENDER',
              icon: Icons.map_rounded,
              onPressed: onGoPractice,
            ),
          ],
        ),
      ),
    );
  }
}
