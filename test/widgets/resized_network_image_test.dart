import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/widgets/resized_network_image.dart';

/// A görgetés közbeni VILLOGÁS regresszió-védelme.
///
/// **A jelzés:** *„pár dolog, pl a djk, hírek stb scrollozás közben villog,
/// gondolom a háttérbetöltés miatt"*.
///
/// **A gyökér:** a `CachedNetworkImage` alapértéke **500 ms be-** és **1000 ms
/// kiúsztatás**, és ez minden újraépítésnél lefut. Görgetéskor a lista elemei
/// újraépülnek, a kép viszont a gyorsítótárból **azonnal** megjön — vagyis az
/// áttűnés feleslegesen „villant" (a placeholderből/üresből úszott be újra).
///
/// Ez a teszt azt rögzíti, hogy a képet rajzoló widget **áttűnés nélkül**
/// épüljön: `fadeInDuration` és `fadeOutDuration` is `Duration.zero`.
void main() {
  testWidgets('a hálózati kép áttűnés nélkül épül (nincs villogás görgetéskor)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: ResizedNetworkImage(
            url: 'https://res.cloudinary.com/fjxo93em/image/upload/v1/huhs/dj.jpg',
            physicalWidth: 600,
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(
      image.fadeInDuration,
      Duration.zero,
      reason: 'a beúsztatás villogást okoz görgetéskor',
    );
    expect(image.fadeOutDuration, Duration.zero);
  });

  testWidgets('a méret-kérés megmarad (a CDN a kijelzett méretet adja)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 120,
          child: ResizedNetworkImage(
            url: 'https://res.cloudinary.com/fjxo93em/image/upload/v1/huhs/dj.jpg',
            physicalWidth: 360,
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, isNotNull);
    expect(image.memCacheWidth! > 0, isTrue);
  });
}
