import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FutbolAnalizApp());
}

class FutbolAnalizApp extends StatelessWidget {
  const FutbolAnalizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Lig Analiz AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const AnaEkran(),
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  final TextEditingController _geminiKeyCtrl = TextEditingController();
  final TextEditingController _footballKeyCtrl = TextEditingController();

  // 6 Büyük Lig ve API ID'leri + Takım Güç Veritabanı ([evAt, evYe, depAt, depYe])
  final Map<String, Map<String, dynamic>> _ligVeritabani = {
    '🇹🇷 Türkiye - Süper Lig': {
      'id': 203,
      'ligOrt': 1.38,
      'takimlar': {
        'Galatasaray': [2.45, 0.75, 2.10, 0.90],
        'Fenerbahçe': [2.35, 0.80, 2.05, 0.85],
        'Beşiktaş': [1.85, 1.05, 1.50, 1.20],
        'Trabzonspor': [1.75, 1.10, 1.35, 1.30],
        'Başakşehir': [1.60, 1.05, 1.25, 1.25],
        'Samsunspor': [1.55, 1.15, 1.20, 1.35],
        'Göztepe': [1.50, 1.10, 1.15, 1.35],
        'Eyüpspor': [1.50, 1.20, 1.15, 1.40],
        'Sivasspor': [1.35, 1.25, 1.05, 1.50],
        'Kasımpaşa': [1.65, 1.45, 1.35, 1.60],
        'Alanyaspor': [1.40, 1.30, 1.10, 1.45],
        'Antalyaspor': [1.35, 1.35, 1.05, 1.55],
        'Rizespor': [1.40, 1.35, 1.00, 1.60],
        'Konyaspor': [1.25, 1.20, 0.95, 1.45],
        'Gaziantep FK': [1.30, 1.40, 1.00, 1.65],
      }
    },
    '🏴󠁧󠁢󠁥󠁮󠁧󠁿 İngiltere - Premier League': {
      'id': 39,
      'ligOrt': 1.55,
      'takimlar': {
        'Manchester City': [2.50, 0.80, 2.15, 0.95],
        'Liverpool': [2.35, 0.85, 2.00, 1.00],
        'Arsenal': [2.30, 0.75, 1.95, 0.85],
        'Chelsea': [2.00, 1.15, 1.75, 1.30],
        'Aston Villa': [1.95, 1.20, 1.55, 1.40],
        'Tottenham': [2.10, 1.30, 1.75, 1.45],
        'Newcastle': [1.95, 1.10, 1.45, 1.40],
        'Manchester United': [1.65, 1.20, 1.35, 1.40],
        'Brighton': [1.75, 1.35, 1.45, 1.55],
        'West Ham': [1.55, 1.45, 1.30, 1.65],
        'Fulham': [1.50, 1.25, 1.20, 1.45],
        'Everton': [1.25, 1.20, 1.00, 1.45],
      }
    },
    '🇪🇸 İspanya - La Liga': {
      'id': 140,
      'ligOrt': 1.32,
      'takimlar': {
        'Real Madrid': [2.40, 0.75, 2.05, 0.90],
        'Barcelona': [2.45, 0.85, 2.10, 1.05],
        'Atletico Madrid': [2.05, 0.75, 1.60, 1.00],
        'Athletic Bilbao': [1.80, 0.90, 1.35, 1.10],
        'Villarreal': [1.85, 1.30, 1.45, 1.50],
        'Real Sociedad': [1.55, 0.95, 1.25, 1.10],
        'Real Betis': [1.55, 1.10, 1.20, 1.35],
        'Girona': [1.75, 1.25, 1.40, 1.45],
        'Sevilla': [1.40, 1.25, 1.10, 1.45],
        'Valencia': [1.25, 1.15, 0.95, 1.45],
      }
    },
    '🇮🇹 İtalya - Serie A': {
      'id': 135,
      'ligOrt': 1.35,
      'takimlar': {
        'Inter': [2.35, 0.70, 2.00, 0.85],
        'Napoli': [2.05, 0.85, 1.75, 1.00],
        'Juventus': [1.85, 0.65, 1.50, 0.85],
        'AC Milan': [2.00, 1.05, 1.70, 1.25],
        'Atalanta': [2.15, 1.10, 1.80, 1.25],
        'Roma': [1.75, 1.00, 1.35, 1.25],
        'Lazio': [1.75, 1.05, 1.40, 1.30],
        'Fiorentina': [1.70, 1.10, 1.35, 1.30],
        'Bologna': [1.55, 0.95, 1.20, 1.20],
        'Torino': [1.25, 1.00, 1.00, 1.25],
      }
    },
    '🇩🇪 Almanya - Bundesliga': {
      'id': 78,
      'ligOrt': 1.62,
      'takimlar': {
        'Bayern Münih': [2.85, 0.95, 2.40, 1.15],
        'Bayer Leverkusen': [2.45, 0.90, 2.10, 1.05],
        'Borussia Dortmund': [2.30, 1.20, 1.85, 1.40],
        'RB Leipzig': [2.20, 1.00, 1.85, 1.20],
        'Stuttgart': [2.15, 1.15, 1.70, 1.40],
        'Eintracht Frankfurt': [1.85, 1.25, 1.50, 1.50],
        'Freiburg': [1.65, 1.30, 1.30, 1.55],
        'Wolfsburg': [1.60, 1.40, 1.30, 1.65],
        'Werder Bremen': [1.55, 1.50, 1.30, 1.70],
        'Mönchengladbach': [1.65, 1.55, 1.35, 1.80],
      }
    },
    '🇫🇷 Fransa - Ligue 1': {
      'id': 61,
      'ligOrt': 1.40,
      'takimlar': {
        'PSG': [2.55, 0.85, 2.25, 0.95],
        'Monaco': [2.05, 1.10, 1.75, 1.30],
        'Marseille': [1.95, 1.05, 1.60, 1.30],
        'Lille': [1.80, 0.90, 1.35, 1.15],
        'Lyon': [1.75, 1.25, 1.45, 1.45],
        'Nice': [1.55, 0.90, 1.25, 1.15],
        'Lens': [1.65, 1.00, 1.25, 1.25],
        'Rennes': [1.65, 1.20, 1.25, 1.40],
        'Brest': [1.55, 1.15, 1.25, 1.35],
        'Strasbourg': [1.40, 1.35, 1.10, 1.55],
      }
    },
  };

