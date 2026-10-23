/// Display name for the rider's nationality.
///
/// `nationality_category_keys` is the catalog the admin files. The stored ISO
/// `nationality` is only a fallback for rows saved before that catalog. Labels
/// match the admin seed in `DEFAULT_NATIONALITY_CATEGORIES`. The rider cannot
/// read `nationality_categories` (staff-only), so an operator-renamed row shows
/// the seed wording until the next app release; an unknown key is shown as-is.
String? riderNationalityLabel({
  required List<String> categoryKeys,
  required String? storedCountry,
  required bool arabic,
}) {
  final keys = categoryKeys
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toList();
  if (keys.isNotEmpty) {
    return keys.map((key) => _nationalitySeedLabel(key, arabic)).join(', ');
  }
  final country = storedCountry?.trim() ?? '';
  return country.isEmpty ? null : country;
}

String _nationalitySeedLabel(String key, bool arabic) {
  final pair = _seedLabels[key];
  if (pair == null) return key;
  final chosen = arabic ? pair.$2 : pair.$1;
  return chosen.isEmpty ? key : chosen;
}

const _seedLabels = <String, (String, String)>{
  'bangladeshi': ('Bangladeshi', 'بنغلاديشي'),
  'benin': ('Benin', 'بنيني'),
  'burkina_faso': ('Burkina Faso', 'بوركيني'),
  'chad': ('Chad', 'تشادي'),
  'egyptian': ('Egyptian', 'مصري'),
  'ethiopia': ('Ethiopia', 'إثيوبي'),
  'filipino': ('Filipino', 'فلبيني'),
  'ghana': ('Ghana', 'غاني'),
  'indian': ('Indian', 'هندي'),
  'kenya': ('Kenya', 'كيني'),
  'mali': ('Mali', 'مالي'),
  'nepalese': ('Nepalese', 'نيبالي'),
  'nigeria': ('Nigeria', 'نيجيري'),
  'pakistani': ('Pakistani', 'باكستاني'),
  'sierra_leone': ('Sierra Leone', 'سيراليوني'),
  'sri_lankan': ('Sri Lankan', 'سريلانكي'),
  'sudan': ('Sudan', 'سوداني'),
  'syrian': ('Syrian', 'سوري'),
  'togo': ('Togo', 'توغولي'),
  'ugandan': ('Ugandan', 'أوغندي'),
};
