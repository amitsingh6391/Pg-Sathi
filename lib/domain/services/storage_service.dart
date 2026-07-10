import 'dart:io';

/// Domain interface for storage service.
/// Abstracts file upload/download operations.
abstract class StorageService {
  /// Uploads an image file and returns its download URL.
  Future<String> uploadImage({required File file, required String path});

  /// Deletes an image from storage using its download URL.
  Future<void> deleteImage(String downloadUrl);

  /// Deletes multiple images from storage.
  /// Returns list of URLs that failed to delete.
  Future<List<String>> deleteImages(List<String> downloadUrls);
}
