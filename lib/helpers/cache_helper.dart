/// Cache helper utility for managing application cache
///
/// Provides functionality to calculate cache size and clear cached data
/// including images and temporary files.

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
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
  /// Calculates size from multiple cache locations:
  /// - Flutter's in-memory image cache
  /// - Temporary directory (images, downloaded files)
  /// - Application documents directory (cache subdirectories)
  /// - External cache directories (Android)
  /// - Database files
  static Future<int> getCacheSize() async {
    try {
      int totalSize = 0;
      
      // 1. Calculate Flutter's in-memory image cache size
      try {
        final imageCacheSize = imageCache.currentSizeBytes;
        totalSize += imageCacheSize;
        debugPrint('Image cache size: ${_formatBytes(imageCacheSize)}');
      } catch (e) {
        debugPrint('Error getting image cache size: $e');
      }
      
      // 2. Calculate temporary directory size (main cache location)
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          final tempSize = await _getDirectorySize(tempDir);
          totalSize += tempSize;
          debugPrint('Temporary directory size: ${_formatBytes(tempSize)}');
        }
      } catch (e) {
        debugPrint('Error getting temporary directory size: $e');
      }
      
      // 3. Calculate application documents directory cache subdirectories
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final appDirSize = await _getDirectorySize(appDir, excludeDatabase: true);
        totalSize += appDirSize;
        debugPrint('Application documents directory size: ${_formatBytes(appDirSize)}');
      } catch (e) {
        debugPrint('Error getting application documents directory size: $e');
      }
      
      // 4. Calculate database size
      try {
        final dbPath = await getDatabasesPath();
        final dbDir = Directory(dbPath);
        if (await dbDir.exists()) {
          final dbSize = await _getDirectorySize(dbDir);
          totalSize += dbSize;
          debugPrint('Database directory size: ${_formatBytes(dbSize)}');
        }
      } catch (e) {
        debugPrint('Error getting database directory size: $e');
      }
      
      // 5. Calculate external cache directory size (Android)
      try {
        final externalCacheDir = await getExternalCacheDirectories();
        if (externalCacheDir != null && externalCacheDir.isNotEmpty) {
          for (final dir in externalCacheDir) {
            if (await dir.exists()) {
              final externalSize = await _getDirectorySize(dir);
              totalSize += externalSize;
              debugPrint('External cache directory size: ${_formatBytes(externalSize)}');
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting external cache directory size: $e');
      }
      
      debugPrint('Total cache size: ${_formatBytes(totalSize)}');
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }

  /// Get directory size recursively
  /// [excludeDatabase] - if true, excludes database files from calculation
  static Future<int> _getDirectorySize(Directory dir, {bool excludeDatabase = false}) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              // Skip database files if excludeDatabase is true
              if (excludeDatabase && entity.path.endsWith('.db')) {
                continue;
              }
              final fileSize = await entity.length();
              size += fileSize;
            } catch (e) {
              debugPrint('Error getting file size for ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating directory size for ${dir.path}: $e');
    }
    return size;
  }

  /// Format bytes to human-readable string (internal helper)
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    return _formatBytes(bytes);
  }

  /// Clear all app cache (images, temporary files, etc.)
  /// Clears:
  /// - Flutter's image cache
  /// - Temporary directory contents
  /// - External cache directories (Android)
  /// Note: Database files are NOT deleted to preserve user data
  static Future<void> clearAllCache() async {
    try {
      // 1. Clear Flutter's image cache
      await clearImageCache();
      
      // 2. Clear temporary directory (but preserve database files)
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
            try {
              // Skip database files
              if (entity.path.endsWith('.db') || entity.path.endsWith('.db-journal')) {
                continue;
              }
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                // Check if directory contains database files before deleting
                bool hasDatabaseFiles = false;
                try {
                  await for (final subEntity in entity.list(recursive: true, followLinks: false)) {
                    if (subEntity is File && 
                        (subEntity.path.endsWith('.db') || subEntity.path.endsWith('.db-journal'))) {
                      hasDatabaseFiles = true;
                      break;
                    }
                  }
                } catch (e) {
                  debugPrint('Error checking directory for database files: $e');
                }
                if (!hasDatabaseFiles) {
                  await entity.delete(recursive: true);
                }
              }
            } catch (e) {
              debugPrint('Error deleting cache file ${entity.path}: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error clearing temporary directory: $e');
      }
      
      // 3. Clear external cache directories (Android)
      try {
        final externalCacheDirs = await getExternalCacheDirectories();
        if (externalCacheDirs != null && externalCacheDirs.isNotEmpty) {
          for (final dir in externalCacheDirs) {
            if (await dir.exists()) {
              await for (final entity in dir.list(recursive: true, followLinks: false)) {
                try {
                  // Skip database files
                  if (entity.path.endsWith('.db') || entity.path.endsWith('.db-journal')) {
                    continue;
                  }
                  if (entity is File) {
                    await entity.delete();
                  } else if (entity is Directory) {
                    await entity.delete(recursive: true);
                  }
                } catch (e) {
                  debugPrint('Error deleting external cache file ${entity.path}: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error clearing external cache directories: $e');
      }
      
      debugPrint('All cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
      rethrow;
    }
  }
}

