import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/rate_me_package_service.dart';
import '../../services/studio_cloud_service.dart';

import '../../models/rate_me_card.dart';
import '../../services/rate_me_response_service.dart';
import '../../services/rate_me_store.dart';
import '../../screens/rate_me_responses_screen.dart';
import '../../screens/studio_rate_me_recipient_screen.dart';

class StudioRateMeInboxScreen extends StatefulWidget {
  const StudioRateMeInboxScreen({super.key});

  @override
  State<StudioRateMeInboxScreen> createState() =>
      _StudioRateMeInboxScreenState();
}

class _StudioRateMeInboxScreenState extends State<StudioRateMeInboxScreen> {
  bool _loading = true;
  bool _cloudBusy = false;

  StudioCloudProfile? _cloudProfile;
  List<StudioCloudDelivery> _cloudDeliveries = const [];

  List<_InboxCard> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    StudioCloudProfile? cloudProfile;
    List<StudioCloudDelivery> cloudDeliveries = const [];

    try {
      if (await StudioCloudService.instance.isAuthenticated) {
        cloudProfile = await StudioCloudService.instance.getMe();
        cloudDeliveries = await StudioCloudService.instance.getInbox();
      }
    } catch (_) {
      cloudProfile = null;
      cloudDeliveries = const [];
    }

    final cards = await StudioRateMeStore.loadAll();
    final items = <_InboxCard>[];

    for (final card in cards) {
      final responses = await StudioRateMeResponseService.loadForCard(card.id);

      if (responses.isEmpty) continue;

      final average =
          await StudioRateMeResponseService.averageRatingForCard(card.id);

      items.add(
        _InboxCard(
          card: card,
          responseCount: responses.length,
          averageRating: average,
          newestAt: responses.first.response.createdAt,
        ),
      );
    }

    items.sort((a, b) => b.newestAt.compareTo(a.newestAt));

    if (!mounted) return;

