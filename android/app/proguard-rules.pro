-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
-keep class androidx.media3.session.** { *; }

# Optional classes referenced by Rhino (via a dependency) that do not exist on Android.
-dontwarn java.beans.**
-dontwarn org.mozilla.javascript.**
-dontwarn javax.script.**
