import '../engine/step.dart';

/// A record of an attempt at one puzzle. [completedAt] is null until solved.
class HistoryRecord {
  final String code;
  final Difficulty difficulty;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int elapsedSeconds;
  final int hintsUsed;

  const HistoryRecord({
    required this.code,
    required this.difficulty,
    required this.startedAt,
    this.completedAt,
    this.elapsedSeconds = 0,
    this.hintsUsed = 0,
  });

  bool get isCompleted => completedAt != null;

  HistoryRecord copyWith({
    DateTime? completedAt,
    int? elapsedSeconds,
    int? hintsUsed,
  }) =>
      HistoryRecord(
        code: code,
        difficulty: difficulty,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        hintsUsed: hintsUsed ?? this.hintsUsed,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'difficulty': difficulty.id,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'elapsedSeconds': elapsedSeconds,
        'hintsUsed': hintsUsed,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        code: json['code'] as String,
        difficulty: difficultyFromId(json['difficulty'] as String),
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
        hintsUsed: (json['hintsUsed'] as num?)?.toInt() ?? 0,
      );
}
