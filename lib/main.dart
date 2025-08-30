// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// UI/Charts
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
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
  late final TabController _tab = TabController(length: 4, vsync: this);

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
        actions: [
          FutureBuilder<int>(
            future: Gamify.xp(),
            builder: (context, snap) {
              final xp = snap.data ?? 0;
              return IconButton(
                tooltip: 'Profil • XP: $xp',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage())),
                icon: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.person_outline),
                  Positioned(
                    right: -6, top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text('$xp', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.water_drop_outlined), text: 'Kesintiler'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Barajlar'),
            Tab(icon: Icon(Icons.science_outlined), text: 'Kalite'),
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Hesaplama'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          OutagesTab(),
          ReservoirsProTab(),
          QualityReportsTab(),   // <- güncellenen sekme
          NeedsCalculatorTab(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 22, height: 22, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.water_drop_outlined, size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text('created by NEO KLOTHO',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(0)!);
}

String fmtPct(double? v) => v == null ? '-' : '${v.toStringAsFixed(2)} %';
String fmtVol(double? v) => v == null ? '-' : '${NumberFormat.decimalPattern().format(v)} m³';
String fmtHeight(double? v) => v == null ? '-' : '${v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0)} m';

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

String fmtDate(DateTime? d) => d == null ? '-' : DateFormat('dd.MM.yyyy HH:mm').format(d);

/* -------------------------------- Modeller ------------------------------ */

class OutageItem {
  final String? ilce, mahalle, sebep, ongoru, kesintisuresi, birimamirligi, aciklama;
  final DateTime? baslangic, bitis;
  OutageItem({
    required this.ilce, required this.mahalle, required this.sebep, required this.ongoru,
    required this.kesintisuresi, required this.birimamirligi, required this.aciklama,
    required this.baslangic, required this.bitis,
  });
  factory OutageItem.fromJson(Map<String, dynamic> m) => OutageItem(
    ilce: _getAny(m, ['IlceAdi','ilce','district'])?.toString(),
    mahalle: _getAny(m, ['Mahalleler','Mahalle','mahalle'])?.toString(),
    ongoru: m['Ongoru']?.toString(),
    birimamirligi: _getAny(m, ['Birim','BirimAmirligi'])?.toString(),
    kesintisuresi: m['KesintiSuresi']?.toString(),
    sebep: _getAny(m, ['Tip','sebep','Neden'])?.toString(),
    aciklama: _getAny(m, ['Aciklama','Açıklama','aciklama'])?.toString(),
    baslangic: _toDate(_getAny(m, ['Baslangic','Başlangic','BaslamaTarihi','Start'])),
    bitis: _toDate(_getAny(m, ['Bitis','Bitiş','BitisTarihi','Finish'])),
  );
}

class ReservoirStatus {
  final String? ad;
  final double? doluluk, hacim;
  final String? seviye;
  final DateTime? tarih;
  final double? tuketilebilirKapasite, maxKapasite, minKapasite, minYukseklik, maxYukseklik;
  ReservoirStatus({
    required this.ad, required this.doluluk, required this.hacim, required this.seviye, required this.tarih,
    this.tuketilebilirKapasite, this.maxKapasite, this.minKapasite, this.minYukseklik, this.maxYukseklik,
  });
  factory ReservoirStatus.fromJson(Map<String, dynamic> m) => ReservoirStatus(
    ad: _getAny(m, ['BarajKuyuAdi','BarajAdı','KaynakAdi','Ad'])?.toString(),
    doluluk: _toDouble(_getAny(m, ['Doluluk','Oran','DolulukOrani'])),
    hacim: _toDouble(_getAny(m, ['KullanılabilirGolSuHacmi','HacimM3','Hacim_(m3)','MevcutHacim'])),
    seviye: _getAny(m, ['Kademe','Durum'])?.toString(),
    tarih: _toDate(_getAny(m, ['DurumTarihi','GuncellemeTarihi','Güncelleme'])),
    tuketilebilirKapasite: _toDouble(_getAny(m, ['TuketilebilirSuKapasitesi','TüketilebilirSuKapasitesi','TuketilebilirKapasite','Tuketilebilir'])),
    maxKapasite: _toDouble(_getAny(m, ['MaksimumSuKapasitesi','MaksSuKapasitesi','MaxKapasite'])),
    minKapasite: _toDouble(_getAny(m, ['MinimumSuKapasitesi','MinSuKapasitesi','MinKapasite'])),
    minYukseklik: _toDouble(_getAny(m, ['MinimumSuYuksekligi','MinimumSuYüksekliği','MinSuYuksekligi','MinYukseklik'])),
    maxYukseklik: _toDouble(_getAny(m, ['MaksimumSuYuksekligi','MaksimumSuYüksekliği','MaxSuYuksekligi','MaxYukseklik'])),
  );
}

/* ---- Kalite raporu ve grup modeli ---- */
class QualityReport {
  final String? ad;               // baraj adı
  final DateTime? tarih;
  final Map<String, dynamic> raw;
  final double? ph, iletkenlik, bulaniklik, sicaklik, serbestKlor;

  QualityReport({
    required this.ad, required this.tarih, required this.raw,
    this.ph, this.iletkenlik, this.bulaniklik, this.sicaklik, this.serbestKlor,
  });

  // Düz (flat) JSON için
  factory QualityReport.fromJson(Map<String, dynamic> m) {
    double? d(dynamic v) => _toDouble(v);
    return QualityReport(
      ad: _getAny(m, ['BarajAdi','Baraj','Tesis','Ad'])?.toString(),
      tarih: _toDate(_getAny(m, ['RaporTarihi','Tarih','Date'])),
      raw: m,
      ph: d(_getAny(m, ['pH','Ph','PH'])),
      iletkenlik: d(_getAny(m, ['Iletkenlik','İletkenlik','Conductivity'])),
      bulaniklik: d(_getAny(m, ['Bulaniklik','Turbidity'])),
      sicaklik: d(_getAny(m, ['Sicaklik','Sıcaklık','Temperature'])),
      serbestKlor: d(_getAny(m, ['SerbestKlor','FreeChlorine'])),
    );
  }

  // İç içe JSON (BarajAnalizleri -> Analizler -> AnalizElemanlari) için
  factory QualityReport.fromNested(Map<String, dynamic> m) {
    double? d(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim().replaceAll(',', '.');
      final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
      return match == null ? null : double.tryParse(match.group(0)!);
    }

    double? pick(List<dynamic> analizler, List<String> keys) {
      for (final a in analizler) {
        final elems = (a as Map)['AnalizElemanlari'] as List<dynamic>? ?? const [];
        for (final e in elems) {
          final mm = Map<String, dynamic>.from(e as Map);
          final ad = (mm['ParametreAdi'] ?? '').toString().toLowerCase();
          if (keys.any((k) => ad.contains(k))) {
            return d(mm['IslenmisSu']);
          }
        }
      }
      return null;
    }

    final analizler = (m['Analizler'] as List?) ?? const [];
    return QualityReport(
      ad: (m['BarajAdi'] ?? m['Ad'] ?? '').toString(),
      tarih: _toDate(m['Tarih']),
      raw: m,
      ph:          pick(analizler, ['ph']),
      bulaniklik:  pick(analizler, ['bulanık','bulanik']),
      iletkenlik:  pick(analizler, ['iletken']),
      serbestKlor: pick(analizler, ['serbest','klor']),
      sicaklik:    pick(analizler, ['sicak','sıcak']),
    );
  }
}

class QualityGroup {
  final String name;
  final List<QualityReport> items; // tarihe göre sıralı
  QualityGroup(this.name, this.items);
}

/* -------------------------------- Servisler ----------------------------- */

class IzsuApi {
  static const _base = 'https://openapi.izmir.bel.tr/api/izsu';

  static Future<http.Response> _get(Uri url) =>
      http.get(url, headers: {'accept': 'application/json'});

  static Future<List<OutageItem>> fetchOutages() async {
    final res = await _get(Uri.parse('$_base/arizakaynaklisukesintileri'));
    if (res.statusCode != 200) throw Exception('Kesintiler hata: ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (data is List) ? data : (data['data'] ?? data['result'] ?? []);
    return list.map<OutageItem>((e) => OutageItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<List<ReservoirStatus>> fetchReservoirs() async {
    final res = await _get(Uri.parse('$_base/barajdurum'));
    if (res.statusCode != 200) throw Exception('Barajlar hata: ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = (data is List) ? data : (data['data'] ?? data['result'] ?? []);
    return list.map<ReservoirStatus>((e) => ReservoirStatus.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---- GÜNCEL ---- iç içe + düz JSON destekler
  static Future<List<QualityReport>> fetchQualityReportsRaw() async {
    final res = await _get(Uri.parse('$_base/barajsukaliteraporlari'));
    if (res.statusCode != 200) {
      throw Exception('Kalite raporları hata: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));

    // 1) kökte liste
    if (data is List) {
      return data.map<QualityReport>((e) => QualityReport.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    // 2) kökte BarajAnalizleri
    if (data is Map && data['BarajAnalizleri'] is List) {
      final list = List<Map<String, dynamic>>.from(data['BarajAnalizleri']);
      return list.map((m) => QualityReport.fromNested(m)).toList();
    }
    // 3) data / result altında liste
    final inner = (data is Map) ? (data['data'] ?? data['result']) : null;
    if (inner is List) {
      return inner.map<QualityReport>((e) => QualityReport.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return <QualityReport>[];
  }

  // Gruplanmış (baraj adına göre) + tarihe göre sıralı
  static Future<List<QualityGroup>> fetchQualityGroups() async {
    final rows = await fetchQualityReportsRaw();
    final Map<String, List<QualityReport>> byName = {};
    for (final r in rows) {
      final key = (r.ad ?? 'Bilinmeyen').trim();
      (byName[key] ??= []).add(r);
    }
    // tarih sıralaması ve son boş değerleri temizleme
    for (final list in byName.values) {
      list.sort((a, b) {
        final ad = a.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });
    }
    final groups = byName.entries.map((e) => QualityGroup(e.key, e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }
}

/* ------------------------------ UI: Kesintiler --------------------------- */

class OutagesTab extends StatefulWidget {
  const OutagesTab({super.key});
  @override
  State<OutagesTab> createState() => _OutagesTabState();
}

class _OutagesTabState extends State<OutagesTab> {
  late Future<List<OutageItem>> _future = IzsuApi.fetchOutages();
  String _query = '';
  String _ilce = 'Tümü';

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
        final ilceler = {'Tümü', ...all.map((e) => e.ilce ?? '-')}.toList()..sort();
        var items = all.where((e) {
          final t = '${e.ilce} ${e.mahalle} ${e.sebep} ${e.aciklama}'.toLowerCase();
          final okText = t.contains(_query.toLowerCase());
          final okIlce = _ilce == 'Tümü' || (e.ilce ?? '-') == _ilce;
          return okText && okIlce;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 220, maxWidth: 900),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'İlçe/mahalle/sebep ara',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          setState(() => _query = v.trim());
                          Gamify.incrementCounter(context, 'filter_use', target: 3, xp: 15, label: 'Filtre Ustası');
                        },
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _ilce,
                    items: ilceler.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {
                      setState(() => _ilce = v!);
                      Gamify.incrementCounter(context, 'filter_use', target: 3, xp: 15, label: 'Filtre Ustası');
                    },
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
      pct = ((e.inSeconds / d.inSeconds).clamp(0.0, 1.0)).toDouble();
    }
    String badge() => (item.bitis != null && DateTime.now().isAfter(item.bitis!)) ? 'Bitti' : 'Aktif';
    final color = badge() == 'Bitti' ? Colors.green : Theme.of(context).colorScheme.primary;
    String prettyDur(Duration? x) {
      if (x == null) return '-';
      final h = x.inHours, m = x.inMinutes.remainder(60);
      return '${h}sa ${m}dk';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text('${item.ilce ?? '-'} • ${item.mahalle ?? '-'}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
              child: Text(badge(), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          _kv('Sebep', item.sebep ?? item.aciklama ?? '-'),
          _kv('Birim', item.birimamirligi ?? '-'),
          if (item.ongoru != null) _kv('Öngörülen', item.ongoru!),
          if (item.kesintisuresi != null) _kv('Süre', item.kesintisuresi!),
          if (item.aciklama != null) _kv('Açıklama', item.aciklama!),
          if (item.baslangic != null) _kv('Başlangıç', fmtDate(item.baslangic)),
          if (item.bitis != null) _kv('Bitiş', fmtDate(item.bitis)),
          if (d != null) _kv('Planlanan', prettyDur(d)),
          if (e != null) _kv('Geçen', prettyDur(e)),
          if (pct != null) ...[
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct, minHeight: 8)),
          ],
        ]),
      ),
    );
  }
}

/* ------------------------------ UI: Barajlar (Liste + Grafik) ----------- */
/* (Bu bölüm senin önceki dosyan gibi; içerik kısaltılmadı, işlev aynı) */

class ReservoirsProTab extends StatefulWidget {
  const ReservoirsProTab({super.key});
  @override
  State<ReservoirsProTab> createState() => _ReservoirsProTabState();
}

class _ReservoirsProTabState extends State<ReservoirsProTab> {
  late Future<List<ReservoirStatus>> _future = IzsuApi.fetchReservoirs();
  int _mode = 0; // 0: Liste, 1: Grafikler
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReservoirStatus>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) {
          return _errorBox(
            icon: Icons.cloud_off,
            text: 'Baraj servisi alınamadı.\n${s.error}',
            onRetry: () => setState(() => _future = IzsuApi.fetchReservoirs()),
          );
        }

        var items = s.data!;
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          items = items.where((e) => (e.ad ?? '').toLowerCase().contains(q)).toList();
        }

        final double avgFill = items.isEmpty ? 0.0
          : items.map((e) => (e.doluluk ?? 0.0).toDouble()).fold<double>(0.0, (a, b) => a + b) / items.length;
        final double totalVol = items.map((e) => (e.hacim ?? 0.0).toDouble()).fold<double>(0.0, (a, b) => a + b);
        final worst = [...items]..sort((a, b) => (a.doluluk ?? 0.0).compareTo(b.doluluk ?? 0.0));

        Widget header = Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 900),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Baraj ara', border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.view_list), label: Text('Liste')),
                    ButtonSegment(value: 1, icon: Icon(Icons.insert_chart_outlined), label: Text('Grafikler')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (v) {
                    setState(() => _mode = v.first);
                    if (_mode == 1) {
                      Gamify.checkAndComplete(context, 'view_charts', xp: 15, label: 'Analist');
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: LayoutBuilder(builder: (context, c) {
              final double w = c.maxWidth;
              const double gap = 8, tileMin = 260;
              int perRow = (w / (tileMin + gap)).floor();
              if (perRow < 1) perRow = 1;
              final double tileW = perRow == 1 ? w : (w - gap * (perRow - 1)) / perRow;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                SizedBox(width: tileW, child: _SummaryTile(title: 'Ortalama Doluluk', value: fmtPct(avgFill), icon: Icons.speed)),
                SizedBox(width: tileW, child: _SummaryTile(title: 'Toplam Hacim', value: fmtVol(totalVol), icon: Icons.water_drop)),
                SizedBox(width: tileW, child: _SummaryTile(title: 'En Düşük (3)', value: worst.take(3).map((e) => (e.ad ?? '-')).join(', ').ifEmpty('-'), icon: Icons.warning_amber_rounded)),
              ]);
            }),
          ),
        ]);

        return NestedScrollView(
          headerSliverBuilder: (_, __) => [SliverToBoxAdapter(child: header)],
          body: _mode == 0 ? _ProList(items: items) : _ChartsBody(items: items),
        );
      },
    );
  }
}

class _ProList extends StatelessWidget {
  final List<ReservoirStatus> items;
  const _ProList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Kayıt yok.'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final it = items[i];
        final double percent = (((it.doluluk ?? 0) / 100).clamp(0.0, 1.0)).toDouble();
        Color badgeColor() {
          final p = it.doluluk ?? 0;
          if (p >= 60) return Colors.green;
          if (p >= 30) return Colors.orange;
          return Colors.red;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                Icon(Icons.deblur, color: badgeColor()),
                const SizedBox(width: 8),
                Flexible(child: Text(it.ad ?? 'Baraj/Kaynak',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                CircularPercentIndicator(
                  radius: 34, lineWidth: 8, percent: percent,
                  center: Text(it.doluluk == null ? '-' : '${it.doluluk!.toStringAsFixed(1)}%'),
                  progressColor: badgeColor(), backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  _CapacityBar(current: it.hacim, max: it.maxKapasite),
                  const SizedBox(height: 2),
                  _MetricsGrid(entries: [
                    _M('Mevcut Hacim', fmtVol(it.hacim)),
                    _M('Tarih', fmtDate(it.tarih)),
                    _M('Tük. Su', fmtVol(it.tuketilebilirKapasite)),
                    _M('MAX Kap.', fmtVol(it.maxKapasite)),
                    _M('MIN Kap.', fmtVol(it.minKapasite)),
                    _M('Yükseklik', '${fmtHeight(it.minYukseklik)} / ${fmtHeight(it.maxYukseklik)}'),
                  ]),
                ])),
              ]),
              const SizedBox(height: 12),
              _MiniDataTable(row: [
                it.seviye ?? '-', fmtVol(it.hacim), fmtVol(it.maxKapasite), fmtPct(it.doluluk), fmtDate(it.tarih),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

/* (Grafikler kısmı aynı kaldı) */
class _ChartsBody extends StatelessWidget {
  final List<ReservoirStatus> items;
  const _ChartsBody({required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Kayıt yok.'));
    final sorted = [...items]..sort((a, b) => ((b.doluluk ?? 0).compareTo(a.doluluk ?? 0)));
    final top10 = sorted.take(10).toList();
    final double totalVol = items.map((e) => (e.hacim ?? 0).toDouble()).fold<double>(0.0, (a, b) => a + b);
    final low = items.where((e) => (e.doluluk ?? 0) < 30).toList();
    final mid = items.where((e) => (e.doluluk ?? 0) >= 30 && (e.doluluk ?? 0) < 60).toList();
    final high = items.where((e) => (e.doluluk ?? 0) >= 60).toList();
    double sumVol(List<ReservoirStatus> l) => l.map((e) => (e.hacim ?? 0).toDouble()).fold<double>(0.0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle(icon: Icons.bar_chart, title: 'Top 10 – Doluluk Oranı'),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: BarChart(BarChartData(
                  gridData: FlGridData(show: false), borderData: FlBorderData(show: false),
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= top10.length) return const SizedBox.shrink();
                        final name = (top10[idx].ad ?? '').split(' ').first;
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis));
                      },
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (int i = 0; i < top10.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: (top10[i].doluluk ?? 0).toDouble(), width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                      ]),
                  ],
                )),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle(icon: Icons.pie_chart_outline, title: 'Toplam: ${fmtVol(totalVol)}'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: PieChart(PieChartData(
                  centerSpaceRadius: 48, sectionsSpace: 2,
                  sections: [
                    PieChartSectionData(value: sumVol(low), title: 'Düşük', radius: 70),
                    PieChartSectionData(value: sumVol(mid), title: 'Orta', radius: 70),
                    PieChartSectionData(value: sumVol(high), title: 'Yüksek', radius: 70),
                  ],
                )),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 8, children: const [
                _LegendDot(text: 'Düşük (<%30)'), _LegendDot(text: 'Orta (%30–60)'), _LegendDot(text: 'Yüksek (≥%60)'),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

/* ------------------------------ UI: Kalite Raporları (Liste + mini grafik) ---- */

class QualityReportsTab extends StatefulWidget {
  const QualityReportsTab({super.key});
  @override
  State<QualityReportsTab> createState() => _QualityReportsTabState();
}

class _QualityReportsTabState extends State<QualityReportsTab> {
  late Future<List<QualityGroup>> _future = IzsuApi.fetchQualityGroups();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QualityGroup>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return _errorBox(
            icon: Icons.cloud_off,
            text: 'Kalite raporları alınamadı.\n${s.error}',
            onRetry: () => setState(() => _future = IzsuApi.fetchQualityGroups()),
          );
        }
        final groups = s.data!;
        if (groups.isEmpty) return const Center(child: Text('Kayıt yok.'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _QualityGroupCard(group: groups[i]),
        );
      },
    );
  }
}

class _QualityGroupCard extends StatelessWidget {
  final QualityGroup group;
  const _QualityGroupCard({required this.group});

  QualityReport? get last => group.items.isEmpty ? null : group.items.last;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = last;

    // sparkline için pH zaman serisi (son 8 nokta)
    final phSpots = <FlSpot>[];
    for (var i = 0; i < group.items.length; i++) {
      final v = group.items[i].ph;
      if (v != null) phSpots.add(FlSpot(i.toDouble(), v));
    }
    final trimmed = phSpots.length > 8 ? phSpots.sublist(phSpots.length - 8) : phSpots;

    Widget _metric(String k, String v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(k, style: t.bodySmall),
        const SizedBox(width: 6),
        Text(v, style: t.bodyMedium),
      ]),
    );

    String _fmtNum(double? n, {int frac = 2}) => n == null ? '-' : n.toStringAsFixed(n % 1 == 0 ? 0 : frac);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.science_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(group.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            Text(r?.tarih == null ? '-' : fmtDate(r!.tarih), style: t.bodySmall),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 8, children: [
            _metric('pH', _fmtNum(r?.ph)),
            _metric('Bulanıklık', _fmtNum(r?.bulaniklik)),
            _metric('İletkenlik', _fmtNum(r?.iletkenlik, frac: 0)),
            _metric('Serbest Klor', _fmtNum(r?.serbestKlor)),
            _metric('Sıcaklık', _fmtNum(r?.sicaklik, frac: 1)),
          ]),
          if (trimmed.length >= 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: LineChart(LineChartData(
                minY: trimmed.map((e) => e.y).reduce((a, b) => a < b ? a : b),
                maxY: trimmed.map((e) => e.y).reduce((a, b) => a > b ? a : b),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trimmed, isCurved: true, barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              )),
            ),
            Text('pH trend (son ${trimmed.length})', style: t.bodySmall),
          ],
        ]),
      ),
    );
  }
}

