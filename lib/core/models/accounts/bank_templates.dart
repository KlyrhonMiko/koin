import 'package:koin/core/icons.dart';

class BankTemplate {
  final String id;
  final String name;
  final String logoAsset;
  final int iconCodePoint;
  final String colorHex;
  final List<String> legacyColorHexes;
  final String? cardForegroundHex;

  const BankTemplate({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.iconCodePoint,
    required this.colorHex,
    this.legacyColorHexes = const [],
    this.cardForegroundHex,
  });

  /// Refresh saved template defaults while retaining user-selected colors.
  static String resolveColorHex(String? logoAsset, String colorHex) {
    for (final template in templates) {
      if (template.logoAsset == logoAsset &&
          template.legacyColorHexes.any(
            (legacy) => legacy.toLowerCase() == colorHex.toLowerCase(),
          )) {
        return template.colorHex;
      }
    }
    return colorHex;
  }

  static String? foregroundHexFor(String? logoAsset) {
    for (final template in templates) {
      if (template.logoAsset == logoAsset) return template.cardForegroundHex;
    }
    return null;
  }

  static final List<BankTemplate> templates = [
    BankTemplate(
      id: 'bdo',
      name: 'BDO',
      logoAsset: 'assets/logos/bdo.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#145DB5',
      legacyColorHexes: ['#093574', '#0C3977'],
    ),
    BankTemplate(
      id: 'bpi',
      name: 'BPI',
      logoAsset: 'assets/logos/bpi.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#E0002A',
      legacyColorHexes: ['#C62828', '#A80024'],
    ),
    BankTemplate(
      id: 'cimb',
      name: 'CIMB',
      logoAsset: 'assets/logos/cimb.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#ED002A',
      legacyColorHexes: ['#D50000', '#BE0025'],
    ),
    BankTemplate(
      id: 'eastwest',
      name: 'EastWest',
      logoAsset: 'assets/logos/eastwest.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#CDDE35',
      legacyColorHexes: ['#B3BD43', '#67257F'],
      cardForegroundHex: '#50601B',
    ),
    BankTemplate(
      id: 'gcash',
      name: 'GCash',
      logoAsset: 'assets/logos/gcash.png',
      iconCodePoint: KoinIcons.wallet.codePoint,
      colorHex: '#007AFF',
      legacyColorHexes: ['#007DFE', '#005CE5'],
    ),
    BankTemplate(
      id: 'gotyme',
      name: 'GoTyme',
      logoAsset: 'assets/logos/gotyme.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#00D5DF',
      legacyColorHexes: ['#1BCCD0', '#007F8B'],
      cardForegroundHex: '#176773',
    ),
    BankTemplate(
      id: 'landbank',
      name: 'Landbank',
      logoAsset: 'assets/logos/landbank.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#48B600',
      legacyColorHexes: ['#1B5E20', '#277A08'],
      cardForegroundHex: '#24570B',
    ),
    BankTemplate(
      id: 'maribank',
      name: 'MariBank',
      logoAsset: 'assets/logos/maribank.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#EA5F00',
    ),
    BankTemplate(
      id: 'maya',
      name: 'Maya',
      logoAsset: 'assets/logos/maya.png',
      iconCodePoint: KoinIcons.wallet.codePoint,
      colorHex: '#00D99D',
      legacyColorHexes: ['#49A35B', '#007A57'],
      cardForegroundHex: '#14634B',
    ),
    BankTemplate(
      id: 'metrobank',
      name: 'Metrobank',
      logoAsset: 'assets/logos/metrobank.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#6852D6',
      legacyColorHexes: ['#1565C0', '#5544A6'],
    ),
    BankTemplate(
      id: 'pnb',
      name: 'PNB',
      logoAsset: 'assets/logos/pnb.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#1645BD',
      legacyColorHexes: ['#0D47A1', '#0B206B'],
    ),
    BankTemplate(
      id: 'rcbc',
      name: 'RCBC',
      logoAsset: 'assets/logos/rcbc.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#1678D4',
      legacyColorHexes: ['#1A237E', '#1965AF'],
    ),
    BankTemplate(
      id: 'securitybank',
      name: 'Security Bank',
      logoAsset: 'assets/logos/securitybank.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#17A9D2',
      legacyColorHexes: ['#00695C', '#344257'],
      cardForegroundHex: '#125675',
    ),
    BankTemplate(
      id: 'unionbank',
      name: 'UnionBank',
      logoAsset: 'assets/logos/unionbank.png',
      iconCodePoint: KoinIcons.bank.codePoint,
      colorHex: '#FF7400',
      legacyColorHexes: ['#F57C00', '#EF6500'],
    ),
  ];
}
