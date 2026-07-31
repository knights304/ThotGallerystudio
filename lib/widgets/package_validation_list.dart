import 'package:flutter/material.dart';

import '../services/package_validation_service.dart';
import '../theme/gallery_theme.dart';

/// Displays validation results for a TG package.
/// Presentation only.
class PackageValidationList extends StatelessWidget {
  const PackageValidationList({
    super.key,
    required this.report,
    this.isLoading = false,
    this.onRefresh,
  });

  final PackageValidationReport? report;
  final bool isLoading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x447D6C8E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded,
                  color: GalleryColors.purpleBright),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Validation',
                  style: TextStyle(fontSize: 17,fontWeight: FontWeight.w900),
                ),
              ),
              if (report != null) ...[
                _Count(Icons.cancel_rounded, report!.errorCount, Colors.redAccent),
                const SizedBox(width: 6),
                _Count(Icons.warning_amber_rounded, report!.warningCount, Colors.amber),
                const SizedBox(width: 6),
                _Count(Icons.info_rounded, report!.informationCount, Colors.lightBlueAccent),
              ],
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading && report == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (report == null)
            const Center(child: Text('Run validation to view package status.'))
          else if (report!.issues.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No validation issues found.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report!.issues.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (_, i) => _IssueTile(issue: report!.issues[i]),
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.icon,this.value,this.color);
  final IconData icon;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context){
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:8,vertical:6),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min,children:[
        Icon(icon,size:16,color:color),
        const SizedBox(width:4),
        Text('$value',style: const TextStyle(fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _IssueTile extends StatelessWidget{
  const _IssueTile({required this.issue});
  final PackageValidationIssue issue;

  @override
  Widget build(BuildContext context){
    final (icon,color)=switch(issue.severity){
      PackageValidationSeverity.error => (Icons.cancel_rounded,Colors.redAccent),
      PackageValidationSeverity.warning => (Icons.warning_amber_rounded,Colors.amber),
      PackageValidationSeverity.info => (Icons.check_circle_rounded,Colors.greenAccent),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Icon(icon,color:color,size:22),
        const SizedBox(width:10),
        Expanded(child:Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Text(issue.title,style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height:3),
            Text(issue.message,
              style: const TextStyle(color: GalleryColors.muted,height:1.35)),
            if(issue.filePath!=null && issue.filePath!.isNotEmpty)...[
              const SizedBox(height:5),
              Text(issue.filePath!,
                style: const TextStyle(fontSize:11,color:GalleryColors.silver)),
            ]
          ],
        ))
      ],
    );
  }
}