/* ------------------------------ UI: Hesaplama (senin önceki hali) ------- */
/* (Aşağıdaki hesaplama, profil & gamification bölümleri birebir korunmuştur) */

class NeedsCalculatorTab extends StatefulWidget {
  const NeedsCalculatorTab({super.key});
  @override
  State<NeedsCalculatorTab> createState() => _NeedsCalculatorTabState();
}

class _NeedsCalculatorTabState extends State<NeedsCalculatorTab> {
  final _form = GlobalKey<FormState>();
  final _peopleCtrl = TextEditingController(text: '3');
  final _daysCtrl = TextEditingController(text: '2');
  final _pricePerLitreCtrl = TextEditingController();
  String _profile = 'Temel';
  double _safetyPct = 10;
  final Map<String, double> _perPersonBreakdown = {
    'İçme': 3, 'Yemek': 2, 'Hijyen (duş/elbise/elve)': 25, 'Tuvalet': 20, 'Çamaşır': 15, 'Temizlik': 10,
  };
  bool get _isCustom => _profile == 'Özel';

  @override
  void dispose() {
    _peopleCtrl.dispose(); _daysCtrl.dispose(); _pricePerLitreCtrl.dispose(); super.dispose();
  }

  double _sumPerPerson() => _perPersonBreakdown.values.fold<double>(0, (a, b) => a + b);

