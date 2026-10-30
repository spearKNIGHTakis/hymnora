import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hymn.dart';
import '../models/stanza.dart';
import '../repositories/hymn_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class HymnDetailsScreen extends StatefulWidget {
  const HymnDetailsScreen({super.key, required this.hymn});

  final Hymn hymn;

  @override
  State<HymnDetailsScreen> createState() => _HymnDetailsScreenState();
}

class _HymnDetailsScreenState extends State<HymnDetailsScreen> {
  late Future<List<Stanza>> _stanzas;
  double _fontSize = 20;

  @override
  void initState() {
    super.initState();
    _stanzas = _load();
  }

  Future<List<Stanza>> _load() {
    return HymnRepository(Supabase.instance.client).fetchStanzas(widget.hymn.id);
  }

  void _retry() {
    setState(() => _stanzas = _load());
  }

  @override
  Widget build(BuildContext context) {
    final hymn = widget.hymn;
    return Scaffold(
      appBar: AppBar(title: Text(hymn.number)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Stanza>>(
              future: _stanzas,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Loading lyrics…');
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Could not load the lyrics. Check your connection and try again.',
                    onRetry: _retry,
                  );
                }
                final stanzas = snapshot.data ?? const <Stanza>[];
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      hymn.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(hymn.language, style: const TextStyle(color: AppColors.textSoft)),
                    const SizedBox(height: 20),
                    if (stanzas.isEmpty)
                      const Text(
                        'Lyrics are not available for this hymn yet.',
                        style: TextStyle(color: AppColors.textSoft),
                      )
                    else
                      for (final s in stanzas) _StanzaView(stanza: s, fontSize: _fontSize),
                  ],
                );
              },
            ),
          ),
          _TextSizeBar(
            value: _fontSize,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
        ],
      ),
    );
  }
}

class _StanzaView extends StatelessWidget {
  const _StanzaView({required this.stanza, required this.fontSize});

  final Stanza stanza;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: stanza.isChorus ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stanza.isChorus ? 'Chorus' : '${stanza.position}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stanza.body, // line breaks are kept exactly as stored
              style: TextStyle(
                fontSize: fontSize,
                height: 1.5,
                color: AppColors.text,
                fontStyle: stanza.isChorus ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextSizeBar extends StatelessWidget {
  const _TextSizeBar({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.text_fields, size: 18),
            Expanded(
              child: Slider(
                value: value,
                min: 16,
                max: 36,
                divisions: 10,
                label: value.round().toString(),
                onChanged: onChanged,
              ),
            ),
            const Icon(Icons.text_fields, size: 30),
          ],
        ),
      ),
    );
  }
}