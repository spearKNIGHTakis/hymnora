/// One hymn from the catalogue. The [id] is the internal ID used in
/// every query. The [number] is only what people see, like "PH1".
String canonicalHymnNumber(String number) =>
    number.replaceFirst(RegExp(r'^EH', caseSensitive: false), 'PH');

class Hymn {
  const Hymn({
    required this.id,
    required this.number,
    required this.title,
    required this.language,
  });

  final String id;
  final String number;
  final String title;
  final String language;
  String get displayNumber =>
      canonicalHymnNumber(number).replaceFirst('PH', 'PH ');
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': canonicalHymnNumber(number),
    'title': title,
    'language': language,
  };

  factory Hymn.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final number = json['number'];
    final title = json['title'];
    final language = json['language'];

    if (id is! String ||
        number is! String ||
        title is! String ||
        language is! String) {
      throw const FormatException('Invalid hymn record');
    }
    return Hymn(
      id: id,
      number: canonicalHymnNumber(number),
      title: title,
      language: language,
    );
  }
}
