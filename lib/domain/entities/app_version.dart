import 'package:equatable/equatable.dart';

/// Represents app version information for update checking.
class AppVersion extends Equatable {
  const AppVersion({
    required this.currentVersion,
    required this.minimumRequiredVersion,
    this.isForceUpdateRequired = false,
    this.updateMessage,
    this.updateUrl,
  });

  /// Current app version (e.g., "1.0.0").
  final String currentVersion;

  /// Minimum required version (e.g., "1.0.0").
  final String minimumRequiredVersion;

  /// Whether a force update is required.
  final bool isForceUpdateRequired;

  /// Optional message to display to users.
  final String? updateMessage;

  /// Optional URL to redirect users for update (Play Store/App Store).
  final String? updateUrl;

  /// Checks if current version is below minimum required version.
  bool get isUpdateRequired {
    return _compareVersions(currentVersion, minimumRequiredVersion) < 0;
  }

  /// Compares two version strings.
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2.
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.tryParse).toList();
    final parts2 = v2.split('.').map(int.tryParse).toList();

    // Ensure both have same length
    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (int i = 0; i < parts1.length; i++) {
      final p1 = parts1[i] ?? 0;
      final p2 = parts2[i] ?? 0;
      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }
    return 0;
  }

  @override
  List<Object?> get props => [
    currentVersion,
    minimumRequiredVersion,
    isForceUpdateRequired,
    updateMessage,
    updateUrl,
  ];
}
