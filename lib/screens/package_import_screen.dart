import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/gallery_card.dart';
import '../services/gallery_store.dart';
import '../services/package_import_service.dart';
import '../theme/gallery_theme.dart';
import '../widgets/gradient_shell.dart';

enum _DuplicateKind {
  none,
  exact,
  fingerprint,
  idConflict,
}

class PackageImportScreen extends StatefulWidget {
  const PackageImportScreen({super.key, required this.store});

  final GalleryStore store;

  @override
  State<PackageImportScreen> createState() => _PackageImportScreenState();
}

class _PackageImportScreenState extends State<PackageImportScreen> {
  PackageImportInspection? _inspection;
  bool _isPicking = false;
  bool _isInspecting = false;
  bool _isImporting = false;
  String? _errorMessage;

  bool get _isBusy => _isPicking || _isInspecting || _isImporting;

  @override
  void dispose() {
    final inspection = _inspection;
    if (inspection != null) {
      unawaited(inspection.dispose());
    }
    super.dispose();
  }

  Future<void> _pickPackage() async {
    if (_isBusy) return;

    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose a TG package',
        type: FileType.custom,
        allowedExtensions: const ['tgpack'],
        allowMultiple: false,
        withData: false,
      );

      if (!mounted || result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null || path.trim().isEmpty) {
        setState(() {
          _errorMessage =
              'The selected package could not be opened as a local file.';
        });
        return;
      }

      await _inspectPackage(File(path));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not choose a package: $error');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _inspectPackage(File packageFile) async {
    final previous = _inspection;

    setState(() {
      _isInspecting = true;
      _inspection = null;
      _errorMessage = null;
    });

    if (previous != null) {
      await previous.dispose();
    }