  void _applyPreset(String p) {
    setState(() {
      _profile = p;
      switch (p) {
        case 'Acil':
          _perPersonBreakdown..update('İçme', (_) => 3)..update('Yemek', (_) => 1)..update('Hijyen (duş/elbise/elve)', (_) => 6)
            ..update('Tuvalet', (_) => 4)..update('Çamaşır', (_) => 0)..update('Temizlik', (_) => 1);
          _safetyPct = 5; break;
        case 'Temel':
          _perPersonBreakdown..update('İçme', (_) => 3)..update('Yemek', (_) => 2)..update('Hijyen (duş/elbise/elve)', (_) => 25)
            ..update('Tuvalet', (_) => 20)..update('Çamaşır', (_) => 15)..update('Temizlik', (_) => 10);
          _safetyPct = 10; break;
        case 'Konfor':
          _perPersonBreakdown..update('İçme', (_) => 3)..update('Yemek', (_) => 3)..update('Hijyen (duş/elbise/elve)', (_) => 40)
            ..update('Tuvalet', (_) => 25)..update('Çamaşır', (_) => 25)..update('Temizlik', (_) => 15);
          _safetyPct = 15; break;
        case 'Özel':
          _safetyPct = _safetyPct.clamp(0.0, 50.0).toDouble(); break;
      }
    });
  }

