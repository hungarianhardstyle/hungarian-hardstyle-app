import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A **közösségi chat** emoji-gombja — kizárólag iOS-en látszik.
///
/// MIÉRT KELL (a tulajdonos jelzése, 2026-09-22, iPhone): *„Androidon van emote a
/// billen, iPhone-on nincs, a chaten sztem kéne egy iPhone-specifikus emote a
/// chatre, ami csak iOS-en látszik."*
///
/// A gyökér **platform-különbség, nem hiba**: Androidon a rendszerbillentyűzeten
/// (Gboard) **van emoji-kulcs** közvetlenül a szöveg mellett, iOS-en viszont az
/// alfabetikus billentyűzeten **nincs** — ott külön billentyűzetre kell váltani.
/// Ezért a közösségi chat beviteli sávjában iOS-en adunk egy gombot, Androidon
/// nem (ott felesleges lenne).
///
/// ⚠️ A **privát chatnek saját** emoji-választója van
/// (`private_messages_screen.dart`), és a tulajdonos kérésére ahhoz **nem
/// nyúlunk** — ezért ez a fájl szándékosan **önálló**, a lista ismétlődik.
/// Az egységesítés külön kör lehet (akkor a privát chat is tesztelt átalakítást
/// kapna).
const chatEmojiChoices = <String>[
  '🙂',
  '😂',
  '🤣',
  '😭',
  '😡',
  '😢',
  '😮',
  '😍',
  '😎',
  '🤔',
  '❤️',
  '🔥',
  '👍',
  '🙌',
  '🎉',
];

/// A gomb **látszik-e** — tiszta döntés, telepítés és plugin nélkül mérhető.
///
/// ⚠️ Csak iOS: Androidon a rendszerbillentyűzet adja az emojit.
bool showsChatEmojiButton(TargetPlatform platform) =>
    platform == TargetPlatform.iOS;

/// A kijelölt helyre szúrja be az emojit (a kurzor helyére), majd a kurzort
/// mögé teszi. Tiszta függvény: `TextEditingController`-rel **tesztelhető**.
void insertChatEmoji(
  TextEditingController controller,
  String emoji, {
  FocusNode? focusNode,
}) {
  final value = controller.value;
  final text = value.text;
  final start = value.selection.start < 0 ? text.length : value.selection.start;
  final end = value.selection.end < 0 ? text.length : value.selection.end;
  controller.value = value.copyWith(
    text: text.replaceRange(start, end, emoji),
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
  focusNode?.requestFocus();
}

/// Az emoji-választó (alsó lap). Visszaadja a választott emojit, vagy `null`-t.
Future<String?> showChatEmojiPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: chatEmojiChoices.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final emoji = chatEmojiChoices[index];
            return Semantics(
              button: true,
              label: emoji,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context, emoji),
                child: Center(
                  // A `FittedBox` a helyére szorítja a platform emoji-glikfját:
                  // némelyik Android-font ascent/descentje nagyobb, mint a rajz.
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26, height: 1),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// A beviteli sáv emoji-gombja. Nem iOS-en **semmit** nem rajzol.
class ChatEmojiButton extends StatelessWidget {
  const ChatEmojiButton({
    super.key,
    required this.controller,
    this.focusNode,
    this.platform,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// ⚠️ Csak **teszteléshez** (illetve ha a hívó már tudja a platformot): a
  /// widget alapból a `defaultTargetPlatform`-ot használja. Azért paraméter, és
  /// nem `debugDefaultTargetPlatformOverride`, mert az utóbbi a keretrendszer
  /// **debug-változója**, amit egy widget-teszt nem állíthat vissza úgy, hogy a
  /// záró invariáns-ellenőrzés ne hasaljon el
  /// („The value of a foundation debug variable was changed by the test.").
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final effectivePlatform = platform ?? defaultTargetPlatform;
    if (!showsChatEmojiButton(effectivePlatform)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Emotikon',
      icon: const Icon(Icons.emoji_emotions_outlined),
      onPressed: () async {
        final emoji = await showChatEmojiPicker(context);
        if (emoji == null) return;
        insertChatEmoji(controller, emoji, focusNode: focusNode);
      },
    );
  }
}
