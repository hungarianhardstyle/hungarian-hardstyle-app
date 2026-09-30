/// **A meghívó-jutalom pontjai** — egy helyen, hogy a felület és a szerver ne
/// csússzon el.
///
/// MIÉRT (a tulajdonos választotta a hat irány közül a *„meghívó-jutalom mindkét
/// félnek"* pontot): a **mért kiindulás** szerint a meghívó oldala már élt
/// (50 pont, egyszer), a **meghívott viszont semmit** nem kapott — pedig ő az,
/// aki regisztrál és profilt tölt ki. A szerveroldali döntés a
/// `functions/referral-reward-plan.js`-ben él; ez a fájl a **felület** számára
/// ugyanazokat a számokat adja.
///
/// ⚠️ **AZ ELCSÚSZÁST EGY KAPU ZÁRJA:** a `test/services/referral_reward_test.dart`
/// beolvassa a szerveroldali modult, és megköveteli, hogy a két szám **egyezzen**
/// — ha a szerveren változik a jutalom, a kliens-teszt azonnal elbukik (nem
/// fordulhat elő, hogy a felület mást ígérjen, mint amit a szerver ad).
library;

/// A meghívó jutalma minden olyan barát után, aki a kódjával regisztrál.
const int referralInviterRewardPoints = 50;

/// A meghívott jutalma a regisztrációért (a kezdéshez).
const int referralInviteeRewardPoints = 25;
