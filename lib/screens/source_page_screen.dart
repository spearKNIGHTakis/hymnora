import 'package:flutter/material.dart';

class SourcePageScreen extends StatefulWidget {
  const SourcePageScreen({
    super.key,
    required this.language,
    required this.initialPage,
  });
  final String language;
  final int initialPage;
  @override
  State<SourcePageScreen> createState() => _SourcePageScreenState();
}

class _SourcePageScreenState extends State<SourcePageScreen> {
  late int _page = widget.initialPage;
  final TransformationController _zoom = TransformationController();
  int get _first => widget.language == 'Twi' ? 1 : 13;
  int get _last => widget.language == 'Twi' ? 442 : 458;
  void _go(int page) {
    setState(() => _page = page);
    _zoom.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.language} hymnbook')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Original source page · pinch to zoom'),
        ),
        Expanded(
          child: InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 6,
            child: Center(
              child: Image.asset(
                'assets/sources/${widget.language == 'Twi' ? 'twi' : 'english'}/$_page.jpg',
                key: ValueKey(_page),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    const Text('This source page could not be loaded.'),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page > _first ? () => _go(_page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('PDF page $_page'),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page < _last ? () => _go(_page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
