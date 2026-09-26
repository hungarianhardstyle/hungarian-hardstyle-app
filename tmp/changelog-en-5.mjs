// A Névjegy-changelog angol fordításai — 5. csomag: a **legfrissebb** kiadások
// sorai (ezek a lista ELEJÉN állnak, ezért a fordítók is elöl mennek, a
// legfrissebbel kezdve), valamint a Névjegy egyik sablonja.
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
