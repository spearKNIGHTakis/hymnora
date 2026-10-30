/// One audio recording of a hymn. [hymnId] is the hymn's internal ID,
/// and [storagePath] is the file's path inside the hymn-audio bucket.
class Recording {
  const Recording({
    required this.id,
    required this.hymnId,
    required this.language,
    required this.storagePath,
  });

  final String id;
  final String hymnId;
  final String language;
  final String storagePath;

  factory Recording.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final hymnId = json['hymn_id'];
    final language = json['language'];
    final storagePath = json['storage_path'];

    if (id is! String ||
        hymnId is! String ||
        language is! String ||
        storagePath is! String ||
        storagePath.trim().isEmpty) {
      throw const FormatException('Invalid recording record');
    }
    return Recording(
      id: id,
      hymnId: hymnId,
      language: language,
      storagePath: storagePath,
    );
  }
}