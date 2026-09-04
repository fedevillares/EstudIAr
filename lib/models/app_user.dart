class AppUser {
  String username;
  String passwordHash;
  String passwordSalt;
  bool isActive;
  bool isAdmin;
  String? deviceId;
  DateTime createdAt;
  DateTime? lastLoginAt;

  // ── Campos de perfil social ──────────────────────────────────────
  String displayName;
  String bio;
  String? avatarUrl;
  int followersCount;
  int followingCount;
  bool isBlockedGlobally; // bloqueo administrativo por moderación

  // ── Uso de IA (proxy vía Cloud Function) ──────────────────────────
  // aiUsageLimit: llamadas a la IA permitidas por día. 0 = sin límite.
  // Lo setea el admin desde el panel. aiUsageCount/aiUsageResetAt los
  // maneja únicamente la Cloud Function "aiProxy" (Admin SDK) — nunca
  // se escriben desde el cliente, ver firestore.rules.
  int aiUsageLimit;
  int aiUsageCount;
  DateTime? aiUsageResetAt;

  AppUser({
    required this.username,
    required this.passwordHash,
    this.passwordSalt = '',
    this.isActive = true,
    this.isAdmin = false,
    this.deviceId,
    required this.createdAt,
    this.lastLoginAt,
    String? displayName,
    this.bio = '',
    this.avatarUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isBlockedGlobally = false,
    this.aiUsageLimit = 0,
    this.aiUsageCount = 0,
    this.aiUsageResetAt,
  }) : displayName = displayName ?? username;

  Map<String, dynamic> toMap() => {
        'username': username,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'isActive': isActive,
        'isAdmin': isAdmin,
        'deviceId': deviceId,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'displayName': displayName,
        'bio': bio,
        'avatarUrl': avatarUrl,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'isBlockedGlobally': isBlockedGlobally,
        'aiUsageLimit': aiUsageLimit,
        'aiUsageCount': aiUsageCount,
        'aiUsageResetAt': aiUsageResetAt?.toIso8601String(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.parse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      username: map['username'] as String? ?? 'unknown',
      passwordHash: map['passwordHash'] as String? ?? '',
      passwordSalt: map['passwordSalt'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      isAdmin: map['isAdmin'] as bool? ?? false,
      deviceId: map['deviceId'] as String?,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      lastLoginAt: _parseDate(map['lastLoginAt']),
      displayName: map['displayName'] as String?,
      bio: map['bio'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (map['followingCount'] as num?)?.toInt() ?? 0,
      isBlockedGlobally: map['isBlockedGlobally'] as bool? ?? false,
      aiUsageLimit: (map['aiUsageLimit'] as num?)?.toInt() ?? 0,
      aiUsageCount: (map['aiUsageCount'] as num?)?.toInt() ?? 0,
      aiUsageResetAt: _parseDate(map['aiUsageResetAt']),
    );
  }
}

enum LoginResult { success, invalidCredentials, inactive, deviceMismatch, tooManyAttempts }