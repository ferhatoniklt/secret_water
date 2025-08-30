import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ---- HARİTA için ----
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ---- UI/Charts ----
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const SecretWaterApp());

class SecretWaterApp extends StatelessWidget {
  const SecretWaterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secret Water',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1976D2),
        brightness: Brightness.light,
        textTheme: GoogleFonts.interTextTheme(),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1976D2),
        brightness: Brightness.dark,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with TickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secret Water'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.water_drop_outlined), text: 'Kesintiler'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Barajlar'),
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Hesaplama'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          OutagesTab(),
          ReservoirsProTab(),
          NeedsCalculatorTab(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.water_drop_outlined, size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'created by NEO KLOTHO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------- ortak yardımcılar -------------------------- */

dynamic _getAny(Map obj, List<String> keys) {
  for (final k in keys) {
    if (obj.containsKey(k) && obj[k] != null) return obj[k];
  }
  return null;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll('%', '').replaceAll(',', '.');
  return double.tryParse(s);
}

String fmtPct(double? v) => v == null ? '-' : '${v.toStringAsFixed(2)} %';
String fmtVol(double? v) =>
    v == null ? '-' : '${NumberFormat.decimalPattern().format(v)} m³';
String fmtHeight(double? v) => v == null
    ? '-'
    : '${v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0)} m';

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is int) {
    if (v > 10000000000) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.fromMillisecondsSinceEpoch(v * 1000);
  }
  if (v is String) {
    final tries = [
      () => DateTime.tryParse(v),
      () => DateFormat('dd.MM.yyyy HH:mm').parseStrict(v),
      () => DateFormat('dd.MM.yyyy').parseStrict(v),
      () => DateFormat('yyyy-MM-dd HH:mm').parseStrict(v),
      () => DateFormat('yyyy-MM-dd').parseStrict(v),
    ];
    for (final f in tries) {
      try {
        final d = f();
        if (d != null) return d;
      } catch (_) {}
    }
  }
  return null;
}

String fmtDate(DateTime? d) =>
    d == null ? '-' : DateFormat('dd.MM.yyyy HH:mm').format(d);

/* -------------------------------- Modeller ------------------------------ */

class OutageItem {
  final String? ilce;
  final String? mahalle;
  final String? sebep;
  final String? ongoru;
  final String? kesintisuresi;
  final String? birimamirligi;
  final String? aciklama;
  final DateTime? baslangic;
  final DateTime? bitis;

  OutageItem({
    required this.ilce,
    required this.mahalle,
    required this.sebep,
    required this.ongoru,
    required this.kesintisuresi,
    required this.birimamirligi,
    required this.aciklama,
    required this.baslangic,
    required this.bitis,
  });

  factory OutageItem.fromJson(Map<String, dynamic> m) => OutageItem(
    ilce: _getAny(m, ['IlceAdi', 'ilce', 'district'])?.toString(),
    mahalle: _getAny(m, ['Mahalleler', 'Mahalle', 'mahalle'])?.toString(),
    ongoru: m['Ongoru']?.toString(),
    birimamirligi: _getAny(m, ['Birim', 'BirimAmirligi'])?.toString(),
    kesintisuresi: m['KesintiSuresi']?.toString(),
    sebep: _getAny(m, ['Tip', 'sebep', 'Neden'])?.toString(),
    aciklama: _getAny(m, ['Aciklama', 'Açıklama', 'aciklama'])?.toString(),
    baslangic: _toDate(
      _getAny(m, ['Baslangic', 'Başlangic', 'BaslamaTarihi', 'Start']),
    ),
    bitis: _toDate(_getAny(m, ['Bitis', 'Bitiş', 'BitisTarihi', 'Finish'])),
  );
}

class ReservoirStatus {
  final String? ad;
  final double? doluluk; // %
  final double? hacim; // m³ (mevcut)
  final String? seviye;
  final DateTime? tarih;

  // ek alanlar
  final double? tuketilebilirKapasite; // m³
  final double? maxKapasite; // m³
  final double? minKapasite; // m³
  final double? minYukseklik; // m
  final double? maxYukseklik; // m

  ReservoirStatus({
    required this.ad,
    required this.doluluk,
    required this.hacim,
    required this.seviye,
    required this.tarih,
    this.tuketilebilirKapasite,
    this.maxKapasite,
    this.minKapasite,
    this.minYukseklik,
    this.maxYukseklik,
  });

