import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Builds the platform-appropriate URL to show [latitude], [longitude] in
/// maps (Apple Maps on iOS, Google Maps elsewhere). [label] is used as the
/// place name when supported.
Uri buildMapsLaunchUri({
  required double latitude,
  required double longitude,
  String? label,
  bool? isWebOverride,
  TargetPlatform? platformOverride,
}) {
  final web = isWebOverride ?? kIsWeb;
  final trimmed = label?.trim();
  final queryParam = Uri.encodeComponent(
    (trimmed != null && trimmed.isNotEmpty) ? trimmed : '$latitude,$longitude',
  );

  Uri appleMaps() => Uri.parse(
    'https://maps.apple.com/?ll=$latitude,$longitude&q=$queryParam',
  );

  Uri googleMaps() => Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$queryParam',
  );

  if (web) {
    return googleMaps();
  }

  final platform = platformOverride ?? defaultTargetPlatform;
  if (platform == TargetPlatform.iOS) {
    return appleMaps();
  }
  return googleMaps();
}

/// Opens the system-relevant maps app at the given coordinates.
Future<bool> launchMapsAt({
  required double latitude,
  required double longitude,
  String? label,
}) {
  final uri = buildMapsLaunchUri(
    latitude: latitude,
    longitude: longitude,
    label: label,
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