  _CalcResult _calc() {
    final people = int.tryParse(_peopleCtrl.text.trim()) ?? 0;
    final days = int.tryParse(_daysCtrl.text.trim()) ?? 0;
    final perPerson = _sumPerPerson();
    final baseLitres = people * days * perPerson;
    final safetyLitres = baseLitres * (_safetyPct / 100.0);
    final totalLitres = baseLitres + safetyLitres;
    int n05 = (totalLitres / 0.5).ceil();
    int n15 = (totalLitres / 1.5).ceil();
    int n5 = (totalLitres / 5.0).ceil();
    int n19 = (totalLitres / 19.0).ceil();
    int tank1000 = (totalLitres / 1000.0).ceil();
    final price = double.tryParse(_pricePerLitreCtrl.text.replaceAll(',', '.'));
    final cost = price == null ? null : totalLitres * price;

    return _CalcResult(
      people: people, days: days, perPerson: perPerson,
      baseLitres: baseLitres, safetyLitres: safetyLitres, totalLitres: totalLitres,
      n05: n05, n15: n15, n5: n5, n19: n19, tank1000: tank1000,
      pricePerLitre: price, estimatedCost: cost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = _calc();
    final double scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.6).toDouble();
    if (res.totalLitres > 0) {
      Gamify.checkAndComplete(context, 'first_calc', xp: 20, label: 'İlk Hesap');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _form,
        child: Column(children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle(icon: Icons.tune, title: 'Profil ve Süre'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _ChipBtn(label: 'Acil', selected: _profile == 'Acil', onTap: () => _applyPreset('Acil')),
                  _ChipBtn(label: 'Temel', selected: _profile == 'Temel', onTap: () => _applyPreset('Temel')),
                  _ChipBtn(label: 'Konfor', selected: _profile == 'Konfor', onTap: () => _applyPreset('Konfor')),
                  _ChipBtn(label: 'Özel', selected: _profile == 'Özel', onTap: () => _applyPreset('Özel')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _numField(controller: _peopleCtrl, label: 'Kişi sayısı', min: 1, max: 200)),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(controller: _daysCtrl, label: 'Gün', min: 1, max: 120)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Güvenlik Payı (%)', style: Theme.of(context).textTheme.labelLarge),
                    Slider(
                      value: _safetyPct, min: 0, max: 50, divisions: 50,
                      label: '${_safetyPct.toStringAsFixed(0)}%',
                      onChanged: (v) => setState(() => _safetyPct = v),
                    ),
                  ])),
                  SizedBox(width: 90, child: Text('+${_safetyPct.toStringAsFixed(0)}%',
                    textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle(icon: Icons.format_list_bulleted, title: 'Kişi başı (L / gün)  •  Toplam: ${_sumPerPerson().toStringAsFixed(0)} L'),
                const SizedBox(height: 8),
                ..._perPersonBreakdown.entries.map((e) => _BreakdownSlider(
                  label: e.key, value: e.value, enabled: _isCustom,
                  onChanged: (v) => setState(() => _perPersonBreakdown[e.key] = v),
                )),
                if (!_isCustom) Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Not: Değerleri düzenlemek için profili “Özel”e alın.', style: Theme.of(context).textTheme.bodySmall),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _SummaryBigRow(items: [
            _SummaryBig(icon: Icons.water_drop, title: 'Toplam', value: '${res.totalLitres.toStringAsFixed(0)} L',
              subtitle: '${res.people} kişi × ${res.days} gün + %${_safetyPct.toStringAsFixed(0)} güvenlik'),
            _SummaryBig(icon: Icons.person, title: 'Kişi Başı / Gün', value: '${res.perPerson.toStringAsFixed(0)} L', subtitle: _profile),
            _SummaryBig(icon: Icons.local_drink_outlined, title: 'Baz İhtiyaç', value: '${res.baseLitres.toStringAsFixed(0)} L', subtitle: 'Güvenlik: +${res.safetyLitres.toStringAsFixed(0)} L'),
          ]),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle(icon: Icons.pie_chart, title: 'Tüketim Dağılımı'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: PieChart(PieChartData(
                    centerSpaceRadius: 48, sectionsSpace: 2,
                    sections: _perPersonBreakdown.entries.map((e) =>
                      PieChartSectionData(value: e.value <= 0 ? 0.01 : e.value, title: e.key.split(' ').first, radius: 70)
                    ).toList(),
                  )),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _pricePerLitreCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Litre başı fiyat (₺) — opsiyonel', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _InfoTile(icon: Icons.payments_outlined, title: 'Tahmini Maliyet',
                    value: res.estimatedCost == null ? '-' : '₺ ${res.estimatedCost!.toStringAsFixed(2)}')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle(icon: Icons.inventory_2_outlined, title: 'Konteyner / Depolama Önerisi'),
                const SizedBox(height: 8),
                _ContainerRow(icon: Icons.local_drink, label: '0.5 L şişe', count: res.n05),
                _ContainerRow(icon: Icons.local_drink, label: '1.5 L şişe', count: res.n15),
                _ContainerRow(icon: Icons.wine_bar_outlined, label: '5 L şişe', count: res.n5),
                _ContainerRow(icon: Icons.water_damage_outlined, label: '19 L damacana', count: res.n19),
                _ContainerRow(icon: Icons.oil_barrel_outlined, label: '1000 L depo', count: res.tank1000),
                const SizedBox(height: 8),
                Text('İpucu: Depolamada karanlık, serin yer ve gıda güvenli kaplar tercih edin. Etiketleyip tarihlemeniz takipte kolaylık sağlar.',
                  style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          SizedBox(height: 8 * scale),
        ]),
      ),
    );
  }

  Widget _numField({required TextEditingController controller, required String label, required int min, required int max}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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

class _CalcResult {
  final int people, days;
  final double perPerson, baseLitres, safetyLitres, totalLitres;
  final int n05, n15, n5, n19, tank1000;
  final double? pricePerLitre, estimatedCost;
  _CalcResult({
    required this.people, required this.days, required this.perPerson,
    required this.baseLitres, required this.safetyLitres, required this.totalLitres,
    required this.n05, required this.n15, required this.n5, required this.n19, required this.tank1000,
    required this.pricePerLitre, required this.estimatedCost,
  });
}

/* ------------------------------ Üyelik & Gamification -------------------- */
/* (Aşağıdaki kısım öncekiyle aynı) */

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _isLogin = true;
  final _name = TextEditingController();
  final _pass = TextEditingController();

  Future<void> _submit() async {
    final name = _name.text.trim();
    final pass = _pass.text.trim();
    if (name.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen ad ve şifre girin.')));
      return;
    }
    final ok = _isLogin ? await Gamify.login(name, pass) : await Gamify.signup(name, pass);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isLogin ? 'Giriş başarısız.' : 'Kayıt başarısız.')));
      return;
    }
    if (!_isLogin) await Gamify.addXp(context, 20, label: 'Hoş geldin');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(future: Gamify.currentUser(), builder: (context, snap) {
      final user = snap.data;
      if (user == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Üyelik')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ToggleButtons(
                        isSelected: [_isLogin, !_isLogin],
                        onPressed: (i) => setState(() => _isLogin = (i == 0)),
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Giriş')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Kayıt')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Kullanıcı adı', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: Icon(_isLogin ? Icons.login : Icons.person_add_alt),
                          label: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Not: Bu demo tamamen cihaz içinde çalışır (offline).', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Profilim'), actions: [
          IconButton(
            tooltip: 'Çıkış',
            onPressed: () async { await Gamify.logout(); if (mounted) setState(() {}); },
            icon: const Icon(Icons.logout),
          )
        ]),
        body: FutureBuilder<_ProfileData>(
          future: Gamify.profileData(),
          builder: (context, s) {
            final p = s.data;
            if (p == null) return const Center(child: CircularProgressIndicator());
            final level = p.level;
            final xpToNext = ((level * 100) - p.xp).clamp(0, 99999);
            return ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(radius: 28, child: Text(user[0].toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Seviye $level • XP ${p.xp}', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: ((p.xp % 100) / 100.0).clamp(0.0, 1.0).toDouble(), minHeight: 10),
                      ),
                      const SizedBox(height: 4),
                      Text('Sonraki seviyeye: $xpToNext XP', style: Theme.of(context).textTheme.bodySmall),
                    ])),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _SectionTitle(icon: Icons.local_fire_department_outlined, title: 'Günlük Giriş (Streak)'),
                      const SizedBox(height: 8),
                      Text('Seri: ${p.streak} gün', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.icon(onPressed: () => Gamify.dailyCheckIn(context), icon: const Icon(Icons.emoji_events_outlined), label: const Text('Bugün giriş yap (+5 XP)')),
                      const SizedBox(height: 6),
                      Text('Son giriş: ${p.lastCheckIn ?? '-'}', style: Theme.of(context).textTheme.bodySmall),
                    ])),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    _SectionTitle(icon: Icons.task_alt_outlined, title: 'Görevler'),
                    SizedBox(height: 8),
                    _TaskTile(done: false, title: 'İlk hesaplamanı yap', xp: 20, tip: 'Hesaplama ekranında bir sonuç oluştur.'),
                    _TaskTile(done: false, title: 'Grafikleri görüntüle', xp: 15, tip: 'Barajlar → Grafikler sekmesine geç.'),
                    _TaskTile(done: false, title: 'Filtre ustası', xp: 15, tip: 'Kesintiler ekranında 3+ kez filtreyi kullan.'),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
    });
  }
}

