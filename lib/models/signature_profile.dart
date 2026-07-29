import 'dart:convert';

class SignatureProfile {
  SignatureProfile({
    this.displayName = 'Your Name',
    this.username = '@yourname',
    this.headline = 'Capture it. Relive it. Share it.',
    this.about = '',
    this.photoPath,
    this.phone = '',
    this.email = '',
    this.location = '',
    this.skills = const [],
    this.links = const [],
    this.badges = const ['Signature Card'],
    this.shareSlug = 'my-signature-card',
  });

  String displayName;
  String username;
  String headline;
  String about;
  String? photoPath;
  String phone;
  String email;
  String location;
  List<String> skills;
  List<ProfileLink> links;
  List<String> badges;
  String shareSlug;

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'username': username,
        'headline': headline,
        'about': about,
        'photoPath': photoPath,
        'phone': phone,
        'email': email,
        'location': location,
        'skills': skills,
        'links': links.map((link) => link.toJson()).toList(),
        'badges': badges,
        'shareSlug': shareSlug,
      };

  factory SignatureProfile.fromJson(Map<String, dynamic> json) {
    return SignatureProfile(
      displayName: json['displayName'] as String? ?? 'Your Name',
      username: json['username'] as String? ?? '@yourname',
      headline: json['headline'] as String? ?? '',
      about: json['about'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      location: json['location'] as String? ?? '',
      skills: List<String>.from(json['skills'] as List? ?? const []),
      links: (json['links'] as List? ?? const [])
          .map((item) => ProfileLink.fromJson(item as Map<String, dynamic>))
          .toList(),
      badges: List<String>.from(json['badges'] as List? ?? const []),
      shareSlug: json['shareSlug'] as String? ?? 'my-signature-card',
    );
  }

  String encode() => jsonEncode(toJson());

  static SignatureProfile decode(String source) =>
      SignatureProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String shareText() {
    final buffer = StringBuffer()
      ..writeln(displayName)
      ..writeln(username)
      ..writeln(headline);

    if (about.trim().isNotEmpty) buffer.writeln('\n$about');
    if (phone.trim().isNotEmpty) buffer.writeln('\nPhone: $phone');
    if (email.trim().isNotEmpty) buffer.writeln('Email: $email');
    if (location.trim().isNotEmpty) buffer.writeln('Location: $location');

    if (skills.isNotEmpty) {
      buffer.writeln('\nSkills: ${skills.join(', ')}');
    }

    if (links.isNotEmpty) {
      buffer.writeln('\nLinks:');
      for (final link in links) {
        buffer.writeln('${link.label}: ${link.url}');
      }
    }

    return buffer.toString().trim();
  }
}

class ProfileLink {
  ProfileLink({required this.label, required this.url});

  String label;
  String url;

  Map<String, dynamic> toJson() => {'label': label, 'url': url};

  factory ProfileLink.fromJson(Map<String, dynamic> json) => ProfileLink(
        label: json['label'] as String? ?? 'Link',
        url: json['url'] as String? ?? '',
      );
}