  late String _seciliLig;
  late String _evTakim;
  late String _depTakim;

  List> _canliMaclar = [];
  bool _bultenYukleniyor = false;
  bool _analizYukleniyor = false;
  Map<String, dynamic>? _sonuclar;
  String _aiYorumu = '';

  @override
  void initState() {
    super.initState();
    _seciliLig = _ligVeritabani.keys.first;
    _takimlariSifirla();
    _anahtarlariYukle();
  }

  void _takimlariSifirla() {
    final Map<String, dynamic> takimlarMap = _ligVeritabani[_seciliLig]!['takimlar'] as Map<String, dynamic>;
    final takimListesi = takimlarMap.keys.toList();
    _evTakim = takimListesi[0];
    _depTakim = takimListesi.length > 1 ? takimListesi[1] : takimListesi[0];
  }

  Future<void> _anahtarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiKeyCtrl.text = prefs.getString('gemini_key') ?? '';
      _footballKeyCtrl.text = prefs.getString('football_key') ?? '';
    });
  }

  Future<void> _anahtarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_key', _geminiKeyCtrl.text.trim());
    await prefs.setString('football_key', _footballKeyCtrl.text.trim());
  }

  Future<void> _canliBultenCek() async {
    final fKey = _footballKeyCtrl.text.trim();
    if (fKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canlı fikstür için sağ üstteki Ayarlar\'dan API-Football anahtarı girebilirsiniz. Şu an listeden istediğiniz maçı seçip analiz edebilirsiniz.')),
      );
      return;
    }

    setState(() => _bultenYukleniyor = true);
    final ligId = _ligVeritabani[_seciliLig]!['id'];

    try {
      final url = Uri.parse('https://v3.football.api-sports.io/fixtures?league=$ligId&next=10');
      final res = await http.get(url, headers: {'x-apisports-key': fKey});
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List resp = body['response'] ?? [];
        setState(() {
          _canliMaclar = resp.map((m) => {
            'ev': m['teams']['home']['name'],
            'dep': m['teams']['away']['name'],
            'tarih': m['fixture']['date'].toString().substring(0, 10),
          }).toList();
        });
      }
    } catch (_) {}
    setState(() => _bultenYukleniyor = false);
  }

  double _poisson(int k, double lambda) {
    if (lambda <= 0) return k == 0 ? 1.0 : 0.0;
    double fakt = 1.0;
    for (int i = 1; i <= k; i++) {
      fakt *= i;
    }
    return (pow(lambda, k) * exp(-lambda)) / fakt;
  }

  Future<void> _otomatikAnalizEt({String? ozelEv, String? ozelDep}) async {
    final ev = ozelEv ?? _evTakim;
    final dep = ozelDep ?? _depTakim;

    final ligBilgi = _ligVeritabani[_seciliLig]!;
    final double ligOrt = (ligBilgi['ligOrt'] as num).toDouble();
    final Map<String, dynamic> takimlar = ligBilgi['takimlar'] as Map<String, dynamic>;

    // Güvenli tip dönüşümü (Hata veren kısım düzeltildi)
    final dynamic hamEvVeri = takimlar[ev];
    final List<double> evVeri = hamEvVeri != null
        ? (hamEvVeri as List<dynamic>).map((e) => (e as num).toDouble()).toList()
        : [1.50, 1.20, 1.25, 1.35];

    final dynamic hamDepVeri = takimlar[dep];
    final List<double> depVeri = hamDepVeri != null
        ? (hamDepVeri as List<dynamic>).map((e) => (e as num).toDouble()).toList()
        : [1.45, 1.25, 1.20, 1.40];

    final double evAt = evVeri[0];
    final double evYe = evVeri[1];
    final double depAt = depVeri[2];
    final double depYe = depVeri[3];

    final double evLambda = (evAt / ligOrt) * (depYe / ligOrt) * ligOrt;
    final double depLambda = (depAt / ligOrt) * (evYe / ligOrt) * ligOrt;

    double ms1 = 0, ms0 = 0, ms2 = 0, ust25 = 0, ust15 = 0, kgVar = 0;
    String enOlasiSkor = '1 - 1';
    double maxSkorOlasilik = 0;

    for (int i = 0; i <= 6; i++) {
      for (int j = 0; j <= 6; j++) {
        double p = _poisson(i, evLambda) * _poisson(j, depLambda);
        if (i > j) ms1 += p;
        if (i == j) ms0 += p;
        if (i < j) ms2 += p;
        if ((i + j) > 1) ust15 += p;
        if ((i + j) > 2) ust25 += p;
        if (i > 0 && j > 0) kgVar += p;

        if (p > maxSkorOlasilik) {
          maxSkorOlasilik = p;
          enOlasiSkor = '$i - $j (%${(p * 100).toStringAsFixed(1)})';
        }
      }
    }

    setState(() {
      _evTakim = ev;
      _depTakim = dep;
      _sonuclar = {
        'evBeklenen': evLambda.toStringAsFixed(2),
        'depBeklenen': depLambda.toStringAsFixed(2),
        'ms1': (ms1 * 100).toStringAsFixed(1),
        'ms0': (ms0 * 100).toStringAsFixed(1),
        'ms2': (ms2 * 100).toStringAsFixed(1),
        'ust15': (ust15 * 100).toStringAsFixed(1),
        'ust25': (ust25 * 100).toStringAsFixed(1),
        'alt25': ((1 - ust25) * 100).toStringAsFixed(1),
        'kgVar': (kgVar * 100).toStringAsFixed(1),
        'enOlasiSkor': enOlasiSkor,
      };
      _analizYukleniyor = true;
      _aiYorumu = 'Yapay zeka $_seciliLig verilerini, kadro güçlerini ve taktiksel eşleşmeyi analiz ediyor...';
    });

    await _geminiOtomatikYorum(ev, dep);
  }

  Future<void> _geminiOtomatikYorum(String ev, String dep) async {
    final apiKey = _geminiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _analizYukleniyor = false;
        _aiYorumu = 'Detaylı yapay zeka yorumu için sağ üstteki Ayarlar (⚙️) ikonundan Gemini API anahtarınızı kaydedin.';
      });
      return;
    }

    final prompt = '''
Sen Avrupa futbolu ve Süper Lig konusunda uzman bir baş analistsin.
Lig: $_seciliLig
Maç: $ev (Ev Sahibi) vs $dep (Deplasman)

Matematiksel Poisson Modeli Çıktıları:
- Beklenen Gol (xG): $ev ${_sonuclar!['evBeklenen']} - ${_sonuclar!['depBeklenen']} $dep
- Maç Sonucu Olasılıkları: MS1 %${_sonuclar!['ms1']} | Beraberlik %${_sonuclar!['ms0']} | MS2 %${_sonuclar!['ms2']}
- Gol Olasılıkları: 1.5 Üst %${_sonuclar!['ust15']} | 2.5 Üst %${_sonuclar!['ust25']} | KG Var %${_sonuclar!['kgVar']}
- En Olası Skor: ${_sonuclar!['enOlasiSkor']}

Lütfen bu iki takımın oyun karakterini, iç/dış saha avantajlarını ve yukarıdaki matematiksel olasılıkları birleştirerek:
1. Maçın Taktiksel Senaryosu (Nasıl bir oyun bekleniyor?)
2. Kilit Faktörler
3. En Güvenilir 2 Tahmin (İdeal Tercih ve Alternatif Tercih)
başlıklarıyla Türkçe, net ve profesyonel bir maç önü analizi yaz.
''';

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'Yorum oluşturulamadı.';
        setState(() {
          _aiYorumu = text;
          _analizYukleniyor = false;
        });
      } else {
        setState(() {
          _aiYorumu = 'API Hatası (${response.statusCode}): Gemini API anahtarınızı kontrol edin.';
          _analizYukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiYorumu = 'İnternet bağlantısı hatası oluştu.';
        _analizYukleniyor = false;
      });
    }
  }

  void _ayarlarPenceresi() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Anahtarları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _geminiKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key (Zorunlu - Yorum İçin)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _footballKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'API-Football Key (İsteğe Bağlı - Fikstür)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _anahtarlariKaydet();
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> takimlarMap = _ligVeritabani[_seciliLig]!['takimlar'] as Map<String, dynamic>;
    final takimListesi = takimlarMap.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚽ 6 Büyük Lig Analiz AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _ayarlarPenceresi,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Lig Seçin', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _seciliLig,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _ligVeritabani.keys
                          .map((lig) => DropdownMenuItem(value: lig, child: Text(lig)))
                          .toList(),
                      onChanged: (yeniLig) {
                        if (yeniLig != null) {
                          setState(() {
                            _seciliLig = yeniLig;
                            _canliMaclar.clear();
                            _sonuclar = null;
                            _takimlariSifirla();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('2. Takımları Seçin (İstatistikler Otomatik Çekilir)',
                        style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: takimListesi.contains(_evTakim) ? _evTakim : takimListesi.first,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Ev Sahibi', border: OutlineInputBorder()),
                            items: takimListesi
                                .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() => _evTakim = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: takimListesi.contains(_depTakim) ? _depTakim : takimListesi.last,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Deplasman', border: OutlineInputBorder()),
                            items: takimListesi
                                .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() => _depTakim = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _otomatikAnalizEt(),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('OTOMATİK ANALİZ ET',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _bultenYukleniyor ? null : _canliBultenCek,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(_bultenYukleniyor ? 'Fikstür Çekiliyor...' : 'Bu Ligin Yaklaşan Maçlarını Getir (Canlı)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_canliMaclar.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFF1E293B),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📅 Yaklaşan Maçlar (Analiz İçin Dokunun)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                      const Divider(),
                      ..._canliMaclar.map((m) => ListTile(
                            dense: true,
                            title: Text('${m['ev']} vs ${m['dep']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Tarih: ${m['tarih']}'),
                            trailing: const Icon(Icons.play_circle_fill, color: Color(0xFF10B981)),
                            onTap: () => _otomatikAnalizEt(ozelEv: m['ev'], ozelDep: m['dep']),
                          )),
                    ],
                  ),
                ),
              ),
            ],
            if (_sonuclar != null) ...[
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📊 $_evTakim - $_depTakim Olasılıkları',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      const Divider(),
                      Text('Beklenen Gol (xG): $_evTakim (${_sonuclar!['evBeklenen']}) - (${_sonuclar!['depBeklenen']}) $_depTakim'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _oranKutusu('MS 1', '%${_sonuclar!['ms1']}', Colors.green),
                          _oranKutusu('MS X', '%${_sonuclar!['ms0']}', Colors.orange),
                          _oranKutusu('MS 2', '%${_sonuclar!['ms2']}', Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _oranKutusu('1.5 ÜST', '%${_sonuclar!['ust15']}', Colors.cyan),
                          _oranKutusu('2.5 ÜST', '%${_sonuclar!['ust25']}', Colors.purple),
                          _oranKutusu('KG VAR', '%${_sonuclar!['kgVar']}', Colors.indigo),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('🎯 En Olası Skor: ${_sonuclar!['enOlasiSkor']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🤖 Yapay Zeka Maç Önü Raporu',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                      const Divider(),
                      if (_analizYukleniyor)
                        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                      else
                        Text(_aiYorumu, style: const TextStyle(fontSize: 15, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _oranKutusu(String baslik, String deger, Color renk) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: renk),
        ),
        child: Column(
          children: [
            Text(baslik, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(deger, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
