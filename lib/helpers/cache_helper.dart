// lib/helpers/cache_helper.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class CacheHelper {
  /// Clear Flutter's image cache
  static Future<void> clearImageCache() async {
    try {
      imageCache.clear();
      imageCache.clearLiveImages();
      // Force evict all images
      imageCache.clear();
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
      
      // 1. Flutter's image cache (current size in memory)
      totalSize += imageCache.currentSizeBytes;
      
      // 2. Get temporary/cache directory
      final cacheDir = await getTemporaryDirectory();
      
      // 3. Calculate size of entire cache directory recursively
      // This includes all subdirectories and files
      if (await cacheDir.exists()) {
        try {
          // Get all files and directories recursively
          await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
            try {
              if (entity is File) {
                // Skip database files
                final fileName = path.basename(entity.path);
                if (!fileName.contains('PersonalFinanceTracker.db') && 
                    !fileName.contains('.db-journal') &&
                    !fileName.contains('.db-wal') &&
                    !fileName.contains('.db-shm')) {
                  try {
                    final fileSize = await entity.length();
                    totalSize += fileSize;
                  } catch (e) {
                    debugPrint('Error getting file size for ${entity.path}: $e');
                  }
                }
              }
            } catch (e) {
              debugPrint('Error processing cache entity: $e');
            }
          }
        } catch (e) {
          debugPrint('Error listing cache directory: $e');
          // Fallback: try to get directory size directly
          totalSize += await _getDirectorySize(cacheDir);
        }
      }
      
      // 4. Check external cache directories (Android)
      try {
        final externalCacheDirs = await getExternalCacheDirectories();
        if (externalCacheDirs != null) {
          for (final externalCacheDir in externalCacheDirs) {
            if (externalCacheDir != null && await externalCacheDir.exists()) {
              totalSize += await _getDirectorySize(externalCacheDir);
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking external cache directories: $e');
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
      // 1. Clear Flutter's image cache (in memory) - do this multiple times to ensure it's cleared
      imageCache.clear();
      imageCache.clearLiveImages();
      imageCache.clear();
      await Future.delayed(const Duration(milliseconds: 50));
      imageCache.clear();
      
      // 2. Clear temporary/cache directory (but preserve database)
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        try {
          // Delete all files and directories recursively, but skip database files
          await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
            try {
              if (entity is File) {
                final fileName = path.basename(entity.path);
                // Skip database files
                if (!fileName.contains('PersonalFinanceTracker.db') && 
                    !fileName.contains('.db-journal') &&
                    !fileName.contains('.db-wal') &&
                    !fileName.contains('.db-shm')) {
                  try {
                    await entity.delete();
                  } catch (e) {
                    debugPrint('Error deleting cache file ${entity.path}: $e');
                  }
                }
              } else if (entity is Directory) {
                final dirName = path.basename(entity.path);
                // Skip database directories
                if (!dirName.contains('database') && 
                    !dirName.contains('databases') &&
                    !dirName.contains('PersonalFinanceTracker')) {
                  try {
                    // Check if directory is empty or only contains database files
                    final contents = await entity.list().toList();
                    final hasNonDbFiles = contents.any((item) {
                      if (item is File) {
                        final name = path.basename(item.path);
                        return !name.contains('.db') && !name.contains('PersonalFinanceTracker');
                      }
                      return true;
                    });
                    if (hasNonDbFiles) {
                      await entity.delete(recursive: true);
                    }
                  } catch (e) {
                    debugPrint('Error deleting cache directory ${entity.path}: $e');
                  }
                }
              }
            } catch (e) {
              debugPrint('Error processing cache entity: $e');
            }
          }
        } catch (e) {
          debugPrint('Error listing cache directory for deletion: $e');
        }
      }
      
      // 3. Clear external cache directories (Android)
      try {
        final externalCacheDirs = await getExternalCacheDirectories();
        if (externalCacheDirs != null) {
          for (final externalCacheDir in externalCacheDirs) {
            if (externalCacheDir != null && await externalCacheDir.exists()) {
              try {
                await for (final entity in externalCacheDir.list(recursive: true, followLinks: false)) {
                  try {
                    if (entity is File) {
                      await entity.delete();
                    } else if (entity is Directory) {
                      await entity.delete(recursive: true);
                    }
                  } catch (e) {
                    debugPrint('Error deleting external cache entity: $e');
                  }
                }
              } catch (e) {
                debugPrint('Error clearing external cache directory: $e');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking external cache directories: $e');
      }
      
      // 4. Force a small delay to ensure deletions complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 5. Clear image cache one more time
      imageCache.clear();
      
      debugPrint('All cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
      rethrow;
    }
  }
}

