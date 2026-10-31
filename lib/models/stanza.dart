/// One stanza or chorus of a hymn, shown in [position] order.
class Stanza {
  const Stanza({
    required this.id,
    required this.position,
    required this.kind,
    required this.body,
  });

  final String id;
  final int position;
  final String kind; // 'verse' or 'chorus'
  final String body;

  bool get isChorus => kind == 'chorus';

  factory Stanza.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final position = json['position'];
    final kind = json['kind'];
    final body = json['body'];

    if (id is! String ||
        position is! int ||
        kind is! String ||
        body is! String) {
      throw const FormatException('Invalid stanza record');
    }
    return Stanza(id: id, position: position, kind: kind, body: body);
  }
}
