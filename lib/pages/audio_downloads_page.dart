import 'package:flutter/material.dart';

import '../services/audio_download_store.dart';
import '../services/audio_downloader.dart';
import '../services/audio_history.dart';
import '../services/library_store.dart';
import 'audio_page.dart';

class AudioDownloadsPage extends StatefulWidget {
  const AudioDownloadsPage({super.key, this.onFind});

  final VoidCallback? onFind;

  @override
  State<AudioDownloadsPage> createState() => _AudioDownloadsPageState();
}

class _AudioDownloadsPageState extends State<AudioDownloadsPage> {
  final _store = HiveAudioDownloadStore.instance;
  final _downloader = AudioDownloader.instance;
  late Future<List<DownloadedAudioBook>> _books;

  @override
  void initState() {
    super.initState();
    _books = _store.downloadedBooks();
    _store.changes.addListener(_refresh);
  }

  @override
  void dispose() {
    _store.changes.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() => _books = _store.downloadedBooks());

  Future<void> _play(DownloadedAudioBook download) async {
    Map<String, dynamic>? history;
    try {
      history = await AudioHistory(LibraryStore.instance)
          .load(download.book.bookId);
    } catch (_) {
      // A progress read failure still leaves the downloaded chapters playable.
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => offlineAudioRequest(download, history)),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('下载')),
    body: FutureBuilder<List<DownloadedAudioBook>>(
      future: _books,
      builder: (context, snapshot) => ValueListenableBuilder(
        valueListenable: _downloader,
        builder: (context, tasks, _) {
          final pending = tasks.where(
            (task) => task.status != AudioDownloadStatus.completed,
          );
          final books = snapshot.data ?? const <DownloadedAudioBook>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
            children: [
              if (pending.isNotEmpty) ...[
                Text('下载任务', style: Theme.of(context).textTheme.titleLarge),
                for (final task in pending) _taskTile(task),
                const SizedBox(height: 16),
              ],
              Text('已下载', style: Theme.of(context).textTheme.titleLarge),
              if (snapshot.hasError)
                ListTile(
                  title: const Text('无法读取下载记录'),
                  trailing: TextButton(
                    onPressed: _refresh,
                    child: const Text('重试'),
                  ),
                )
              else if (!snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (books.isEmpty)
                ListTile(
                  title: const Text('还没有下载的听书'),
                  subtitle: const Text('联网找一本书，在播放页下载音频，断网后就能在这里听。'),
                  onTap: widget.onFind,
                ),
              for (final download in books)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.headphones),
                    title: Text(download.book.title),
                    subtitle: Text(
                      '可离线听 · 已下载 ${download.chapters.length}/${download.book.chapters.length} 章'
                      ' · ${(download.bytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    ),
                    onTap: () => _play(download),
                    trailing: IconButton(
                      tooltip: '继续听 ${download.book.title}',
                      icon: const Icon(Icons.play_circle_fill),
                      onPressed: () => _play(download),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _taskTile(AudioDownloadTask task) {
    final running =
        task.status == AudioDownloadStatus.downloading ||
        task.status == AudioDownloadStatus.waiting;
    final status = switch (task.status) {
      AudioDownloadStatus.waiting => '等待下载',
      AudioDownloadStatus.downloading => '下载中',
      AudioDownloadStatus.paused => '已暂停',
      AudioDownloadStatus.failed => '下载失败',
      AudioDownloadStatus.completed => '已下载',
    };
    return ListTile(
      title: Text(task.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.error == null ? status : '$status · ${task.error}'),
          if (task.status == AudioDownloadStatus.downloading)
            LinearProgressIndicator(value: task.progress),
        ],
      ),
      trailing: TextButton(
        onPressed: running
            ? () => _downloader.pause(task.itemId, toneId: task.toneId)
            : () => _downloader.resume(task.itemId, toneId: task.toneId),
        child: Text(running ? '暂停' : '继续下载'),
      ),
    );
  }
}
