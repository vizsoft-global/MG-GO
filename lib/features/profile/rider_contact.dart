/// Riders created from the admin panel get a synthetic `driver+<digits>@…`
/// address, and the number the rider actually knows is those digits. Returns
/// null for a real email address, which is not a phone number.
String? driverPhoneFromEmail(String? email) {
  if (email == null) return null;
  final match = RegExp(r'^driver\+(\d+)@').firstMatch(email.trim());
  if (match == null) return null;
  return '+${match.group(1)}';
}
