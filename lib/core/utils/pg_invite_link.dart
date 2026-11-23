/// Builds the shareable link encoded in a PG's registration QR.
///
/// Hosting serves `/pg/<id>` as a landing page, and the same path is
/// registered as an app link so installed apps open it directly.
abstract class PgInviteLink {
  static const String host = 'pg-sathi.web.app';
  static const String _pathPrefix = '/pg/';

  /// Public URL for [pgId], e.g. `https://pg-sathi.web.app/pg/abc`.
  static String url(String pgId) =>
      'https://$host$_pathPrefix${Uri.encodeComponent(pgId)}';

  /// In-app route for [pgId].
  static String route(String pgId) =>
      '$_pathPrefix${Uri.encodeComponent(pgId)}';
}
