import 'dart:convert';

class CreatorProfile {
  CreatorProfile({
    required this.id,
    required this.displayName,
    this.handle = '',
    this.bio = '',
    this.avatarPath,
    this.logoPath,
    this.watermarkPath,
    this.signature = '',
    this.defaultTheme = 'Cyberpunk',
    this.accentHex = '#9B5CFF',
    this.website = '',
    this.socialLinks = const {},
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  String displayName;
  String handle;
  String bio;
  String? avatarPath;
  String? logoPath;
  String? watermarkPath;
  String signature;
  String defaultTheme;
  String accentHex;
  String website;
  Map<String, String> socialLinks;
  bool isDefault;
  DateTime? createdAt;
  DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'handle': handle,
        'bio': bio,
        'avatarPath': avatarPath,
        'logoPath': logoPath,
        'watermarkPath': watermarkPath,
        'signature': signature,
        'defaultTheme': defaultTheme,
        'accentHex': accentHex,
        'website': website,
        'socialLinks': socialLinks,
        'isDefault': isDefault,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CreatorProfile.fromJson(Map<String, dynamic> json) => CreatorProfile(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        displayName: json['displayName'] as String? ?? 'Creator',
        handle: json['handle'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        avatarPath: json['avatarPath'] as String?,
        logoPath: json['logoPath'] as String?,
        watermarkPath: json['watermarkPath'] as String?,
        signature: json['signature'] as String? ?? '',
        defaultTheme: json['defaultTheme'] as String? ?? 'Cyberpunk',
        accentHex: json['accentHex'] as String? ?? '#9B5CFF',
        website: json['website'] as String? ?? '',
        socialLinks:
            Map<String, String>.from(json['socialLinks'] as Map? ?? const {}),
        isDefault: json['isDefault'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );

  static String encodeList(List<CreatorProfile> profiles) =>
      jsonEncode(profiles.map((profile) => profile.toJson()).toList());

  static List<CreatorProfile> decodeList(String source) =>
      (jsonDecode(source) as List)
          .map((item) => CreatorProfile.fromJson(item as Map<String, dynamic>))
          .toList();
}
