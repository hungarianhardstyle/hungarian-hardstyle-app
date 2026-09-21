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

# Az audio_service (a megvásárolt zenék háttér-lejátszása) a médiamunkamenetet az
# Activity TÍPUSÁRA építi: a plugin `context instanceof AudioServiceFragmentActivity`
# ellenőrzést végez, a szolgáltatást és a fejhallgató-vevőt pedig a manifest nevezi
# meg. R8 teljes módban ezt az osztályt BEPAKOLTA egy másikba (a release mapping
# szerint `AudioServiceFragmentActivity -> R8$$REMOVED$$CLASS$$…`), ami éles
# buildben némán megváltoztathatja a viselkedést — vagyis a zárképernyős
# vezérlés „csak a release-ben" nem működne. Ezért ezeket megtartjuk.
-keep class com.ryanheise.audioservice.** { *; }
