import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hymn.dart';
import '../models/recording.dart';
import '../models/stanza.dart';

/// Removes characters that have special meaning in search filters,
/// so user input can't break the query.
String sanitizeSearchQuery(String input) {
  return input.replaceAll(RegExp(r'[,()%_*\\]'), ' ').trim();
}

/// The only place that talks to the hymn tables and the audio bucket.
class HymnRepository {
  HymnRepository(this._client);

  static const audioBucket = 'hymn-audio';

  final SupabaseClient _client;

  /// Published hymns, optionally filtered by search text and language.
  /// The text is matched against the number, the title and the lyrics.
  Future<List<Hymn>> searchHymns({String query = '', String? language}) async {
    final q = sanitizeSearchQuery(query);

    var request = _client
        .from('hymns')
        .select('id, number, title, language')
        .eq('is_published', true);

    if (language != null) {
      request = request.eq('language', language);
    }

    if (q.isNotEmpty) {
      final stanzaRows = await _client
          .from('hymn_stanzas')
          .select('hymn_id')
          .ilike('body', '%$q%')
          .limit(200);
      final lyricIds =
          stanzaRows.map((r) => r['hymn_id']).whereType<String>().toSet();

      final filters = <String>['number.ilike.%$q%', 'title.ilike.%$q%'];
      if (lyricIds.isNotEmpty) {
        filters.add('id.in.(${lyricIds.join(',')})');
      }
      request = request.or(filters.join(','));
    }

    final rows = await request.order('number').limit(100);
    return rows.map<Hymn>((row) => Hymn.fromJson(row)).toList();
  }

  /// The languages that have at least one published hymn.
  Future<List<String>> fetchLanguages() async {
    final rows = await _client
        .from('hymns')
        .select('language')
        .eq('is_published', true);
    final languages =
        rows.map((r) => r['language']).whereType<String>().toSet().toList();
    languages.sort();
    return languages;
  }

  /// Stanzas for one hymn, always looked up by the internal hymn ID.
  Future<List<Stanza>> fetchStanzas(String hymnId) async {
    final rows = await _client
        .from('hymn_stanzas')
        .select('id, position, kind, body')
        .eq('hymn_id', hymnId)
        .order('position');

    return rows.map<Stanza>((row) => Stanza.fromJson(row)).toList();
  }

  /// Published recordings for one hymn, by internal hymn ID.
  Future<List<Recording>> fetchRecordings(String hymnId) async {
    final rows = await _client
        .from('hymn_recordings')
        .select('id, hymn_id, language, storage_path')
        .eq('hymn_id', hymnId)
        .eq('is_published', true)
        .order('language');

    return rows.map<Recording>((row) => Recording.fromJson(row)).toList();
  }

  /// Builds the playable address for a recording in the public bucket.
  /// This does not prove the file exists. The player reports that.
  Uri recordingUrl(Recording recording) {
    final url = _client.storage
        .from(audioBucket)
        .getPublicUrl(recording.storagePath);
    return Uri.parse(url);
  }
}