class _TaskTile extends StatelessWidget {
  final bool done; final String title; final int xp; final String tip;
  const _TaskTile({required this.done, required this.title, required this.xp, required this.tip});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : null),
      title: Text(title),
      subtitle: Text(done ? 'Tamamlandı' : 'Ödül: +$xp XP • $tip'),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String text; final bool active;
  const _BadgeChip({required this.text, required this.active});
  @override
  Widget build(BuildContext context) {
    final c = active ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor;
    return Chip(
      avatar: CircleAvatar(backgroundColor: c, child: const Icon(Icons.star, size: 14, color: Colors.white)),
      label: Text(text, style: TextStyle(color: active ? null : Theme.of(context).disabledColor)),
      side: BorderSide(color: c.withOpacity(.4)), backgroundColor: c.withOpacity(.08),
    );
  }
}

class _ProfileData {
  final int xp, level, streak;
  final String? lastCheckIn;
  final Set<String> done;
  _ProfileData({required this.xp, required this.level, required this.streak, required this.lastCheckIn, required this.done});
}

class Gamify {
  static Future<bool> signup(String name, String pass) async {
    final p = await SharedPreferences.getInstance();
    if (p.getString('user_name') != null) return false;
    await p.setString('user_name', name);
    await p.setString('user_pass', pass);
    await p.setInt('xp', 0);
    await p.setInt('streak', 0);
    await p.setString('last_check', '');
    await p.setStringList('tasks_done', []);
    await p.setInt('cnt_filter_use', 0);
    return true;
  }

