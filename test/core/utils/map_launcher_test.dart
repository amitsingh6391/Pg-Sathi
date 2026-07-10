import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/core/utils/map_launcher.dart';

void main() {
  group('buildMapsLaunchUri', () {
    test('should_use_google_maps_when_web', () {
      final uri = buildMapsLaunchUri(
        latitude: 12.9716,
        longitude: 77.5946,
        label: 'MG Road',
        isWebOverride: true,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], 'MG Road');
    });

    test('should_use_apple_maps_when_ios', () {
      final uri = buildMapsLaunchUri(
        latitude: 12.9716,
        longitude: 77.5946,
        label: 'MG Road',
        isWebOverride: false,
        platformOverride: TargetPlatform.iOS,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['ll'], '12.9716,77.5946');
      expect(uri.queryParameters['q'], 'MG Road');
    });

    test('should_use_google_maps_when_android', () {
      final uri = buildMapsLaunchUri(
        latitude: 12.9716,
        longitude: 77.5946,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
      );

      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query'], '12.9716,77.5946');
    });

    test('should_fallback_to_lat_lng_when_label_empty', () {
      final uri = buildMapsLaunchUri(
        latitude: 1.0,
        longitude: 2.0,
        label: '   ',
        isWebOverride: true,
      );

      expect(uri.queryParameters['query'], '1.0,2.0');
    });
  });
}
