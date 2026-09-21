/// A DJ-adatlap **claim-állapota** — a szerver döntése.
///
/// MIÉRT EZ A MODELL: a tulajdonos kérése szerint a claim gomb *„csak akkor
/// jelenjen meg, ha valamelyik email cím egyezik (booking vagy privát)"* — ezt a
/// döntést a szerver hozza (`functions/artist-claim-plan.js`), mert a privát
/// e-mail cím **nem szivároghat ki** a kliensre. A felület csak ennyit tud meg:
/// foglalt-e, az enyém-e, és claimelhetem-e.
class ArtistClaimStatus {
  const ArtistClaimStatus({
    required this.claimed,
    required this.mine,
    required this.canClaim,
    this.reason = '',
  });

  /// Biztonságos alapállapot (ismeretlen adat / hiba esetén): **nem** kínálunk
  /// claim gombot, mert nem tudjuk, hogy szabad-e.
  static const ArtistClaimStatus unknown = ArtistClaimStatus(
    claimed: false,
    mine: false,
    canClaim: false,
  );

  /// Bárki claimelte-e már az adatlapot?
  final bool claimed;

  /// Az **én** claimem-e?
  final bool mine;

  /// Claimelhetem-e most (egyezik valamelyik e-mail cím)?
  final bool canClaim;

  /// A szerver indoklása (diagnosztika; a felület nem mutatja).
  final String reason;

  factory ArtistClaimStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return unknown;
    return ArtistClaimStatus(
      claimed: json['claimed'] == true,
      mine: json['mine'] == true,
      canClaim: json['canClaim'] == true,
      reason: json['reason'] is String ? json['reason'] as String : '',
    );
  }
}
