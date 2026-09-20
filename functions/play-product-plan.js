'use strict';

/**
 * A Play-termék „változatlan?" döntése — tiszta logika, nulla függőség.
 *
 * MIÉRT: a kiadvány-szinkron eddig **minden körben** felküldte az összes terméket
 * a Play Console-ra (egy GET + egy PATCH termékenként), akkor is, ha semmi nem
 * változott. Ez élesben 5 percenként időtúllépéshez vezetett (~475 hibabejegyzés
 * 24 órában), és feleslegesen fogyasztotta a Play API keretét.
 *
 * A javítás szándékosan a **biztonságos** irány: a Play-válasz **megmarad**
 * (tehát a kézzel, a Play Console-ban átírt terméket továbbra is azonnal
 * észrevesszük és javítjuk), csak a **felesleges ÍRÁST** hagyjuk ki. Nincs
 * gyorsítótár és nincs „utolsó szinkron" jelölő, ezért nem tud elavulni.
 *
 * A döntés pontosan azt hasonlítja, amit a PATCH küldene (a kérés törzse:
 * `listings` + `purchaseOptions`, `updateMask: 'listings,purchaseOptions'`):
 *   - a `listings` a PATCH-csel **lecserélődik**, ezért csak akkor egyező, ha a
 *     jelenlegi állapot pontosan az egyetlen `hu-HU` bejegyzés, ugyanazzal a
 *     címmel és leírással;
 *   - a `purchaseOptions`-nél a régiók a jelenlegiből **megmaradnak**, ezért a
 *     régiók számának egyeznie kell, és a `HU` régiónak pontosan a kívánt árat
 *     és elérhetőséget kell mutatnia;
 *   - a `purchaseOptionId` és a `buyOption` megléte is kell (ezeket küldjük).
 *
 * AMIT SZÁNDÉKOSAN NEM HASONLÍT: a `state` (a PATCH nem tartalmazza, tehát nem
 * is változtatná meg — a döntésbe véve csak felesleges írásokat okozna).
 */
function playProductMatches(current, desired) {
  const {
    title = '',
    description = '',
    price = 0,
    purchaseOptionId = 'default',
  } = desired || {};
  if (!current || typeof current !== 'object') return false;
  // Ár nélkül nincs mit összehasonlítani (a hívó ilyenkor nem is hívja).
  if (!Number.isFinite(Number(price)) || Number(price) <= 0) return false;

  const listings = Array.isArray(current.listings) ? current.listings : [];
  if (listings.length !== 1) return false;
  const listing = listings[0] || {};
  if (String(listing.languageCode || '') !== 'hu-HU') return false;
  if (String(listing.title || '') !== String(title)) return false;
  if (String(listing.description || '') !== String(description)) return false;

  const options = Array.isArray(current.purchaseOptions) ? current.purchaseOptions : [];
  const option =
    options.find((item) => String(item?.purchaseOptionId || '') === String(purchaseOptionId)) ||
    (options.length === 1 ? options[0] : null);
  if (!option) return false;
  if (!option.buyOption) return false;

  const configs = Array.isArray(option.regionalPricingAndAvailabilityConfigs)
    ? option.regionalPricingAndAvailabilityConfigs
    : [];
  // A PATCH azokat a régiókat, amelyeknek nincs `regionCode`-juk, ELDOBNÁ —
  // ilyenkor tehát nem mondhatjuk, hogy semmi nem változna.
  if (configs.some((item) => !String(item?.regionCode || ''))) return false;
  const hungary = configs.find((item) => String(item?.regionCode || '') === 'HU');
  if (!hungary) return false;
  if (String(hungary.availability || '') !== 'AVAILABLE') return false;
  const hungaryPrice = hungary.price || {};
  if (String(hungaryPrice.currencyCode || '') !== 'HUF') return false;
  if (String(hungaryPrice.units ?? '') !== String(price)) return false;
  if (Number(hungaryPrice.nanos || 0) !== 0) return false;

  return true;
}

module.exports = { playProductMatches };