  static Future<bool> login(String name, String pass) async {
    final p = await SharedPreferences.getInstance();
    final n = p.getString('user_name');
    final pw = p.getString('user_pass');
    return (n == name && pw == pass);
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('user_name');
    await p.remove('user_pass');
    await p.remove('xp');
    await p.remove('streak');
    await p.remove('last_check');
    await p.remove('tasks_done');
    await p.remove('cnt_filter_use');
  }

  static Future<String?> currentUser() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('user_name');
  }

  static Future<int> xp() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('xp') ?? 0;
  }

  static Future<void> addXp(BuildContext context, int amount, {String? label}) async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getInt('xp') ?? 0;
    await p.setInt('xp', cur + amount);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🏆 +$amount XP${label != null ? ' • $label' : ''}')));
    }
  }

  static Future<int> level() async {
    final x = await xp();
    return (x ~/ 100) + 1;
  }

  static Future<_ProfileData> profileData() async {
    final p = await SharedPreferences.getInstance();
    final x = p.getInt('xp') ?? 0;
    final st = p.getInt('streak') ?? 0;
    final lc = p.getString('last_check');
    final done = Set<String>.from(p.getStringList('tasks_done') ?? []);
    final lvl = (x ~/ 100) + 1;
    return _ProfileData(xp: x, level: lvl, streak: st, lastCheckIn: (lc == null || lc.isEmpty) ? null : lc, done: done);
  }

  static Future<void> _markDone(String key) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('tasks_done') ?? [];
    if (!list.contains(key)) {
      list.add(key);
      await p.setStringList('tasks_done', list);
    }
  }

  static Future<void> checkAndComplete(BuildContext context, String key, {required int xp, String? label}) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('tasks_done') ?? [];
    if (!list.contains(key)) {
      await addXp(context, xp, label: label);
      await _markDone(key);
    }
  }

  static Future<void> incrementCounter(BuildContext context, String key, {required int target, required int xp, String? label}) async {
    final p = await SharedPreferences.getInstance();
    final k = 'cnt_$key';
    final cur = p.getInt(k) ?? 0;
    final next = cur + 1;
    await p.setInt(k, next);
    final doneList = p.getStringList('tasks_done') ?? [];
    if (next >= target && !doneList.contains(key)) {
      await addXp(context, xp, label: label);
      await _markDone(key);
    }
  }

  static Future<void> dailyCheckIn(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final last = p.getString('last_check') ?? '';
    int streak = p.getInt('streak') ?? 0;

    if (last == today) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bugün zaten giriş yaptın.')));
      }
      return;
    }

    DateTime? lastDate;
    if (last.isNotEmpty) { try { lastDate = DateTime.parse(last); } catch (_) {} }
    if (lastDate != null) {
      final diff = DateTime.now().difference(lastDate).inDays;
      streak = (diff == 1) ? streak + 1 : 1;
    } else {
      streak = 1;
    }

    await p.setString('last_check', today);
    await p.setInt('streak', streak);
    await addXp(context, 5, label: 'Günlük Giriş');
  }
}

