import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hymnora/services/catalogue_cache.dart';
import 'package:hymnora/repositories/hymn_repository.dart';

void main() {
  const hymn = {
    'id': 'h1',
    'number': 'PH1',
    'title': 'Sing together',
    'language': 'Twi',
  };
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'lyrics, recordings, search and favourites survive network loss',
    () async {
      var online = true;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (!online) throw const SocketException('Offline');
          final data = request.url.path.endsWith('hymn_stanzas')
              ? [
                  {
                    'id': 's1',
                    'hymn_id': 'h1',
                    'position': 1,
                    'kind': 'verse',
                    'body': 'Grace and joy',
                  },
                ]
              : request.url.path.endsWith('hymn_recordings')
              ? [
                  {
                    'id': 'r1',
                    'hymn_id': 'h1',
                    'language': 'Twi',
                    'storage_path': 'h1/twi.mp3',
                  },
                ]
              : [hymn];
          return http.Response(
            jsonEncode(data),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = HymnRepository(client, includeBundled: false);
      await repo.searchHymns();
      await repo.fetchLanguages();
      await repo.fetchStanzas('h1');
      await repo.fetchRecordings('h1');
      online = false;
      expect((await repo.searchHymns(query: 'grace')).single.id, 'h1');
      expect(await repo.searchHymns(language: 'English'), isEmpty);
      expect((await repo.fetchStanzas('h1')).single.body, 'Grace and joy');
      expect((await repo.fetchRecordings('h1')).single.id, 'r1');
      expect(
        (await repo.fetchHymnsByIds(['h1'])).single.title,
        'Sing together',
      );
      expect(await repo.fetchLanguages(), ['Twi']);
      expect(HymnRepository.usingOfflineContent.value, isTrue);
      await client.dispose();
    },
  );

  test(
    'uncached network failures are surfaced instead of appearing empty',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((_) async {
          throw const SocketException('Offline');
        }),
      );
      await expectLater(
        HymnRepository(client, includeBundled: false).fetchStanzas('missing'),
        throwsA(isA<SocketException>()),
      );
      await client.dispose();
    },
  );

  test(
    'reversed remote and previously cached stanzas display in numeric order',
    () async {
      var online = true;
      final reversed = [
        for (final position in [4, 3, 2, 1])
          {
            'id': 's$position',
            'position': position,
            'kind': position == 2 ? 'chorus' : 'verse',
            'body': 'Stanza $position',
          },
      ];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (!online) throw const SocketException('Offline');
          return http.Response(
            jsonEncode(reversed),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = HymnRepository(client, includeBundled: false);
      for (final isOnline in [true, false]) {
        online = isOnline;
        if (!online) await CatalogueCache.write('stanzas_h1', reversed);
        final stanzas = await repo.fetchStanzas('h1');
        expect(stanzas.map((s) => s.position), [1, 2, 3, 4]);
        expect(stanzas.map((s) => s.body), [
          'Stanza 1',
          'Stanza 2',
          'Stanza 3',
          'Stanza 4',
        ]);
        expect(stanzas[1].isChorus, isTrue);
      }
    },
  );

  test('concurrent catalogue writes retain all hymns', () async {
    await Future.wait([
      CatalogueCache.rememberHymns([hymn]),
      CatalogueCache.rememberHymns([
        {...hymn, 'id': 'h2'},
      ]),
    ]);
    expect((await CatalogueCache.read('hymns'))!.length, 2);
  });
}
