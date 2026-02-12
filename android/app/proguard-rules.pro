# Existing rules...
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeToken
-keepattributes Signature
-keepattributes *Annotation*

# ADD THESE NEW LINES:
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepclassmembers class * {
  @android.webkit.JavascriptInterface <methods>;
}