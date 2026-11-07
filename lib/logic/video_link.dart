/// Links aus TikTok, YouTube und Instagram: Link erkennen und den Text dazu (Beschreibung) holen.
/// Die Auswertung der Seiten ist reines Dart und testbar, nur [videoText] geht ins Netz.
library;

import 'dart:convert';
import 'dart:io';

final _linkMuster = RegExp(r'https?://[^\s<>"]+');

const _videoSeiten = ['tiktok.com', 'youtube.com', 'youtu.be', 'instagram.com', 'facebook.com', 'fb.watch'];

/// Erster Link aus einem geteilten Text, wenn er zu einer Video-Seite gehört. Sonst null.
String? videoLink(String text) {
  for (final m in _linkMuster.allMatches(text)) {
    final url = m.group(0)!.replaceAll(RegExp(r'[).,;!?]+$'), '');
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (_videoSeiten.any((s) => host == s || host.endsWith('.$s'))) return url;
  }
  return null;
}

String _entities(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

/// Titel und volle Beschreibung aus einer YouTube-Seite.
String? youtubeTextAusHtml(String html) {
  String? feld(String name) {
    final m = RegExp('"$name":"((?:[^"\\\\]|\\\\.)*)"').firstMatch(html);
    if (m == null) return null;
    try {
      return jsonDecode('"${m.group(1)}"') as String;
    } catch (_) {
      return null;
    }
  }

  final titel = feld('title') ?? '';
  final beschr = feld('shortDescription') ?? '';
  final t = [titel, beschr].where((e) => e.trim().isNotEmpty).join('\n\n').trim();
  return t.isEmpty ? null : t;
}

/// Allgemeiner Weg: Vorschautext der Seite (og:title und og:description).
String? ogTextAusHtml(String html) {
  String? meta(String prop) {
    for (final re in [
      RegExp('<meta[^>]+(?:property|name)=["\']$prop["\'][^>]*content=["\']([^"\']*)["\']', caseSensitive: false),
      RegExp('<meta[^>]+content=["\']([^"\']*)["\'][^>]*(?:property|name)=["\']$prop["\']', caseSensitive: false),
    ]) {
      final m = re.firstMatch(html);
      if (m != null && m.group(1)!.trim().isNotEmpty) return _entities(m.group(1)!.trim());
    }
    return null;
  }

  final t = [meta('og:title'), meta('og:description') ?? meta('description')].whereType<String>().join('\n\n').trim();
  return t.isEmpty ? null : t;
}

/// Titel aus der TikTok-oEmbed-Antwort (das ist die Videobeschreibung des Autors).
String? tiktokTextAusJson(String json) {
  try {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final t = (m['title'] as String?)?.trim() ?? '';
    return t.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}

Future<String> _holen(String url, {Map<String, String> kopf = const {}}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
    req.followRedirects = true;
    req.maxRedirects = 6;
    req.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36');
    req.headers.set('Accept-Language', 'de-DE,de;q=0.9');
    kopf.forEach(req.headers.set);
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode >= 400) throw HttpException('Antwort ${res.statusCode}');
    final bytes = <int>[];
    await for (final b in res) {
      bytes.addAll(b);
      if (bytes.length > 3 * 1024 * 1024) break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    client.close(force: true);
  }
}

/// Holt Titel und Beschreibung zu einem Video-Link. Wirft eine Ausnahme, wenn die Seite nicht erreichbar ist.
/// Es geht nur der Link an die Video-Seite, sonst nichts.
Future<String> videoText(String url) async {
  final host = Uri.parse(url).host.toLowerCase();
  if (host.endsWith('tiktok.com')) {
    try {
      final j = await _holen('https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}');
      final t = tiktokTextAusJson(j);
      if (t != null) return t;
    } catch (_) {}
  }
  final html = await _holen(url, kopf: {'Cookie': 'CONSENT=YES+1; SOCS=CAI'});
  final text = (host.contains('youtube') || host == 'youtu.be' ? youtubeTextAusHtml(html) : null) ?? ogTextAusHtml(html);
  return _entities(text ?? '');
}
