/**
 * A fordítási meta kulcsai — **egy helyen**.
 *
 * MIÉRT: ugyanezt a három kulcsot használja a cikk-író, a tartalom-író és a
 * plugin is. Az első változatban a tartalom-író a cikk-íróból importálta — az
 * viszont a modul betöltésekor lefutott (`main()`), ezért a két eszköz
 * összekeveredett. Ez a kis modul ezt oldja meg: nincs mellékhatása.
 *
 * A kulcsok a plugin `includes/post-translation-meta.php`-jában vannak
 * regisztrálva (`huhs_translation_post_types()` típusaira).
 */
export const META_KEYS = {
  title: '_huhs_title_en',
  excerpt: '_huhs_excerpt_en',
  content: '_huhs_content_en',
};
