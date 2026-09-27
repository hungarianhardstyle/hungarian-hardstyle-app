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

# A Play Console „teljes képernyős mód" javaslata (2026-09-27, mérve).
#
# A `MainActivity.onCreate` **már** meghívja az `enableEdgeToEdge()`-t, a Play
# statikus szkennere viszont a **DEX-ben keresi a nevet** — az R8 pedig a
# `-repackageclasses ''` + `-allowaccessmodification` mellett **beinlajnolja és
# átnevezi**, ezért a 376-os csomagban **0 találat** volt (`tmp/probe-play-suggestions.mjs`):
#   enableEdgeToEdge: 0, EdgeToEdge: 0
# Ezért a definíciót megtartjuk. **MÉRVE a 377-es csomagon**
# (`tmp/probe-edge-to-edge-dex.mjs`, `tmp/probe-edge-to-edge-methods.mjs`):
#   'androidx/activity/EdgeToEdge' előfordulás: 1 (classes.dex) + 24 (classes2.dex)
#   hivatkozó osztály: hu/hungarianhardstyle/app/MainActivity
#   az osztály metódusai: enable / enable$default  (ez a Kotlin-bővítmény JVM-neve)
# Vagyis a szkenner mostantól látja, hogy az app **igényli** a teljes képernyős módot.
#
# ⚠️ A másik jelzés („elavult API-kat használ a teljes képernyős megjelenítéshez")
# **nem** a saját kódunkból jön: a mért tulajdonosok a csomagolt könyvtárak
# (`com.google.android.play.core.common.PlayCoreDialogWrapperActivity` és az
# újracsomagolt androidx-osztályok). Az `android:windowOptOutEdgeToEdgeEnforcement`
# zászlót **nem** használjuk, és a cél-SDK 36-on az Android amúgy is kikényszeríti
# a teljes képernyős módot.
-keep class androidx.activity.EdgeToEdge { *; }
-keepclassmembers class androidx.activity.EdgeToEdge {
    public static void enable(...);
    public static void enable$default(...);
}
