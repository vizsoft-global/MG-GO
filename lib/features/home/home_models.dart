import '../../l10n/app_localizations.dart';
import 'shift_adherence_minutes.dart';

/// Elapsed seconds for an open online session that started in [periodStart]..now.
///
/// Sessions left `is_online` from a previous day/week must not inflate
/// today's or this week's Time in with wall-clock hours.
int liveOpenSessionSeconds({
  required bool isOnline,
  DateTime? wentOnlineAt,
  required DateTime now,
  required DateTime periodStart,
}) {
  if (!isOnline || wentOnlineAt == null) return 0;
  if (wentOnlineAt.isBefore(periodStart)) return 0;
  final live = now.difference(wentOnlineAt).inSeconds;
  return live > 0 ? live : 0;
}

class ShiftAdherence {
  const ShiftAdherence({
    this.scheduledStartAt,
    this.scheduledEndAt,
    this.actualInAt,
    this.actualOutAt,
    this.minutesLate = 0,
    this.minutesEarlyOut = 0,
    this.onlineSeconds = 0,
    this.scheduledSeconds = 0,
  });

  const ShiftAdherence.empty() : this();

  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final DateTime? actualInAt;
  final DateTime? actualOutAt;
  final int minutesLate;
  final int minutesEarlyOut;
  final int onlineSeconds;
  final int scheduledSeconds;

  bool get hasScheduledShift => scheduledStartAt != null;
  bool get hasClockedIn => actualInAt != null;

  String? summaryLabel(AppLocalizations l10n) {
    if (!hasScheduledShift || !hasClockedIn) return null;
    if (minutesLate > 0) {
      return l10n.minutesLateVsShift(minutesLate);
    }
    if (minutesEarlyOut > 0) {
      return l10n.minutesEarlyOutVsShift(minutesEarlyOut);
    }
    return l10n.onTimeVsShift;
  }

  String? shortLabel(AppLocalizations l10n) {
    if (!hasScheduledShift || !hasClockedIn) return null;
    if (minutesLate > 0) {
      return l10n.shiftAdherenceLateShort(minutesLate);
    }
    if (minutesEarlyOut > 0) {
      return l10n.shiftAdherenceEarlyShort(minutesEarlyOut);
    }
    return l10n.shiftAdherenceOnTimeShort;
  }

  factory ShiftAdherence.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ShiftAdherence.empty();
    }
    DateTime? parse(String? raw) =>
        raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);

    final scheduledStartAt = parse(json['scheduled_start_at'] as String?);
    final scheduledEndAt = parse(json['scheduled_end_at'] as String?);
    final actualOutAt = parse(json['actual_out_at'] as String?);
    final declaredSeconds = (json['scheduled_seconds'] as num?)?.toInt() ?? 0;
    final scheduledSeconds = resolveScheduledSeconds(
      declaredSeconds: declaredSeconds,
      scheduledStart: scheduledStartAt,
      scheduledEnd: scheduledEndAt,
    );
    final jsonEarly = (json['minutes_early_out'] as num?)?.toInt();
    final recomputed = scheduledStartAt != null && scheduledEndAt != null
        ? shiftMinutesEarlyOut(
            scheduledStart: scheduledStartAt,
            scheduledEnd: scheduledEndAt,
            actualOut: actualOutAt,
          )
        : 0;
    // Prefer the server minutes when present. Recomputing from ISO strings
    // on the device clock can skip the window clamp (naive 09:35 vs UTC
    // 08:30Z → 415, or 150) even when Postgres already sent 300.
    final rawEarly = jsonEarly ?? recomputed;

    return ShiftAdherence(
      scheduledStartAt: scheduledStartAt,
      scheduledEndAt: scheduledEndAt,
      actualInAt: parse(json['actual_in_at'] as String?),
      actualOutAt: actualOutAt,
      minutesLate: (json['minutes_late'] as num?)?.toInt() ?? 0,
      minutesEarlyOut: capShiftEarlyOutMinutes(
        rawEarly,
        scheduledSeconds: scheduledSeconds,
      ),
      onlineSeconds: (json['online_seconds'] as num?)?.toInt() ?? 0,
      scheduledSeconds: scheduledSeconds,
    );
  }
}

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    this.captionEn,
    this.captionAr,
    this.deepLink,
  });

  final String id;
  final String imageUrl;
  final String? captionEn;
  final String? captionAr;
  final String? deepLink;

  String? captionFor(String localeName) {
    final isAr = localeName.toLowerCase().startsWith('ar');
    final primary = isAr ? captionAr : captionEn;
    final fallback = isAr ? captionEn : captionAr;
    final text = (primary != null && primary.trim().isNotEmpty)
        ? primary
        : fallback;
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['image_url'] as String? ?? '';
    return HomeBanner(
      id: json['id'] as String? ?? '',
      imageUrl: imageUrl,
      captionEn: json['caption_en'] as String?,
      captionAr: json['caption_ar'] as String?,
      deepLink: json['deep_link'] as String?,
    );
  }
}

