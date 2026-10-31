import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hymnora/repositories/hymn_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('published edits override bundled text and unpublishing stays hidden offline', () async {
    SharedPreferences.setMockInitialValues({});
    var online = true;
    var visible = true;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      httpClient: MockClient((request) async {
        if (!online) throw const SocketException('Offline');
        final path = request.url.path;
        final rows = path.endsWith('hymnora_overrides')
            ? [
                {
                  'source_key': 'local:twi:1',
                  'hymn_id': 'backend-id',
                  'is_visible': visible,
                },
              ]
            : path.endsWith('hymn_stanzas')
            ? [
                {
                  'id': 's1',
                  'position': 1,
                  'kind': 'verse',
                  'body': 'Reviewed lyric text',
                },
              ]
            : visible
            ? [
                {
                  'id': 'backend-id',
                  'number': 'PH1',
                  'title': 'Reviewed hymn title',
                  'language': 'Twi',
                  'source_key': 'local:twi:1',
                  'content_version': 2,
                },
              ]
            : [];
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repo = HymnRepository(client);
    final published = await repo.searchHymns(language: 'Twi');
    expect(
      published.firstWhere((h) => h.id == 'local:twi:1').title,
      'Reviewed hymn title',
    );
    expect(
      (await repo.fetchStanzas('local:twi:1')).single.body,
      'Reviewed lyric text',
    );
    visible = false;
    expect(
      (await repo.searchHymns(language: 'Twi'))
          .any((h) => h.id == 'local:twi:1'),
      isFalse,
    );
    online = false;
    expect(
      (await repo.searchHymns(language: 'Twi'))
          .any((h) => h.id == 'local:twi:1'),
      isFalse,
    );
    expect(await repo.fetchStanzas('local:twi:1'), isEmpty);
    await client.dispose();
  });
}
