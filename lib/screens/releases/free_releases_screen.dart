import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/releases_provider.dart';
import 'release_detail_screen.dart';

class FreeReleasesScreen extends ConsumerWidget {
  const FreeReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(releasesProvider((search: '', artistId: 0)));
    return Scaffold(
      appBar: AppBar(title: const Text('Ingyenes kiadványok')),
      body: releases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Az ingyenes kiadványok nem tölthetők be.'),
        ),
        data: (items) {
          final free = items.where((release) => release.isFree).toList();
          if (free.isEmpty) {
            return const Center(child: Text('Nincs ingyenes kiadvány.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            itemCount: free.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final release = free[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReleaseDetailScreen(release: release),
                    ),
                  ),
                  child: SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 150,
                          child: release.coverUrl.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xFF242424),
                                  child: Icon(
                                    Icons.album,
                                    size: 42,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: release.coverUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  maxWidthDiskCache: 300,
                                  placeholder: (_, _) => const ColoredBox(
                                    color: Color(0xFF242424),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => const ColoredBox(
                                    color: Color(0xFF242424),
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 42,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: Text(
                              release.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: const Text('Ingyenesen letölthető WAV'),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
