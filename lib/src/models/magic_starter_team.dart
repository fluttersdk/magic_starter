/// Lightweight team DTO used by the starter plugin's team resolver.
///
/// App-specific Team models should provide a `toMagicStarterTeam()` method
/// that converts to this type.
class MagicStarterTeam {
  final dynamic id;
  final String? name;
  final String? photoUrl;
  final bool isPersonalTeam;

  const MagicStarterTeam({
    required this.id,
    this.name,
    this.photoUrl,
    this.isPersonalTeam = false,
  });

  /// Create from a map (e.g. API response).
  factory MagicStarterTeam.fromMap(Map<String, dynamic> map) {
    final personalTeam = map['personal_team'];
    return MagicStarterTeam(
      id: map['id'],
      name: map['name'] as String?,
      photoUrl: map['profile_photo_url'] as String?,
      isPersonalTeam: personalTeam == true || personalTeam == 1,
    );
  }
}
