enum MarketAccessLevel { viewer, editor }

extension MarketAccessLevelX on MarketAccessLevel {
  String get databaseValue => name;

  String get label => switch (this) {
    MarketAccessLevel.viewer => 'Nur ansehen',
    MarketAccessLevel.editor => 'Bearbeiten',
  };

  static MarketAccessLevel fromDatabase(String value) =>
      value == MarketAccessLevel.editor.name
      ? MarketAccessLevel.editor
      : MarketAccessLevel.viewer;
}

class MarketSession {
  const MarketSession({required this.marketId, required this.accessLevel});

  final String marketId;
  final MarketAccessLevel accessLevel;

  bool get canEdit => accessLevel == MarketAccessLevel.editor;

  factory MarketSession.fromRpc(Map<String, dynamic> value) => MarketSession(
    marketId: value['market_id'] as String,
    accessLevel: MarketAccessLevelX.fromDatabase(
      value['access_level'] as String? ?? '',
    ),
  );
}
