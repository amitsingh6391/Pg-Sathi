import 'package:equatable/equatable.dart';

/// A named external link (e.g. Apply Online, Official Notification PDF).
///
/// Framework-agnostic value object used across entities that need to expose
/// a small, ordered list of related external resources to the user.
class LabeledLink extends Equatable {
  const LabeledLink({required this.label, required this.url});

  /// Short human-readable label shown on the CTA button.
  final String label;

  /// Absolute URL. The renderer is responsible for validating scheme and
  /// wrapping this with any click-tracking redirect.
  final String url;

  @override
  List<Object?> get props => [label, url];

  Map<String, dynamic> toMap() => {'label': label, 'url': url};

  factory LabeledLink.fromMap(Map<String, dynamic> map) {
    return LabeledLink(
      label: (map['label'] as String?) ?? '',
      url: (map['url'] as String?) ?? '',
    );
  }
}
