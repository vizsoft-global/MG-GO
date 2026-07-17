import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../home_models.dart';

class TodayTimeInBanner extends StatefulWidget {
  const TodayTimeInBanner({
    required this.accumulatedOnlineSeconds,
    required this.wentOnlineAt,
    required this.isOnline,
    super.key,
  });

  /// Seconds already recorded in attendance from earlier sessions today.
  final int accumulatedOnlineSeconds;
  final DateTime? wentOnlineAt;
  final bool isOnline;

  @override
  State<TodayTimeInBanner> createState() => _TodayTimeInBannerState();
}

class _TodayTimeInBannerState extends State<TodayTimeInBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant TodayTimeInBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline ||
        oldWidget.wentOnlineAt != widget.wentOnlineAt ||
        oldWidget.accumulatedOnlineSeconds != widget.accumulatedOnlineSeconds) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.isOnline) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _totalOnlineSeconds() {
    var total = widget.accumulatedOnlineSeconds;
    if (widget.isOnline && widget.wentOnlineAt != null) {
      final live =
          DateTime.now().difference(widget.wentOnlineAt!).inSeconds;
      if (live > 0) total += live;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return const SizedBox.shrink();
    }

    final duration =
        HomeWeekStats.formatElapsed(Duration(seconds: _totalOnlineSeconds()));
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.homeOnlineBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder, width: 0.7),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: AppColors.blueberry),
          const SizedBox(width: 8),
          Text(
            l10n.timeInToday(duration),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF141414),
            ),
          ),
        ],
      ),
    );
  }
}
