// A Névjegy-changelog angol fordításai — 1. csomag (0–32. sor).
//
// A kulcs a `tmp/changelog-hu.json` MEGFELELŐ indexe (a magyar sor), ezért itt
// csak az angol szövegek állnak: így nem kell a hosszú magyar sorokat újra
// leírni, és a párosítás **index szerint** ellenőrizhető (a hiányzó/többlet sor
// azonnal kiderül). A szövegek szándékosan **ékezet nélküliek** (a szótár-kapu
// az angol értékben jelzi a magyar ékezetet).
export default [
  'Fixed: on the English interface the Game results screen header (and the "GAME RESULTS" badge on the home screen) now appears in English — these used to stay Hungarian.',
  'Fixed: on the English interface the reply preview is now in English in the Chat and in comments ("Reply to … message / comment").',
  'Fixed: more labels that stayed Hungarian — the comment prefix, the privacy policy and the My music help texts (the dictionary could not find these before).',
  'Fixed: the release date label ("Release: …") and the "Appearances" section of the DJ profile now appear in English on the English interface too.',
  'Fixed: when you switch language, the loaded content (news, events, DJs, releases) switches to the selected language immediately — it used to lag because of the saved list.',
  'The help section is called "FAQ" in English, and its answers no longer contain formatting junk (the `</p>` tags are gone).',
  'NEW: the home screen and the News tab refresh by themselves — a new article shows up within a minute, without pulling down; when the app comes to the foreground (for example you open it from a notification) we check immediately.',
  'NEW in the Chat: tapping a reply quote makes the app JUMP to the original message in the conversation (and highlights it briefly) — it does not open a separate window.',
  'On the English interface the "partygoer" role label is now "Partyface".',
  'Notifications also arrive in the language you selected: the text of the Chat like, the reply, the mention, the comment, the event rating, new content, the prize and the friend request all appear in English if you switched to English.',
  'Your chosen language is stored in your profile, so push notifications speak your language too.',
  'The English interface has been extended further: the long explanatory and legal texts (privacy policy, help pages) also appear in English.',
  'On the English interface the news category and tag names appear in English too (for example Hirek becomes News, fesztival becomes festival) — DJ and brand names stay unchanged.',
  'On the English interface Achievement names and descriptions appear in English too — in the HUHS Legend leaderboard and in the community list as well — and the "Community" button label now fits in the header.',
  'Several hundred more labels appear in English on the English interface: the texts of lists, cards, buttons and status messages that had partly stayed Hungarian.',
  'The Hungarian interface is unchanged, and the Chat as well as the users own texts are still not translated.',
  'On the English interface the latest articles appear in English too — the translation comes from the server.',
  'When you switch language the loaded content is refreshed as well, so no list in the other language stays on the screen.',
  'On several screens (More, Settings, About, newsletter, music) the longer explanatory texts also appear in English.',
  'NEW: HU/EN language switch in the top right corner of the home screen — the app interface (menus, buttons, messages) is available in English too.',
  'Hungarian stays the default and your choice is remembered. The Chat and the users own texts are not translated.',
  'NEW in the Chat: @everyone — if you type it, everyone gets a notification about the message. Only an admin or moderator can use it.',
  'Tapping a Chat notification now takes the app exactly to the marked message even among deeper, older messages.',
  'Tapping a Chat notification now ALWAYS takes the app to the marked message — on a cold start (when the Chat had not been opened yet) this could fail before.',
  'NEW in the Chat: you can reference someone or something with @ — a person, an article, a DJ, an organizer, an event and a release. Just type the @ sign and the first letters of the name and the options pop up.',
  'The reference is clickable: for a person their profile, for an article the article, for a DJ their profile, and for an organizer, an event and a release their own page opens.',
  'If you mention someone, they get a notification about it, and tapping it takes them straight to that Chat message.',
  'Notifications now show WHO liked your Chat message and who commented on an article — before it only said "liked" and "someone commented".',
  'Tapping a Chat notification takes the Chat straight to the message the notification is about and highlights it briefly — you do not have to find it yourself.',
  'For the newsletter the confirmation email is no longer sent again to an address that already received it — the screen tells you that you have already subscribed, or that you can request it again soon. Before, confirmation emails could be generated for the same address without limit.',
  'NEW: the DJ profile now shows the appearances of the DJ — the releases they feature on. The newest is first, up to four, and the "All appearances" button below opens the full list.',
  'The release card is the same as in the releases list: it shows the cover, the artists, the release date and the genre, and tapping it opens the details page.',
  'The section appears instantly from the saved data, and it is only shown if the DJ has appearances — it does not leave an empty gap.',
];