class HomeDashboard {
  const HomeDashboard({
    required this.driver,
    required this.session,
    required this.week,
    this.primaryWeeklyIncentive,
    this.deliveryRules = const [],
    this.shiftAdherence,
    this.banner,
    this.forceAppUpdate = false,
    this.forceAppUpdateMinCode,
  });

  final HomeDriverInfo driver;
  final HomeSessionInfo session;
  final HomeWeekStats week;
  final HomeIncentiveProgress? primaryWeeklyIncentive;
  final List<HomeDeliveryRuleSummary> deliveryRules;
  final ShiftAdherence? shiftAdherence;
  final HomeBanner? banner;
  final bool forceAppUpdate;
  final int? forceAppUpdateMinCode;

  bool get isOnline => session.isOnline;
  bool get isOnDuty => driver.isOnDuty;
  bool get isOnlineOnDuty => isOnline && isOnDuty;

  /// Accumulated online seconds from earlier sessions today (from attendance).
  int get todayAccumulatedOnlineSeconds =>
      shiftAdherence?.onlineSeconds ?? 0;

  /// Total time clocked in today, including the current session when online.
  int get todayOnlineSeconds {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return todayAccumulatedOnlineSeconds +
        liveOpenSessionSeconds(
          isOnline: isOnline,
          wentOnlineAt: session.wentOnlineAt,
          now: now,
          periodStart: todayStart,
        );
  }

  factory HomeDashboard.fromJson(Map<String, dynamic> json) {
    final incentiveRaw = json['primary_weekly_incentive'];
    return HomeDashboard(
      driver: HomeDriverInfo.fromJson(
        Map<String, dynamic>.from(json['driver'] as Map? ?? {}),
      ),
      session: HomeSessionInfo.fromJson(
        Map<String, dynamic>.from(json['session'] as Map? ?? {}),
      ),
      week: HomeWeekStats.fromJson(
        Map<String, dynamic>.from(json['week'] as Map? ?? {}),
      ),
      primaryWeeklyIncentive:
          incentiveRaw == null ||
              incentiveRaw is! Map ||
              incentiveRaw['name'] == null
          ? null
          : HomeIncentiveProgress.fromJson(
              Map<String, dynamic>.from(incentiveRaw),
            ),
      deliveryRules: (json['delivery_rules'] as List? ?? [])
          .map(
            (e) => HomeDeliveryRuleSummary.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(growable: false),
      shiftAdherence: json['shift_adherence'] == null
          ? null
          : ShiftAdherence.fromJson(
              Map<String, dynamic>.from(json['shift_adherence'] as Map),
            ),
      banner: () {
        if (json['banner'] is! Map) return null;
        final parsed = HomeBanner.fromJson(
          Map<String, dynamic>.from(json['banner'] as Map),
        );
        return parsed.imageUrl.trim().isEmpty ? null : parsed;
      }(),
      forceAppUpdate: json['force_app_update'] == true,
      forceAppUpdateMinCode: () {
        final raw = json['force_app_update_min_code'];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        if (raw is String) return int.tryParse(raw);
        return null;
      }(),
    );
  }
}

class HomeDriverInfo {
  const HomeDriverInfo({
    required this.fullName,
    required this.isOnDuty,
    this.partnerName,
    this.partnerLogoUrl,
  });

