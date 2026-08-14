import 'dart:math' as math;

/// Where a bearing came from.
///
/// Wire values match `HEADING_SOURCES` in
/// `src/features/live-tracking-v2/fleet-wire.ts`. The admin panel shows the
/// source next to the bearing, because a compass reading at a standstill and a
/// GPS course at 40km/h are not equally strong claims about which way a bike is
/// pointing — and collapsing them into one number would hide that.
enum HeadingSource { none, gps, compass }

extension HeadingSourceApi on HeadingSource {
  String get apiValue => switch (this) {
    HeadingSource.none => 'none',
    HeadingSource.gps => 'gps',
    HeadingSource.compass => 'compass',
  };
}

class FusedHeading {
  const FusedHeading(this.degrees, this.source);

  static const unknown = FusedHeading(null, HeadingSource.none);

  /// 0–360, clockwise from true north. Null when nothing is trustworthy, in
  /// which case the admin marker holds its previous bearing rather than
  /// snapping north.
  final double? degrees;
  final HeadingSource source;

  bool get isKnown => degrees != null && source != HeadingSource.none;
}

/// Signed shortest angular difference from [from] to [to], in (-180, 180].
double shortestHeadingDelta(double from, double to) {
  final delta = (to - from) % 360;
  if (delta > 180) return delta - 360;
  if (delta <= -180) return delta + 360;
  return delta;
}

double normalizeHeading(double degrees) {
  final wrapped = degrees % 360;
  return wrapped < 0 ? wrapped + 360 : wrapped;
}

/// Fuses the GPS course with the phone's compass into one bearing.
///
/// Pure Dart with an injected clock: no sensor plugin, no platform channel, so
/// the whole rule set is unit-testable. The caller feeds it whatever arrives
/// ([onCompass] at sensor rate, [onPosition] per fix) and reads [heading] when
/// it is about to publish.
///
/// The rule is GPS-first, and deliberately so: the compass reports **phone**
/// orientation, not bike orientation. A phone lying flat in a delivery bag says
/// nothing about where the bike is headed, so while there is real motion the
/// GPS course wins and the compass is only there to fill the standstill gap
/// where Android reports a course of `-1`.
class HeadingFuser {
  /// Below this, Android's fused provider bearing is mostly noise — it reports a
  /// stale course, or none at all. Set under
  /// `AdaptiveLocationScheduler.movingSpeedThresholdMps` (1.5) on purpose: a
  /// rider pushing a bike at walking pace has a usable course even though the
  /// scheduler still calls that idle.
  static const gpsCourseMinSpeedMps = 1.0;

  /// A course from an old fix is not a current bearing.
  static const gpsCourseMaxAge = Duration(seconds: 6);

  /// The compass stream is continuous; a gap this long means the sensor or the
  /// subscription is gone.
  static const compassMaxAge = Duration(seconds: 3);

  /// Android hard-codes accuracy into a few buckets, so this rejects only the
  /// clearly uncalibrated readings (a figure-eight-needed magnetometer) rather
  /// than trying to grade them.
  static const compassMaxErrorDeg = 45.0;

  /// Low-pass weight applied per compass event. At the ~20Hz these sensors fire
  /// this settles in well under a second while flattening single-sample spikes.
  static const compassSmoothing = 0.2;

  /// Ceiling on how fast the *published* bearing may swing, in degrees/second.
  /// This is what stops a magnet near the mount — or the gps→compass handover
  /// at a red light — from spinning the marker: a 180 degree disagreement takes
  /// two seconds to walk across instead of teleporting.
  static const maxSlewDegPerSecond = 90.0;

  double? _compassEstimate;
  double? _compassErrorDeg;
  DateTime? _compassAt;

  double? _gpsCourse;
  DateTime? _gpsAt;

  double? _emitted;
  DateTime? _emittedAt;

  /// Last published bearing, whatever its source. Exposed for diagnostics.
  double? get lastHeading => _emitted;

  /// Smoothed compass bearing, or null while the sensor has said nothing usable.
  double? get compassDeg =>
      _compassErrorDeg != null && _compassErrorDeg! > compassMaxErrorDeg
      ? null
      : _compassEstimate;

