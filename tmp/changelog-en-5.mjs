// A Névjegy-changelog angol fordításai — 5. csomag: a **legfrissebb** kiadások
// sorai (ezek a lista ELEJÉN állnak, ezért a fordítók is elöl mennek, a
// legfrissebbel kezdve), valamint a Névjegy egyik sablonja.
export const release373 = [
  'Fixed: the news categories (on the cards and in the article header) appear in English on the English interface too.',
  'Fixed: the "&amp;" encoding artefact no longer appears in DJ and organizer descriptions — it shows "&" instead.',
  'Fixed: on the English interface the event friends line, the yearly name/e-mail change notice, the "Unlocked with an ad" label and the friend count are in English too.',
  'Fixed: a duplicated word was removed from the Hungarian points notification text.',
];

export const release372 = [
  'Fixed: when you switch language an already open article, event or release page also switches to the selected language immediately.',
];

export const release371 = [
  'NEW: an @everyone mention in the Chat now also sends a push notification (banner) — personal @mentions stay silent.',
  'The sender of an @everyone message gets feedback: how many recipients and how many devices were notified.',
  'Fixed: when you switch language the news list switches over immediately as well — no need to restart the app.',
];

export const release370 = [
  'Fixed: the title of the article (and of the release, event or DJ) in notifications now appears in the selected language as well.',
  'Titles in the notifications you already received are translated too — you do not have to wait for new ones.',
];

export const release369 = [
  'Fixed: on the English interface notification texts appear instantly in the selected language — older notifications are translated too, you do not have to wait for new ones.',
  'Fixed: the title of a private message notification also speaks the selected language (it used to be Hungarian).',
  'Fixed: the "archived" title of the delete-notifications dialog appears in English as well.',
];

export const release368 = [
  'Fixed: on the English interface the release notes (About → What is new) appear in English as well — the full history, back to the earliest releases.',
  'The release note lines are now translated from the dictionary, so they switch to the selected language instantly.',
];

/** Nem changelog-sor, hanem a Névjegy egyik sablonja (a `{n}` a verziókód). */
export const extraKeys = {
  'Ehhez a verzióhoz ({n}) még nincs kiadási jegyzet.':
    'There are no release notes for version {n} yet.',
};
