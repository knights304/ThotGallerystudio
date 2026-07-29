import 'package:flutter/material.dart';

import '../models/gallery_card.dart';
import '../services/gallery_store.dart';
import '../theme/gallery_theme.dart';
import '../widgets/gallery_card_tile.dart';
import '../widgets/gradient_shell.dart';
import '../features/media_studio/media_studio_screen.dart';
import '../features/card_studio/card_studio_screen.dart';
import '../features/publishing_suite/publishing_suite_screen.dart';
import '../features/creator_profiles/creator_profiles_screen.dart';
import '../services/creator_profile_store.dart';
import '../features/theme_builder/theme_builder_screen.dart';
import 'card_detail_screen.dart';
import 'piece_wizard_screen.dart';
import 'signature_profile_screen.dart';

enum _VaultSort { recentlyEdited, title, rarity, favoritesFirst }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, required this.creators});

  final GalleryStore store;
  final CreatorProfileStore creators;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _filter = 'All';
  String _query = '';
  _VaultSort _sort = _VaultSort.recentlyEdited;
  bool _denseBinder = false;
  bool _pagedBinder = true;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<GalleryCard> get _visibleCards {
    final query = _query.trim().toLowerCase();
    final cards = widget.store.cards.where((card) {
      final filterMatch = switch (_filter) {
        'Favorites' => card.isFavorite,
        'Drafts' => card.status == GalleryCardStatus.idea,
        'Published' => card.status != GalleryCardStatus.idea,
        'Legendary' => card.rarity.toLowerCase() == 'legendary',
        _ when _filter.startsWith('Collection: ') =>
          card.collections.contains(_filter.substring(12)),
        _ when _filter.startsWith('Template: ') =>
          card.template.name == _filter.substring(10),
        _ => true,
      };
      if (!filterMatch) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        card.title,
        card.description,
        card.location,
        card.notes,
        card.rarity,
        card.setName,
        ...card.tags,
        ...card.collections,
        ...card.participants,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    switch (_sort) {
      case _VaultSort.recentlyEdited:
        cards.sort(
            (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(2000)).compareTo(
                  a.updatedAt ?? a.createdAt ?? DateTime(2000),
                ));
        break;
      case _VaultSort.title:
        cards.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _VaultSort.rarity:
        int weight(GalleryCard card) => switch (card.rarity.toLowerCase()) {
              'legendary' => 4,
              'epic' => 3,
              'rare' => 2,
              _ => 1,
            };
        cards.sort((a, b) => weight(b).compareTo(weight(a)));
        break;
      case _VaultSort.favoritesFirst:
        cards.sort((a, b) {
          final favorite =
              (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
          if (favorite != 0) return favorite;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
    return cards;
  }

  Future<void> _createPiece() async {
    await Navigator.of(context).push<GalleryCard>(
      MaterialPageRoute(
        builder: (_) => PieceWizardScreen(store: widget.store),
      ),
    );
  }

  Future<void> _openCard(GalleryCard card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(card: card, store: widget.store),
      ),
    );
  }

  Future<void> _showPieceMenu(GalleryCard card) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open piece'),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              leading:
                  Icon(card.isFavorite ? Icons.heart_broken : Icons.favorite),
              title: Text(card.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites'),
              onTap: () => Navigator.pop(context, 'favorite'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Duplicate as draft'),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete piece'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'open') {
      await _openCard(card);
      return;
    }

    if (action == 'favorite') {
      await widget.store.toggleFavorite(card.id);
      return;
    }

    if (action == 'duplicate') {
      await widget.store.duplicateCard(card);
      return;
    }

    if (action == 'delete') {
      if (!mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Gallery Piece?'),
          content: Text(
              'This removes “${card.title}” and its saved media from the vault.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed == true) {
        await widget.store.deleteCard(card.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) {
        0 => GradientShell(child: _buildStudio()),
        1 => MediaStudioScreen(store: widget.store),
        2 => CardStudioScreen(store: widget.store),
        3 =>
          PublishingSuiteScreen(store: widget.store, creators: widget.creators),
        4 => CreatorProfilesScreen(store: widget.creators),
        5 => const ThemeBuilderScreen(),
        _ => SignatureProfileScreen(store: widget.store),
      },
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _createPiece,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('New Piece'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_mosaic_outlined),
            selectedIcon: Icon(Icons.auto_awesome_mosaic),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library_rounded),
            label: 'Media',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style_rounded),
            label: 'Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            selectedIcon: Icon(Icons.rocket_launch_rounded),
            label: 'Publish',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'Creators',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            selectedIcon: Icon(Icons.palette_rounded),
            label: 'Themes',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            label: 'Signature',
          ),
        ],
      ),
    );
  }

  Widget _buildStudio() {
    final width = MediaQuery.sizeOf(context).width;
    final normalColumns = width >= 1050
        ? 4
        : width >= 720
            ? 3
            : 2;
    final columns = _denseBinder ? normalColumns + 1 : normalColumns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THOT GALLERY STUDIO',
                    style: TextStyle(
                      letterSpacing: 2.2,
                      color: GalleryColors.silver,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your private card workshop.',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            _CountBadge(
              icon: Icons.style_rounded,
              value: widget.store.cards.length,
              label: 'Pieces',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SearchBar(
                hintText: 'Search titles, tags, notes, collections...',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_VaultSort>(
              tooltip: 'Sort vault',
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              icon: const Icon(Icons.sort_rounded),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: _VaultSort.recentlyEdited,
                    child: Text('Recently edited')),
                PopupMenuItem(
                    value: _VaultSort.title, child: Text('Title A–Z')),
                PopupMenuItem(value: _VaultSort.rarity, child: Text('Rarity')),
                PopupMenuItem(
                    value: _VaultSort.favoritesFirst,
                    child: Text('Favorites first')),
              ],
            ),
            IconButton.filledTonal(
              tooltip: _pagedBinder ? 'Continuous vault' : 'Paged binder',
              onPressed: () => setState(() => _pagedBinder = !_pagedBinder),
              icon: Icon(
                _pagedBinder
                    ? Icons.menu_book_rounded
                    : Icons.view_module_rounded,
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: _denseBinder ? 'Comfortable binder' : 'Dense binder',
              onPressed: () => setState(() => _denseBinder = !_denseBinder),
              icon: Icon(_denseBinder
                  ? Icons.grid_view_rounded
                  : Icons.grid_on_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _QuickStat(
                  label: 'All',
                  value: widget.store.cards.length,
                  icon: Icons.grid_view_rounded,
                  selected: _filter == 'All',
                  onTap: () => setState(() => _filter = 'All')),
              _QuickStat(
                  label: 'Favorites',
                  value: widget.store.favorites.length,
                  icon: Icons.favorite_rounded,
                  selected: _filter == 'Favorites',
                  onTap: () => setState(() => _filter = 'Favorites')),
              _QuickStat(
                  label: 'Drafts',
                  value: widget.store.drafts.length,
                  icon: Icons.edit_note_rounded,
                  selected: _filter == 'Drafts',
                  onTap: () => setState(() => _filter = 'Drafts')),
              _QuickStat(
                  label: 'Published',
                  value: widget.store.published.length,
                  icon: Icons.public_rounded,
                  selected: _filter == 'Published',
                  onTap: () => setState(() => _filter = 'Published')),
              _QuickStat(
                  label: 'Legendary',
                  value: widget.store.cards
                      .where((c) => c.rarity.toLowerCase() == 'legendary')
                      .length,
                  icon: Icons.auto_awesome,
                  selected: _filter == 'Legendary',
                  onTap: () => setState(() => _filter = 'Legendary')),
            ],
          ),
        ),
        if (widget.store.collections.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.store.collections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final collection = widget.store.collections[index];
                final value = 'Collection: $collection';
                return ChoiceChip(
                  label: Text(collection),
                  selected: _filter == value,
                  avatar: const Icon(Icons.folder_special_outlined, size: 18),
                  onSelected: (_) => setState(() => _filter = value),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '${_visibleCards.length} visible',
              style: const TextStyle(
                  color: GalleryColors.muted, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const Text('Long-press a card for actions',
                style: TextStyle(color: GalleryColors.muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _visibleCards.isEmpty
              ? _EmptyVault(onCreate: _createPiece)
              : _pagedBinder
                  ? _BinderPager(
                      cards: _visibleCards,
                      columns: columns,
                      childAspectRatio: width >= 720 ? 0.9 : 0.72,
                      onOpen: _openCard,
                      onFavorite: (card) =>
                          widget.store.toggleFavorite(card.id),
                      onLongPress: _showPieceMenu,
                    )
                  : GridView.builder(
                      itemCount: _visibleCards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: width >= 720 ? 0.9 : 0.72,
                      ),
                      itemBuilder: (context, index) {
                        final card = _visibleCards[index];
                        return GalleryCardTile(
                          card: card,
                          onFavorite: () =>
                              widget.store.toggleFavorite(card.id),
                          onLongPress: () => _showPieceMenu(card),
                          onTap: () => _openCard(card),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _BinderPager extends StatefulWidget {
  const _BinderPager({
    required this.cards,
    required this.columns,
    required this.childAspectRatio,
    required this.onOpen,
    required this.onFavorite,
    required this.onLongPress,
  });

  final List<GalleryCard> cards;
  final int columns;
  final double childAspectRatio;
  final ValueChanged<GalleryCard> onOpen;
  final ValueChanged<GalleryCard> onFavorite;
  final ValueChanged<GalleryCard> onLongPress;

  @override
  State<_BinderPager> createState() => _BinderPagerState();
}

class _BinderPagerState extends State<_BinderPager> {
  final PageController _controller = PageController();
  int _page = 0;

  int get _rows => widget.columns >= 4 ? 2 : 3;
  int get _perPage => widget.columns * _rows;
  int get _pageCount => (widget.cards.length / _perPage).ceil();

  @override
  void didUpdateWidget(covariant _BinderPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= _pageCount && _pageCount > 0) {
      _page = _pageCount - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpToPage(_page);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _pageCount,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, pageIndex) {
              final start = pageIndex * _perPage;
              final end =
                  (start + _perPage).clamp(0, widget.cards.length).toInt();
              final pageCards = widget.cards.sublist(start, end);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GalleryColors.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x447D6C8E)),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pageCards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: widget.childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final card = pageCards[index];
                    return GalleryCardTile(
                      card: card,
                      onTap: () => widget.onOpen(card),
                      onFavorite: () => widget.onFavorite(card),
                      onLongPress: () => widget.onLongPress(card),
                    );
                  },
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous binder page',
              onPressed: _page > 0
                  ? () => _controller.previousPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      )
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: GalleryColors.panel,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Binder ${_page + 1} / $_pageCount',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Next binder page',
              onPressed: _page + 1 < _pageCount
                  ? () => _controller.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      )
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GalleryColors.purpleBright.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: GalleryColors.purpleBright),
          const SizedBox(width: 8),
          Text('$value $label',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.selected,
      required this.onTap});

  final String label;
  final int value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: selected ? GalleryColors.purpleDeep : GalleryColors.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? Colors.white : GalleryColors.silver),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0 ? constraints.maxHeight : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.style_outlined,
                      size: 70,
                      color: GalleryColors.purpleBright,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your vault is waiting.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Craft your first Gallery Piece with a cover, photos, videos, tags, collections, and a collectible card face.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GalleryColors.muted),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Create First Piece'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
