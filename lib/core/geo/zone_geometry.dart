import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Zone geometry helpers mirroring admin `zone-geometry.ts` semantics.
enum ZoneGeometryType { polygon, circle }

class ZoneShape {
  const ZoneShape({
    required this.zoneType,
    this.geometry,
  });

  final ZoneGeometryType zoneType;
  final Map<String, dynamic>? geometry;
}

class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// True when [lat]/[lng] is inside the zone OR within [bufferMeters] of its boundary.
bool isWithinZoneProximity({
  required double lat,
  required double lng,
  required ZoneShape zone,
  required int bufferMeters,
}) {
  if (bufferMeters < 0) return false;
  if (zone.geometry == null) return false;

  if (zone.zoneType == ZoneGeometryType.circle) {
    final circle = _circleFromFeature(zone.geometry!);
    if (circle == null) return false;
    final dist = Geolocator.distanceBetween(
      lat,
      lng,
      circle.center.latitude,
      circle.center.longitude,
    );
    return dist <= circle.radiusMeters + bufferMeters;
  }

  final ring = _polygonRingFromFeature(zone.geometry!);
  if (ring.length < 3) return false;

  if (_isPointInPolygon(lat, lng, ring)) {
    return true;
  }

  return _distanceToPolygonBoundaryMeters(lat, lng, ring) <= bufferMeters;
}

double nearestRestaurantDistanceMeters({
  required double lat,
  required double lng,
  required Iterable<LatLng> restaurants,
}) {
  var minDistance = double.infinity;
  for (final restaurant in restaurants) {
    final dist = Geolocator.distanceBetween(
      lat,
      lng,
      restaurant.latitude,
      restaurant.longitude,
    );
    if (dist < minDistance) {
      minDistance = dist;
    }
  }
  return minDistance;
}

/// True when [lat]/[lng] is strictly inside the shape (no proximity buffer).
bool isPointInsideZoneShape({
  required double lat,
  required double lng,
  required ZoneShape shape,
}) {
  return isWithinZoneProximity(
    lat: lat,
    lng: lng,
    zone: shape,
    bufferMeters: 0,
  );
}

/// Returns 0 when inside the shape; otherwise meters to the nearest boundary point.
double distanceToZoneShapeMeters({
  required double lat,
  required double lng,
  required ZoneShape shape,
}) {
  return distanceToZoneBoundaryMeters(lat: lat, lng: lng, zone: shape);
}

/// Returns 0 when inside the zone; otherwise meters to the nearest boundary point.
double distanceToZoneBoundaryMeters({
  required double lat,
  required double lng,
  required ZoneShape zone,
}) {
  if (zone.geometry == null) return double.infinity;

  if (zone.zoneType == ZoneGeometryType.circle) {
    final circle = _circleFromFeature(zone.geometry!);
    if (circle == null) return double.infinity;
    final dist = Geolocator.distanceBetween(
      lat,
      lng,
      circle.center.latitude,
      circle.center.longitude,
    );
    return math.max(0, dist - circle.radiusMeters);
  }

  final ring = _polygonRingFromFeature(zone.geometry!);
  if (ring.length < 3) return double.infinity;
  if (_isPointInPolygon(lat, lng, ring)) return 0;
  return _distanceToPolygonBoundaryMeters(lat, lng, ring);
}

/// Smallest amount the driver is outside allowed range (zone buffer + restaurants).
double distanceBeyondDeliveryRangeMeters({
  required double lat,
  required double lng,
  required ZoneShape? zone,
  required int proximityMeters,
  required Iterable<LatLng> restaurants,
}) {
  final candidates = <double>[];

  if (zone != null) {
    final boundaryDist = distanceToZoneBoundaryMeters(
      lat: lat,
      lng: lng,
      zone: zone,
    );
    if (boundaryDist.isFinite) {
      candidates.add((boundaryDist - proximityMeters).clamp(0, double.infinity));
    }
  }

  final restaurantDistance = nearestRestaurantDistanceMeters(
    lat: lat,
    lng: lng,
    restaurants: restaurants,
  );
  if (restaurantDistance.isFinite) {
    candidates.add(
      (restaurantDistance - proximityMeters).clamp(0, double.infinity),
    );
  }

  if (candidates.isEmpty) return double.infinity;
  return candidates.reduce(math.min);
}

