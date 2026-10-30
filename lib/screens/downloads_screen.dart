import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../services/audio_service.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _confirmRemove(BuildContext context, DownloadItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove download?'),
        content: Text(
          '${item.hymnNumber} · ${item.hymnTitle} (${item.language}) will be '
          'deleted from this phone. You can download it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DownloadManager.instance.remove(item.recordingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([DownloadManager.instance, AudioService.instance]),
      builder: (context, _) {
        final downloads = DownloadManager.instance;
        final audio = AudioService.instance;
        final items = downloads.items;

        return Scaffold(
          appBar: AppBar(title: const Text('Downloads')),
          body: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_outlined,
                            size: 56, color: AppColors.accent),
                        SizedBox(height: 16),
                        Text(
                          'Nothing downloaded yet.\nOpen a hymn with a recording and tap "Download for offline".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSoft, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${items.length} recording${items.length == 1 ? '' : 's'} · ${formatBytes(downloads.totalBytes)} on this phone',
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                    ),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DownloadTile(
                          item: item,
                          isPlaying: audio.currentRecordingId == item.recordingId &&
                              audio.status == PlaybackStatus.playing,
                          isLoading: audio.currentRecordingId == item.recordingId &&
                              audio.status == PlaybackStatus.loading,
                          onPlayPause: () {
                            final uri = downloads.localUri(item.recordingId);
                            if (uri == null) return;
                            if (audio.currentRecordingId == item.recordingId &&
                                audio.status == PlaybackStatus.playing) {
                              audio.pause();
                            } else {
                              audio.playRecording(
                                recordingId: item.recordingId,
                                url: uri,
                              );
                            }
                          },
                          onRemove: () => _confirmRemove(context, item),
                        ),
                      ),
                    if (audio.status == PlaybackStatus.error &&
                        items.any((i) => i.recordingId == audio.currentRecordingId))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          audio.errorMessage ?? 'Playback failed.',
                          style: const TextStyle(color: AppColors.text),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.item,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onRemove,
  });

  final DownloadItem item;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: IconButton.filled(
          tooltip: isPlaying ? 'Pause' : 'Play',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
          ),
          onPressed: isLoading ? null : onPlayPause,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        title: Text(
          '${item.hymnNumber} · ${item.hymnTitle}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        subtitle: Text('${item.language} · ${formatBytes(item.bytes)}'),
        trailing: IconButton(
          tooltip: 'Remove download',
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      ),
    );
  }
}