    try {
      final inspection = await PackageImportService.inspectPackage(packageFile);

      if (!mounted) {
        await inspection.dispose();
        return;
      }

      setState(() => _inspection = inspection);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Package inspection failed: $error');
    } finally {
      if (mounted) setState(() => _isInspecting = false);
    }
  }

  GalleryCard? get _duplicateById {
    final card = _inspection?.card;
    if (card == null) return null;

    for (final existing in widget.store.cards) {
      if (existing.id == card.id) {
        return existing;
      }
    }

    return null;
  }

  GalleryCard? get _duplicateByFingerprint {
    final card = _inspection?.card;
    if (card == null || card.fingerprint.trim().isEmpty) {
      return null;
    }

    for (final existing in widget.store.cards) {
      if (existing.fingerprint.isNotEmpty &&
          existing.fingerprint == card.fingerprint) {
        return existing;
      }
    }

    return null;
  }

  String get _incomingContentHash {
    final manifest = _inspection?.manifest;

    if (manifest == null) {
      return '';
    }

    return manifest.fileHashes[manifest.cardFile] ?? '';
  }

  _DuplicateKind get _duplicateKind {
    final card = _inspection?.card;

    if (card == null) {
      return _DuplicateKind.none;
    }

    final idMatch = _duplicateById;
    final fingerprintMatch = _duplicateByFingerprint;

    if (idMatch != null) {
      final incomingHash = _incomingContentHash.trim();
      final storedHash = idMatch.importedContentHash.trim();

      if (incomingHash.isNotEmpty &&
          storedHash.isNotEmpty &&
          incomingHash == storedHash) {
        return _DuplicateKind.exact;
      }

      return _DuplicateKind.idConflict;
    }

    if (fingerprintMatch != null && fingerprintMatch.id != card.id) {
      return _DuplicateKind.fingerprint;
    }

    return _DuplicateKind.none;
  }

  String? get _duplicateMessage {
    final card = _inspection?.card;
    if (card == null) {
      return null;
    }

    final idMatch = _duplicateById;
    final fingerprintMatch = _duplicateByFingerprint;

    return switch (_duplicateKind) {
      _DuplicateKind.none => null,
      _DuplicateKind.exact => 'This exact card is already in your vault.',
      _DuplicateKind.fingerprint =>
        'This collectible is already in your vault as '
            '"${fingerprintMatch?.title ?? card.title}".',
      _DuplicateKind.idConflict => 'Card ID ${card.id} is already used by '
          '"${idMatch?.title ?? 'another card'}". '
          'You can replace the existing card with this verified package.',
    };
  }

  Future<bool> _confirmReplacement() async {
    final incoming = _inspection?.card;
    final existing = _duplicateById;

    if (incoming == null || existing == null) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.sync_problem_rounded,
            color: Colors.amber,
            size: 38,
          ),
          title: const Text('Replace Existing Card?'),
          content: Text(
            'Card ID ${incoming.id} already belongs to '
            '"${existing.title}".\n\n'
            'Replace it with the verified package "${incoming.title}"?\n\n'
            'The existing card data and its active media references will be '
            'replaced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Replace Existing'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _importPackage({bool replaceExisting = false}) async {
    final inspection = _inspection;
    final card = inspection?.card;

    if (_isBusy || inspection == null || card == null || !inspection.isValid) {
      return;
    }

    final duplicateKind = _duplicateKind;

    if (duplicateKind == _DuplicateKind.exact ||
        duplicateKind == _DuplicateKind.fingerprint) {
      final message = _duplicateMessage;
      if (message != null) {
        _showMessage(message);
      }
      return;
    }

    if (duplicateKind == _DuplicateKind.idConflict && !replaceExisting) {
      final confirmed = await _confirmReplacement();
      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final manifest = inspection.manifest;
      final packageName = inspection.packageFile.uri.pathSegments.isEmpty
          ? inspection.packageFile.path
          : inspection.packageFile.uri.pathSegments.last;

      final importedCard = GalleryCard.fromJson(card.toJson())
        ..importedContentHash = _incomingContentHash
        ..importedAt = DateTime.now()
        ..sourcePackageName = packageName
        ..importedPackageVersion = manifest?.packageVersion ?? 0
        ..importedCreatorVersion = manifest?.creatorVersion ?? ''
        ..importWasReplacement = duplicateKind == _DuplicateKind.idConflict;

      await widget.store.upsertCard(importedCard);
      await inspection.dispose();

      if (!mounted) return;

      setState(() => _inspection = null);
      Navigator.of(context).pop(importedCard);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import TG Package'),
        actions: [
          IconButton(
            tooltip: 'Choose package',
            onPressed: _isBusy ? null : _pickPackage,
            icon: const Icon(Icons.folder_open_rounded),
          ),
        ],
      ),
      body: GradientShell(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              _ErrorBanner(message: _errorMessage!),
              const SizedBox(height: 16),
            ],
            if (_isInspecting)
              const _LoadingPanel()
            else if (inspection == null)
              _EmptyState(isBusy: _isBusy, onChoose: _pickPackage)
            else ...[
              _buildPackagePanel(inspection),
              const SizedBox(height: 16),
              if (inspection.card != null) ...[
                _buildCardPreview(inspection.card!),
                const SizedBox(height: 16),
              ],
              _buildVerificationPanel(inspection),
              if (_duplicateMessage != null) ...[
                const SizedBox(height: 16),
                _DuplicateBanner(message: _duplicateMessage!),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar:
          inspection == null ? null : _buildBottomBar(inspection),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderIcon(),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TG PACKAGE IMPORTER',
                  style: TextStyle(
                    color: GalleryColors.silver,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verify before it enters your vault.',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 7),
                Text(
                  'Every protected file is checked against the package SHA-256 integrity table.',
                  style: TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 14,
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

  Widget _buildPackagePanel(PackageImportInspection inspection) {
    final manifest = inspection.manifest;
    final packageName = inspection.packageFile.uri.pathSegments.isEmpty
        ? inspection.packageFile.path
        : inspection.packageFile.uri.pathSegments.last;

    return _SectionCard(
      title: 'Package',
      icon: Icons.inventory_2_rounded,
      trailing: _StatusBadge(
        valid: inspection.isValid,
        errorCount: inspection.errorCount,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'File', value: packageName),
          _InfoRow(
            label: 'Version',
            value: manifest == null
                ? 'Unavailable'
                : 'TG v${manifest.packageVersion}',
          ),
          _InfoRow(
            label: 'Creator',
            value: manifest?.creatorVersion.isEmpty ?? true
                ? 'Unknown'
                : manifest!.creatorVersion,
          ),
          _InfoRow(
            label: 'Card ID',
            value: manifest?.cardId.isEmpty ?? true
                ? 'Unavailable'
                : manifest!.cardId,
          ),
          _InfoRow(
            label: 'Protected files',
            value: '${manifest?.fileHashes.length ?? 0}',
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildCardPreview(GalleryCard card) {
    final coverPath = card.coverImagePath;
    final coverExists = coverPath != null &&
        coverPath.isNotEmpty &&
        File(coverPath).existsSync();

    return _SectionCard(
      title: 'Card Preview',
      icon: Icons.style_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 112,
            height: 142,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: GalleryColors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: GalleryColors.purpleBright.withValues(alpha: 0.3),
              ),
            ),
            child: coverExists
                ? Image.file(File(coverPath), fit: BoxFit.cover)
                : const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 38,
                      color: GalleryColors.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title.trim().isEmpty ? 'Untitled piece' : card.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  card.description.trim().isEmpty
                      ? 'No description'
                      : card.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: GalleryColors.muted, height: 1.35),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: Icons.auto_awesome_rounded,
                      text:
                          card.rarity.trim().isEmpty ? 'Unrated' : card.rarity,
                    ),
                    _Pill(
                      icon: Icons.photo_library_rounded,
                      text:
                          '${card.media.where((item) => item.type == GalleryMediaType.photo).length} photos',
                    ),
                    _Pill(
                      icon: Icons.movie_rounded,
                      text:
                          '${card.media.where((item) => item.type == GalleryMediaType.video).length} videos',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPanel(PackageImportInspection inspection) {
    final issues = inspection.issues;

    return _SectionCard(
      title: 'Verification',
      icon: Icons.verified_user_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CountBadge(icon: Icons.cancel_rounded, value: inspection.errorCount),
          const SizedBox(width: 8),
          _CountBadge(
              icon: Icons.warning_amber_rounded,
              value: inspection.warningCount),
        ],
      ),
      child: issues.isEmpty
          ? const Text('No verification messages.')
          : Column(
              children: [
                for (var index = 0; index < issues.length; index++) ...[
                  _IssueTile(issue: issues[index]),
                  if (index != issues.length - 1) const Divider(height: 18),
                ],
              ],
            ),
    );
  }

  Widget _buildBottomBar(PackageImportInspection inspection) {
    final duplicateKind = _duplicateKind;

    final canImport =
        inspection.isValid && duplicateKind == _DuplicateKind.none && !_isBusy;

    final canReplace = inspection.isValid &&
        duplicateKind == _DuplicateKind.idConflict &&
        !_isBusy;

    final statusText = switch (duplicateKind) {
      _DuplicateKind.exact => 'This exact card is already in your vault.',
      _DuplicateKind.fingerprint =>
        'This collectible is already in your vault under another card ID.',
      _DuplicateKind.idConflict =>
        'The card ID already exists. Review carefully before replacing it.',
      _DuplicateKind.none => inspection.isValid
          ? 'Package verified and ready to import.'
          : '${inspection.errorCount} verification '
              'error${inspection.errorCount == 1 ? '' : 's'} must be fixed.',
    };

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: GalleryColors.surface,
          border: Border(
            top: BorderSide(
              color: GalleryColors.purpleBright.withValues(alpha: 0.22),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                statusText,
                style: const TextStyle(
                  color: GalleryColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (canReplace)
              FilledButton.icon(
                onPressed: () => _importPackage(),
                icon: _isImporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  _isImporting ? 'Replacing...' : 'Replace Existing',
                ),
              )
            else
              FilledButton.icon(
                onPressed: canImport ? _importPackage : null,
                icon: _isImporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_done_rounded),
                label: Text(_isImporting ? 'Importing...' : 'Import'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

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
        Icons.move_to_inbox_rounded,
        color: Colors.white,
        size: 31,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isBusy, required this.onChoose});

  final bool isBusy;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Choose Package',
      icon: Icons.folder_open_rounded,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 62,
                color: GalleryColors.purpleBright,
              ),
              const SizedBox(height: 14),
              const Text(
                'Select a .tgpack to inspect.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Nothing is added to your vault until verification passes and you press Import.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GalleryColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: isBusy ? null : onChoose,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Choose .tgpack'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'Verifying Package',
      icon: Icons.security_rounded,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Extracting files and checking SHA-256 hashes...',
              textAlign: TextAlign.center,
              style: TextStyle(color: GalleryColors.muted),
            ),
          ],
        ),
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
        color: GalleryColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x447D6C8E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: GalleryColors.purpleBright),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 17),
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
            width: 112,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.valid, required this.errorCount});

  final bool valid;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: valid
            ? Colors.greenAccent.withValues(alpha: 0.12)
            : GalleryColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: valid
              ? Colors.greenAccent.withValues(alpha: 0.35)
              : Colors.redAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            valid ? Icons.verified_rounded : Icons.gpp_bad_rounded,
            color: valid ? Colors.greenAccent : Colors.redAccent,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            valid ? 'Verified' : '$errorCount blocked',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: GalleryColors.purpleBright),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final PackageImportIssue issue;

  @override
  Widget build(BuildContext context) {
    final icon = switch (issue.severity) {
      PackageImportIssueSeverity.error => Icons.cancel_rounded,
      PackageImportIssueSeverity.warning => Icons.warning_amber_rounded,
      PackageImportIssueSeverity.info => Icons.check_circle_rounded,
    };

    final color = switch (issue.severity) {
      PackageImportIssueSeverity.error => Colors.redAccent,
      PackageImportIssueSeverity.warning => Colors.amber,
      PackageImportIssueSeverity.info => Colors.greenAccent,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.message,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (issue.path != null && issue.path!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  issue.path!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: GalleryColors.muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DuplicateBanner extends StatelessWidget {
  const _DuplicateBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.content_copy_rounded, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
