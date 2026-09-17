# Flutter, Firebase and AndroidX use their published consumer rules.
# Keep this file available for only project-specific rules when R8 reports one.

# Enable R8 class repackaging and access modification for the Play optimization
# metric. This applies to the release configuration through build.gradle.kts.
-repackageclasses ''
-allowaccessmodification

# R8 full mode must not rename Room's generated WorkManager database. It is
# instantiated from Room metadata during AndroidX Startup before Flutter runs.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.model.** { *; }

# Firebase's ComponentDiscovery instantiates ComponentRegistrar classes through
# reflection. R8 full mode kept the class names but removed their no-arg
# constructors, so Firebase App Check (Play Integrity attestation) silently
# failed to register in release builds:
#   NoSuchMethodException: ...FirebaseAppCheckPlayIntegrityRegistrar.<init> []
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep class com.google.firebase.appcheck.** { *; }
