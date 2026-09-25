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
if php /work/tools/verify-push-dedupe.php | tail -3; then
  echo "PUSH-DEDUPE OK"
else
  echo "PUSH-DEDUPE HIBA"
  fail=1
fi

exit $fail
