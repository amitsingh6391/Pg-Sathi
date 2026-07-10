import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/storage_service.dart' as domain;

// NOTE: The old approach of setting customMetadata firebaseStorageDownloadTokens
// and manually building download URLs does NOT work with the new
// firebasestorage.app bucket format and causes a 400 error.
// We now use ref.getDownloadURL() which is the correct approach.

/// Service for uploading files to Firebase Storage.
/// Handles image uploads for library photos.
class StorageService implements domain.StorageService {
  StorageService({required this.storage});

  final FirebaseStorage storage;

  /// Uploads an image file to Firebase Storage.
  /// Returns the download URL of the uploaded file.
  ///
  /// [file] - The image file to upload
  /// [path] - The storage path (e.g., 'library_photos/{libraryId}/')
  ///
  /// Throws [StorageException] if upload fails.
  @override
  Future<String> uploadImage({required File file, required String path}) async {
    try {
      final fileName = '${const Uuid().v4()}.jpg';
      final fullPath = '$path$fileName';
      final bytes = await file.readAsBytes();

      final ref = storage.ref().child(fullPath);
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('StorageService: uploaded $fullPath → $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw StorageException(_firebaseStorageMessage(e, storage.bucket));
    } catch (e) {
      throw StorageException('Failed to upload image: $e');
    }
  }

  /// Uploads a file (image or PDF) to Firebase Storage.
  /// Returns the download URL of the uploaded file.
  ///
  /// [file] - The file to upload
  /// [path] - The storage path
  /// [fileName] - The file name with extension
  /// [contentType] - MIME type (e.g., 'image/jpeg', 'application/pdf')
  ///
  /// Throws [StorageException] if upload fails.
  Future<String> uploadFile({
    required File file,
    required String path,
    required String fileName,
    required String contentType,
  }) async {
    try {
      final fullPath = '$path$fileName';
      final bytes = await file.readAsBytes();

      final ref = storage.ref().child(fullPath);
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'public, max-age=31536000',
        ),
      );

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('StorageService: uploaded $fullPath → $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw StorageException(_firebaseStorageMessage(e, storage.bucket));
    } catch (e) {
      throw StorageException('Failed to upload file: $e');
    }
  }

  /// Deletes an image from Firebase Storage using its download URL.
  ///
  /// [downloadUrl] - The download URL of the image to delete
  ///
  /// Throws [StorageException] if deletion fails.
  @override
  Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      throw StorageException(_firebaseStorageMessage(e, storage.bucket));
    } catch (e) {
      throw StorageException('Failed to delete image: $e');
    }
  }

  /// Deletes multiple images from Firebase Storage.
  ///
  /// [downloadUrls] - List of download URLs to delete
  ///
  /// Returns list of URLs that failed to delete (empty if all succeeded).
  @override
  Future<List<String>> deleteImages(List<String> downloadUrls) async {
    final failedUrls = <String>[];

    for (final url in downloadUrls) {
      try {
        await deleteImage(url);
      } catch (e) {
        failedUrls.add(url);
      }
    }

    return failedUrls;
  }

  String _firebaseStorageMessage(FirebaseException e, String bucket) {
    debugPrint(
      'StorageService: Firebase Storage error code=${e.code}, '
      'bucket=$bucket, message=${e.message}',
    );

    if (e.code == 'object-not-found' ||
        e.code == 'bucket-not-found' ||
        e.code == 'project-not-found') {
      return 'Firebase Storage is not enabled for this project/bucket '
          '($bucket). Open Firebase Console > Storage and enable it. '
          'Your console currently shows that the project must be upgraded '
          'before Storage can be used.';
    }

    if (e.code == 'unauthorized' || e.code == 'permission-denied') {
      return 'Firebase Storage rules blocked this upload. Check Storage rules '
          'for bucket $bucket.';
    }

    // Handle unknown 400 errors — common with new firebasestorage.app buckets
    // when SDK version is outdated or bucket URL format is incorrect.
    if (e.code == 'unknown' &&
        (e.message?.contains('400') == true ||
            e.message?.toLowerCase().contains('bad request') == true)) {
      return 'Firebase Storage 400 error on bucket $bucket. '
          'This is usually caused by an outdated SDK or incorrect bucket URL. '
          'Ensure the bucket is gs://$bucket and firebase_storage is up to date.';
    }

    return 'Failed to upload image: [firebase_storage/${e.code}] '
        '${e.message ?? 'Unknown Firebase Storage error'}';
  }
}

/// Exception thrown by StorageService operations.
class StorageException implements Exception {
  StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}
