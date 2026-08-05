import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gallery_card.dart';
import '../models/nfc_entitlement.dart';
import '../models/physical_card_history_record.dart';
import '../services/nfc_card_service.dart';
import '../services/physical_card_history_service.dart';
import '../theme/gallery_theme.dart';
import '../widgets/gradient_shell.dart';
import 'physical_card_history_screen.dart';

class NfcCardPublisherScreen extends StatefulWidget {
  const NfcCardPublisherScreen({
    super.key,
    required this.card,
  });

  final GalleryCard card;

  @override
  State<NfcCardPublisherScreen> createState() => _NfcCardPublisherScreenState();
}

class _NfcCardPublisherScreenState extends State<NfcCardPublisherScreen> {
  final _titleController = TextEditingController();
  final _packageController = TextEditingController();
  final _maxRedemptionsController = TextEditingController();
  final _serialController = TextEditingController();
  final _editionController = TextEditingController();
  final GlobalKey _printCardKey = GlobalKey();
  late String _physicalEntitlementId;
  PhysicalCardHistoryRecord? _editingRecord;

  NfcEntitlementType _type = NfcEntitlementType.access;
  NfcRedemptionMode _redemptionMode = NfcRedemptionMode.unlimited;
  DateTime? _expiresAt;

  bool _checkingAvailability = true;
  bool _nfcAvailable = false;
  bool _writing = false;
  bool _reading = false;
  bool _exporting = false;
  bool _savingHistory = false;

  NfcCardWriteResult? _writeResult;
  NfcCardReadResult? _readResult;

  GalleryCard get _card => widget.card;
  bool get _busy => _writing || _reading || _exporting || _savingHistory;

  @override
  void initState() {
    super.initState();
    _physicalEntitlementId = _generatePhysicalEntitlementId();
    _titleController.text = _card.title;
    _checkAvailability();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _packageController.dispose();
    _maxRedemptionsController.dispose();
    _serialController.dispose();
    _editionController.dispose();
    super.dispose();
  }

  String _generatePhysicalEntitlementId() {
    final random = Random.secure();
    final token = List<int>.generate(
      8,
      (_) => random.nextInt(256),
    )
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();

    final safeCardId =
        _card.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    final cardPart = safeCardId.isEmpty ? 'CARD' : safeCardId;

    return 'NFC-$cardPart-$token';
  }

  String get _entitlementId => _physicalEntitlementId;

  NfcEntitlement get _entitlement {
    _card.ensureFingerprint();

    return NfcEntitlement(
      id: _entitlementId,
      type: _type,
      cardId: _card.id,
      fingerprint: _card.fingerprint,
      title: _titleController.text.trim(),
      targetPackageId: _packageController.text.trim(),
      redemptionMode: _redemptionMode,
      maxRedemptions: int.tryParse(_maxRedemptionsController.text.trim()),
      expiresAt: _expiresAt,
      serialNumber: int.tryParse(_serialController.text.trim()),
      editionSize: int.tryParse(_editionController.text.trim()),
    );
  }

  Uri get _viewerUri => NfcCardService.buildEntitlementUri(_entitlement);

  String _typeLabel(NfcEntitlementType type) => switch (type) {
        NfcEntitlementType.access => 'Viewer Access',
        NfcEntitlementType.gift => 'Gift / Perk',
        NfcEntitlementType.unlock => 'Unlock Pass',
      };

  String _typeDescription(NfcEntitlementType type) => switch (type) {
        NfcEntitlementType.access =>
          'Opens the Viewer and identifies the Gallery Card or package that '
              'should be offered for import.',
        NfcEntitlementType.gift =>
          'Represents a complimentary card, package, bonus, or perk that the '
              'Viewer can redeem.',
        NfcEntitlementType.unlock =>
          'Represents permission to unlock protected Viewer content. '
              'Decryption keys should be delivered securely by a backend, '
              'never stored directly on the NFC tag.',
      };

  String _redemptionLabel(NfcRedemptionMode mode) => switch (mode) {
        NfcRedemptionMode.unlimited => 'Unlimited taps',
        NfcRedemptionMode.onePerAccount => 'One per account',
        NfcRedemptionMode.oneTime => 'One-time redemption',
        NfcRedemptionMode.limited => 'Limited redemptions',
      };

