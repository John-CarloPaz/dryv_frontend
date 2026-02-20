class AppUser {
  final int id;
  final String name;
  final String email;
  final DateTime? emailVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final email = json['email'];

    return AppUser(
      id: id is int ? id : int.tryParse('$id') ?? 0,
      name: name is String ? name : (name?.toString() ?? ''),
      email: email is String ? email : (email?.toString() ?? ''),
      emailVerifiedAt: _tryParseDate(json['email_verified_at']),
      createdAt: _tryParseDate(json['created_at']),
      updatedAt: _tryParseDate(json['updated_at']),
    );
  }

  static DateTime? _tryParseDate(Object? value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return DateTime.tryParse(value.toString());
  }
}
