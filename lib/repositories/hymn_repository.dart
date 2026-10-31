import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/hymn.dart';
import '../models/recording.dart';
import '../models/stanza.dart';
import '../services/catalogue_cache.dart';
import '../services/bundled_catalogue.dart';

String sanitizeSearchQuery(String input) =>
    input.replaceAll(RegExp(r'[,()%_*\\]'), ' ').trim();

class HymnRepository {
  HymnRepository(this._client, {this.includeBundled = true});
  final SupabaseClient? _client;
  final bool includeBundled;
  static const audioBucket = 'hymn-audio';
  static final usingOfflineContent = ValueNotifier<bool>(false);
  Future<void> _load() async {
    if (includeBundled) await BundledCatalogue.load();
  }

  List<Hymn> _merge(List<Hymn> local, List<Map<String, dynamic>> remote) {
    final registered = remote.map((row) {
      final h = Hymn.fromJson(row);
      return includeBundled
          ? BundledCatalogue.registerRemote(
              h,
              sourceKey: row['source_key'] as String?,
              published: row.containsKey('content_version'),
            )
          : h;
    }).toList();
    final result = {
      for (final h in local)
        if (!includeBundled || BundledCatalogue.isVisible(h.id))
          h.id: (includeBundled ? BundledCatalogue.hymn(h.id) : null) ?? h,
      for (final h in registered)
        if (!includeBundled || BundledCatalogue.isVisible(h.id)) h.id: h,
    }.values.toList();
    result.sort(BundledCatalogue.compare);
    return result;
  }

  Future<List<Hymn>> fetchHymnsByIds(List<String> ids) async {
    await _load();
    final local = <Hymn>[];
    final remoteIds = <String>[];
    for (final id in ids) {
      if (includeBundled && !BundledCatalogue.isVisible(id)) continue;
      final hymn = includeBundled ? BundledCatalogue.hymn(id) : null;
      if (hymn != null) {
        local.add(hymn);
      } else {
        remoteIds.add(id);
      }
    }
    if (remoteIds.isEmpty) return local;
    try {
      if (_client == null) throw StateError('Backend unavailable');
      final rows = await _client
          .from('hymns')
          .select('*')
          .eq('is_published', true)
          .inFilter('id', remoteIds)
          .order('number')
          .retry(enabled: false, requestTimeout: const Duration(seconds: 8));
      usingOfflineContent.value = false;
      await CatalogueCache.rememberHymns(rows);
      return [...local, ...rows.map(Hymn.fromJson)]
        ..sort(BundledCatalogue.compare);
    } catch (_) {
      usingOfflineContent.value = true;
      final cached = await CatalogueCache.hymnsByIds(remoteIds);
      if (cached.length != remoteIds.toSet().length) rethrow;
      return [...local, ...cached]..sort(BundledCatalogue.compare);
    }
  }

