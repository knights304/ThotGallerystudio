import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/gallery_card.dart';
import '../services/package_builder_service.dart';
import '../services/package_validation_service.dart';
import '../theme/gallery_theme.dart';
import '../widgets/gradient_shell.dart';
import '../widgets/metadata_panel.dart';

class PackageBuilderScreen extends StatefulWidget {
  const PackageBuilderScreen({
    super.key,
    required this.card,
  });

  final GalleryCard card;

  @override
  State<PackageBuilderScreen> createState() => _PackageBuilderScreenState();
}

class _PackageBuilderScreenState extends State<PackageBuilderScreen> {
  PackageValidationReport? _validation;
  PackageBuildProgress? _progress;
  PackageBuildResult? _result;
  Directory? _outputDirectory;

  bool _isValidating = false;
  bool _isBuilding = false;
  String? _errorMessage;

  GalleryCard get _card => widget.card;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await _resolveDefaultOutputDirectory();
    await _validate();
  }

  Future<void> _resolveDefaultOutputDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      final base = downloads ?? await getApplicationDocumentsDirectory();
      final directory = Directory(p.join(base.path, 'Thot Gallery Packages'));

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _outputDirectory = directory;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _outputDirectory = null;
      });
    }
  }

  Future<void> _validate() async {
    if (_isValidating || _isBuilding) {
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final report = await PackageValidationService.validate(_card);

      if (!mounted) {
        return;
      }

      setState(() {
        _validation = report;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Validation failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  Future<void> _chooseOutputDirectory() async {
    if (_isBuilding) {
      return;
    }

    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose TG package folder',
      );

      if (selectedPath == null || !mounted) {
        return;
      }

      setState(() {
        _outputDirectory = Directory(selectedPath);
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Could not choose a folder: $error';
      });
    }
  }

  Future<void> _buildPackage() async {
    final validation = _validation;
    final outputDirectory = _outputDirectory;

    if (_isBuilding) {
      return;
    }

    if (validation == null) {
      await _validate();
      return;
    }

    if (!validation.canBuild) {
      _showMessage(
        'Fix the validation errors before building this package.',
      );
      return;
    }

    if (outputDirectory == null) {
      _showMessage('Choose an output folder first.');
      return;
    }

    setState(() {
      _isBuilding = true;
      _result = null;
      _errorMessage = null;
      _progress = const PackageBuildProgress(
        stage: PackageBuildStage.validating,
        progress: 0,
        message: 'Starting package build...',
      );
    });

    try {
      final result = await PackageBuilderService.buildPackage(
        card: _card,
        outputDirectory: outputDirectory,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            _progress = progress;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _progress = const PackageBuildProgress(
          stage: PackageBuildStage.completed,
          progress: 1,
          message: 'TG package built successfully.',
        );
      });

      await _showBuildCompleteDialog(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Package build failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBuilding = false;
        });
      }
    }
  }

  Future<void> _showBuildCompleteDialog(PackageBuildResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.inventory_2_rounded,
            color: GalleryColors.purpleBright,
            size: 42,
          ),
          title: const Text('Package Complete'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(result.packageFile.path),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  result.packageFile.path,
                  style: const TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Size: ${PackageValidationService.formatBytes(result.manifest.packageSizeBytes)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'SHA-256: ${_shortHash(result.manifest.packageHash)}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: result.packageFile.path),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Package path copied.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Path'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    final width = MediaQuery.sizeOf(context).width;
    final useTwoColumns = width >= 960;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Package Builder'),
        actions: [
          IconButton(
            tooltip: 'Run validation again',
            onPressed: _isBuilding ? null : _validate,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: GradientShell(
        child: RefreshIndicator(
          onRefresh: _validate,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _buildHeader(validation),
              const SizedBox(height: 16),
              MetadataPanel(
                card: _card,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              if (useTwoColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildPackageSummary(validation),
                          const SizedBox(height: 16),
                          _buildOutputPanel(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _buildValidationPanel(validation),
                    ),
                  ],
                )
              else ...[
                _buildPackageSummary(validation),
                const SizedBox(height: 16),
                _buildOutputPanel(),
                const SizedBox(height: 16),
                _buildValidationPanel(validation),
              ],
              if (_progress != null || _isBuilding) ...[
                const SizedBox(height: 16),
                _buildProgressPanel(),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _buildResultPanel(_result!),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(validation),
    );
  }

  Widget _buildHeader(PackageValidationReport? validation) {
    final ready = validation?.canBuild == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: ready
              ? Colors.greenAccent.withValues(alpha: 0.45)
              : GalleryColors.purpleBright.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: GalleryColors.purpleDeep,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              ready ? Icons.inventory_2_rounded : Icons.inventory_2_outlined,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TG PACKAGE BUILDER',
                  style: TextStyle(
                    color: GalleryColors.silver,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  ready
                      ? 'Ready to seal this piece into a .tgpack.'
                      : 'Review the package before export.',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _card.title.trim().isEmpty ? 'Untitled piece' : _card.title,
                  style: const TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          _ReadinessBadge(
            isLoading: _isValidating,
            isReady: ready,
            errorCount: validation?.errorCount ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSummary(PackageValidationReport? validation) {
    final coverPath = _card.coverImagePath;
    final coverExists = coverPath != null &&
        coverPath.isNotEmpty &&
        File(coverPath).existsSync();

    return _SectionCard(
      title: 'Package Summary',
      icon: Icons.dashboard_customize_rounded,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 118,
                height: 148,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: GalleryColors.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: GalleryColors.purpleBright.withValues(alpha: 0.3),
                  ),
                ),
                child: coverExists
                    ? Image.file(
                        File(coverPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _MissingCoverPreview(),
                      )
                    : const _MissingCoverPreview(),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Card',
                      value:
                          _card.title.trim().isEmpty ? 'Untitled' : _card.title,
                    ),
                    _SummaryRow(
                      label: 'Set',
                      value: _card.setName.trim().isEmpty
                          ? 'Not assigned'
                          : _card.setName,
                    ),
                    _SummaryRow(
                      label: 'Rarity',
                      value: _card.rarity.trim().isEmpty
                          ? 'Not assigned'
                          : _card.rarity,
                    ),
                    _SummaryRow(
                      label: 'Card number',
                      value: '${_card.cardNumber} / ${_card.setTotal}',
                    ),
                    _SummaryRow(
                      label: 'Package format',
                      value: '.tgpack v1',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.photo_library_rounded,
                  value: '${validation?.photoCount ?? _photoCount}',
                  label: 'Photos',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.movie_rounded,
                  value: '${validation?.videoCount ?? _videoCount}',
                  label: 'Videos',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.sd_storage_rounded,
                  value: validation?.estimatedSizeLabel ?? 'Calculating',
                  label: 'Estimated',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPanel() {
    final path = _outputDirectory?.path ?? 'No output folder selected';

    return _SectionCard(
      title: 'Output',
      icon: Icons.folder_zip_rounded,
      trailing: TextButton.icon(
        onPressed: _isBuilding ? null : _chooseOutputDirectory,
        icon: const Icon(Icons.folder_open_rounded),
        label: const Text('Choose'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Package folder',
            style: TextStyle(
              color: GalleryColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            path,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 15),
          const Text(
            'Output filename',
            style: TextStyle(
              color: GalleryColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _expectedFilename,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationPanel(PackageValidationReport? validation) {
    if (_isValidating && validation == null) {
      return const _SectionCard(
        title: 'Validation',
        icon: Icons.fact_check_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (validation == null) {
      return _SectionCard(
        title: 'Validation',
        icon: Icons.fact_check_rounded,
        child: Center(
          child: FilledButton.icon(
            onPressed: _validate,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Run Validation'),
          ),
        ),
      );
    }

    return _SectionCard(
      title: 'Validation',
      icon: Icons.fact_check_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniCount(
            icon: Icons.cancel_rounded,
            value: validation.errorCount,
            label: 'Errors',
          ),
          const SizedBox(width: 8),
          _MiniCount(
            icon: Icons.warning_amber_rounded,
            value: validation.warningCount,
            label: 'Warnings',
          ),
        ],
      ),
      child: validation.issues.isEmpty
          ? const Text('No validation results.')
          : Column(
              children: [
                for (var index = 0;
                    index < validation.issues.length;
                    index++) ...[
                  _ValidationIssueTile(issue: validation.issues[index]),
                  if (index != validation.issues.length - 1)
                    const Divider(height: 18),
                ],
              ],
            ),
    );
  }

  Widget _buildProgressPanel() {
    final progress = _progress;
    final value = (progress?.progress ?? 0).clamp(0.0, 1.0);

    return _SectionCard(
      title: 'Build Progress',
      icon: Icons.bolt_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: _isBuilding ? value : 1,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  progress?.message ?? 'Waiting to build...',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: GalleryColors.silver,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            Text(
              _stageLabel(progress.stage),
              style: const TextStyle(
                color: GalleryColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultPanel(PackageBuildResult result) {
    return _SectionCard(
      title: 'Completed Package',
      icon: Icons.verified_rounded,
      trailing: const Icon(
        Icons.check_circle_rounded,
        color: Colors.greenAccent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.basename(result.packageFile.path),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            result.packageFile.path,
            style: const TextStyle(
              color: GalleryColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.sd_storage_rounded,
                text: PackageValidationService.formatBytes(
                  result.manifest.packageSizeBytes,
                ),
              ),
              _InfoPill(
                icon: Icons.fingerprint_rounded,
                text: _shortHash(result.manifest.packageHash),
              ),
              _InfoPill(
                icon: Icons.perm_media_rounded,
                text: '${result.manifest.mediaCount} media files',
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: result.packageFile.path),
              );
              _showMessage('Package path copied.');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Package Path'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(PackageValidationReport? validation) {
    final canBuild = validation?.canBuild == true &&
        _outputDirectory != null &&
        !_isBuilding &&
        !_isValidating;

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
                validation == null
                    ? 'Validation required'
                    : validation.canBuild
                        ? '${validation.totalMediaCount} media files ready'
                        : '${validation.errorCount} error${validation.errorCount == 1 ? '' : 's'} must be fixed',
                style: const TextStyle(
                  color: GalleryColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: canBuild ? _buildPackage : null,
              icon: _isBuilding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.inventory_2_rounded),
              label: Text(
                _isBuilding ? 'Building...' : 'Build Package',
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _photoCount =>
      _card.media.where((item) => item.type == GalleryMediaType.photo).length;

  int get _videoCount =>
      _card.media.where((item) => item.type == GalleryMediaType.video).length;

  String get _expectedFilename {
    final cleanTitle = _card.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    return '${cleanTitle.isEmpty ? 'untitled_gallery_piece' : cleanTitle}.tgpack';
  }

  static String _stageLabel(PackageBuildStage stage) {
    return switch (stage) {
      PackageBuildStage.validating => 'Validation',
      PackageBuildStage.creatingWorkspace => 'Workspace setup',
      PackageBuildStage.copyingCover => 'Cover transfer',
      PackageBuildStage.copyingMedia => 'Media transfer',
      PackageBuildStage.writingCard => 'Card metadata',
      PackageBuildStage.writingManifest => 'Manifest generation',
      PackageBuildStage.compressing => 'Archive compression',
      PackageBuildStage.hashing => 'Integrity hash',
      PackageBuildStage.cleaningUp => 'Temporary-file cleanup',
      PackageBuildStage.completed => 'Complete',
    };
  }

  static String _shortHash(String value) {
    if (value.isEmpty) {
      return 'Hash unavailable';
    }

    if (value.length <= 16) {
      return value.toUpperCase();
    }

    return '${value.substring(0, 8).toUpperCase()}…'
        '${value.substring(value.length - 8).toUpperCase()}';
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
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

class _ReadinessBadge extends StatelessWidget {
  const _ReadinessBadge({
    required this.isLoading,
    required this.isReady,
    required this.errorCount,
  });

  final bool isLoading;
  final bool isReady;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? 'Checking'
        : isReady
            ? 'Ready'
            : '$errorCount blocked';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isReady
            ? Colors.greenAccent.withValues(alpha: 0.12)
            : GalleryColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isReady
              ? Colors.greenAccent.withValues(alpha: 0.35)
              : GalleryColors.purpleBright.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isReady ? Icons.check_circle_rounded : Icons.lock_rounded,
              color: isReady ? Colors.greenAccent : GalleryColors.silver,
              size: 17,
            ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(
                color: GalleryColors.muted,
                fontSize: 12,
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Icon(icon, color: GalleryColors.purpleBright, size: 21),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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

class _MiniCount extends StatelessWidget {
  const _MiniCount({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: GalleryColors.panel,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationIssueTile extends StatelessWidget {
  const _ValidationIssueTile({
    required this.issue,
  });

  final PackageValidationIssue issue;

  @override
  Widget build(BuildContext context) {
    final icon = switch (issue.severity) {
      PackageValidationSeverity.error => Icons.cancel_rounded,
      PackageValidationSeverity.warning => Icons.warning_amber_rounded,
      PackageValidationSeverity.info => Icons.check_circle_rounded,
    };

    final color = switch (issue.severity) {
      PackageValidationSeverity.error => Colors.redAccent,
      PackageValidationSeverity.warning => Colors.amber,
      PackageValidationSeverity.info => Colors.greenAccent,
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
              Text(
                issue.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                issue.message,
                style: const TextStyle(
                  color: GalleryColors.muted,
                  height: 1.35,
                ),
              ),
              if (issue.filePath != null &&
                  issue.filePath!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  issue.filePath!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GalleryColors.silver,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: GalleryColors.purpleBright),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingCoverPreview extends StatelessWidget {
  const _MissingCoverPreview();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: GalleryColors.panel,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: GalleryColors.muted,
          size: 38,
        ),
      ),
    );
  }
}
