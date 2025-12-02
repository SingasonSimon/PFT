// lib/helpers/cache_helper.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CacheHelper {
  /// Clear Flutter's image cache
  static Future<void> clearImageCache() async {
    try {
      imageCache.clear();
      imageCache.clearLiveImages();
      debugPrint('Image cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
      rethrow;
    }
  }

  /// Get app cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      int totalSize = 0;
      
      // Get application documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      
      // Calculate size of database
      final dbFile = File('${appDir.path}/../databases/PersonalFinanceTracker.db');
      if (await dbFile.exists()) {
        totalSize += await dbFile.length();
      }
      
      // Calculate size of cache directory (images, etc.)
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        totalSize += await _getDirectorySize(cacheDir);
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }

  /// Get directory size recursively
  static Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              size += await entity.length();
            } catch (e) {
              debugPrint('Error getting file size: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }
    return size;
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Clear all app cache (images, temporary files, etc.)
  static Future<void> clearAllCache() async {
    try {
      // Clear image cache
      await clearImageCache();
      
      // Clear temporary directory
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            debugPrint('Error deleting cache file: $e');
          }
        }
      }
      
      debugPrint('All cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
      rethrow;
    }
  }
}

