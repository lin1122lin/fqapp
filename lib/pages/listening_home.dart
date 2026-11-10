import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/audio_floating_routes.dart';
import '../services/backend_service.dart';
import '../services/release_update.dart';
import 'about_page.dart';
import 'audio_downloads_page.dart';
import 'audio_page.dart';
import 'search_page.dart';

class ListeningHome extends StatefulWidget {
  const ListeningHome({super.key});

  @override
  State<ListeningHome> createState() => _ListeningHomeState();
}

class _ListeningHomeState extends State<ListeningHome> {
  int _tab = 0;
  late Future<RecentListen?> _recent;
  late final Future<({String version, Uri apk})?> _update;
  bool _dismissedUpdate = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _recent = loadRecentListen();
    _update = checkReleaseUpdate(
      AboutPage.versionText.split(' ').first,
    ).catchError((Object _) => null);
  }

  Future<void> _continue(RecentListen recent) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final request = await recent.request();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => request));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂时无法继续听。断网时请从「下载」打开已下载章节。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _recent = loadRecentListen();
        });
      }
    }
  }

  Future<void> _find() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await BackendService.instance.start().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const SearchPage(audioOnly: true)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法联网找书，已下载的书仍可播放。')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _recent = loadRecentListen();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AudioFloatingRouteScope.configure(context, hidden: false);
    final page = switch (_tab) {
      1 => Scaffold(
        appBar: AppBar(title: const Text('找书')),
        body: Center(
          child: FilledButton.icon(
            onPressed: _opening ? null : _find,
            icon: const Icon(Icons.search),
            label: Text(_opening ? '正在连接…' : '搜索有声书'),
          ),
        ),
      ),
      2 => AudioDownloadsPage(onFind: () => setState(() => _tab = 1)),
      _ => _continuePage(),
    };
    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() {
          _tab = index;
          if (index == 0) _recent = loadRecentListen();
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.headphones), label: '继续听'),
          NavigationDestination(icon: Icon(Icons.search), label: '找书'),
          NavigationDestination(icon: Icon(Icons.download), label: '下载'),
        ],
      ),
    );
  }

  Widget _continuePage() => Scaffold(
    appBar: AppBar(
      title: const Text('继续听'),
      actions: [
        IconButton(
          tooltip: '关于和更新',
          icon: const Icon(Icons.info_outline),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const AboutPage(listeningEdition: true),
            ),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
      children: [
        FutureBuilder<RecentListen?>(
          future: _recent,
          builder: (context, snapshot) {
            final recent = snapshot.data;
            if (recent == null) {
              return ListTile(
                title: const Text('从一本有声书开始'),
                subtitle: const Text('有下载的书时，点「下载」就能离线播放。'),
                onTap: () => setState(() => _tab = 2),
              );
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      recent.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: recent.progress),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _opening ? null : () => _continue(recent),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('接着听'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (!_dismissedUpdate)
          FutureBuilder(
            future: _update,
            builder: (context, snapshot) {
              final update = snapshot.data;
              if (update == null) return const SizedBox.shrink();
              return Card(
                child: ListTile(
                  title: Text('有新版本 ${update.version}'),
                  subtitle: TextButton(
                    onPressed: () => launchUrl(
                      update.apk,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('下载更新'),
                  ),
                  trailing: IconButton(
                    tooltip: '稍后再说',
                    onPressed: () => setState(() => _dismissedUpdate = true),
                    icon: const Icon(Icons.close),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}