  factory ReservoirStatus.fromJson(Map<String, dynamic> m) => ReservoirStatus(
    ad: _getAny(m, ['BarajKuyuAdi', 'BarajAdı', 'KaynakAdi', 'Ad'])?.toString(),
    doluluk: _toDouble(_getAny(m, ['Doluluk', 'Oran', 'DolulukOrani'])),
    hacim: _toDouble(
      _getAny(m, [
        'KullanılabilirGolSuHacmi',
        'HacimM3',
        'Hacim_(m3)',
        'MevcutHacim',
      ]),
    ),
    seviye: _getAny(m, ['Kademe', 'Durum'])?.toString(),
    tarih: _toDate(
      _getAny(m, ['DurumTarihi', 'GuncellemeTarihi', 'Güncelleme']),
    ),
    tuketilebilirKapasite: _toDouble(
      _getAny(m, [
        'TuketilebilirSuKapasitesi',
        'TüketilebilirSuKapasitesi',
        'TuketilebilirKapasite',
        'Tuketilebilir',
      ]),
    ),
    maxKapasite: _toDouble(
      _getAny(m, ['MaksimumSuKapasitesi', 'MaksSuKapasitesi', 'MaxKapasite']),
    ),
    minKapasite: _toDouble(
      _getAny(m, ['MinimumSuKapasitesi', 'MinSuKapasitesi', 'MinKapasite']),
    ),
    minYukseklik: _toDouble(
      _getAny(m, [
        'MinimumSuYuksekligi',
        'MinimumSuYüksekliği',
        'MinSuYuksekligi',
        'MinYukseklik',
      ]),
    ),
    maxYukseklik: _toDouble(
      _getAny(m, [
        'MaksimumSuYuksekligi',
        'MaksimumSuYüksekliği',
        'MaxSuYuksekligi',
        'MaxYukseklik',
      ]),
    ),
  );
}

/* --- Baraj/Kuyu/Kaynak konum modeli (harita) --- */
class WaterSource {
  final String? ad;
  final String? tur; // Baraj/Kuyu/Kaynak
  final double? lat;
  final double? lon;

  WaterSource({this.ad, this.tur, this.lat, this.lon});

  factory WaterSource.fromJson(Map<String, dynamic> m) {
    double? _d(v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
    }

    return WaterSource(
      ad: _getAny(m, ['Ad', 'Adi', 'KaynakAdi', 'BarajAdi', 'Adı'])?.toString(),
      tur: _getAny(m, ['Tur', 'Tür', 'KaynakTuru', 'Tip'])?.toString(),
      lat: _d(_getAny(m, ['Lat', 'Latitude', 'Enlem', 'lat'])),
      lon: _d(_getAny(m, ['Lon', 'Lng', 'Longitude', 'Boylam', 'lon'])),
    );
  }
}

/* -------------------------------- Servisler ----------------------------- */

class IzsuApi {
  static const _base = 'https://openapi.izmir.bel.tr/api/izsu';

  static Future<http.Response> _get(Uri url) {
    return http.get(url, headers: {'accept': 'application/json'});
  }

