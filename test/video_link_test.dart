import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/video_link.dart';

void main() {
  test('Video-Link aus geteiltem Text erkennen', () {
    expect(videoLink('Schau mal: https://vm.tiktok.com/ZGdabc123/ lecker!'), 'https://vm.tiktok.com/ZGdabc123/');
    expect(videoLink('https://youtu.be/abc123?si=xy'), 'https://youtu.be/abc123?si=xy');
    expect(videoLink('(https://www.youtube.com/watch?v=abc)'), 'https://www.youtube.com/watch?v=abc');
    expect(videoLink('https://www.instagram.com/reel/xyz/'), 'https://www.instagram.com/reel/xyz/');
    expect(videoLink('https://www.otto.de/rechnung'), isNull);
    expect(videoLink('Rechnung über 95 Euro'), isNull);
  });

  test('YouTube: Titel und Beschreibung aus der Seite', () {
    const html = r'..."title":"Pasta in 10 Minuten","lengthSeconds":"600","shortDescription":"Zutaten:\n200 g Nudeln\n1 Dose Tomaten\n\nGuten Appetit & viel Spaß","x":1';
    final t = youtubeTextAusHtml(html)!;
    expect(t, contains('Pasta in 10 Minuten'));
    expect(t, contains('200 g Nudeln\n1 Dose Tomaten'));
    expect(t, contains('Guten Appetit & viel Spaß'));
    expect(youtubeTextAusHtml('<html></html>'), isNull);
  });

  test('Vorschautext (og) und TikTok-Antwort', () {
    const html = '<meta property="og:title" content="Lasagne &amp; mehr"><meta content="500 g Hack, 1 Packung Platten" property="og:description">';
    expect(ogTextAusHtml(html), 'Lasagne & mehr\n\n500 g Hack, 1 Packung Platten');
    expect(tiktokTextAusJson('{"title":"Zutaten: 3 Eier, Mehl #rezept"}'), 'Zutaten: 3 Eier, Mehl #rezept');
    expect(tiktokTextAusJson('kaputt'), isNull);
  });
}
