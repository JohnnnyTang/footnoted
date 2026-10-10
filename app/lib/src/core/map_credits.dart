// Frozen W3 seam. Legal credit text (handoff, Compliance › Map attribution):
// not localised, never paraphrased. Read by the map overlay and About.

class CreditSpan {
  const CreditSpan(this.text, [this.url]);

  final String text;

  /// Opened with url_launcher when the span is tapped; null = plain text.
  final String? url;
}

class MapCredit {
  const MapCredit(this.spans);

  final List<CreditSpan> spans;

  String get text => spans.map((s) => s.text).join();
}

const osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

const osmCredit = MapCredit([
  CreditSpan('© OpenStreetMap contributors', osmCopyrightUrl),
]);

const openFreeMapCredit = MapCredit([
  CreditSpan('OpenFreeMap', 'https://openfreemap.org'),
  CreditSpan(' '),
  CreditSpan('© OpenMapTiles', 'https://www.openmaptiles.org/'),
  CreditSpan(' Data from '),
  CreditSpan('OpenStreetMap', osmCopyrightUrl),
]);

/// Every credit that must stay visible on the map and on About, in order.
const mapCredits = [osmCredit, openFreeMapCredit];
