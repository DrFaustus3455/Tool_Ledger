/// Normalizes camera, USB-keyboard and manually entered asset references.
/// QR payloads contain only the opaque asset identifier, never personal or
/// financial information.
abstract final class QrAssetReference {
  static String normalize(String raw) => raw.trim().toUpperCase();

  static bool isValid(String raw) {
    final value = normalize(raw);
    return RegExp(r'^[A-Z0-9][A-Z0-9_-]{4,39}$').hasMatch(value);
  }
}
