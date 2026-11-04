import 'package:flutter/material.dart';

import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/history_repository.dart';

class WatchStatsPage extends StatefulWidget {
  const WatchStatsPage({super.key, required this.repository});

  final IHistoryRepository repository;

  @override
  State<WatchStatsPage> createState() => _WatchStatsPageState();
}

class _WatchStatsPageState extends State<WatchStatsPage> {
  IHistoryRepository get repository => widget.repository;
  String query = '';
  bool byEpisodes = false;

  String date(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('观看统计详情')),
        body: StreamBuilder<void>(
          stream: repository.changes,
          builder: (context, snapshot) {
            final grouped = <int, List<History>>{};
            for (final h in repository.getAllHistories()) {
              if (h.progresses.isNotEmpty) {
                grouped.putIfAbsent(h.bangumiItem.id, () => []).add(h);
              }
            }
            final all = grouped.values.map(_WatchEntry.new).toList();
            final entries = all.where((e) =>
                '${e.latest.bangumiItem.name} ${e.latest.bangumiItem.nameCn}'
                    .toLowerCase().contains(query.toLowerCase())).toList();
            entries.sort((a, b) {
              if (byEpisodes) {
                final count = b.episodes.length.compareTo(a.episodes.length);
                if (count != 0) return count;
              }
              return b.latest.lastWatchTime.compareTo(a.latest.lastWatchTime);
            });
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('共 ${all.length} 部 · ${all.fold<int>(0, (n, e) => n + e.episodes.length)} 集',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('依据现存历史记录统计，集数跨播放源去重；有记录不代表已看完。清除历史会影响统计。'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '搜索作品', prefixIcon: Icon(Icons.search)),
                    onChanged: (value) => setState(() => query = value.trim()),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('最近观看'), selected: !byEpisodes,
                        onSelected: (_) => setState(() => byEpisodes = false)),
                    ChoiceChip(label: const Text('观看集数'), selected: byEpisodes,
                        onSelected: (_) => setState(() => byEpisodes = true)),
                  ]),
                ]),
              ),
              Expanded(child: entries.isEmpty
                  ? Center(child: Text(all.isEmpty ? '还没有观看记录' : '没有匹配的作品'))
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final e = entries[index];
                        final item = e.latest.bangumiItem;
                        final episodes = e.episodes.keys.toList()..sort();
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ExpansionTile(
                            key: PageStorageKey(item.id),
                            title: Text(item.nameCn.isEmpty ? item.name : item.nameCn),
                            subtitle: Text('已观看 ${episodes.length} 集\n上次观看：${date(e.latest.lastWatchTime)} · 第 ${e.latest.lastWatchEpisode} 集'),
                            children: episodes.map((number) {
                              final p = e.episodes[number]!;
                              final seconds = p.progress.inSeconds;
                              return ListTile(
                                title: Text('第 $number 集'),
                                subtitle: Text(p.updatedAtMs > 0
                                    ? '最近记录：${date(DateTime.fromMillisecondsSinceEpoch(p.updatedAtMs))}'
                                    : '历史记录未保存分集时间'),
                                trailing: Text(seconds > 0
                                    ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
                                    : '无续播进度'),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    )),
            ]);
          },
        ),
      );
}

class _WatchEntry {
  _WatchEntry(List<History> histories) {
    histories.sort((a, b) => b.lastWatchTime.compareTo(a.lastWatchTime));
    latest = histories.first;
    final times = <int, int>{};
    for (final h in histories) {
      for (final entry in h.progresses.entries) {
        final time = entry.value.effectiveUpdatedAtMs(h.lastWatchTime);
        if (!times.containsKey(entry.key) || time > times[entry.key]!) {
          times[entry.key] = time;
          episodes[entry.key] = entry.value;
        }
      }
    }
  }

  late final History latest;
  final episodes = <int, Progress>{};
}