  final String fullName;
  final bool isOnDuty;
  final String? partnerName;
  final String? partnerLogoUrl;

  bool get hasDisplayablePartnerLogo {
    final url = partnerLogoUrl?.trim();
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  factory HomeDriverInfo.fromJson(Map<String, dynamic> json) {
    return HomeDriverInfo(
      fullName: json['full_name'] as String? ?? 'Driver',
      isOnDuty: json['is_on_duty'] as bool? ?? false,
      partnerName: json['partner_name'] as String?,
      partnerLogoUrl: json['partner_logo_url'] as String?,
    );
  }
}

class HomeSessionInfo {
  const HomeSessionInfo({
    required this.isOnline,
    this.wentOnlineAt,
    this.speedMps,
    this.distanceTodayMeters = 0,
  });

  final bool isOnline;
  final DateTime? wentOnlineAt;
  final double? speedMps;
  final double distanceTodayMeters;

  factory HomeSessionInfo.fromJson(Map<String, dynamic> json) {
    final wentOnlineRaw = json['went_online_at'] as String?;
    return HomeSessionInfo(
      isOnline: json['is_online'] as bool? ?? false,
      wentOnlineAt: wentOnlineRaw != null
          ? DateTime.tryParse(wentOnlineRaw)
          : null,
      speedMps: (json['speed_mps'] as num?)?.toDouble(),
      distanceTodayMeters:
          (json['distance_today_meters'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HomeWeekStats {
  const HomeWeekStats({
    required this.startDate,
    required this.endDate,
    required this.earningsKwd,
    required this.deliveriesCount,
    required this.onlineSeconds,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final double earningsKwd;
  final int deliveriesCount;
  final int onlineSeconds;

  String get earningsLabel {
    final value = earningsKwd == earningsKwd.roundToDouble()
        ? earningsKwd.toInt().toString()
        : earningsKwd.toStringAsFixed(3);
    return '$value KD';
  }

  String get onlineTimeLabel {
    final hours = onlineSeconds ~/ 3600;
    final minutes = (onlineSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  static String formatElapsed(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '0m';
  }

  factory HomeWeekStats.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return HomeWeekStats(
      startDate: parseDate(json['start_date'] as String?),
      endDate: parseDate(json['end_date'] as String?),
      earningsKwd: (json['earnings_kwd'] as num?)?.toDouble() ?? 0,
      deliveriesCount: (json['deliveries_count'] as num?)?.toInt() ?? 0,
      onlineSeconds: (json['online_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeIncentiveProgress {
  const HomeIncentiveProgress({
    required this.name,
    required this.eligibleCount,
    required this.progressCount,
    required this.target,
    required this.rewardKwd,
    required this.remainingDeliveries,
    this.targetMode = 'single',
    this.tiers = const [],
  });

  final String name;
  final int eligibleCount;
  /// Submitted orders for the Home bar (pay still uses [eligibleCount]).
  final int progressCount;
  final int target;
  final double rewardKwd;
  final int remainingDeliveries;
  final String targetMode;
  final List<HomeIncentiveTier> tiers;

  String bonusHeadline(AppLocalizations l10n) {
    if (remainingDeliveries <= 0) {
      return l10n.weeklyBonusUnlocked;
    }
    final reward = rewardKwd == rewardKwd.roundToDouble()
        ? rewardKwd.toInt().toString()
        : rewardKwd.toStringAsFixed(0);
    return l10n.deliveriesAwayFromBonus(remainingDeliveries, reward);
  }

  String bumperSubtitle(AppLocalizations l10n) {
    if (remainingDeliveries <= 0) return l10n.weeklyBonusUnlockedShort;
    final reward = rewardKwd == rewardKwd.roundToDouble()
        ? rewardKwd.toInt().toString()
        : rewardKwd.toStringAsFixed(0);
    return l10n.deliverMoreToUnlockKd(remainingDeliveries, reward);
  }

  int get maxTierThreshold {
    if (tiers.isNotEmpty) {
      return tiers.map((t) => t.threshold).reduce((a, b) => a > b ? a : b);
    }
    return target > 0 ? target : 1;
  }

  factory HomeIncentiveProgress.fromJson(Map<String, dynamic> json) {
    final eligible = (json['eligible_count'] as num?)?.toInt() ?? 0;
    final progress = (json['progress_count'] as num?)?.toInt() ?? eligible;
    final target = (json['target'] as num?)?.toInt() ?? 0;
    final leftover = target - progress;
    final remaining = (json['remaining_deliveries'] as num?)?.toInt() ??
        (target > 0 ? (leftover < 0 ? 0 : leftover) : 0);
    return HomeIncentiveProgress(
      name: json['name'] as String? ?? 'Weekly Bonus',
      eligibleCount: eligible,
      progressCount: progress,
      target: target,
      rewardKwd: (json['reward_kwd'] as num?)?.toDouble() ?? 0,
      remainingDeliveries: remaining,
      targetMode: json['target_mode'] as String? ?? 'single',
      tiers: (json['tiers'] as List? ?? [])
          .map(
            (e) =>
                HomeIncentiveTier.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false),
    );
  }
}

class HomeIncentiveTier {
  const HomeIncentiveTier({
    required this.threshold,
    this.rewardKwd,
    this.rewardPerDeliveryKwd,
    this.rewardMode = 'fixed',
  });

  final int threshold;
  final double? rewardKwd;
  final double? rewardPerDeliveryKwd;
  final String rewardMode;

  String get rewardLabel {
    if (rewardMode == 'per_delivery' && rewardPerDeliveryKwd != null) {
      final v = rewardPerDeliveryKwd!;
      return v == 0.25
          ? '1/4 KD'
          : v == 0.5
          ? '1/2 KD'
          : '$v KD';
    }
    if (rewardKwd == null) return '';
    final v = rewardKwd!;
    if (v == 0.25) return '1/4 KD';
    if (v == 0.5) return '1/2 KD';
    if (v == 1) return '1 KD';
    return '$v KD';
  }

  factory HomeIncentiveTier.fromJson(Map<String, dynamic> json) {
    return HomeIncentiveTier(
      threshold: (json['threshold'] as num?)?.toInt() ?? 0,
      rewardKwd: (json['reward_kwd'] as num?)?.toDouble(),
      rewardPerDeliveryKwd: (json['reward_per_delivery_kwd'] as num?)
          ?.toDouble(),
      rewardMode: json['reward_mode'] as String? ?? 'fixed',
    );
  }
}

class HomeDeliveryRuleSummary {
  const HomeDeliveryRuleSummary({
    required this.id,
    required this.name,
    required this.scopeType,
    this.restaurantName,
    this.startDate,
    this.endDate,
    this.summary,
  });

  final String id;
  final String name;
  final String scopeType;
  final String? restaurantName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? summary;

  factory HomeDeliveryRuleSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return HomeDeliveryRuleSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Delivery rule',
      scopeType: json['scope_type'] as String? ?? 'restaurant',
      restaurantName: json['restaurant_name'] as String?,
      startDate: parseDate(json['start_date'] as String?),
      endDate: parseDate(json['end_date'] as String?),
      summary: json['summary'] as String?,
    );
  }
}

/// A cached on-duty dashboard must not light the Clock In toggle after sign-out.
///
/// Sign-out clears the tracking token; a leftover cache from the previous
/// session is what flashed "In" until the live RPC landed.
Map<String, dynamic> dutySafeHomeDashboardCache({
  required Map<String, dynamic> cached,
  required bool hasLiveDutyToken,
}) {
  if (hasLiveDutyToken) return cached;
  final driver = Map<String, dynamic>.from(
    cached['driver'] is Map
        ? Map<String, dynamic>.from(cached['driver'] as Map)
        : const {},
  );
  final session = Map<String, dynamic>.from(
    cached['session'] is Map
        ? Map<String, dynamic>.from(cached['session'] as Map)
        : const {},
  );
  driver['is_on_duty'] = false;
  session['is_online'] = false;
  return {
    ...cached,
    'driver': driver,
    'session': session,
  };
}
