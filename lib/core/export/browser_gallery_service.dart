import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/creator_profile.dart';
import '../../models/gallery_card.dart';

class BrowserGalleryService {
  Future<File> export(
    GalleryCard card, {
    CreatorProfile? creator,
    bool darkMode = true,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory(
        p.join(documents.path, 'ThotGallery', 'Exports', card.id, 'browser'));
    await folder.create(recursive: true);
    final html = buildHtml(card, creator: creator, darkMode: darkMode);
    final file = File(p.join(folder.path, 'index.html'));
    await file.writeAsString(html, flush: true);
    return file;
  }

  String buildHtml(
    GalleryCard card, {
    CreatorProfile? creator,
    bool darkMode = true,
  }) {
    String esc(String value) => const HtmlEscape().convert(value);
    final media = card.media
        .where((item) => item.type == GalleryMediaType.photo)
        .map((item) => item.path)
        .toList();
    if (card.coverImagePath != null && !media.contains(card.coverImagePath)) {
      media.insert(0, card.coverImagePath!);
    }
    String fileUri(String path) => Uri.file(path).toString();
    final gallery = media
        .map((path) =>
            '<button class="thumb" onclick="openLightbox(\'${esc(fileUri(path))}\')"><img src="${esc(fileUri(path))}" alt="Gallery image"></button>')
        .join();
    final cover =
        card.coverImagePath == null ? '' : fileUri(card.coverImagePath!);
    final creatorName = creator?.displayName ?? 'Thot Gallery';
    final creatorHandle = creator?.handle ?? '';
    final accent = creator?.accentHex ?? '#9B5CFF';
    final jsonLd = jsonEncode({
      '@context': 'https://schema.org',
      '@type': 'CreativeWork',
      'name': card.title,
      'description': card.description,
      'creator': {'@type': 'Person', 'name': creatorName},
      'identifier': card.id,
    });
    return '''<!doctype html>
<html lang="en" data-theme="${darkMode ? 'dark' : 'light'}">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(card.title)} | Thot Gallery</title>
<meta name="description" content="${esc(card.description)}">
<meta property="og:title" content="${esc(card.title)}"><meta property="og:description" content="${esc(card.description)}">
<meta property="og:type" content="website"><meta name="theme-color" content="$accent">
<script type="application/ld+json">$jsonLd</script>
<style>
:root{--accent:$accent;--bg:#f6f3fb;--panel:#fff;--text:#18131f;--muted:#665f70}html[data-theme=dark]{--bg:#09070d;--panel:#15101c;--text:#faf7ff;--muted:#aaa1b5}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 20% 0,color-mix(in srgb,var(--accent) 24%,transparent),transparent 36%),var(--bg);color:var(--text);font-family:Inter,system-ui,sans-serif;min-height:100vh}.shell{max-width:1120px;margin:auto;padding:24px}.top{display:flex;justify-content:space-between;align-items:center;gap:12px}.brand{letter-spacing:.18em;text-transform:uppercase;font-weight:800}.btn{border:1px solid color-mix(in srgb,var(--accent) 60%,transparent);background:var(--panel);color:var(--text);padding:10px 14px;border-radius:999px;cursor:pointer}.hero{display:grid;grid-template-columns:minmax(280px,430px) 1fr;gap:42px;align-items:center;margin:50px 0}.card{aspect-ratio:2.5/3.5;perspective:1200px;cursor:pointer}.inner{width:100%;height:100%;position:relative;transform-style:preserve-3d;transition:transform .7s}.card.flipped .inner{transform:rotateY(180deg)}.face{position:absolute;inset:0;backface-visibility:hidden;border-radius:28px;overflow:hidden;border:2px solid color-mix(in srgb,var(--accent) 70%,white 15%);box-shadow:0 30px 80px color-mix(in srgb,var(--accent) 30%,transparent);background:var(--panel)}.front img{width:100%;height:100%;object-fit:cover}.overlay{position:absolute;inset:auto 0 0;padding:24px;background:linear-gradient(transparent,rgba(0,0,0,.92));color:white}.back{transform:rotateY(180deg);display:grid;place-items:center;text-align:center;padding:36px;background:radial-gradient(circle,var(--accent),#08050c 65%)}h1{font-size:clamp(38px,6vw,76px);line-height:.95;margin:.2em 0}.meta{color:var(--muted);font-size:18px}.chips{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}.chip{padding:7px 11px;border-radius:999px;background:color-mix(in srgb,var(--accent) 17%,var(--panel));border:1px solid color-mix(in srgb,var(--accent) 35%,transparent)}.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}.thumb{border:0;padding:0;background:none;cursor:zoom-in}.thumb img{width:100%;aspect-ratio:1;object-fit:cover;border-radius:16px}.lightbox{display:none;position:fixed;inset:0;background:rgba(0,0,0,.94);place-items:center;z-index:9}.lightbox.open{display:grid}.lightbox img{max-width:92vw;max-height:90vh}.footer{margin:60px 0 20px;color:var(--muted)}@media(max-width:760px){.hero{grid-template-columns:1fr}.shell{padding:16px}.card{max-width:420px;margin:auto}}
</style></head>
<body><main class="shell"><header class="top"><div class="brand">Thot Gallery</div><button class="btn" onclick="toggleTheme()">Light / Dark</button></header>
<section class="hero"><div class="card" onclick="this.classList.toggle('flipped')"><div class="inner"><article class="face front">${cover.isEmpty ? '<div style="height:100%;display:grid;place-items:center">NO COVER</div>' : '<img src="${esc(cover)}" alt="${esc(card.title)}">'}<div class="overlay"><b>${esc(card.rarity)}</b><h2>${esc(card.title)}</h2><small>Tap to flip</small></div></article><article class="face back"><div><div class="brand">${esc(card.id)}</div><h2>${esc(card.shortFingerprint)}</h2><p>${esc(card.verificationPayload)}</p></div></article></div></div>
<div><div class="meta">${esc(card.setName)} · ${esc(card.rarity)}</div><h1>${esc(card.title)}</h1><p>${esc(card.description)}</p><div class="chips">${card.tags.map((tag) => '<span class="chip">${esc(tag)}</span>').join()}</div><p class="meta">Created by ${esc(creatorName)} ${esc(creatorHandle)}</p><button class="btn" onclick="downloadMetadata()">Download metadata</button></div></section>
<section><h2>Living Gallery</h2><div class="gallery">$gallery</div></section><footer class="footer">Offline-ready export · ${esc(card.id)} · ${esc(card.shortFingerprint)}</footer></main>
<div id="lightbox" class="lightbox" onclick="this.classList.remove('open')"><img id="lightboxImage"></div>
<script>function toggleTheme(){const h=document.documentElement;h.dataset.theme=h.dataset.theme==='dark'?'light':'dark';localStorage.setItem('theme',h.dataset.theme)}document.documentElement.dataset.theme=localStorage.getItem('theme')||document.documentElement.dataset.theme;function openLightbox(src){document.getElementById('lightboxImage').src=src;document.getElementById('lightbox').classList.add('open')}function downloadMetadata(){const data=${jsonEncode(jsonEncode(card.toJson()))};const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type:'application/json'}));a.download='${card.id}.json';a.click()}</script></body></html>''';
  }
}
