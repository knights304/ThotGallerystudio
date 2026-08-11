import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/rate_me_card.dart';
import '../../services/rate_me_package_service.dart';
import '../../services/rate_me_response_service.dart';
import '../../services/rate_me_store.dart';
import '../../screens/rate_me_editor_screen.dart';
import '../../screens/rate_me_responses_screen.dart';
import 'rate_me_inbox_screen.dart';

class StudioRateMeHomeScreen extends StatefulWidget {
  const StudioRateMeHomeScreen({super.key});

  @override
  State<StudioRateMeHomeScreen> createState() => _StudioRateMeHomeScreenState();
}

class _StudioRateMeHomeScreenState extends State<StudioRateMeHomeScreen> {
  bool _loading = true;
  bool _importing = false;
  String _query = '';

  List<StudioRateMeCard> _cards = const [];
  Map<String, int> _responseCounts = const {};
  Map<String, double> _averageRatings = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<StudioRateMeCard> get _visibleCards {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) {
      return _cards;
    }

    return _cards.where((card) {
      final haystack = [
        card.title,
        card.description,
        card.owner.displayName,
        for (final media in card.media) media.caption,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  int get _totalResponses {
    return _responseCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
  }

  double get _overallAverage {
    var weightedTotal = 0.0;
    var ratedResponses = 0;

    for (final card in _cards) {
      final count = _responseCounts[card.id] ?? 0;
      final average = _averageRatings[card.id] ?? 0;

      if (count > 0 && average > 0) {
        weightedTotal += average * count;
        ratedResponses += count;
      }
    }

    if (ratedResponses == 0) {
      return 0;
    }

    return weightedTotal / ratedResponses;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    final cards = await StudioRateMeStore.loadAll();
    final responseCounts = <String, int>{};
    final averageRatings = <String, double>{};

    for (final card in cards) {
      responseCounts[card.id] =
          await StudioRateMeResponseService.countForCard(card.id);
      averageRatings[card.id] =
          await StudioRateMeResponseService.averageRatingForCard(
        card.id,
      );
    }

    if (!mounted) return;

    setState(() {
      _cards = cards;
      _responseCounts = responseCounts;
      _averageRatings = averageRatings;
      _loading = false;
    });
  }

  Future<void> _createCard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const StudioRateMeEditorScreen(),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _editCard(
    StudioRateMeCard card,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudioRateMeEditorScreen(
          initialCard: card,
        ),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _openResponses(
    StudioRateMeCard card,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudioRateMeResponsesScreen(
          card: card,
        ),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _openInbox() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const StudioRateMeInboxScreen(),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _importCard() async {
    if (_importing) return;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a Rate Me card',
      type: FileType.custom,
      allowedExtensions: const ['tgrate'],
    );

    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _importing = true);

    try {
      final imported = await StudioRateMePackageService.importPackage(
        File(path),
      );

      final saved = await StudioRateMeStore.saveCard(
        imported.card,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      _message('Imported “${saved.title}”.');

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StudioRateMeEditorScreen(
            initialCard: saved,
          ),
        ),
      );

      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      _message('Could not import Rate Me card: $error');
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _deleteCard(
    StudioRateMeCard card,
  ) async {
    final responseCount = _responseCounts[card.id] ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Rate Me Card?'),
        content: Text(
          responseCount == 0
              ? 'Delete “${card.title}” and its locally stored media?'
              : 'Delete “${card.title}”, its media, and '
                  '$responseCount stored response'
                  '${responseCount == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              false,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              true,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await StudioRateMeResponseService.deleteAllForCard(
      card.id,
    );
    await StudioRateMeStore.deleteCard(card.id);

    if (!mounted) return;

    await _load();

    if (!mounted) return;
    _message('Deleted “${card.title}”.');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Me Studio'),
        actions: [
          IconButton(
            tooltip: 'Rate Me Inbox',
            onPressed: _openInbox,
            icon: Badge(
              isLabelVisible: _totalResponses > 0,
              label: Text('$_totalResponses'),
              child: const Icon(Icons.inbox_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Import .tgrate',
            onPressed: _importing ? null : _importCard,
            icon: _importing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                    ),
                  )
                : const Icon(
                    Icons.download_for_offline_outlined,
                  ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCard,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Rate Me'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  100,
                ),
                children: [
                  const Text(
                    'RATE ME',
                    style: TextStyle(
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Create cards, share them with Viewers, '
                    'and collect honest feedback.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 18),
                  _OverviewPanel(
                    cardCount: _cards.length,
                    responseCount: _totalResponses,
                    averageRating: _overallAverage,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _createCard,
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                        ),
                        label: const Text(
                          'Create Rate Me Card',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importing ? null : _importCard,
                        icon: const Icon(
                          Icons.file_download_outlined,
                        ),
                        label: const Text('Import .tgrate'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openInbox,
                        icon: const Icon(Icons.inbox_outlined),
                        label: Text(
                          _totalResponses == 0
                              ? 'Response Inbox'
                              : 'Response Inbox ($_totalResponses)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SearchBar(
                    hintText: 'Search Rate Me cards and creators...',
                    leading: const Icon(Icons.search_rounded),
                    onChanged: (value) {
                      setState(() => _query = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Your Rate Me Cards',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${_visibleCards.length}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_cards.isEmpty)
                    _EmptyRateMe(
                      onCreate: _createCard,
                      onImport: _importCard,
                    )
                  else if (_visibleCards.isEmpty)
                    const _NoMatches()
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1050
                            ? 3
                            : constraints.maxWidth >= 680
                                ? 2
                                : 1;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _visibleCards.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: columns == 1 ? 1.7 : 1.1,
                          ),
                          itemBuilder: (context, index) {
                            final card = _visibleCards[index];

                            return _RateMeCardTile(
                              card: card,
                              responseCount: _responseCounts[card.id] ?? 0,
                              averageRating: _averageRatings[card.id] ?? 0,
                              onEdit: () => _editCard(card),
                              onResponses: () => _openResponses(card),
                              onDelete: () => _deleteCard(card),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.cardCount,
    required this.responseCount,
    required this.averageRating,
  });

  final int cardCount;
  final int responseCount;
  final double averageRating;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _OverviewMetric(
                icon: Icons.style_outlined,
                value: '$cardCount',
                label: 'Cards',
              ),
            ),
            Expanded(
              child: _OverviewMetric(
                icon: Icons.forum_outlined,
                value: '$responseCount',
                label: 'Responses',
              ),
            ),
            Expanded(
              child: _OverviewMetric(
                icon: Icons.star_rounded,
                value: averageRating > 0
                    ? '${averageRating.toStringAsFixed(2)} 🍆'
                    : '—',
                label: 'Average',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFA78BFA),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _RateMeCardTile extends StatelessWidget {
  const _RateMeCardTile({
    required this.card,
    required this.responseCount,
    required this.averageRating,
    required this.onEdit,
    required this.onResponses,
    required this.onDelete,
  });

  final StudioRateMeCard card;
  final int responseCount;
  final double averageRating;
  final VoidCallback onEdit;
  final VoidCallback onResponses;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final coverPath = card.coverImagePath;
    final hasCover = coverPath != null &&
        coverPath.trim().isNotEmpty &&
        File(coverPath).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                    )
                  else
                    const ColoredBox(
                      color: Color(0xFF21192D),
                      child: Center(
                        child: Icon(
                          Icons.rate_review_rounded,
                          size: 64,
                          color: Color(0xFFFFC857),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'responses') {
                          onResponses();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit card'),
                        ),
                        PopupMenuItem(
                          value: 'responses',
                          child: Text('View responses'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete card'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (card.owner.displayName.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      card.owner.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: [
                      _TinyPill(
                        icon: Icons.collections_outlined,
                        label: '${card.media.length} media',
                      ),
                      _TinyPill(
                        icon: Icons.forum_outlined,
                        label: '$responseCount',
                      ),
                      _TinyPill(
                        icon: Icons.star_rounded,
                        label: averageRating > 0
                            ? '${averageRating.toStringAsFixed(1)} 🍆'
                            : '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onEdit,
                          child: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: onResponses,
                          child: const Text('Responses'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFFA78BFA),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRateMe extends StatelessWidget {
  const _EmptyRateMe({
    required this.onCreate,
    required this.onImport,
  });

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          children: [
            const Icon(
              Icons.rate_review_outlined,
              size: 72,
              color: Color(0xFFA78BFA),
            ),
            const SizedBox(height: 15),
            const Text(
              'Create your first Rate Me card',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add photos and videos, export the card, '
              'and let another Viewer or Studio user rate it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Card'),
                ),
                OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(
                    Icons.file_download_outlined,
                  ),
                  label: const Text('Import Card'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Color(0xFFA78BFA),
            ),
            SizedBox(height: 12),
            Text(
              'No matching Rate Me cards',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
