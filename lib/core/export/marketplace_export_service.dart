import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/creator_profile.dart';
import '../../models/gallery_card.dart';
import 'browser_gallery_service.dart';
import 'thot_package_service.dart';

class MarketplaceExportResult {
  const MarketplaceExportResult({required this.folder, required this.files});
  final Directory folder;
  final List<File> files;
}

class MarketplaceExportService {
  final BrowserGalleryService browser = BrowserGalleryService();
  final ThotPackageService packages = ThotPackageService();

  Future<MarketplaceExportResult> exportPiece(
    GalleryCard card, {
    CreatorProfile? creator,
    bool includeHtml = true,
    bool includePackage = true,
    bool includePdf = true,
    bool includeSocial = true,
    bool includeMetadata = true,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory(
        p.join(documents.path, 'ThotGallery', 'Marketplace', card.id));
    await folder.create(recursive: true);
    final files = <File>[];
    String? html;

    if (includeHtml) {
      html = browser.buildHtml(card, creator: creator);
      final file = File(p.join(folder.path, 'index.html'));
      await file.writeAsString(html, flush: true);
      files.add(file);
    }
    if (includeMetadata) {
      final payload = {
        'schema': 'thot-gallery-marketplace-v1',
        'piece': card.toJson(),
        'creator': creator?.toJson(),
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
      };
      final file = File(p.join(folder.path, '${card.id}.marketplace.json'));
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload),
          flush: true);
      files.add(file);
    }
    if (includeSocial) {
      files.add(await _socialPreview(card, creator, folder));
    }
    if (includePdf) {
      files.add(await _printSheet(card, creator, folder));
    }
    if (includePackage) {
      files.add(
        await packages.exportPackage(
          card,
          creator: creator,
          browserHtml: html,
        ),
      );
    }

    final zip = Archive();
    for (final file in files) {
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      zip.addFile(ArchiveFile.bytes(p.basename(file.path), bytes));
    }
    final bundle = File(p.join(folder.path, '${card.id}-marketplace.zip'));
    await bundle.writeAsBytes(ZipEncoder().encode(zip), flush: true);
    files.add(bundle);
    return MarketplaceExportResult(folder: folder, files: files);
  }

  Future<List<MarketplaceExportResult>> exportBatch(
    List<GalleryCard> cards, {
    CreatorProfile? creator,
  }) async {
    final results = <MarketplaceExportResult>[];
    for (final card in cards) {
      results.add(await exportPiece(card, creator: creator));
    }
    return results;
  }

  Future<File> _socialPreview(
    GalleryCard card,
    CreatorProfile? creator,
    Directory folder,
  ) async {
    final canvas = img.Image(width: 1200, height: 630);
    img.fill(canvas, color: img.ColorRgb8(10, 7, 14));
    img.fillRect(canvas,
        x1: 0, y1: 0, x2: 38, y2: 630, color: img.ColorRgb8(155, 92, 255));
    if (card.coverImagePath != null) {
      final coverFile = File(card.coverImagePath!);
      if (await coverFile.exists()) {
        final decoded = img.decodeImage(await coverFile.readAsBytes());
        if (decoded != null) {
          final fitted = img.copyResizeCropSquare(decoded, size: 540);
          img.compositeImage(canvas, fitted, dstX: 50, dstY: 45);
        }
      }
    }
    img.drawString(canvas, card.title,
        font: img.arial48, x: 635, y: 110, color: img.ColorRgb8(255, 255, 255));
    img.drawString(canvas, '${card.rarity} · ${card.setName}',
        font: img.arial24, x: 638, y: 190, color: img.ColorRgb8(185, 155, 235));
    img.drawString(canvas, creator?.displayName ?? 'Thot Gallery',
        font: img.arial24, x: 638, y: 480, color: img.ColorRgb8(220, 214, 228));
    img.drawString(canvas, card.id,
        font: img.arial24, x: 638, y: 525, color: img.ColorRgb8(155, 92, 255));
    final file = File(p.join(folder.path, '${card.id}-social-1200x630.png'));
    await file.writeAsBytes(img.encodePng(canvas), flush: true);
    return file;
  }

  Future<File> _printSheet(
    GalleryCard card,
    CreatorProfile? creator,
    Directory folder,
  ) async {
    final doc = pw.Document();
    pw.MemoryImage? cover;
    if (card.coverImagePath != null) {
      final source = File(card.coverImagePath!);
      if (await source.exists()) {
        cover = pw.MemoryImage(await source.readAsBytes());
      }
    }
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('THOT GALLERY · PRINT SHEET',
                style: pw.TextStyle(fontSize: 12, letterSpacing: 2)),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 270,
                  height: 378,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.purple300, width: 2),
                    borderRadius: pw.BorderRadius.circular(14),
                  ),
                  child: cover == null
                      ? pw.Center(child: pw.Text('NO COVER'))
                      : pw.ClipRRect(
                          horizontalRadius: 12,
                          verticalRadius: 12,
                          child: pw.Image(cover, fit: pw.BoxFit.cover),
                        ),
                ),
                pw.SizedBox(width: 28),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(card.rarity.toUpperCase(),
                          style: const pw.TextStyle(
                              color: PdfColors.purple500, fontSize: 12)),
                      pw.SizedBox(height: 8),
                      pw.Text(card.title,
                          style: pw.TextStyle(
                              fontSize: 28, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      pw.Text(card.description),
                      pw.SizedBox(height: 18),
                      pw.Text(
                          'Creator: ${creator?.displayName ?? 'Thot Gallery'}'),
                      pw.Text('Piece: ${card.id}'),
                      pw.Text('Set: ${card.setName}'),
                      pw.Text('Fingerprint: ${card.shortFingerprint}'),
                      pw.SizedBox(height: 18),
                      pw.Text('Tags: ${card.tags.join(', ')}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final file = File(p.join(folder.path, '${card.id}-print-sheet.pdf'));
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }
}
