import 'package:flutter/material.dart';

import '../../../domain/entities/library.dart';
import 'library_details_screen.dart';

/// Screen for viewing library details when exploring (before membership).
/// Redirects to unified LibraryDetailsScreen with membershipInfo = null.
class ExploreLibraryDetailScreen extends StatelessWidget {
  const ExploreLibraryDetailScreen({
    super.key,
    required this.library,
    required this.userId,
  });

  final Library library;
  final String userId;

  @override
  Widget build(BuildContext context) {
    // Use unified LibraryDetailsScreen without membership info
    return LibraryDetailsScreen(
      library: library,
      userId: userId,
      membershipInfo: null, // Non-member mode
    );
  }
}
