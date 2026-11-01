enum ScoreLevel {
  good,
  moderate,
  poor,
  unknown;

  static ScoreLevel fromScore(int score) {
    if (score >= 70) return ScoreLevel.good;
    if (score >= 40) return ScoreLevel.moderate;
    return ScoreLevel.poor;
  }
}

class DimensionScore {
  const DimensionScore({
    required this.name,
    required this.value,
    required this.description,
    this.factors = const [],
  });

  factory DimensionScore.unknown(String name) => DimensionScore(
        name: name,
        value: 50,
        description: 'Not enough data to assess',
      );

  factory DimensionScore.fromJson(Map<String, dynamic> json) => DimensionScore(
        name: json['name'] as String,
        value: json['value'] as int,
        description: json['description'] as String? ?? '',
        factors: (json['factors'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );

  final String name;
  final int value;
  final String description;
  final List<String> factors;

  ScoreLevel get level => ScoreLevel.fromScore(value);

  Map<String, Object?> toJson() => {
        'name': name,
        'value': value,
        'description': description,
        'factors': factors,
      };

  DimensionScore copyWith({
    String? name,
    int? value,
    String? description,
    List<String>? factors,
  }) =>
      DimensionScore(
        name: name ?? this.name,
        value: value ?? this.value,
        description: description ?? this.description,
        factors: factors ?? this.factors,
      );
}

class NetworkScore {
  const NetworkScore({
    required this.overallScore,
    required this.computedAt,
    required this.security,
    required this.health,
    required this.reliability,
    required this.speed,
    required this.vulnerabilities,
    this.metadata = const {},
  });

  factory NetworkScore.fromJson(Map<String, dynamic> json) => NetworkScore(
        overallScore: json['overallScore'] as int,
        computedAt: DateTime.parse(json['computedAt'] as String),
        security:
            DimensionScore.fromJson(json['security'] as Map<String, dynamic>),
        health: DimensionScore.fromJson(json['health'] as Map<String, dynamic>),
        reliability: DimensionScore.fromJson(
            json['reliability'] as Map<String, dynamic>),
        speed:
            DimensionScore.fromJson(json['speed'] as Map<String, dynamic>),
        vulnerabilities: DimensionScore.fromJson(
            json['vulnerabilities'] as Map<String, dynamic>),
        metadata: (json['metadata'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as String)) ??
            const {},
      );

  final int overallScore;
  final DateTime computedAt;
  final DimensionScore security;
  final DimensionScore health;
  final DimensionScore reliability;
  final DimensionScore speed;
  final DimensionScore vulnerabilities;
  final Map<String, String> metadata;

  List<DimensionScore> get dimensions => [
        security,
        health,
        reliability,
        speed,
        vulnerabilities,
      ];

  ScoreLevel get level => ScoreLevel.fromScore(overallScore);

  bool get hasData => metadata.isNotEmpty;

  Map<String, Object?> toJson() => {
        'overallScore': overallScore,
        'computedAt': computedAt.toIso8601String(),
        'security': security.toJson(),
        'health': health.toJson(),
        'reliability': reliability.toJson(),
        'speed': speed.toJson(),
        'vulnerabilities': vulnerabilities.toJson(),
        'metadata': metadata,
      };

  NetworkScore copyWith({
    int? overallScore,
    DateTime? computedAt,
    DimensionScore? security,
    DimensionScore? health,
    DimensionScore? reliability,
    DimensionScore? speed,
    DimensionScore? vulnerabilities,
    Map<String, String>? metadata,
  }) =>
      NetworkScore(
        overallScore: overallScore ?? this.overallScore,
        computedAt: computedAt ?? this.computedAt,
        security: security ?? this.security,
        health: health ?? this.health,
        reliability: reliability ?? this.reliability,
        speed: speed ?? this.speed,
        vulnerabilities: vulnerabilities ?? this.vulnerabilities,
        metadata: metadata ?? this.metadata,
      );
}