  String get _expirationLabel {
    final value = _expiresAt;
    if (value == null) {
      return 'No expiration';
    }

    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Future<void> _pickExpiration() async {
    if (_busy) return;

    final now = DateTime.now();
    final initial = _expiresAt ?? now.add(const Duration(days: 30));

    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Choose entitlement expiration',
    );

    if (!mounted || selected == null) return;

    setState(() {
      _expiresAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        23,
        59,
        59,
      );
      _writeResult = null;
      _readResult = null;
    });
  }

  void _clearExpiration() {
    if (_busy) return;

    setState(() {
      _expiresAt = null;
      _writeResult = null;
      _readResult = null;
    });
  }

  void _loadHistoryRecord(PhysicalCardHistoryRecord record) {
    final entitlement = record.entitlement;

    setState(() {
      _editingRecord = record;
      _physicalEntitlementId = record.id;
      _type = entitlement.type;
      _redemptionMode = entitlement.redemptionMode;
      _expiresAt = entitlement.expiresAt;

      _titleController.text = entitlement.title;
      _packageController.text = entitlement.targetPackageId;
      _maxRedemptionsController.text =
          entitlement.maxRedemptions?.toString() ?? '';
      _serialController.text = entitlement.serialNumber?.toString() ?? '';
      _editionController.text = entitlement.editionSize?.toString() ?? '';

      _writeResult = null;
      _readResult = null;
    });
  }

  Future<void> _checkAvailability() async {
    setState(() => _checkingAvailability = true);

    try {
      final available = await NfcCardService.isAvailable;

      if (!mounted) return;

      setState(() => _nfcAvailable = available);
    } catch (_) {
      if (!mounted) return;
      setState(() => _nfcAvailable = false);
    } finally {
      if (mounted) {
        setState(() => _checkingAvailability = false);
      }
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(
      ClipboardData(text: _viewerUri.toString()),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('NFC redemption link copied.'),
      ),
    );
  }

  Future<void> _writeTag() async {
    if (_busy || !_nfcAvailable) return;

    if (_redemptionMode == NfcRedemptionMode.limited &&
        (int.tryParse(_maxRedemptionsController.text.trim()) ?? 0) <= 0) {
      _showMessage(
        'Enter a redemption limit greater than zero.',
        success: false,
      );
      return;
    }

    setState(() {
      _writing = true;
      _writeResult = null;
      _readResult = null;
    });

    try {
      final result = await NfcCardService.writeViewerAccessCard(
        uri: _viewerUri,
      );

      if (!mounted) return;

      setState(() => _writeResult = result);
      _showMessage(result.message, success: result.isSuccess);
    } finally {
      if (mounted) {
        setState(() => _writing = false);
      }
    }
  }

  Future<void> _readTag() async {
    if (_busy || !_nfcAvailable) return;

    setState(() {
      _reading = true;
      _readResult = null;
    });

    try {
      final result = await NfcCardService.readViewerAccessCard();

      if (!mounted) return;

      setState(() => _readResult = result);

      final parsed = result.uri == null
          ? null
          : NfcCardService.parseEntitlementUri(result.uri!);

      if (!result.isSuccess) {
        _showMessage(result.message, success: false);
      } else if (parsed == null) {
        _showMessage(
          'The tag is readable, but it is not a THOT Gallery entitlement.',
          success: false,
        );
      } else if (parsed.id == _entitlement.id &&
          parsed.cardId == _entitlement.cardId &&
          parsed.fingerprint == _entitlement.fingerprint &&
          parsed.type == _entitlement.type) {
        _showMessage(
          'Physical NFC card matches this entitlement.',
          success: true,
        );
      } else {
        _showMessage(
          'The tag contains a different THOT Gallery entitlement.',
          success: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _reading = false);
      }
    }
  }

  void _showMessage(
    String message, {
    required bool success,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  String _safeFilename(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return cleaned.isEmpty ? 'THOT_Gallery_NFC' : cleaned;
  }

  Future<void> _exportPrintableCard() async {
    if (_busy) return;

    setState(() => _exporting = true);

    try {
      final currentContext = _printCardKey.currentContext;
      if (currentContext == null) {
        throw StateError('Printable card preview is not ready yet.');
      }

      final boundary =
          currentContext.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Could not render the printable card.');
      }

      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) {
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw StateError('Could not encode the printable card as PNG.');
      }

      final exportDir = await Directory.systemTemp.createTemp('tg_nfc_card_');
      final typeName = _typeLabel(_type).replaceAll(' ', '_');
      final filename =
          '${_safeFilename(_card.title)}_${_safeFilename(typeName)}.png';
      final file = File('${exportDir.path}/$filename');

      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        flush: true,
      );

      await _savePhysicalCardSetup(showConfirmation: false);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${_card.title} Physical NFC / QR Card',
          text: 'Printable THOT Gallery physical-card asset. '
              'QR and NFC use the same entitlement.',
        ),
      );

      if (!mounted) return;

      _showMessage(
        'Printable physical-card PNG created.',
        success: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Could not export the printable card: $error',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _savePhysicalCardSetup({
    bool showConfirmation = true,
  }) async {
    if (_savingHistory) return;

    setState(() => _savingHistory = true);

    try {
      final now = DateTime.now();
      final record = PhysicalCardHistoryRecord(
        id: _entitlement.id,
        createdAt: _editingRecord?.createdAt ?? now,
        updatedAt: now,
        entitlement: _entitlement,
        redemptionUri: _viewerUri.toString(),
        sourceCardTitle: _card.title,
        sourceCardRarity: _card.rarity,
      );

      await PhysicalCardHistoryService.save(record);

      if (mounted) {
        setState(() => _editingRecord = record);
      }

      if (!mounted || !showConfirmation) return;

      _showMessage(
        'Physical card setup saved to history.',
        success: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Could not save physical card history: $error',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() => _savingHistory = false);
      }
    }
  }

  Future<void> _openHistory() async {
    if (_busy) return;

    final record = await Navigator.of(context).push<PhysicalCardHistoryRecord>(
      MaterialPageRoute(
        builder: (_) => const PhysicalCardHistoryScreen(),
      ),
    );

    if (!mounted || record == null) {
      return;
    }

    _loadHistoryRecord(record);

    _showMessage(
      'Loaded saved physical card setup.',
      success: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Physical NFC Card'),
        actions: [
          IconButton(
            tooltip: 'New physical card',
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _editingRecord = null;
                      _physicalEntitlementId = _generatePhysicalEntitlementId();
                      _type = NfcEntitlementType.access;
                      _redemptionMode = NfcRedemptionMode.unlimited;
                      _expiresAt = null;
                      _titleController.text = _card.title;
                      _packageController.clear();
                      _maxRedemptionsController.clear();
                      _serialController.clear();
                      _editionController.clear();
                      _writeResult = null;
                      _readResult = null;
                    });
                  },
            icon: const Icon(Icons.add_card_rounded),
          ),
          IconButton(
            tooltip: 'Physical card history',
            onPressed: _busy ? null : _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: GradientShell(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 36),
          children: [
            _buildHero(),
            const SizedBox(height: 16),
            _buildCardPanel(),
            const SizedBox(height: 16),
            _buildEntitlementPanel(),
            const SizedBox(height: 16),
            _buildRedemptionPanel(),
            const SizedBox(height: 16),
            _buildQrPanel(),
            const SizedBox(height: 16),
            _buildLinkPanel(),
            const SizedBox(height: 16),
            _buildNfcStatusPanel(),
            const SizedBox(height: 16),
            _buildActionsPanel(),
            if (_writeResult != null) ...[
              const SizedBox(height: 16),
              _buildWriteResultPanel(_writeResult!),
            ],
            if (_readResult != null) ...[
              const SizedBox(height: 16),
              _buildReadResultPanel(_readResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: .35),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroIcon(),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHYSICAL CARD CREATOR',
                  style: TextStyle(
                    color: GalleryColors.silver,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Turn an NFC card into access, a gift, or an unlock.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'The tag stores a redemption entitlement, not the media '
                  'package or a decryption key.',
                  style: TextStyle(
                    color: GalleryColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPanel() {
    return _SectionCard(
      title: 'Gallery Card',
      icon: Icons.style_rounded,
      child: Column(
        children: [
          _InfoRow(label: 'Title', value: _card.title),
          _InfoRow(label: 'Card ID', value: _card.id),
          _InfoRow(label: 'Rarity', value: _card.rarity),
          _InfoRow(
            label: 'Fingerprint',
            value: _card.shortFingerprint,
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildEntitlementPanel() {
    return _SectionCard(
      title: 'What This Physical Card Does',
      icon: Icons.card_giftcard_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<NfcEntitlementType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Physical card type',
            ),
            items: NfcEntitlementType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(_typeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                      _writeResult = null;
                      _readResult = null;
                    });
                  },
          ),
          const SizedBox(height: 12),
          Text(
            _typeDescription(_type),
            style: const TextStyle(
              color: GalleryColors.muted,
              height: 1.35,
            ),
          ),
          if (_editingRecord != null) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: GalleryColors.purpleBright,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Editing a saved physical-card setup.',
                    style: TextStyle(
                      color: GalleryColors.silver,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Entitlement label',
              hintText: 'VIP Gift, Free Rare Card, Backstage Unlock...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _packageController,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Package / perk ID (optional)',
              hintText: 'Reserved for Viewer/backend package lookup',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionPanel() {
    final limited = _redemptionMode == NfcRedemptionMode.limited;

    return _SectionCard(
      title: 'Redemption Rules',
      icon: Icons.rule_rounded,
      child: Column(
        children: [
          DropdownButtonFormField<NfcRedemptionMode>(
            initialValue: _redemptionMode,
            decoration: const InputDecoration(
              labelText: 'Redemption mode',
            ),
            items: NfcRedemptionMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(_redemptionLabel(mode)),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _redemptionMode = value);
                  },
          ),
          if (limited) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _maxRedemptionsController,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Maximum redemptions',
                hintText: '100',
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serialController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Physical serial',
                    hintText: '17',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _editionController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Edition size',
                    hintText: '100',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickExpiration,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(_expirationLabel),
                ),
              ),
              if (_expiresAt != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove expiration',
                  onPressed: _clearExpiration,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'One-time, limited, account-bound, expiration, revocation, and '
            'secure unlock enforcement will require the Viewer to redeem this '
            'entitlement through a backend service.',
            style: TextStyle(
              color: GalleryColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPanel() {
    final uri = _viewerUri.toString();

    return _SectionCard(
      title: 'Printable Physical Card',
      icon: Icons.qr_code_2_rounded,
      child: Column(
        children: [
          RepaintBoundary(
            key: _printCardKey,
            child: _PrintablePhysicalCard(
              title: _titleController.text.trim().isEmpty
                  ? _card.title
                  : _titleController.text.trim(),
              cardId: _card.id,
              rarity: _card.rarity,
              typeLabel: _typeLabel(_type),
              redemptionLabel: _redemptionLabel(_redemptionMode),
              editionLabel: _entitlement.hasEdition
                  ? '${_entitlement.serialNumber} / '
                      '${_entitlement.editionSize}'
                  : null,
              expirationLabel:
                  _entitlement.expiresAt == null ? null : _expirationLabel,
              entitlementId: _entitlement.id,
              uri: uri,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Print this card asset or place it into your physical-card '
            'design. The QR carries the same entitlement as the NFC tag.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GalleryColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _savePhysicalCardSetup,
              icon: _savingHistory
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              label: Text(
                _savingHistory
                    ? 'Saving setup...'
                    : _editingRecord == null
                        ? 'Save Physical Card Setup'
                        : 'Update Saved Setup',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _exportPrintableCard,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(
                _exporting ? 'Creating PNG...' : 'Export Printable Card PNG',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('Copy QR / NFC Redemption Link'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPanel() {
    return _SectionCard(
      title: 'NFC Entitlement',
      icon: Icons.link_rounded,
      trailing: IconButton(
        tooltip: 'Copy entitlement link',
        onPressed: _copyLink,
        icon: const Icon(Icons.copy_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: 'ID',
            value: _entitlement.id,
          ),
          _InfoRow(
            label: 'Type',
            value: _typeLabel(_entitlement.type),
          ),
          if (_entitlement.hasEdition)
            _InfoRow(
              label: 'Edition',
              value:
                  '${_entitlement.serialNumber} / ${_entitlement.editionSize}',
            ),
          if (_entitlement.expiresAt != null)
            _InfoRow(
              label: 'Expires',
              value: _expirationLabel,
            ),
          const SizedBox(height: 4),
          SelectableText(
            _viewerUri.toString(),
            style: const TextStyle(
              color: GalleryColors.silver,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNfcStatusPanel() {
    final Widget status;

    if (_checkingAvailability) {
      status = const Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.3),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text('Checking NFC availability...'),
          ),
        ],
      );
    } else if (_nfcAvailable) {
      status = const _StatusLine(
        icon: Icons.nfc_rounded,
        title: 'NFC ready',
        message:
            'This device can scan NFC tags. Use an NDEF-compatible writable tag.',
        success: true,
      );
    } else {
      status = const _StatusLine(
        icon: Icons.nfc_rounded,
        title: 'NFC unavailable',
        message: 'NFC is disabled or this device does not support NFC writing.',
        success: false,
      );
    }

    return _SectionCard(
      title: 'Device NFC',
      icon: Icons.sensors_rounded,
      trailing: IconButton(
        tooltip: 'Check NFC again',
        onPressed: _busy ? null : _checkAvailability,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: status,
    );
  }

  Widget _buildActionsPanel() {
    return _SectionCard(
      title: 'Physical Card Actions',
      icon: Icons.credit_card_rounded,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !_nfcAvailable || _busy || _checkingAvailability
                  ? null
                  : _writeTag,
              icon: _writing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.nfc_rounded),
              label: Text(
                _writing ? 'Waiting for NFC tag...' : 'Write Physical NFC Card',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: !_nfcAvailable || _busy || _checkingAvailability
                  ? null
                  : _readTag,
              icon: _reading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: Text(
                _reading ? 'Waiting for NFC tag...' : 'Test NFC Card',
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Writing replaces the current NDEF message on a writable tag. '
            'Test the card before making a tag permanently read-only.',
            style: TextStyle(
              color: GalleryColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteResultPanel(NfcCardWriteResult result) {
    return _SectionCard(
      title: 'Last Write',
      icon: result.isSuccess
          ? Icons.verified_rounded
          : Icons.error_outline_rounded,
      child: _StatusLine(
        icon: result.isSuccess
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded,
        title: result.isSuccess ? 'Written & verified' : 'Write failed',
        message: result.message,
        success: result.isSuccess,
      ),
    );
  }

  Widget _buildReadResultPanel(NfcCardReadResult result) {
    final parsed = result.uri == null
        ? null
        : NfcCardService.parseEntitlementUri(result.uri!);

    final matches = parsed != null &&
        parsed.id == _entitlement.id &&
        parsed.cardId == _entitlement.cardId &&
        parsed.fingerprint == _entitlement.fingerprint &&
        parsed.type == _entitlement.type;

    return _SectionCard(
      title: 'Last Test',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(
            icon: matches ? Icons.verified_rounded : Icons.info_outline_rounded,
            title: matches
                ? 'Physical card matches'
                : result.isSuccess
                    ? 'Different entitlement'
                    : 'Could not verify tag',
            message: result.message,
            success: matches,
          ),
          if (result.uri != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Read from tag',
              style: TextStyle(
                color: GalleryColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              result.uri.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrintablePhysicalCard extends StatelessWidget {
  const _PrintablePhysicalCard({
    required this.title,
    required this.cardId,
    required this.rarity,
    required this.typeLabel,
    required this.redemptionLabel,
    required this.entitlementId,
    required this.uri,
    this.editionLabel,
    this.expirationLabel,
  });

  final String title;
  final String cardId;
  final String rarity;
  final String typeLabel;
  final String redemptionLabel;
  final String entitlementId;
  final String uri;
  final String? editionLabel;
  final String? expirationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: GalleryColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: .45),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: GalleryColors.purpleBright,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'THOT GALLERY',
                  style: TextStyle(
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.nfc_rounded,
                color: GalleryColors.silver,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$typeLabel • $rarity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalleryColors.silver,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: uri,
              version: QrVersions.auto,
              size: 210,
              gapless: false,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap NFC or scan QR to redeem',
            style: TextStyle(
              color: GalleryColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _PrintableLine(label: 'Card', value: cardId),
          _PrintableLine(label: 'Rule', value: redemptionLabel),
          if (editionLabel != null)
            _PrintableLine(label: 'Edition', value: editionLabel!),
          if (expirationLabel != null)
            _PrintableLine(label: 'Expires', value: expirationLabel!),
          const SizedBox(height: 12),
          Text(
            entitlementId,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalleryColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintableLine extends StatelessWidget {
  const _PrintableLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: GalleryColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: GalleryColors.purpleDeep,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.nfc_rounded,
        color: Colors.white,
        size: 31,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: .2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: GalleryColors.purpleBright,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.bottomPadding = 10,
  });

  final String label;
  final String value;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: GalleryColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.title,
    required this.message,
    required this.success,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.greenAccent : Colors.amber;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: GalleryColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
