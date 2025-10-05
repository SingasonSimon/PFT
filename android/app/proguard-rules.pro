# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Rules for the local_auth plugin to prevent code shrinking issues.
-keep class androidx.core.content.ContextCompat
-keep class androidx.fragment.app.FragmentActivity
-keep class androidx.biometric.BiometricPrompt