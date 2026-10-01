class BankTemplate {
  final String id;
  final String name;
  final String logoAsset;
  final int iconCodePoint;
  final String colorHex;

  const BankTemplate({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.iconCodePoint,
    required this.colorHex,
  });

  static const List<BankTemplate> templates = [
    BankTemplate(
      id: 'bdo',
      name: 'BDO',
      logoAsset: 'assets/logos/bdo.png',
      iconCodePoint: 0xe069, // Icons.account_balance_rounded
      colorHex: '#093574',
    ),
    BankTemplate(
      id: 'bpi',
      name: 'BPI',
      logoAsset: 'assets/logos/bpi.png',
      iconCodePoint: 0xe069,
      colorHex: '#C62828',
    ),
    BankTemplate(
      id: 'cimb',
      name: 'CIMB',
      logoAsset: 'assets/logos/cimb.png',
      iconCodePoint: 0xe069,
      colorHex: '#D50000',
    ),
    BankTemplate(
      id: 'eastwest',
      name: 'EastWest',
      logoAsset: 'assets/logos/eastwest.png',
      iconCodePoint: 0xe069,
      colorHex: '#B3BD43',
    ),
    BankTemplate(
      id: 'gcash',
      name: 'GCash',
      logoAsset: 'assets/logos/gcash.png',
      iconCodePoint: 0xf08b4, // Icons.wallet_rounded
      colorHex: '#007DFE',
    ),
    BankTemplate(
      id: 'gotyme',
      name: 'GoTyme',
      logoAsset: 'assets/logos/gotyme.png',
      iconCodePoint: 0xe069,
      colorHex: '#1BCCD0',
    ),
    BankTemplate(
      id: 'landbank',
      name: 'Landbank',
      logoAsset: 'assets/logos/landbank.png',
      iconCodePoint: 0xe069,
      colorHex: '#1B5E20',
    ),
    BankTemplate(
      id: 'maribank',
      name: 'MariBank',
      logoAsset: 'assets/logos/maribank.png',
      iconCodePoint: 0xe069,
      colorHex: '#EA5F00',
    ),
    BankTemplate(
      id: 'maya',
      name: 'Maya',
      logoAsset: 'assets/logos/maya.png',
      iconCodePoint: 0xf08b4,
      colorHex: '#49A35B',
    ),
    BankTemplate(
      id: 'metrobank',
      name: 'Metrobank',
      logoAsset: 'assets/logos/metrobank.png',
      iconCodePoint: 0xe069,
      colorHex: '#1565C0',
    ),
    BankTemplate(
      id: 'pnb',
      name: 'PNB',
      logoAsset: 'assets/logos/pnb.png',
      iconCodePoint: 0xe069,
      colorHex: '#0D47A1',
    ),
    BankTemplate(
      id: 'rcbc',
      name: 'RCBC',
      logoAsset: 'assets/logos/rcbc.png',
      iconCodePoint: 0xe069,
      colorHex: '#1A237E',
    ),
    BankTemplate(
      id: 'securitybank',
      name: 'Security Bank',
      logoAsset: 'assets/logos/securitybank.png',
      iconCodePoint: 0xe069,
      colorHex: '#00695C',
    ),
    BankTemplate(
      id: 'unionbank',
      name: 'UnionBank',
      logoAsset: 'assets/logos/unionbank.png',
      iconCodePoint: 0xe069,
      colorHex: '#F57C00',
    ),
  ];
}
