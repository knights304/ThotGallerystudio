import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/gallery_card.dart';
import '../models/tg_package_manifest.dart';
import 'package_validation_service.dart';

enum PackageBuildStage {
  validating,
  creatingWorkspace,
  copyingCover,
  copyingMedia,
  writingCard,
  writingManifest,
  compressing,
  hashing,
  cleaningUp,
  completed,
}

class PackageBuildProgress {
  const PackageBuildProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });

  final PackageBuildStage stage;
  final double progress;
  final String message;
}

class PackageBuildResult {
  const PackageBuildResult({
    required this.packageFile,
    required this.manifest,
    required this.validation,
  });

  final File packageFile;
  final TGPackageManifest manifest;
  final PackageValidationReport validation;
}

class PackageBuilderService {
  const PackageBuilderService._();

  static Future<PackageBuildResult> buildPackage({
    required GalleryCard card,
    required Directory outputDirectory,
    void Function(PackageBuildProgress progress)? onProgress,
  }) async {
    void update(PackageBuildStage s,double p,String m){
      onProgress?.call(PackageBuildProgress(stage:s,progress:p,message:m));
    }

    update(PackageBuildStage.validating,0.05,'Validating package...');
    final validation = await PackageValidationService.validate(card);
    if(!validation.canBuild){
      throw Exception('Package validation failed.');
    }

    final tempDir = await Directory.systemTemp.createTemp('tgpkg_');
    try{
      update(PackageBuildStage.creatingWorkspace,0.10,'Creating workspace...');

      final coverDir = Directory(p.join(tempDir.path,'cover'))..createSync(recursive:true);
      final mediaDir = Directory(p.join(tempDir.path,'media'))..createSync(recursive:true);

      if(card.coverImagePath!=null && card.coverImagePath!.isNotEmpty){
        update(PackageBuildStage.copyingCover,0.20,'Copying cover...');
        await File(card.coverImagePath!)
            .copy(p.join(coverDir.path,p.basename(card.coverImagePath!)));
      }

      update(PackageBuildStage.copyingMedia,0.35,'Copying media...');
      for(final media in card.media){
        await File(media.path)
            .copy(p.join(mediaDir.path,p.basename(media.path)));
      }

      update(PackageBuildStage.writingCard,0.55,'Writing card.json...');
      await File(p.join(tempDir.path,'card.json'))
          .writeAsString(const JsonEncoder.withIndent('  ').convert(card.toJson()));

      update(PackageBuildStage.writingManifest,0.65,'Writing tg_manifest.json...');
      var manifest = TGPackageManifest.fromCard(card);
      final manifestFile = File(p.join(tempDir.path,'tg_manifest.json'));
      await manifestFile.writeAsString(manifest.toPrettyJson());

      update(PackageBuildStage.compressing,0.80,'Compressing package...');
      await outputDirectory.create(recursive:true);
      final outPath = p.join(
        outputDirectory.path,
        '${card.title.replaceAll(RegExp(r'[^\w\s-]'),'').replaceAll(' ','_')}.tgpack'
      );

      final encoder = ZipFileEncoder();
      encoder.create(outPath);
      encoder.addDirectory(tempDir);
      encoder.close();

      update(PackageBuildStage.hashing,0.92,'Calculating hash...');
      final pkgFile = File(outPath);
      final hash = sha256.convert(await pkgFile.readAsBytes()).toString();
      manifest = manifest.copyWith(
        packageHash: hash,
        packageSizeBytes: await pkgFile.length(),
      );

      await manifestFile.writeAsString(manifest.toPrettyJson());

      update(PackageBuildStage.completed,1.0,'Package complete.');

      return PackageBuildResult(
        packageFile: pkgFile,
        manifest: manifest,
        validation: validation,
      );
    } finally{
      if(await tempDir.exists()){
        await tempDir.delete(recursive:true);
      }
    }
  }
}