    setState(() {
      _cloudProfile = cloudProfile;
      _cloudDeliveries = cloudDeliveries;
      _items = items;
      _loading = false;
    });
  }

  int get _totalResponses =>
      _items.fold(0, (sum, item) => sum + item.responseCount);

  Future<void> _open(_InboxCard item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudioRateMeResponsesScreen(card: item.card),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _connectCloudProfile() async {
    if (_cloudBusy) return;

    var enteredToken = '';

    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Connect Studio Cloud Profile'),
          content: TextField(
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (value) {
              enteredToken = value.trim();
            },
            decoration: const InputDecoration(
              labelText: 'Device token',
              hintText: 'tga_...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  enteredToken,
                );
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );

    if (token == null || token.isEmpty || !mounted) return;

    setState(() => _cloudBusy = true);

    try {
      await StudioCloudService.instance.saveDeviceToken(token);

      final profile = await StudioCloudService.instance.getMe();

      if (profile.profileType != 'studio') {
        await StudioCloudService.instance.clearDeviceToken();

        throw const StudioCloudException(
          'That token belongs to a Viewer profile.',
        );
      }

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected as @${profile.username}.',
          ),
        ),
      );
    } on StudioCloudException catch (error) {
      await StudioCloudService.instance.clearDeviceToken();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not connect: ${error.message}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cloudBusy = false);
      }
    }
  }

  Future<void> _disconnectCloudProfile() async {
    if (_cloudBusy) return;

    setState(() => _cloudBusy = true);

    try {
      await StudioCloudService.instance.clearDeviceToken();

      if (!mounted) return;

      setState(() {
        _cloudProfile = null;
        _cloudDeliveries = const [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Studio Cloud Profile disconnected.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cloudBusy = false);
      }
    }
  }

  Future<void> _importCloudDelivery(
    StudioCloudDelivery delivery,
  ) async {
    if (_cloudBusy) return;

    setState(() => _cloudBusy = true);

    File? temporaryFile;

    try {
      final bytes = await StudioCloudService.instance.downloadRateMePackage(
        delivery.id,
      );

      final temporary = await getTemporaryDirectory();

      temporaryFile = File(
        '${temporary.path}/'
        '${delivery.cardId}_${delivery.id}.tgrate',
      );

      await temporaryFile.writeAsBytes(
        bytes,
        flush: true,
      );

      final imported = await StudioRateMePackageService.importPackage(
        temporaryFile,
      );

      final openedDelivery = await StudioCloudService.instance.markOpened(
        delivery.id,
      );

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StudioRateMeRecipientScreen(
            card: imported.card,
            delivery: openedDelivery,
          ),
        ),
      );

      if (!mounted) return;

      await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not import cloud Rate Me: $error',
          ),
        ),
      );
    } finally {
      try {
        if (temporaryFile != null && await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _cloudBusy = false);
      }
    }
  }

  Future<void> _archiveCloudDelivery(
    StudioCloudDelivery delivery,
  ) async {
    if (_cloudBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Incoming Rate Me?'),
        content: Text(
          'Remove this Rate Me card from '
          '@${delivery.sender.username} from your inbox? '
          'This does not delete their original card.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cloudBusy = true);

    try {
      await StudioCloudService.instance.archiveDelivery(
        delivery.id,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incoming Rate Me removed from inbox.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not remove Rate Me: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cloudBusy = false);
      }
    }
  }

  Widget _buildCloudSection() {
    final profile = _cloudProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  profile == null
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                  color: const Color(0xFFA78BFA),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cloud Rate Me',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (profile == null) ...[
              const Text(
                'Connect Studio to its THOT Gallery '
                'cloud profile to receive Rate Me '
                'cards directly.',
                style: TextStyle(
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _cloudBusy ? null : _connectCloudProfile,
                icon: const Icon(Icons.link_rounded),
                label: const Text(
                  'Connect Studio Cloud Profile',
                ),
              ),
            ] else ...[
              Text(
                profile.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '@${profile.username} · Studio',
                style: const TextStyle(
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${_cloudDeliveries.length} incoming '
                'cloud Rate Me card'
                '${_cloudDeliveries.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_cloudDeliveries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No incoming cloud Rate Me cards.',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                )
              else
                for (final delivery in _cloudDeliveries) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.rate_review_outlined,
                      ),
                    ),
                    title: Text(
                      delivery.cardId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      'From @${delivery.sender.username}'
                      ' · ${delivery.status}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: _cloudBusy
                              ? null
                              : () => _importCloudDelivery(
                                    delivery,
                                  ),
                          child: Text(
                            delivery.status == 'sent' ? 'Open' : 'Open',
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Remove from inbox',
                          onPressed: _cloudBusy
                              ? null
                              : () => _archiveCloudDelivery(
                                    delivery,
                                  ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cloudBusy ? null : _disconnectCloudProfile,
                icon: const Icon(
                  Icons.link_off_rounded,
                ),
                label: const Text(
                  'Disconnect Cloud Profile',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Me Inbox'),
        actions: [
          IconButton(
            tooltip: 'Refresh inbox',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _buildCloudSection(),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mark_email_unread_outlined,
                            size: 34,
                            color: Color(0xFFA78BFA),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'All Rate Me Responses',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$_totalResponses total response'
                                  '${_totalResponses == 1 ? '' : 's'} '
                                  'across ${_items.length} card'
                                  '${_items.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_items.isEmpty)
                    const _EmptyInbox()
                  else
                    for (final item in _items) ...[
                      Card(
                        child: ListTile(
                          onTap: () => _open(item),
                          leading: CircleAvatar(
                            child: Text(
                              item.averageRating > 0
                                  ? item.averageRating.toStringAsFixed(1)
                                  : '—',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          title: Text(
                            item.card.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(
                            '${item.responseCount} response'
                            '${item.responseCount == 1 ? '' : 's'}'
                            '${item.averageRating > 0 ? ' · ${item.averageRating.toStringAsFixed(2)} / 5' : ''}',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }
}

class _InboxCard {
  const _InboxCard({
    required this.card,
    required this.responseCount,
    required this.averageRating,
    required this.newestAt,
  });

  final StudioRateMeCard card;
  final int responseCount;
  final double averageRating;
  final DateTime newestAt;
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Color(0xFFA78BFA),
            ),
            SizedBox(height: 14),
            Text(
              'Your Rate Me inbox is empty',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Imported .tgrateresponse files will appear here, grouped by Rate Me card.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
