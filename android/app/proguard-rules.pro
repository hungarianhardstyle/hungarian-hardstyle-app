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
