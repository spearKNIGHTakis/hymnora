import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hymn.dart';
import '../models/stanza.dart';

/// The only place that talks to the hymn tables.
class HymnRepository {
  HymnRepository(this._client);

  final SupabaseClient _client;

  Future<List<Hymn>> fetchPublishedHymns() async {
    final rows = await _client
        .from('hymns')
        .select('id, number, title, language')
        .eq('is_published', true)
        .order('number');

    return rows.map<Hymn>((row) => Hymn.fromJson(row)).toList();
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
}