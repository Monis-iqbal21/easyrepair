# ──────────────────────────────────────────────────────────────────────────────
# EasyRepair — release ProGuard / R8 rules
#
# The Flutter Gradle plugin already injects flutter_embed_rules.pro which
# covers the Flutter engine itself.  These rules cover the Android-native
# portions of the Flutter plugins used by this app.
# ──────────────────────────────────────────────────────────────────────────────

# ── Flutter plugin registrant (generated at build time) ───────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Firebase (firebase_core, firebase_messaging) ──────────────────────────────
# Firebase bundles consumer rules in its AARs, but explicit keeps prevent
# R8 from stripping reflection-accessed classes in edge cases.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── OkHttp / Okio ─────────────────────────────────────────────────────────────
# Used internally by Firebase Android SDK and other platform libraries.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ── Standard Android keeps ────────────────────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

-keepclassmembers class * implements java.io.Serializable {
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
