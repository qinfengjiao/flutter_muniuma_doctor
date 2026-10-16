class AppEnv {
  const AppEnv({
    required this.name,
    required this.apiBase,
    required this.cosDomain,
    required this.medicalRecordDomain,
    required this.websiteDomain,
  });

  final String name;
  final String apiBase;
  final String cosDomain;
  final String medicalRecordDomain;
  final String websiteDomain;
}

/// 与 iOS `kMNCurrentServerType` 一致：0 测试、1 预发布、2 正式。
class AppConfig {
  static const envs = <AppEnv>[
    AppEnv(
      name: '测试',
      apiBase: 'https://v2apitest.muniuma.cn',
      cosDomain: 'https://filetestcos.muniuma.cn',
      medicalRecordDomain: 'https://mrtest.muniuma.cn/',
      websiteDomain: 'https://ysphonetest.muniuma.cn/#/',
    ),
    AppEnv(
      name: '预发布',
      apiBase: 'https://v2apireal.muniuma.cn',
      cosDomain: 'https://mnmfilecos.muniuma.cn',
      medicalRecordDomain: 'https://mrrel.muniuma.cn/',
      websiteDomain: 'https://ysphonerel.muniuma.cn/#/',
    ),
    AppEnv(
      name: '正式',
      apiBase: 'https://v2api.muniuma.cn',
      cosDomain: 'https://mnmfilecos.muniuma.cn',
      medicalRecordDomain: 'https://mr.muniuma.cn/',
      websiteDomain: 'https://ysphone.muniuma.cn/#/',
    ),
  ];

  static const serviceAgreementUrl =
      'https://ysphone.muniuma.cn/#/serviceAgreement';
  static const privacyAgreementUrl =
      'https://ysphone.muniuma.cn/#/privacyAgreement';

  static const loginClientDoctor = 5;
  static const loginTypeSms = 1;
  static const loginTypePassword = 2;
  static const smsTypeRegister = 1;
  static const smsTypeResetPassword = 2;

  static String join(String base, String path) {
    final normalizedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }

  static String? imageUrl(String? raw, String cosDomain) {
    if (raw == null || raw.trim().isEmpty) return null;
    final first = raw.split('|').first.split(',').first.trim();
    if (first.isEmpty) return null;
    if (first.startsWith('http://') || first.startsWith('https://')) {
      const marker = 'myqcloud.com';
      final index = first.indexOf(marker);
      if (index >= 0) {
        return '$cosDomain${first.substring(index + marker.length)}';
      }
      return first;
    }
    if (first.startsWith('/')) return '$cosDomain$first';
    return '$cosDomain/$first';
  }
}