  Future<List<Hymn>> searchHymns({String query = '', String? language}) async {
    await _load();
    if (includeBundled && _client != null) {
      try {
        final overrides = await _client
            .from('hymnora_overrides')
            .select('source_key,hymn_id,is_visible')
            .retry(enabled: false, requestTimeout: const Duration(seconds: 5));
        BundledCatalogue.applyOverrides(overrides);
        await CatalogueCache.write('visibility', overrides);
      } on PostgrestException catch (_) {
        /* Older backends continue to serve the original catalogue. */
      } catch (_) {
        /* Retain the last known publishing decisions offline. */
      }
    }
    final q = sanitizeSearchQuery(query);
    final local = includeBundled
        ? BundledCatalogue.search(query: q, language: language)
        : <Hymn>[];
    if (_client == null) return local;
    try {
      final lyricIds = <String>{};
      if (q.isNotEmpty) {
        for (var offset = 0; ; offset += 500) {
          final rows = await _client
              .from('hymn_stanzas')
              .select('hymn_id')
              .ilike('body', '%$q%')
              .order('id')
              .range(offset, offset + 499)
              .retry(
                enabled: false,
                requestTimeout: const Duration(seconds: 8),
              );
          lyricIds.addAll(rows.map((r) => r['hymn_id']).whereType<String>());
          if (rows.length < 500) break;
        }
      }
      final all = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        var request = _client
            .from('hymns')
            .select('*')
            .eq('is_published', true);
        if (language != null) request = request.eq('language', language);
        if (q.isNotEmpty) {
          final filters = ['number.ilike.%$q%', 'title.ilike.%$q%'];
          if (lyricIds.isNotEmpty) filters.add('id.in.(${lyricIds.join(',')})');
          request = request.or(filters.join(','));
        }
        final rows = await request
            .order('number')
            .order('id')
            .range(offset, offset + 499)
            .retry(enabled: false, requestTimeout: const Duration(seconds: 8));
        all.addAll(rows);
        if (rows.length < 500) break;
      }
      usingOfflineContent.value = false;
      await CatalogueCache.rememberHymns(all);
      return _rank(_merge(local, all), q);
    } catch (_) {
      usingOfflineContent.value = true;
      final cached = await CatalogueCache.read('hymns');
      if (cached == null && !(includeBundled && BundledCatalogue.available)) {
        rethrow;
      }
      final matches = <Map<String, dynamic>>[];
      for (final row in cached ?? <Map<String, dynamic>>[]) {
        if (language != null && row['language'] != language) continue;
        final lyrics = await CatalogueCache.read('stanzas_${row['id']}') ?? [];
        final text =
            '${row['number']} ${row['title']} ${lyrics.map((s) => s['body']).join(' ')}';
        if (q.isEmpty ||
            BundledCatalogue.normalize(text)
                .contains(BundledCatalogue.normalize(q))) {
          matches.add(row);
        }
      }
      return _rank(_merge(local, matches), q);
    }
  }

  List<Hymn> _rank(List<Hymn> hymns, String q) {
    final exact = BundledCatalogue.normalize(q);
    hymns.sort((a, b) {
      final ae = BundledCatalogue.normalize(a.number) == exact;
      final be = BundledCatalogue.normalize(b.number) == exact;
      return ae != be ? (ae ? -1 : 1) : BundledCatalogue.compare(a, b);
    });
    return hymns;
  }

  Future<List<String>> fetchLanguages() async {
    await _load();
    final local = includeBundled ? BundledCatalogue.languages : <String>[];
    if (_client == null) return local;
    try {
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final page = await _client
            .from('hymns')
            .select('language')
            .eq('is_published', true)
            .order('id')
            .range(offset, offset + 499)
            .retry(enabled: false, requestTimeout: const Duration(seconds: 8));
        rows.addAll(page);
        if (page.length < 500) break;
      }
      await CatalogueCache.write('languages', rows);
      return {
        ...local,
        ...rows.map((r) => r['language']).whereType<String>(),
      }.toList()..sort();
    } catch (_) {
      final rows = await CatalogueCache.read('languages');
      if (rows == null && local.isEmpty) rethrow;
      return {
        ...local,
        ...?rows?.map((r) => r['language']).whereType<String>(),
      }.toList()..sort();
    }
  }

  Future<List<Stanza>> fetchStanzas(String hymnId) async {
    await _load();
    final local = includeBundled
        ? BundledCatalogue.stanzas(hymnId)
        : <Stanza>[];
    if (includeBundled && !BundledCatalogue.isVisible(hymnId)) return [];
    final remoteId = includeBundled
        ? BundledCatalogue.remoteId(hymnId)
        : hymnId;
    if (remoteId.startsWith('local:') || _client == null) return local;
    try {
      final rows = await _cached('stanzas_$remoteId', () async {
        return await _client
            .from('hymn_stanzas')
            .select('id, position, kind, body')
            .eq('hymn_id', remoteId)
            .order('position')
            .retry(enabled: false, requestTimeout: const Duration(seconds: 8));
      });
      return rows.isEmpty && local.isNotEmpty
          ? local
          : (rows.map(Stanza.fromJson).toList()
              ..sort((a, b) => a.position.compareTo(b.position)));
    } catch (_) {
      if (includeBundled && BundledCatalogue.isLocal(hymnId)) return local;
      rethrow;
    }
  }

  Future<List<Recording>> fetchRecordings(String hymnId) async {
    await _load();
    if (includeBundled && !BundledCatalogue.isVisible(hymnId)) return [];
    final id = includeBundled ? BundledCatalogue.remoteId(hymnId) : hymnId;
    if (id.startsWith('local:') || _client == null) return [];
    final rows = await _cached(
      'recordings_$id',
      () async => await _client
          .from('hymn_recordings')
          .select('*')
          .eq('hymn_id', id)
          .eq('is_published', true)
          .order('language')
          .retry(enabled: false, requestTimeout: const Duration(seconds: 8)),
    );
    return rows.map(Recording.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> _cached(
    String key,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) async {
    try {
      final rows = await fetch();
      usingOfflineContent.value = false;
      await CatalogueCache.write(key, rows);
      return rows;
    } catch (_) {
      usingOfflineContent.value = true;
      final rows = await CatalogueCache.read(key);
      if (rows == null) rethrow;
      return rows;
    }
  }

  Uri recordingUrl(Recording recording) {
    if (_client == null) throw StateError('Backend unavailable');
    return Uri.parse(
      _client.storage.from(audioBucket).getPublicUrl(recording.storagePath),
    );
  }
}
