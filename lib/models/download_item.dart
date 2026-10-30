/// A recording that has been fully downloaded to the phone.
/// Hymn details are stored too, so the Downloads tab works offline.
class DownloadItem {
  const DownloadItem({
    required this.recordingId,
    required this.hymnId,
    required this.hymnNumber,
    required this.hymnTitle,
    required this.language,
    required this.fileName,
    required this.bytes,
  });

  final String recordingId;
  final String hymnId;
  final String hymnNumber;
  final String hymnTitle;
  final String language;

  /// Just the file name. The folder is looked up at runtime.
  final String fileName;
  final int bytes;

  Map<String, dynamic> toJson() => {
        'recordingId': recordingId,
        'hymnId': hymnId,
        'hymnNumber': hymnNumber,
        'hymnTitle': hymnTitle,
        'language': language,
        'fileName': fileName,
        'bytes': bytes,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    final recordingId = json['recordingId'];
    final hymnId = json['hymnId'];
    final hymnNumber = json['hymnNumber'];
    final hymnTitle = json['hymnTitle'];
    final language = json['language'];
    final fileName = json['fileName'];
    final bytes = json['bytes'];

    if (recordingId is! String ||
        hymnId is! String ||
        hymnNumber is! String ||
        hymnTitle is! String ||
        language is! String ||
        fileName is! String ||
        bytes is! int) {
      throw const FormatException('Invalid download record');
    }
    return DownloadItem(
      recordingId: recordingId,
      hymnId: hymnId,
      hymnNumber: hymnNumber,
      hymnTitle: hymnTitle,
      language: language,
      fileName: fileName,
      bytes: bytes,
    );
  }
}