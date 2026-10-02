#!/bin/sh
# A KIADOTT plugin-csomag PHP-jának ellenőrzése — a konténeren belül fut.
#
#   * 1) szintaxis: `php -l` minden PHP fájlra;
#   * 2) viselkedés: `tools/php/plugin-translation-test.php` WordPress-stubokkal,
#        először kulcs nélkül/örökölt kulccsal, majd a `HUHS_OPENAI_API_KEY`
#        konstans ágban (külön futás, mert a konstans nem definiálható kétszer).
#
# A plugin a **kibontott ZIP-ből** jön (`/work/tmp/php-plugin/huhs-mobile-api`),
# vagyis a mérés a szállítandó csomagot nézi, nem a forráskönyvtárat.
set -u

PLUGIN="/work/tmp/php-plugin/huhs-mobile-api"
TEST="/work/tools/php/plugin-translation-test.php"
fail=0

echo "=== 1) PHP szintaxis (php -l, minden fájl)"
count=0
for f in $(find "$PLUGIN" -name '*.php' | sort); do
  count=$((count + 1))
  if ! out=$(php -l "$f" 2>&1); then
    echo "SYNTAX HIBA: $f"
    echo "$out"
    fail=1
  fi
done
echo "lintelt PHP fajl: $count"
[ "$fail" -eq 0 ] && echo "PHP LINT OK"

echo ""
echo "=== 2) Viselkedés-teszt (WordPress-stubokkal, valódi PHP)"
if php "$TEST" "$PLUGIN"; then
  echo "VISELKEDES OK"
else
  echo "VISELKEDES HIBA"
  fail=1
fi

echo ""
echo "=== 3) Viselkedés-teszt az ÖRÖKÖLT KONSTANS kulccsal (külön futás)"
if php "$TEST" "$PLUGIN" legacy-constant; then
  echo "KONSTANS-AG OK"
else
  echo "KONSTANS-AG HIBA"
  fail=1
fi

# ⚠️ EZ A MEGLÉVŐ, PHP-ban írt ellenőrző eszköz (a push-lánc újrapróbálkozása) —
# eddig azért nem futott, mert nem volt PHP ezen a gépen. Most a konténerben fut.
echo ""
echo "=== 4) A push-lánc újrapróbálkozása (meglévő PHP-ellenőrző)"
if php /work/tools/verify-push-dedupe.php "$PLUGIN" | tail -4; then
  echo "PUSH-DEDUPE OK"
else
  echo "PUSH-DEDUPE HIBA"
  fail=1
fi

echo ""
echo "=== 5) Nyelvenkénti emlékeztető (2.14.6)"
if php /work/tools/verify-push-language.php "$PLUGIN"; then
  echo "PUSH-NYELV OK"
else
  echo "PUSH-NYELV HIBA"
  fail=1
fi

# ⚠️ A 2.14.11 újdonsága: a szavazás/játék megnyílása. A mérés a TELJES küldési
# láncot futtatja stubolt FCM-mel (nyelvenkénti szöveg, frissességi kapu,
# idempotencia, ütemezés) — nem csak azt nézi, hogy „szerepel-e a szövegben".
echo ""
echo "=== 6) Szavazás/játék megnyílása (2.14.11)"
if php /work/tools/verify-push-open-notice.php "$PLUGIN"; then
  echo "PUSH-OPEN OK"
else
  echo "PUSH-OPEN HIBA"
  fail=1
fi

# ⚠️ A 2.14.12 újdonsága: a HÍR-PUSH ŐRE. Éles mérés szerint (2026-09-30) a nap
# két cikke után egyetlen push sem indult, mert a közzététel-hook nem futott le
# (a küldési lánc viszont jó: kézzel 1024 eszköz, 0 hiba). A mérés a teljes
# láncot futtatja stubolt FCM-mel, és a frissességi kaput is.
echo ""
echo "=== 7) A hír-push őre (2.14.12)"
if php /work/tools/verify-push-news-watchdog.php "$PLUGIN"; then
  echo "PUSH-NEWS OK"
else
  echo "PUSH-NEWS HIBA"
  fail=1
fi

# ⚠️ A 2.14.13 újdonsága: a kifutás sebessége (a tulajdonos jelzése: „csak lassan
# jött"). A mérés a kereteket ÉS a lánc pontosságát nézi: a folytatás 1 másodperc,
# a körök nem ismételnek, a feladat a végén megszűnik.
echo ""
echo "=== 8) A push-kifutás sebessége (2.14.13)"
if php /work/tools/verify-push-speed.php "$PLUGIN"; then
  echo "PUSH-SPEED OK"
else
  echo "PUSH-SPEED HIBA"
  fail=1
fi

# ⚠️ A 2.14.15 újdonsága: a TWITCH-BEHARANGOZÓ a plugin adminjában (a tulajdonos
# jelzése: „nem látok sehol olyan opciót, ahol meg tudok adni twitch stream
# beharangozót"). A mérés a valódi PHP-t futtatja: a végpont, az admin-oldal, a
# tisztítás szabályai és az alapérték (nem kapcsolja ki a működő élő kártyát).
echo ""
echo "=== 9) Twitch beharangozó a plugin adminjában (2.14.15)"
if php /work/tools/verify-twitch-card.php "$PLUGIN"; then
  echo "TWITCH-CARD OK"
else
  echo "TWITCH-CARD HIBA"
  fail=1
fi

exit $fail