  void onCompass(double? degrees, {double? accuracyDeg, required DateTime now}) {
    if (degrees == null || degrees.isNaN) return;
    final reading = normalizeHeading(degrees);
    _compassErrorDeg = accuracyDeg;
    _compassAt = now;

    final previous = _compassEstimate;
    if (previous == null) {
      _compassEstimate = reading;
      return;
    }
    _compassEstimate = normalizeHeading(
      previous + shortestHeadingDelta(previous, reading) * compassSmoothing,
    );
  }

  void onPosition({
    required double? courseDeg,
    required double? speedMps,
    required DateTime now,
  }) {
    // Geolocator reports -1 for "no course", and a course below walking pace is
    // not one either.
    final hasCourse =
        courseDeg != null &&
        !courseDeg.isNaN &&
        courseDeg >= 0 &&
        speedMps != null &&
        speedMps >= gpsCourseMinSpeedMps;
    _gpsCourse = hasCourse ? normalizeHeading(courseDeg) : null;
    _gpsAt = hasCourse ? now : null;
  }

  /// Resolves the bearing to publish, advancing the slew limiter.
  ///
  /// Not a getter, because calling it moves internal state — reading the fused
  /// heading twice a second and once a second must not produce the same curve.
  FusedHeading heading(DateTime now) {
    final course = _freshGpsCourse(now);
    if (course != null) {
      // A GPS course is passed through unfiltered. It is already the direction
      // of travel, and slew-limiting it would lag a real corner.
      _emitted = course;
      _emittedAt = now;
      return FusedHeading(course, HeadingSource.gps);
    }

    final compass = _freshCompass(now);
    if (compass == null) {
      _emittedAt = now;
      return FusedHeading.unknown;
    }

    final previous = _emitted;
    final previousAt = _emittedAt;
    if (previous == null || previousAt == null) {
      _emitted = compass;
      _emittedAt = now;
      return FusedHeading(compass, HeadingSource.compass);
    }

    final elapsed = now.difference(previousAt).inMilliseconds / 1000;
    final maxStep = maxSlewDegPerSecond * (elapsed <= 0 ? 0 : elapsed);
    final delta = shortestHeadingDelta(previous, compass);
    final step = delta.abs() <= maxStep
        ? delta
        : maxStep * (delta.isNegative ? -1 : 1);
    final next = normalizeHeading(previous + step);
    _emitted = next;
    _emittedAt = now;
    return FusedHeading(next, HeadingSource.compass);
  }

  void reset() {
    _compassEstimate = null;
    _compassErrorDeg = null;
    _compassAt = null;
    _gpsCourse = null;
    _gpsAt = null;
    _emitted = null;
    _emittedAt = null;
  }

  double? _freshGpsCourse(DateTime now) {
    final at = _gpsAt;
    final course = _gpsCourse;
    if (at == null || course == null) return null;
    return now.difference(at) <= gpsCourseMaxAge ? course : null;
  }

  double? _freshCompass(DateTime now) {
    final at = _compassAt;
    final estimate = _compassEstimate;
    if (at == null || estimate == null) return null;
    if (now.difference(at) > compassMaxAge) return null;
    final error = _compassErrorDeg;
    if (error != null && !error.isNaN && error.abs() > compassMaxErrorDeg) {
      return null;
    }
    return estimate;
  }
}

/// Rounds a bearing for the wire. Sub-degree precision is below what either
/// sensor can claim and below what a 28px marker can show.
int? wireHeading(double? degrees) {
  if (degrees == null || degrees.isNaN) return null;
  return normalizeHeading(degrees).round() % 360;
}

/// Circular mean of two bearings, weighted toward [a] by [weightA].
///
/// Not used by the fuser itself — kept here because it is the correct way to
/// average bearings and the naive arithmetic mean (which puts 350 and 10 at 180)
/// is the mistake anyone extending this file will otherwise make.
double blendHeadings(double a, double b, double weightA) {
  final wa = weightA.clamp(0.0, 1.0);
  final ra = a * math.pi / 180;
  final rb = b * math.pi / 180;
  final x = math.cos(ra) * wa + math.cos(rb) * (1 - wa);
  final y = math.sin(ra) * wa + math.sin(rb) * (1 - wa);
  if (x == 0 && y == 0) return normalizeHeading(a);
  return normalizeHeading(math.atan2(y, x) * 180 / math.pi);
}
