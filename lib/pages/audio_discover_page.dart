import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backend_service.dart';
import '../widgets/search/search_media_tile.dart';
import 'category_page.dart';
import 'detail_page.dart';
import 'home_provider.dart';
import 'search_page.dart';

final audioDiscoverProvider = NotifierProvider<HomeNotifier, HomeState>(
  () => HomeNotifier(
    initialTabIndex: HomeNotifier.tabs.indexOf('听书'),
    usesLocalTabs: true,
  ),
);

class AudioDiscoverPage extends ConsumerStatefulWidget {
  const AudioDiscoverPage({super.key});

  @override
  ConsumerState<AudioDiscoverPage> createState() => _AudioDiscoverPageState();
}

class _AudioDiscoverPageState extends ConsumerState<AudioDiscoverPage> {
  bool _loading = false;
  bool _connectionFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(audioDiscoverProvider).items.isEmpty) _load();
    });
  }

  Future<void> _connect() =>
      BackendService.instance.start().timeout(const Duration(seconds: 12));

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _connectionFailed = false;
    });
    try {
      await _connect();
      if (!mounted) return;
      await ref.read(audioDiscoverProvider.notifier).load(manualRefresh: true);
    } on Exception {
      if (mounted) setState(() => _connectionFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget page) async {
    try {
      await _connect();
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => page));
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法联网找书，已下载的书仍可播放。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(audioDiscoverProvider);
    final items = {
      for (final item in [
        ...feed.cells.expand((cell) => cell.flatten()),
        ...feed.items,
      ])
        if (item.kind == 'audio' && item.id.isNotEmpty) item.id: item,
    }.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('找书')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
          itemCount: items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => _open(const SearchPage(audioOnly: true)),
                    icon: const Icon(Icons.search),
                    label: const Text('搜索有声书'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(const CategoryPage(audioOnly: true)),
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('听书分类'),
                  ),
                  const SizedBox(height: 20),
                  Text('在线推荐', style: Theme.of(context).textTheme.titleLarge),
                ],
              );
            }
            if (index <= items.length) {
              final item = items[index - 1];
              return SearchNovelRow(
                key: ValueKey(item.id),
                item: item,
                onTap: () => openBookDetail(context, item),
              );
            }
            if (_loading || feed.isLoading || feed.isLoadMore) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_connectionFailed || feed.error != null || items.isEmpty) {
              return ListTile(
                title: const Text('暂时没有推荐'),
                trailing: TextButton(onPressed: _load, child: const Text('重试')),
              );
            }
            return feed.hasMore
                ? TextButton(
                    onPressed: ref
                        .read(audioDiscoverProvider.notifier)
                        .loadMore,
                    child: const Text('加载更多'),
                  )
                : const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
