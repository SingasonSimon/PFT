/// Cache helper utility for managing application cache
///
/// Provides functionality to calculate cache size and clear cached data
/// including images and temporary files.

import 'package:flutter/material.dart';
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
  /// Calculates size from cache locations (excludes database files as they are user data, not cache):
  /// - Flutter's in-memory image cache
  /// - Temporary directory (images, downloaded files)
  /// - Application documents directory (cache subdirectories, excluding database)
  /// - External cache directories (Android)
  /// Note: Database files are NOT included as they are user data, not cache
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
      // Exclude database files from temp directory
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          final tempSize = await _getDirectorySize(tempDir, excludeDatabase: true);
          totalSize += tempSize;
          debugPrint('Temporary directory size: ${_formatBytes(tempSize)}');
        }
      } catch (e) {
        debugPrint('Error getting temporary directory size: $e');
      }
      
      // 3. Calculate application documents directory cache subdirectories
      // Exclude database files as they are user data
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final appDirSize = await _getDirectorySize(appDir, excludeDatabase: true);
        totalSize += appDirSize;
        debugPrint('Application documents directory size: ${_formatBytes(appDirSize)}');
      } catch (e) {
        debugPrint('Error getting application documents directory size: $e');
      }
      
      // 4. Calculate external cache directory size (Android)
      // Exclude database files from external cache
      try {
        final externalCacheDir = await getExternalCacheDirectories();
        if (externalCacheDir != null && externalCacheDir.isNotEmpty) {
          for (final dir in externalCacheDir) {
            if (await dir.exists()) {
              final externalSize = await _getDirectorySize(dir, excludeDatabase: true);
              totalSize += externalSize;
              debugPrint('External cache directory size: ${_formatBytes(externalSize)}');
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting external cache directory size: $e');
      }
      
      debugPrint('Total cache size (excluding database): ${_formatBytes(totalSize)}');
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }

  /// Get directory size recursively
  /// [excludeDatabase] - if true, excludes database files and related files from calculation
  static Future<int> _getDirectorySize(Directory dir, {bool excludeDatabase = false}) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              // Skip database files if excludeDatabase is true
              if (excludeDatabase) {
                final path = entity.path.toLowerCase();
                if (path.endsWith('.db') || 
                    path.endsWith('.db-journal') || 
                    path.endsWith('.db-wal') ||
                    path.endsWith('.db-shm')) {
                  continue;
                }
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
              final path = entity.path.toLowerCase();
              if (path.endsWith('.db') || 
                  path.endsWith('.db-journal') || 
                  path.endsWith('.db-wal') ||
                  path.endsWith('.db-shm')) {
                continue;
              }
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                // Check if directory contains database files before deleting
                bool hasDatabaseFiles = false;
                try {
                  await for (final subEntity in entity.list(recursive: true, followLinks: false)) {
                    if (subEntity is File) {
                      final subPath = subEntity.path.toLowerCase();
                      if (subPath.endsWith('.db') || 
                          subPath.endsWith('.db-journal') || 
                          subPath.endsWith('.db-wal') ||
                          subPath.endsWith('.db-shm')) {
                        hasDatabaseFiles = true;
                        break;
                      }
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
      
      // 3. Clear cacheable files from application documents directory
      // Preserve important files like shared preferences, database files, and Flutter assets
      try {
        final appDir = await getApplicationDocumentsDirectory();
        if (await appDir.exists()) {
          await for (final entity in appDir.list(recursive: true, followLinks: false)) {
            try {
              if (entity is File) {
                final path = entity.path.toLowerCase();
                // Skip important files: database, shared preferences, Flutter assets, and other user data
                if (path.endsWith('.db') || 
                    path.endsWith('.db-journal') || 
                    path.endsWith('.db-wal') ||
                    path.endsWith('.db-shm') ||
                    path.contains('shared_prefs') ||
                    path.contains('flutter_assets') ||
                    path.contains('kernel_blob') ||
                    path.contains('vm_snapshot') ||
                    path.contains('isolate_snapshot') ||
                    path.endsWith('.xml') ||
                    path.endsWith('.json')) {
                  continue;
                }
                // Delete cacheable files (images, temp files, etc.)
                await entity.delete();
              } else if (entity is Directory) {
                final dirPath = entity.path.toLowerCase();
                // Skip Flutter assets directory
                if (dirPath.contains('flutter_assets')) {
                  continue;
                }
                // Check if directory contains important files before deleting
                bool hasImportantFiles = false;
                try {
                  await for (final subEntity in entity.list(recursive: true, followLinks: false)) {
                    if (subEntity is File) {
                      final subPath = subEntity.path.toLowerCase();
                      if (subPath.endsWith('.db') || 
                          subPath.endsWith('.db-journal') || 
                          subPath.endsWith('.db-wal') ||
                          subPath.endsWith('.db-shm') ||
                          subPath.contains('shared_prefs') ||
                          subPath.contains('flutter_assets') ||
                          subPath.contains('kernel_blob') ||
                          subPath.contains('vm_snapshot') ||
                          subPath.contains('isolate_snapshot') ||
                          subPath.endsWith('.xml') ||
                          subPath.endsWith('.json')) {
                        hasImportantFiles = true;
                        break;
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('Error checking directory for important files: $e');
                  hasImportantFiles = true; // Err on the side of caution
                }
                if (!hasImportantFiles) {
                  await entity.delete(recursive: true);
                }
              }
            } catch (e) {
              // Silently skip errors for files that don't exist or can't be deleted
              // (e.g., Flutter framework files)
            }
          }
        }
      } catch (e) {
        debugPrint('Error clearing application documents directory: $e');
      }
      
      // 4. Clear external cache directories (Android)
      try {
        final externalCacheDirs = await getExternalCacheDirectories();
        if (externalCacheDirs != null && externalCacheDirs.isNotEmpty) {
          for (final dir in externalCacheDirs) {
            if (await dir.exists()) {
              await for (final entity in dir.list(recursive: true, followLinks: false)) {
                try {
                  // Skip database files
                  final path = entity.path.toLowerCase();
                  if (path.endsWith('.db') || 
                      path.endsWith('.db-journal') || 
                      path.endsWith('.db-wal') ||
                      path.endsWith('.db-shm')) {
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

