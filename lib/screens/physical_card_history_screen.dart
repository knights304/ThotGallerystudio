import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/nfc_entitlement.dart';
import '../models/physical_card_history_record.dart';
import '../services/physical_card_history_service.dart';
import '../theme/gallery_theme.dart';
import '../widgets/gradient_shell.dart';

class PhysicalCardHistoryScreen extends StatefulWidget {
  const PhysicalCardHistoryScreen({super.key});

  @override
  State<PhysicalCardHistoryScreen> createState() =>
      _PhysicalCardHistoryScreenState();
}

class _PhysicalCardHistoryScreenState extends State<PhysicalCardHistoryScreen> {
  List<PhysicalCardHistoryRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final records = await PhysicalCardHistoryService.loadAll();

    if (!mounted) return;

    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _copyLink(PhysicalCardHistoryRecord record) async {
    await Clipboard.setData(
      ClipboardData(text: record.redemptionUri),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redemption link copied.'),
      ),
    );
  }

  Future<void> _share(PhysicalCardHistoryRecord record) async {
    await SharePlus.instance.share(
      ShareParams(
        text: record.redemptionUri,
        subject: record.entitlement.title.isEmpty
            ? 'THOT Gallery physical card'
            : record.entitlement.title,
      ),
    );
  }

  Future<void> _duplicate(PhysicalCardHistoryRecord record) async {
    final duplicate = await PhysicalCardHistoryService.duplicate(record);

    if (!mounted) return;

    await _load();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          duplicate.entitlement.hasEdition
              ? 'Created new physical card edition '
                  '${duplicate.entitlement.serialNumber} / '
                  '${duplicate.entitlement.editionSize}.'
              : 'Created a duplicate physical-card setup with a new ID.',
        ),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () {
            Navigator.of(context).pop(duplicate);
          },
        ),
      ),
    );
  }

  Future<void> _delete(PhysicalCardHistoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Physical Card Setup?'),
        content: Text(
          'Remove "${record.entitlement.title.isEmpty ? record.sourceCardTitle : record.entitlement.title}" '
          'from Creator history?\n\n'
          'This does not deactivate a QR or NFC card that has already been '
          'distributed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await PhysicalCardHistoryService.delete(record.id);
    await _load();
  }

  String _typeLabel(NfcEntitlementType type) => switch (type) {
        NfcEntitlementType.access => 'Viewer Access',
        NfcEntitlementType.gift => 'Gift / Perk',
        NfcEntitlementType.unlock => 'Unlock Pass',
      };

  String _redemptionLabel(NfcRedemptionMode mode) => switch (mode) {
        NfcRedemptionMode.unlimited => 'Unlimited taps',
        NfcRedemptionMode.onePerAccount => 'One per account',
        NfcRedemptionMode.oneTime => 'One-time',
        NfcRedemptionMode.limited => 'Limited',
      };

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Physical Card History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: GradientShell(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
                ? const _EmptyHistory()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 36),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return _HistoryCard(
                        record: record,
                        typeLabel: _typeLabel(record.entitlement.type),
                        redemptionLabel:
                            _redemptionLabel(record.entitlement.redemptionMode),
                        dateLabel: _dateLabel(record.updatedAt),
                        onOpen: () => Navigator.of(context).pop(record),
                        onDuplicate: () => _duplicate(record),
                        onCopy: () => _copyLink(record),
                        onShare: () => _share(record),
                        onDelete: () => _delete(record),
                      );
                    },
                  ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: GalleryColors.purpleBright,
            ),
            const SizedBox(height: 14),
            const Text(
              'No physical cards saved yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Save a setup from the Physical Card Creator and it will '
              'appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GalleryColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.typeLabel,
    required this.redemptionLabel,
    required this.dateLabel,
    required this.onOpen,
    required this.onDuplicate,
    required this.onCopy,
    required this.onShare,
    required this.onDelete,
  });

  final PhysicalCardHistoryRecord record;
  final String typeLabel;
  final String redemptionLabel;
  final String dateLabel;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final entitlement = record.entitlement;
    final title = entitlement.title.trim().isEmpty
        ? record.sourceCardTitle
        : entitlement.title;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: GalleryColors.purpleDeep,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Physical Card' : title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$typeLabel • $redemptionLabel',
                      style: const TextStyle(
                        color: GalleryColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: GalleryColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'open') onOpen();
                  if (value == 'duplicate') onDuplicate();
                  if (value == 'copy') onCopy();
                  if (value == 'share') onShare();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: Text('Reopen / Edit'),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate Setup'),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Text('Copy Link'),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Text('Share Link'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete History'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: QrImageView(
                data: record.redemptionUri,
                version: QrVersions.auto,
                size: 180,
                gapless: false,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _HistoryLine(label: 'Card', value: entitlement.cardId),
          if (record.sourceCardRarity.isNotEmpty)
            _HistoryLine(
              label: 'Rarity',
              value: record.sourceCardRarity,
            ),
          if (entitlement.targetPackageId.isNotEmpty)
            _HistoryLine(
              label: 'Package / perk',
              value: entitlement.targetPackageId,
            ),
          if (entitlement.hasEdition)
            _HistoryLine(
              label: 'Edition',
              value: '${entitlement.serialNumber} / ${entitlement.editionSize}',
            ),
          if (entitlement.expiresAt != null)
            _HistoryLine(
              label: 'Expires',
              value: entitlement.expiresAt!.toLocal().toString(),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Reopen / Edit Setup'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDuplicate,
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('Duplicate Setup'),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            record.redemptionUri,
            style: const TextStyle(
              color: GalleryColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: GalleryColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