  static Future<List<OutageItem>> fetchOutages() async {
    final res = await _get(Uri.parse('$_base/arizakaynaklisukesintileri'));
    if (res.statusCode != 200) {
      throw Exception('Kesintiler hata: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (data is List) ? data : (data['data'] ?? data['result'] ?? []);
    return list
        .map<OutageItem>(
          (e) => OutageItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  static Future<List<ReservoirStatus>> fetchReservoirs() async {
    final res = await _get(Uri.parse('$_base/barajdurum'));
    if (res.statusCode != 200) {
      throw Exception('Barajlar hata: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (data is List) ? data : (data['data'] ?? data['result'] ?? []);
    return list
        .map<ReservoirStatus>(
          (e) => ReservoirStatus.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  static Future<List<WaterSource>> fetchSources() async {
    final res = await _get(Uri.parse('$_base/barajvekuyular'));
    if (res.statusCode != 200) {
      throw Exception('Baraj/Kuyular hata: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (data is List) ? data : (data['data'] ?? data['result'] ?? []);
    return list
        .map<WaterSource>(
          (e) => WaterSource.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }
}

/* ------------------------------ UI: Kesintiler (Gelişmiş) --------------- */

class OutagesTab extends StatefulWidget {
  const OutagesTab({super.key});
  @override
  State<OutagesTab> createState() => _OutagesTabState();
}

class _OutagesTabState extends State<OutagesTab> {
  late Future<List<OutageItem>> _future;
  String _query = '';
  String _ilce = 'Tümü';

  @override
  void initState() {
    super.initState();
    _future = IzsuApi.fetchOutages();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OutageItem>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return _errorBox(
            icon: Icons.cloud_off,
            text: 'Kesinti servisi yanıt vermiyor.\n${s.error}',
            onRetry: () => setState(() => _future = IzsuApi.fetchOutages()),
          );
        }
        final all = s.data!;
        final ilceler = {'Tümü', ...all.map((e) => e.ilce ?? '-')}.toList()
          ..sort();
        var items = all.where((e) {
          final t = '${e.ilce} ${e.mahalle} ${e.sebep} ${e.aciklama}'
              .toLowerCase();
          final okText = t.contains(_query.toLowerCase());
          final okIlce = _ilce == 'Tümü' || (e.ilce ?? '-') == _ilce;
          return okText && okIlce;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      maxWidth: 900,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'İlçe/mahalle/sebep ara',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _ilce,
                    items: ilceler
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _ilce = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Kayıt yok.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _OutageCard(item: items[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OutageCard extends StatelessWidget {
  final OutageItem item;
  const _OutageCard({required this.item});

  Duration? _duration() {
    if (item.baslangic == null || item.bitis == null) return null;
    return item.bitis!.difference(item.baslangic!);
  }

  Duration? _elapsed() {
    if (item.baslangic == null) return null;
    final end = item.bitis ?? DateTime.now();
    final now = DateTime.now();
    if (now.isBefore(item.baslangic!)) return Duration.zero;
    return (now.isAfter(end) ? end : now).difference(item.baslangic!);
  }

  @override
  Widget build(BuildContext context) {
    final d = _duration();
    final e = _elapsed();
    double? pct;
    if (d != null && e != null && d.inSeconds > 0) {
      pct = (e.inSeconds / d.inSeconds).clamp(0.0, 1.0);
    }

    String badge() {
      if (item.bitis != null && DateTime.now().isAfter(item.bitis!)) {
        return 'Bitti';
      }
      return 'Aktif';
    }

    final color = badge() == 'Bitti'
        ? Colors.green
        : Theme.of(context).colorScheme.primary;

    String prettyDur(Duration? x) {
      if (x == null) return '-';
      final h = x.inHours;
      final m = x.inMinutes.remainder(60);
      return '${h}sa ${m}dk';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.ilce ?? '-'} • ${item.mahalle ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    badge(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _kv('Sebep', item.sebep ?? item.aciklama ?? '-'),
            _kv('Birim', item.birimamirligi ?? '-'),
            if (item.ongoru != null) _kv('Öngörülen', item.ongoru!),
            if (item.kesintisuresi != null)
              _kv('Süre', item.kesintisuresi!),
            if (item.aciklama != null) _kv('Açıklama', item.aciklama!),
                
            if (item.baslangic != null)
              _kv('Başlangıç', fmtDate(item.baslangic)),
            if (item.bitis != null) _kv('Bitiş', fmtDate(item.bitis)),
            if (d != null) _kv('Planlanan', prettyDur(d)),
            if (e != null) _kv('Geçen', prettyDur(e)),
            if (pct != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: pct, minHeight: 8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ UI: Barajlar (Pro, Sliver) --------------- */

class ReservoirsProTab extends StatefulWidget {
  const ReservoirsProTab({super.key});
  @override
  State<ReservoirsProTab> createState() => _ReservoirsProTabState();
}

class _ReservoirsProTabState extends State<ReservoirsProTab> {
  late Future<_ReservoirBundle> _future;
  int _mode = 0; // 0: Liste, 1: Harita, 2: Grafikler
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReservoirBundle> _load() async {
    final statuses = await IzsuApi.fetchReservoirs();
    final sources = await IzsuApi.fetchSources();

    String norm(String? s) => (s ?? '')
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();

    final locByName = <String, WaterSource>{};
    for (final w in sources) {
      locByName[norm(w.ad)] = w;
    }

    final withCoords = <_ReservoirWithCoord>[];
    for (final st in statuses) {
      withCoords.add(
        _ReservoirWithCoord(status: st, loc: locByName[norm(st.ad)]),
      );
    }
    return _ReservoirBundle(all: withCoords);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReservoirBundle>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return _errorBox(
            icon: Icons.cloud_off,
            text: 'Baraj servisi/konumu alınamadı.\n${s.error}',
            onRetry: () => setState(() => _future = _load()),
          );
        }

        // filtre
        var items = s.data!.all;
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          items = items
              .where((e) => (e.status.ad ?? '').toLowerCase().contains(q))
              .toList();
        }

        // özet metrikler
        final fills = items.map((e) => e.status.doluluk ?? 0).toList();
        final avgFill = fills.isEmpty
            ? 0
            : fills.reduce((a, b) => a + b) / fills.length;
        final totalVol = items
            .map((e) => e.status.hacim ?? 0)
            .fold<double>(0, (a, b) => a + b);
        final worst = [...items]
          ..sort(
            (a, b) => (a.status.doluluk ?? 0).compareTo(b.status.doluluk ?? 0),
          );

        // --- HEADER bileşeni (scroll ile birlikte hareket) ---
        Widget header = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 260,
                      maxWidth: 900,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Baraj ara',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.view_list),
                          label: Text('Liste'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.map),
                          label: Text('Harita'),
                        ),
                        ButtonSegment(
                          value: 2,
                          icon: Icon(Icons.insert_chart_outlined),
                          label: Text('Grafikler'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (v) =>
                          setState(() => _mode = v.first),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: LayoutBuilder(
                builder: (context, c) {
                  final double w = c.maxWidth;
                  const double gap = 8;
                  const double tileMin = 260;
                  int perRow = (w / (tileMin + gap)).floor();
                  if (perRow < 1) perRow = 1;
                  final double tileW = perRow == 1
                      ? w
                      : (w - gap * (perRow - 1)) / perRow;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: tileW,
                        child: _SummaryTile(
                          title: 'Ortalama Doluluk',
                          value: fmtPct(avgFill as double?),
                          icon: Icons.speed,
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        child: _SummaryTile(
                          title: 'Toplam Hacim',
                          value: fmtVol(totalVol),
                          icon: Icons.water_drop,
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        child: _SummaryTile(
                          title: 'En Düşük (3)',
                          value: worst
                              .take(3)
                              .map((e) => (e.status.ad ?? '-'))
                              .join(', ')
                              .ifEmpty('-'),
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );

        return NestedScrollView(
          headerSliverBuilder: (_, __) => [SliverToBoxAdapter(child: header)],
          body: switch (_mode) {
            0 => _ProList(items: items),
            1 => _MapBody(items: items),
            2 => _ChartsBody(items: items),
            _ => _ProList(items: items),
          },
        );
      },
    );
  }
}

/* ------------------------------ List Body -------------------------------- */

class _ProList extends StatelessWidget {
  final List<_ReservoirWithCoord> items;
  const _ProList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Kayıt yok.'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final it = items[i].status;
        final loc = items[i].loc;
        final double percent = (((it.doluluk ?? 0) / 100).clamp(
          0.0,
          1.0,
        )).toDouble();

        Color badgeColor() {
          final p = it.doluluk ?? 0;
          if (p >= 60) return Colors.green;
          if (p >= 30) return Colors.orange;
          return Colors.red;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.deblur, color: badgeColor()),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        it.ad ?? 'Baraj/Kaynak',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (loc?.lat != null && loc?.lon != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${loc!.lat!.toStringAsFixed(3)}, ${loc.lon!.toStringAsFixed(3)}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircularPercentIndicator(
                      radius: 34,
                      lineWidth: 8,
                      percent: percent,
                      center: Text(
                        it.doluluk == null
                            ? '-'
                            : '${it.doluluk!.toStringAsFixed(1)}%',
                      ),
                      progressColor: badgeColor(),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _CapacityBar(current: it.hacim, max: it.maxKapasite),
                          const SizedBox(height: 2),
                          _MetricsGrid(
                            entries: [
                              _M('Mevcut Hacim', fmtVol(it.hacim)),
                              _M('Tarih', fmtDate(it.tarih)),
                              _M('Tük. Su', fmtVol(it.tuketilebilirKapasite)),
                              _M('MAX Kap.', fmtVol(it.maxKapasite)),
                              _M('MIN Kap.', fmtVol(it.minKapasite)),
                              _M(
                                'Yükseklik',
                                '${fmtHeight(it.minYukseklik)} / ${fmtHeight(it.maxYukseklik)}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MiniDataTable(
                  row: [
                    it.seviye ?? '-',
                    fmtVol(it.hacim),
                    fmtVol(it.maxKapasite),
                    fmtPct(it.doluluk),
                    fmtDate(it.tarih),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ------------------------------ Map Body --------------------------------- */

class _MapBody extends StatelessWidget {
  final List<_ReservoirWithCoord> items;
  const _MapBody({required this.items});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _ReservoirMap(items: items),
    );
  }
}

/* ------------------------------ Charts Body ------------------------------ */

class _ChartsBody extends StatelessWidget {
  final List<_ReservoirWithCoord> items;
  const _ChartsBody({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Kayıt yok.'));
    final sorted = [...items]
      ..sort(
        (a, b) => ((b.status.doluluk ?? 0).compareTo(a.status.doluluk ?? 0)),
      );
    final top10 = sorted.take(10).toList();

    final totalVol = items
        .map((e) => e.status.hacim ?? 0)
        .fold<double>(0, (a, b) => a + b);
    final low = items.where((e) => (e.status.doluluk ?? 0) < 30).toList();
    final mid = items
        .where(
          (e) => (e.status.doluluk ?? 0) >= 30 && (e.status.doluluk ?? 0) < 60,
        )
        .toList();
    final high = items.where((e) => (e.status.doluluk ?? 0) >= 60).toList();

    double sumVol(List<_ReservoirWithCoord> l) =>
        l.map((e) => e.status.hacim ?? 0).fold<double>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  icon: Icons.bar_chart,
                  title: 'Top 10 – Doluluk Oranı',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      alignment: BarChartAlignment.spaceAround,
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= top10.length) {
                                return const SizedBox.shrink();
                              }
                              final name = (top10[idx].status.ad ?? '')
                                  .split(' ')
                                  .first;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < top10.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: (top10[i].status.doluluk ?? 0).toDouble(),
                                width: 16,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  icon: Icons.pie_chart_outline,
                  title: 'Toplam: ${fmtVol(totalVol)})',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 48,
                      sectionsSpace: 2,
                      sections: [
                        PieChartSectionData(
                          value: sumVol(low),
                          title: 'Düşük',
                          radius: 70,
                        ),
                        PieChartSectionData(
                          value: sumVol(mid),
                          title: 'Orta',
                          radius: 70,
                        ),
                        PieChartSectionData(
                          value: sumVol(high),
                          title: 'Yüksek',
                          radius: 70,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: const [
                    _LegendDot(text: 'Düşük (<%30)'),
                    _LegendDot(text: 'Orta (%30–60)'),
                    _LegendDot(text: 'Yüksek (≥%60)'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ------------------------------ UI: Harita ------------------------------- */

class _ReservoirMap extends StatelessWidget {
  final List<_ReservoirWithCoord> items;
  const _ReservoirMap({required this.items});

  @override
  Widget build(BuildContext context) {
    final pts = items
        .where((e) => e.loc?.lat != null && e.loc?.lon != null)
        .toList();
    if (pts.isEmpty) {
      return const Center(child: Text('Koordinat bilgisi bulunamadı.'));
    }
    final avgLat =
        pts.map((e) => e.loc!.lat!).reduce((a, b) => a + b) / pts.length;
    final avgLon =
        pts.map((e) => e.loc!.lon!).reduce((a, b) => a + b) / pts.length;

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(avgLat, avgLon),
        initialZoom: 8.5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'secret_water.app',
        ),
        MarkerLayer(
          markers: [
            for (final e in pts)
              Marker(
                point: LatLng(e.loc!.lat!, e.loc!.lon!),
                width: 200,
                height: 44,
                child: _MapMarker(res: e.status),
              ),
          ],
        ),
      ],
    );
  }
}

class _MapMarker extends StatelessWidget {
  final ReservoirStatus res;
  const _MapMarker({required this.res});

  @override
  Widget build(BuildContext context) {
    Color badgeColor() {
      final p = res.doluluk ?? 0;
      if (p >= 60) return Colors.green;
      if (p >= 30) return Colors.orange;
      return Colors.red;
    }

    return GestureDetector(
      onTap: () {
        final msg =
            '${res.ad ?? 'Baraj'}\n'
            'Doluluk: ${fmtPct(res.doluluk)}\n'
            'Hacim: ${fmtVol(res.hacim)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
          border: Border.all(color: badgeColor(), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_outlined, size: 18),
            const SizedBox(width: 6),
            Text(
              '${res.ad ?? 'Baraj'} • ${fmtPct(res.doluluk)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ UI: Hesaplama ---------------------------- */

class NeedsCalculatorTab extends StatefulWidget {
  const NeedsCalculatorTab({super.key});
  @override
  State<NeedsCalculatorTab> createState() => _NeedsCalculatorTabState();
}

class _NeedsCalculatorTabState extends State<NeedsCalculatorTab> {
  final _form = GlobalKey<FormState>();

  // Temel girdiler
  final _peopleCtrl = TextEditingController(text: '3');
  final _daysCtrl = TextEditingController(text: '2');
  final _pricePerLitreCtrl = TextEditingController(); // opsiyonel

  // Profil ve güvenlik payı
  String _profile = 'Temel';
  double _safetyPct = 10; // %

  // Ayrıntılı dağılım (kişi başı L/gün)
  final Map<String, double> _perPersonBreakdown = {
    'İçme': 3,
    'Yemek': 2,
    'Hijyen (duş/elbise/elve)': 25,
    'Tuvalet': 20,
    'Çamaşır': 15,
    'Temizlik': 10,
  };

  // Özel profil modunda yalnız breakdown kullanılacak
  bool get _isCustom => _profile == 'Özel';

  @override
  void dispose() {
    _peopleCtrl.dispose();
    _daysCtrl.dispose();
    _pricePerLitreCtrl.dispose();
    super.dispose();
  }

  double _sumPerPerson() =>
      _perPersonBreakdown.values.fold<double>(0, (a, b) => a + b);

  void _applyPreset(String p) {
    setState(() {
      _profile = p;
      switch (p) {
        case 'Acil':
          _perPersonBreakdown
            ..update('İçme', (_) => 3)
            ..update('Yemek', (_) => 1)
            ..update('Hijyen (duş/elbise/elve)', (_) => 6)
            ..update('Tuvalet', (_) => 4)
            ..update('Çamaşır', (_) => 0)
            ..update('Temizlik', (_) => 1);
          _safetyPct = 5;
          break;
        case 'Temel':
          _perPersonBreakdown
            ..update('İçme', (_) => 3)
            ..update('Yemek', (_) => 2)
            ..update('Hijyen (duş/elbise/elve)', (_) => 25)
            ..update('Tuvalet', (_) => 20)
            ..update('Çamaşır', (_) => 15)
            ..update('Temizlik', (_) => 10);
          _safetyPct = 10;
          break;
        case 'Konfor':
          _perPersonBreakdown
            ..update('İçme', (_) => 3)
            ..update('Yemek', (_) => 3)
            ..update('Hijyen (duş/elbise/elve)', (_) => 40)
            ..update('Tuvalet', (_) => 25)
            ..update('Çamaşır', (_) => 25)
            ..update('Temizlik', (_) => 15);
          _safetyPct = 15;
          break;
        case 'Özel':
          // mevcut değerleri koru
          _safetyPct = _safetyPct.clamp(0, 50);
          break;
      }
    });
  }

  // Hesaplama
  _CalcResult _calc() {
    final people = int.tryParse(_peopleCtrl.text.trim()) ?? 0;
    final days = int.tryParse(_daysCtrl.text.trim()) ?? 0;
    final perPerson = _sumPerPerson(); // L/kişi/gün
    final baseLitres = people * days * perPerson;
    final safetyLitres = baseLitres * (_safetyPct / 100.0);
    final totalLitres = baseLitres + safetyLitres;

    // konteyner önerileri
    int n05 = (totalLitres / 0.5).ceil();
    int n15 = (totalLitres / 1.5).ceil();
    int n5 = (totalLitres / 5.0).ceil();
    int n19 = (totalLitres / 19.0).ceil();
    int tank1000 = (totalLitres / 1000.0).ceil();

    // maliyet
    final price = double.tryParse(_pricePerLitreCtrl.text.replaceAll(',', '.'));
    final cost = price == null ? null : totalLitres * price;

    return _CalcResult(
      people: people,
      days: days,
      perPerson: perPerson,
      baseLitres: baseLitres,
      safetyLitres: safetyLitres,
      totalLitres: totalLitres,
      n05: n05,
      n15: n15,
      n5: n5,
      n19: n19,
      tank1000: tank1000,
      pricePerLitre: price,
      estimatedCost: cost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = _calc();
    final scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _form,
        child: Column(
          children: [
            // Hızlı profiller
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(icon: Icons.tune, title: 'Profil ve Süre'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChipBtn(
                          label: 'Acil',
                          selected: _profile == 'Acil',
                          onTap: () => _applyPreset('Acil'),
                        ),
                        _ChipBtn(
                          label: 'Temel',
                          selected: _profile == 'Temel',
                          onTap: () => _applyPreset('Temel'),
                        ),
                        _ChipBtn(
                          label: 'Konfor',
                          selected: _profile == 'Konfor',
                          onTap: () => _applyPreset('Konfor'),
                        ),
                        _ChipBtn(
                          label: 'Özel',
                          selected: _profile == 'Özel',
                          onTap: () => _applyPreset('Özel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _numField(
                            controller: _peopleCtrl,
                            label: 'Kişi sayısı',
                            min: 1,
                            max: 200,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _numField(
                            controller: _daysCtrl,
                            label: 'Gün',
                            min: 1,
                            max: 120,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Güvenlik Payı (%)',
                                  style: Theme.of(context).textTheme.labelLarge),
                              Slider(
                                value: _safetyPct,
                                min: 0,
                                max: 50,
                                divisions: 50,
                                label: '${_safetyPct.toStringAsFixed(0)}%',
                                onChanged: (v) =>
                                    setState(() => _safetyPct = v),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            '+${_safetyPct.toStringAsFixed(0)}%',
                            textAlign: TextAlign.end,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Ayrıntılı dağılım
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                        icon: Icons.format_list_bulleted,
                        title:
                            'Kişi başı (L / gün)  •  Toplam: ${_sumPerPerson().toStringAsFixed(0)} L'),
                    const SizedBox(height: 8),
                    ..._perPersonBreakdown.entries.map((e) {
                      return _BreakdownSlider(
                        label: e.key,
                        value: e.value,
                        enabled: _isCustom, // Özel değilse sadece göster
                        onChanged: (v) =>
                            setState(() => _perPersonBreakdown[e.key] = v),
                      );
                    }),
                    if (!_isCustom)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Not: Değerleri düzenlemek için profili “Özel”e alın.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Özet kartları
            _SummaryBigRow(
              items: [
                _SummaryBig(
                  icon: Icons.water_drop,
                  title: 'Toplam',
                  value:
                      '${res.totalLitres.toStringAsFixed(0)} L',
                  subtitle:
                      '${res.people} kişi × ${res.days} gün + %${_safetyPct.toStringAsFixed(0)} güvenlik',
                ),
                _SummaryBig(
                  icon: Icons.person,
                  title: 'Kişi Başı / Gün',
                  value: '${res.perPerson.toStringAsFixed(0)} L',
                  subtitle: _profile,
                ),
                _SummaryBig(
                  icon: Icons.local_drink_outlined,
                  title: 'Baz İhtiyaç',
                  value: '${res.baseLitres.toStringAsFixed(0)} L',
                  subtitle: 'Güvenlik: +${res.safetyLitres.toStringAsFixed(0)} L',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Grafik + Maliyet
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(icon: Icons.pie_chart, title: 'Tüketim Dağılımı'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 48,
                          sectionsSpace: 2,
                          sections: _perPersonBreakdown.entries.map((e) {
                            final v = e.value;
                            return PieChartSectionData(
                              value: v <= 0 ? 0.01 : v,
                              title: e.key.split(' ').first,
                              radius: 70,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pricePerLitreCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Litre başı fiyat (₺) — opsiyonel',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.payments_outlined,
                            title: 'Tahmini Maliyet',
                            value: res.estimatedCost == null
                                ? '-'
                                : '₺ ${res.estimatedCost!.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Konteyner önerileri
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                        icon: Icons.inventory_2_outlined,
                        title: 'Konteyner / Depolama Önerisi'),
                    const SizedBox(height: 8),
                    _ContainerRow(icon: Icons.local_drink, label: '0.5 L şişe', count: res.n05),
                    _ContainerRow(icon: Icons.local_drink, label: '1.5 L şişe', count: res.n15),
                    _ContainerRow(icon: Icons.wine_bar_outlined, label: '5 L şişe', count: res.n5),
                    _ContainerRow(icon: Icons.water_damage_outlined, label: '19 L damacana', count: res.n19),
                    _ContainerRow(icon: Icons.oil_barrel_outlined, label: '1000 L depo', count: res.tank1000),
                    const SizedBox(height: 8),
                    Text(
                      'İpucu: Depolamada karanlık, serin yer ve gıda güvenli kaplar tercih edin. Etiketleyip tarihlemeniz takipte kolaylık sağlar.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 8 * scale.toDouble()),
          ],
        ),
      ),
    );
  }

  // ortak numerik alan
  Widget _numField({
    required TextEditingController controller,
    required String label,
    required int min,
    required int max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        signed: false,
        decimal: false,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final n = int.tryParse((v ?? '').trim());
        if (n == null) return 'Sayı girin';
        if (n < min) return '$min\'dan küçük olamaz';
        if (n > max) return '$max\'ı aşamaz';
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }
}

/* ------------------------------ Hesap yardımcı sınıf --------------------- */

class _CalcResult {
  final int people;
  final int days;
  final double perPerson;
  final double baseLitres;
  final double safetyLitres;
  final double totalLitres;
  final int n05, n15, n5, n19, tank1000;
  final double? pricePerLitre;
  final double? estimatedCost;

  _CalcResult({
    required this.people,
    required this.days,
    required this.perPerson,
    required this.baseLitres,
    required this.safetyLitres,
    required this.totalLitres,
    required this.n05,
    required this.n15,
    required this.n5,
    required this.n19,
    required this.tank1000,
    required this.pricePerLitre,
    required this.estimatedCost,
  });
}

/* ------------------------------ Küçük UI bileşenleri -------------------- */

class _ChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChipBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _BreakdownSlider extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  const _BreakdownSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Slider(
                  value: value,
                  min: 0,
                  max: 80,
                  divisions: 80,
                  label: '${value.toStringAsFixed(0)} L',
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${value.toStringAsFixed(0)} L',
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBigRow extends StatelessWidget {
  final List<_SummaryBig> items;
  const _SummaryBigRow({required this.items});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      int cols = w < 520 ? 1 : (w < 820 ? 2 : 3);
      final gap = 8.0;
      final tileW = cols == 1 ? w : (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items
            .map((e) => SizedBox(width: tileW, child: e))
            .toList(growable: false),
      );
    });
  }
}

class _SummaryBig extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  const _SummaryBig({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContainerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _ContainerRow({required this.icon, required this.label, required this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(count == 0 ? '-' : count.toString(),
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}


/* ------------------------------ küçük yardımcı UI ------------------------ */

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 150, child: Text('$k:')),
      Expanded(child: Text(v)),
    ],
  ),
);

Widget _errorBox({
  required IconData icon,
  required String text,
  required VoidCallback onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    ),
  );
}

/* ------------------------------ İç Tipler/Helpers ----------------------- */

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  final double? current;
  final double? max;
  const _CapacityBar({this.current, this.max});

  @override
  Widget build(BuildContext context) {
    double pct = 0.0;
    if ((current ?? 0) > 0 && (max ?? 0) > 0) {
      pct = ((current! / max!).clamp(0.0, 1.0)).toDouble();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storage, size: 16),
            const SizedBox(width: 6),
            Text(
              'Kapasite Kullanımı',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            Text(max == null ? '-' : '${(pct * 100).toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: (max == null || max == 0) ? null : pct,
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final List<_M> entries;
  const _MetricsGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        int cols;
        if (w < 400) {
          cols = 2;
        } else if (w < 720) {
          cols = 3;
        } else {
          cols = 4;
        }

        // Cihazdaki yazı ölçeğine göre karo yüksekliğini büyüt
        final scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.6);
        final double tileHeight = 48 * scale + 8; // eskisi 52 sabitti

        return GridView.builder(
          itemCount: entries.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: tileHeight,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (_, i) {
            final e = entries[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.k,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // satır yüksekliğini sıkı tut
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(height: 1.05),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniDataTable extends StatelessWidget {
  final List<String> row;
  const _MiniDataTable({required this.row});

  @override
  Widget build(BuildContext context) {
    final headers = ['Seviye', 'Mevcut', 'Max', 'Doluluk', 'Tarih'];

    // Satır yüksekliklerini yazı ölçeğine göre hesapla
    final scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.6);
    final double dataH = 44 * scale; // veri satırı
    final double headH = 38 * scale; // başlık satırı

    final table = DataTable(
      headingRowHeight: headH,
      dataRowMinHeight: dataH,
      dataRowMaxHeight: dataH,
      headingTextStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      dataTextStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(height: 1.1),
      columnSpacing: 16,
      horizontalMargin: 0,
      columns: [
        for (final h in headers)
          DataColumn(label: Text(h, overflow: TextOverflow.ellipsis)),
      ],
      rows: [
        DataRow(
          cells: [
            for (final c in row)
              DataCell(Text(c, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ],
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String text;
  const _LegendDot({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(radius: 6),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _M {
  final String k, v;
  _M(this.k, this.v);
}

extension _StrX on String {
  String ifEmpty(String alt) => trim().isEmpty ? alt : this;
}

// mevcut veri bağlama tipleri
class _ReservoirWithCoord {
  final ReservoirStatus status;
  final WaterSource? loc;
  _ReservoirWithCoord({required this.status, required this.loc});
}

class _ReservoirBundle {
  final List<_ReservoirWithCoord> all;
  _ReservoirBundle({required this.all});
}