ZoneShape? zoneShapeFromContext({
  required String? zoneType,
  required Map<String, dynamic>? zoneGeometry,
}) {
  if (zoneType == null || zoneGeometry == null) return null;
  final type = switch (zoneType) {
    'polygon' => ZoneGeometryType.polygon,
    'circle' => ZoneGeometryType.circle,
    _ => null,
  };
  if (type == null) return null;
  return ZoneShape(zoneType: type, geometry: zoneGeometry);
}

class _CircleData {
  const _CircleData({required this.center, required this.radiusMeters});

  final LatLng center;
  final double radiusMeters;
}

_CircleData? _circleFromFeature(Map<String, dynamic> feature) {
  final geometry = _geometryNode(feature);
  if (geometry == null || geometry['type'] != 'Point') return null;

  final coords = geometry['coordinates'] as List<dynamic>?;
  if (coords == null || coords.length < 2) return null;

  final lng = (coords[0] as num).toDouble();
  final lat = (coords[1] as num).toDouble();
  final props = feature['properties'] as Map<String, dynamic>?;
  final radius = (props?['radiusMeters'] as num?)?.toDouble() ?? 0;
  if (radius <= 0) return null;

  return _CircleData(center: LatLng(lat, lng), radiusMeters: radius);
}

List<LatLng> _polygonRingFromFeature(Map<String, dynamic> feature) {
  final geometry = _geometryNode(feature);
  if (geometry == null || geometry['type'] != 'Polygon') return const [];

  final coordinates = geometry['coordinates'] as List<dynamic>?;
  if (coordinates == null || coordinates.isEmpty) return const [];

  final ring = coordinates.first as List<dynamic>;
  return ring
      .map((coord) {
        final pair = coord as List<dynamic>;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      })
      .toList(growable: false);
}

Map<String, dynamic>? _geometryNode(Map<String, dynamic> feature) {
  if (feature['type'] == 'Feature') {
    final geometry = feature['geometry'];
    if (geometry is Map<String, dynamic>) return geometry;
    return null;
  }
  if (feature['type'] == 'Polygon' || feature['type'] == 'Point') {
    return feature;
  }
  return null;
}

bool _isPointInPolygon(double lat, double lng, List<LatLng> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].longitude;
    final yi = ring[i].latitude;
    final xj = ring[j].longitude;
    final yj = ring[j].latitude;

    final intersects = ((yi > lat) != (yj > lat)) &&
        (lng <
            (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

double _distanceToPolygonBoundaryMeters(double lat, double lng, List<LatLng> ring) {
  var minDistance = double.infinity;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    final dist = _distancePointToSegmentMeters(
      lat,
      lng,
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (dist < minDistance) minDistance = dist;
  }
  return minDistance;
}

double _distancePointToSegmentMeters(
  double lat,
  double lng,
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final ax = lng1;
  final ay = lat1;
  final bx = lng2;
  final by = lat2;
  final px = lng;
  final py = lat;

  final abx = bx - ax;
  final aby = by - ay;
  final apx = px - ax;
  final apy = py - ay;

  final abLenSq = abx * abx + aby * aby;
  if (abLenSq == 0) {
    return Geolocator.distanceBetween(lat, lng, lat1, lng1);
  }

  var t = (apx * abx + apy * aby) / abLenSq;
  t = t.clamp(0.0, 1.0);

  final closestLat = ay + t * aby;
  final closestLng = ax + t * abx;
  return Geolocator.distanceBetween(lat, lng, closestLat, closestLng);
}

String formatDistanceMeters(double meters) {
  if (meters.isInfinite || meters.isNaN) return 'unknown distance';
  final rounded = meters.round();
  if (rounded < 1000) return '${rounded}m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km >= 10 ? 0 : 1)}km';
}
