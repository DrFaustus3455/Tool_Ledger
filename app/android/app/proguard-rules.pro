# Flutter / plugin defaults are handled by the Flutter Gradle plugin.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
# ML Kit barcode scanning (mobile_scanner)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
