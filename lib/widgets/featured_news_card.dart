import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/content/date_formatters.dart';
import '../core/i18n/content_labels.dart';
import '../core/i18n/tr.dart';
import '../models/post.dart';
import '../screens/news/news_detail_screen.dart';
import '../services/wordpress_service.dart';
import 'detail_prefetch.dart';
import 'news_reaction_button.dart';
import 'resized_network_image.dart';

class FeaturedNewsCard extends StatelessWidget {
  final Post post;

  /// Széles (alacsony) nézet: kevesebb cím-sor, kisebb belső hézag.
  ///
  /// ⚠️ MIÉRT (mért hiba, 2026-10-03): fekvő iPhone-on a kártya magassága
  /// **206 px**-re csökken (a tulajdonos kérése: *„túl nagy, bár túl kicsi se
  /// legyen”*), és a 4 soros cím + a nagy belső hézag **kifutott** volna belőle
  /// (a `Column` `Spacer`-e nulla alá nem megy). Álló nézetben (`dense: false`)
  /// minden bitre a régi.
  final bool dense;

  const FeaturedNewsCard({super.key, required this.post, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return DetailPrefetch(
      onPrefetch: () => WordpressService().getPost(post.id),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) *
                0.42)
            .round()
            .clamp(360, 1600);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewsDetailScreen(post: post)),
        );
      },
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Hero(
                tag: "post_${post.id}",
                child: post.imageUrl.isNotEmpty
                    ? FeaturedNewsImageBand(
                        url: post.imageUrl,
                        physicalWidth: imageCacheWidth,
                      )
                    : Container(
                        color: colors.surfaceContainerHighest,
                        child: const Icon(
                          Icons.article,
                          color: Colors.white54,
                          size: 60,
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Container(
                padding: dense
                    ? const EdgeInsets.fromLTRB(14, 10, 12, 10)
                    : const EdgeInsets.fromLTRB(16, 18, 14, 14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  border: Border(
                    left: BorderSide(color: colors.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        post.isSticky
                            ? tr(context, 'KIEMELT HÍR')
                            : tr(context, 'FRISS HÍR'),
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      post.title,
                      maxLines: dense ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    if (post.articleCategories.isNotEmpty) ...[
                      SizedBox(height: dense ? 5 : 8),
                      Text(
                        articleCategoriesLabel(
                          context,
                          post.articleCategories,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          letterSpacing: .3,
                        ),
                      ),
                    ],
                    SizedBox(height: dense ? 7 : 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatHungarianDate(post.date),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NewsReactionButton(postId: post.id),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A kiemelt hír képének sávja (build 405).
///
/// ⚠️ MÉRT HIBA (2026-11-05, a tulajdonos jelzése: *„mondjuk az app főoldalon is
/// fura"*): a kiemelt kártya álló telefonon **358×250 px**, a képsáv ebből
/// `flex: 5/12` = **149×250 px** — vagyis ÁLLÓ. Egy 1200×630-as (1,90) borítóképet
/// `BoxFit.cover`-rel ebbe belekényszerítve a kép **31%-a** látszott: az arcok
/// óriásira nagyítva, a fejek levágva.
///
/// Ezért a sávban a kép **teljes egészében** látszik (`BoxFit.contain`, felülre
/// igazítva) — a látható hányad **31% → 100%** —, a maradékot pedig ugyanannak a
/// képnek az elmosott változata tölti ki. Így egyetlen kép sem vágódik le, akár
/// fekvő, akár álló a borító; a kártya mérete és a szöveg helye **változatlan**.
class FeaturedNewsImageBand extends StatelessWidget {
  const FeaturedNewsImageBand({
    super.key,
    required this.url,
    required this.physicalWidth,
  });

  final String url;
  final int physicalWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) Elmosott háttér: ugyanaz a kép, hogy a sáv ne legyen üres.
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 16,
            sigmaY: 16,
            tileMode: TileMode.clamp,
          ),
          child: ResizedNetworkImage(
            url: url,
            physicalWidth: physicalWidth,
            fit: BoxFit.cover,
          ),
        ),
        // 2) Sötétítés: az éles kép ne „villogjon" a világos elmosott háttéren.
        ColoredBox(color: Colors.black.withValues(alpha: 0.30)),
        // 3) Az ÉLES kép: teljes egészében, felülre igazítva (nem vágja le a fejet).
        Align(
          alignment: Alignment.topCenter,
          child: ResizedNetworkImage(
            url: url,
            physicalWidth: physicalWidth,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        ),
      ],
    );
  }
}
