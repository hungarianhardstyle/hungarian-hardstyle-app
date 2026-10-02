#!/bin/sh
# A KIADOTT plugin-csomag PHP-jĂˇnak ellenĹ‘rzĂ©se â€” a kontĂ©neren belĂĽl fut.
#
#   * 1) szintaxis: `php -l` minden PHP fĂˇjlra;
#   * 2) viselkedĂ©s: `tools/php/plugin-translation-test.php` WordPress-stubokkal,
#        elĹ‘szĂ¶r kulcs nĂ©lkĂĽl/Ă¶rĂ¶kĂ¶lt kulccsal, majd a `HUHS_OPENAI_API_KEY`
#        konstans Ăˇgban (kĂĽlĂ¶n futĂˇs, mert a konstans nem definiĂˇlhatĂł kĂ©tszer).
#
# A plugin a **kibontott ZIP-bĹ‘l** jĂ¶n (`/work/tmp/php-plugin/huhs-mobile-api`),
# vagyis a mĂ©rĂ©s a szĂˇllĂ­tandĂł csomagot nĂ©zi, nem a forrĂˇskĂ¶nyvtĂˇrat.
set -u

PLUGIN="/work/tmp/php-plugin/huhs-mobile-api"
TEST="/work/tools/php/plugin-translation-test.php"
fail=0

echo "=== 1) PHP szintaxis (php -l, minden fĂˇjl)"
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
echo "=== 2) ViselkedĂ©s-teszt (WordPress-stubokkal, valĂłdi PHP)"
if php "$TEST" "$PLUGIN"; then
  echo "VISELKEDES OK"
else
  echo "VISELKEDES HIBA"
  fail=1
fi

echo ""
echo "=== 3) ViselkedĂ©s-teszt az Ă–RĂ–KĂ–LT KONSTANS kulccsal (kĂĽlĂ¶n futĂˇs)"
if php "$TEST" "$PLUGIN" legacy-constant; then
  echo "KONSTANS-AG OK"
else
  echo "KONSTANS-AG HIBA"
  fail=1
fi

# âš ď¸Ź EZ A MEGLĂ‰VĹ, PHP-ban Ă­rt ellenĹ‘rzĹ‘ eszkĂ¶z (a push-lĂˇnc ĂşjraprĂłbĂˇlkozĂˇsa) â€”
# eddig azĂ©rt nem futott, mert nem volt PHP ezen a gĂ©pen. Most a kontĂ©nerben fut.
echo ""
echo "=== 4) A push-lĂˇnc ĂşjraprĂłbĂˇlkozĂˇsa (meglĂ©vĹ‘ PHP-ellenĹ‘rzĹ‘)"
if php /work/tools/verify-push-dedupe.php "$PLUGIN" | tail -4; then
  echo "PUSH-DEDUPE OK"
else
  echo "PUSH-DEDUPE HIBA"
  fail=1
fi

echo ""
echo "=== 5) NyelvenkĂ©nti emlĂ©keztetĹ‘ (2.14.6)"
if php /work/tools/verify-push-language.php "$PLUGIN"; then
  echo "PUSH-NYELV OK"
else
  echo "PUSH-NYELV HIBA"
  fail=1
fi

# âš ď¸Ź A 2.14.11 ĂşjdonsĂˇga: a szavazĂˇs/jĂˇtĂ©k megnyĂ­lĂˇsa. A mĂ©rĂ©s a TELJES kĂĽldĂ©si
# lĂˇncot futtatja stubolt FCM-mel (nyelvenkĂ©nti szĂ¶veg, frissessĂ©gi kapu,
# idempotencia, ĂĽtemezĂ©s) â€” nem csak azt nĂ©zi, hogy â€žszerepel-e a szĂ¶vegben".
echo ""
echo "=== 6) SzavazĂˇs/jĂˇtĂ©k megnyĂ­lĂˇsa (2.14.11)"
if php /work/tools/verify-push-open-notice.php "$PLUGIN"; then
  echo "PUSH-OPEN OK"
else
  echo "PUSH-OPEN HIBA"
  fail=1
fi

# âš ď¸Ź A 2.14.12 ĂşjdonsĂˇga: a HĂŤR-PUSH ĹRE. Ă‰les mĂ©rĂ©s szerint (2026-09-30) a nap
# kĂ©t cikke utĂˇn egyetlen push sem indult, mert a kĂ¶zzĂ©tĂ©tel-hook nem futott le
# (a kĂĽldĂ©si lĂˇnc viszont jĂł: kĂ©zzel 1024 eszkĂ¶z, 0 hiba). A mĂ©rĂ©s a teljes
# lĂˇncot futtatja stubolt FCM-mel, Ă©s a frissessĂ©gi kaput is.
echo ""
echo "=== 7) A hĂ­r-push Ĺ‘re (2.14.12)"
if php /work/tools/verify-push-news-watchdog.php "$PLUGIN"; then
  echo "PUSH-NEWS OK"
else
  echo "PUSH-NEWS HIBA"
  fail=1
fi

# âš ď¸Ź A 2.14.13 ĂşjdonsĂˇga: a kifutĂˇs sebessĂ©ge (a tulajdonos jelzĂ©se: â€žcsak lassan
# jĂ¶tt"). A mĂ©rĂ©s a kereteket Ă‰S a lĂˇnc pontossĂˇgĂˇt nĂ©zi: a folytatĂˇs 1 mĂˇsodperc,
# a kĂ¶rĂ¶k nem ismĂ©telnek, a feladat a vĂ©gĂ©n megszĹ±nik.
echo ""
echo "=== 8) A push-kifutĂˇs sebessĂ©ge (2.14.13)"
if php /work/tools/verify-push-speed.php "$PLUGIN"; then
  echo "PUSH-SPEED OK"
else
  echo "PUSH-SPEED HIBA"
  fail=1
fi

# âš ď¸Ź A 2.14.15 ĂşjdonsĂˇga: a TWITCH-BEHARANGOZĂ“ a plugin adminjĂˇban (a tulajdonos
# jelzĂ©se: â€žnem lĂˇtok sehol olyan opciĂłt, ahol meg tudok adni twitch stream
# beharangozĂłt"). A mĂ©rĂ©s a valĂłdi PHP-t futtatja: a vĂ©gpont, az admin-oldal, a
# tisztĂ­tĂˇs szabĂˇlyai Ă©s az alapĂ©rtĂ©k (nem kapcsolja ki a mĹ±kĂ¶dĹ‘ Ă©lĹ‘ kĂˇrtyĂˇt).
echo ""
echo "=== 9) Twitch beharangozĂł a plugin adminjĂˇban (2.14.15)"
if php /work/tools/verify-twitch-card.php "$PLUGIN"; then
  echo "TWITCH-CARD OK"
else
  echo "TWITCH-CARD HIBA"
  fail=1
fi


# ⚠️ A 2.14.18 újdonsága: a NYEREMÉNYJÁTÉKBÓL való törlés (a tulajdonos kérése:
# „ha valaki törli a regisztrációját az appban, kerüljön ki a neve a
# nyereményjátékból is, ne nyerhessen jegyet”). A mérés a valódi PHP-t futtatja:
# csak a törölt játékos sora tűnik el (minden játékból), a nyertes jelölése is
# törlődik, a többi játékos érintetlen, és a művelet idempotens.
echo ""
echo "=== 10) A nyereményjátékból való törlés (2.14.18)"
if php /work/tools/verify-prize-forget.php "$PLUGIN"; then
  echo "PRIZE-FORGET OK"
else
  echo "PRIZE-FORGET HIBA"
  fail=1
fi

exit $fail