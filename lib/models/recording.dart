enum RecordingType {
  maleSolo('male_solo', 'Male solo'),
  femaleSolo('female_solo', 'Female solo'),
  choir('choir', 'Choir'),
  congregation('congregation', 'Congregation'),
  unspecified('unspecified', 'Recording');

  const RecordingType(this.value, this.label);
  final String value;
  final String label;
  static RecordingType parse(Object? value) =>
      values.firstWhere((t) => t.value == value, orElse: () => unspecified);
}

class VerseCue {
  const VerseCue(this.position, this.milliseconds);
  final int position;
  final int milliseconds;
}

class Recording {
  const Recording({
    required this.id,
    required this.hymnId,
    required this.language,
    required this.storagePath,
    this.type = RecordingType.unspecified,
    this.performer = '',
    this.cues = const [],
  });
  final String id, hymnId, language, storagePath, performer;
  final RecordingType type;
  final List<VerseCue> cues;
  String get label =>
      performer.isEmpty ? type.label : '${type.label} · $performer';
  factory Recording.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['hymn_id'] is! String ||
        json['language'] is! String ||
        json['storage_path'] is! String ||
        (json['storage_path'] as String).trim().isEmpty) {
      throw const FormatException('Invalid recording record');
    }
    final cues = <VerseCue>[];
    for (final c in json['cues'] as List? ?? []) {
      if (c is Map &&
          c['position'] is int &&
          c['milliseconds'] is int &&
          c['position'] > 0 &&
          c['milliseconds'] >= 0) {
        cues.add(VerseCue(c['position'], c['milliseconds']));
      }
    }
    cues.sort((a, b) => a.milliseconds.compareTo(b.milliseconds));
    return Recording(
      id: json['id'],
      hymnId: json['hymn_id'],
      language: json['language'],
      storagePath: json['storage_path'],
      type: RecordingType.parse(json['recording_type']),
      performer: json['performer'] as String? ?? '',
      cues: List.unmodifiable(cues),
    );
  }
}