/* ------------------------------ Küçük UI bileşenleri -------------------- */

class _ChipBtn extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _ChipBtn({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
}

class _BreakdownSlider extends StatelessWidget {
  final String label; final double value; final bool enabled; final ValueChanged<double> onChanged;
  const _BreakdownSlider({required this.label, required this.value, required this.enabled, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          Slider(value: value, min: 0, max: 80, divisions: 80, label: '${value.toStringAsFixed(0)} L', onChanged: enabled ? onChanged : null),
        ])),
        SizedBox(width: 64, child: Text('${value.toStringAsFixed(0)} L', textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _SummaryBigRow extends StatelessWidget {
  final List<_SummaryBig> items; const _SummaryBigRow({required this.items});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      int cols = w < 520 ? 1 : (w < 820 ? 2 : 3);
      final gap = 8.0;
      final tileW = cols == 1 ? w : (w - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: items.map((e) => SizedBox(width: tileW, child: e)).toList(growable: false));
    });
  }
}

class _SummaryBig extends StatelessWidget {
  final IconData icon; final String title; final String value; final String? subtitle;
  const _SummaryBig({required this.icon, required this.title, required this.value, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(radius: 22, child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)),
          ])),
        ]),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String title; final String value;
  const _InfoTile({required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icon), const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
    );
  }
}

