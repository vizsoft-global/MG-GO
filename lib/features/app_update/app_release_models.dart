class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.apkSizeBytes,
    required this.apkSha256,
    required this.isRequired,
    this.minSupportedVersionCode,
    this.releaseNotes,
  });

  final String versionName;
  final int versionCode;
  final int? minSupportedVersionCode;
  final String apkUrl;
  final int apkSizeBytes;
  final String apkSha256;
  final String? releaseNotes;
  final bool isRequired;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      versionName: json['version_name'] as String? ?? '',
      versionCode: _asInt(json['version_code']),
      minSupportedVersionCode: json['min_supported_version_code'] == null
          ? null
          : _asInt(json['min_supported_version_code']),
      apkUrl: json['apk_url'] as String? ?? '',
      apkSizeBytes: _asInt(json['apk_size_bytes']),
      apkSha256: (json['apk_sha256'] as String? ?? '').toLowerCase(),
      releaseNotes: json['release_notes'] as String?,
      isRequired: json['is_required'] == true,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum UpdateKind { none, optional, forced }

class UpdateDecision {
  const UpdateDecision.none()
      : kind = UpdateKind.none,
        release = null;

  const UpdateDecision.available(this.release, this.kind);

  final UpdateKind kind;
  final AppRelease? release;

  bool get hasUpdate => kind != UpdateKind.none;
  bool get isForced => kind == UpdateKind.forced;
}
