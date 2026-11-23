/// Remembers a route to open once the user finishes logging in.
///
/// Set by screens that require login before they can continue (e.g. the PG
/// QR invite); consumed by the auth screen after a successful sign-in.
abstract class PostLoginRedirect {
  static String? _path;

  static void set(String path) => _path = path;

  /// Returns the stored path and clears it.
  static String? take() {
    final path = _path;
    _path = null;
    return path;
  }
}