class _ContainerRow extends StatelessWidget {
  final IconData icon; final String label; final int count;
  const _ContainerRow({required this.icon, required this.label, required this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18), const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(count == 0 ? '-' : count.toString(), style: Theme.of(context).textTheme.titleMedium),
      ]),
    );
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 150, child: Text('$k:')),
    Expanded(child: Text(v)),
  ]),
);

Widget _errorBox({required IconData icon, required String text, required VoidCallback onRetry}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48), const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
      ]),
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  final String title, value; final IconData icon;
  const _SummaryTile({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  final double? current, max;
  const _CapacityBar({this.current, this.max});
  @override
  Widget build(BuildContext context) {
    double pct = 0.0;
    if ((current ?? 0) > 0 && (max ?? 0) > 0) pct = ((current! / max!).clamp(0.0, 1.0)).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.storage, size: 16), const SizedBox(width: 6),
        Text('Kapasite Kullanımı', style: Theme.of(context).textTheme.labelLarge),
        const Spacer(), Text(max == null ? '-' : '${(pct * 100).toStringAsFixed(1)}%'),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(minHeight: 10, value: (max == null || max == 0) ? null : pct)),
    ]);
  }
}

class _MetricsGrid extends StatelessWidget {
  final List<_M> entries; const _MetricsGrid({required this.entries});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      int cols = w < 400 ? 2 : (w < 720 ? 3 : 4);
      final double scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.6).toDouble();
      final double tileHeight = 48 * scale + 8;
      return GridView.builder(
        itemCount: entries.length,
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, mainAxisExtent: tileHeight, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemBuilder: (_, i) {
          final e = entries[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.k, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.05)),
              const SizedBox(height: 4),
              Text(e.v, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.1)),
            ]),
          );
        },
      );
    });
  }
}

class _MiniDataTable extends StatelessWidget {
  final List<String> row; const _MiniDataTable({required this.row});
  @override
  Widget build(BuildContext context) {
    final headers = ['Seviye','Mevcut','Max','Doluluk','Tarih'];
    final double scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.6).toDouble();
    final table = DataTable(
      headingRowHeight: 38 * scale,
      dataRowMinHeight: 44 * scale,
      dataRowMaxHeight: 44 * scale,
      headingTextStyle: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, height: 1.1),
      dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.1),
      columnSpacing: 16, horizontalMargin: 0,
      columns: [for (final h in headers) DataColumn(label: Text(h, overflow: TextOverflow.ellipsis))],
      rows: [DataRow(cells: [for (final c in row) DataCell(Text(c, overflow: TextOverflow.ellipsis))])],
    );
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon; final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon), const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final String text; const _LegendDot({required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [const CircleAvatar(radius: 6), const SizedBox(width: 6), Text(text)]);
}

class _M { final String k, v; _M(this.k, this.v); }

extension _StrX on String { String ifEmpty(String alt) => trim().isEmpty ? alt : this; }
