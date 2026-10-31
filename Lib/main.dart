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
      title: 'Futbol Analiz AI',
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
  final TextEditingController _evAdCtrl = TextEditingController(text: 'Galatasaray');
  final TextEditingController _depAdCtrl = TextEditingController(text: 'Fenerbahçe');
  final TextEditingController _evAtilanCtrl = TextEditingController(text: '2.1');
  final TextEditingController _evYenenCtrl = TextEditingController(text: '0.8');
  final TextEditingController _depAtilanCtrl = TextEditingController(text: '1.9');
  final TextEditingController _depYenenCtrl = TextEditingController(text: '0.9');
  final TextEditingController _geminiKeyCtrl = TextEditingController();

  Map<String, dynamic>? _sonuclar;
  String _aiYorumu = '';
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _anahtariYukle();
  }

  Future<void> _anahtariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiKeyCtrl.text = prefs.getString('gemini_key') ?? '';
    });
  }

  Future<void> _anahtariKaydet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_key', key.trim());
  }

  // Faktöriyel ve Poisson Hesaplama Motoru
  double _poisson(int k, double lambda) {
    if (lambda <= 0) return k == 0 ? 1.0 : 0.0;
    double fakt = 1.0;
    for (int i = 1; i <= k; i++) {
      fakt *= i;
    }
    return (pow(lambda, k) * exp(-lambda)) / fakt;
  }

  Future<void> _analizEt() async {
    final double evAt = double.tryParse(_evAtilanCtrl.text.replaceAll(',', '.')) ?? 1.5;
    final double evYe = double.tryParse(_evYenenCtrl.text.replaceAll(',', '.')) ?? 1.1;
    final double depAt = double.tryParse(_depAtilanCtrl.text.replaceAll(',', '.')) ?? 1.3;
    final double depYe = double.tryParse(_depYenenCtrl.text.replaceAll(',', '.')) ?? 1.2;

    const double ligOrt = 1.35;
    final double evLambda = (evAt / ligOrt) * (depYe / ligOrt) * ligOrt;
    final double depLambda = (depAt / ligOrt) * (evYe / ligOrt) * ligOrt;

    double ms1 = 0, ms0 = 0, ms2 = 0, ust25 = 0, kgVar = 0;
    String enOlasiSkor = '1 - 1';
    double maxSkorOlasilik = 0;

    for (int i = 0; i <= 6; i++) {
      for (int j = 0; j <= 6; j++) {
        double p = _poisson(i, evLambda) * _poisson(j, depLambda);
        if (i > j) ms1 += p;
        if (i == j) ms0 += p;
        if (i < j) ms2 += p;
        if ((i + j) > 2) ust25 += p;
        if (i > 0 && j > 0) kgVar += p;

        if (p > maxSkorOlasilik) {
          maxSkorOlasilik = p;
          enOlasiSkor = '$i - $j (%${(p * 100).toStringAsFixed(1)})';
        }
      }
    }

    setState(() {
      _sonuclar = {
        'evBeklenen': evLambda.toStringAsFixed(2),
        'depBeklenen': depLambda.toStringAsFixed(2),
        'ms1': (ms1 * 100).toStringAsFixed(1),
        'ms0': (ms0 * 100).toStringAsFixed(1),
        'ms2': (ms2 * 100).toStringAsFixed(1),
        'ust25': (ust25 * 100).toStringAsFixed(1),
        'alt25': ((1 - ust25) * 100).toStringAsFixed(1),
        'kgVar': (kgVar * 100).toStringAsFixed(1),
        'enOlasiSkor': enOlasiSkor,
      };
      _yukleniyor = true;
      _aiYorumu = 'Yapay zeka maç verilerini analiz ediyor...';
    });

    await _geminiYorumAl();
  }

  Future<void> _geminiYorumAl() async {
    final apiKey = _geminiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _yukleniyor = false;
        _aiYorumu = 'Detaylı yapay zeka maç yorumu için sağ üstteki Ayarlar (dişli) ikonundan Gemini API anahtarınızı girin.';
      });
      return;
    }

    final prompt = '''
Sen profesyonel bir futbol analistisin. Aşağıdaki maç verilerini ve Poisson modeli sonuçlarını inceleyerek maçın nasıl geçeceğini, taktiksel beklentiyi ve en mantıklı 2 tahmini Türkçe olarak net maddelerle yaz:
Maç: ${_evAdCtrl.text} vs ${_depAdCtrl.text}
Beklenen Goller (xG): ${_evAdCtrl.text} (${_sonuclar!['evBeklenen']}) - ${_depAdCtrl.text} (${_sonuclar!['depBeklenen']})
Kazanma Olasılıkları: Ev %${_sonuclar!['ms1']}, Beraberlik %${_sonuclar!['ms0']}, Deplasman %${_sonuclar!['ms2']}
2.5 Üst Olasılığı: %${_sonuclar!['ust25']} | KG Var Olasılığı: %${_sonuclar!['kgVar']}
En Olası Skor: ${_sonuclar!['enOlasiSkor']}
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
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'Yorum üretilemedi.';
        setState(() {
          _aiYorumu = text;
          _yukleniyor = false;
        });
      } else {
        setState(() {
          _aiYorumu = 'API Hatası (${response.statusCode}): Lütfen Gemini API anahtarınızı kontrol edin.';
          _yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiYorumu = 'Bağlantı hatası: İnternet bağlantınızı kontrol edin.';
        _yukleniyor = false;
      });
    }
  }

  void _ayarlarPenceresi() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Ayarları'),
        content: TextField(
          controller: _geminiKeyCtrl,
          decoration: const InputDecoration(
            labelText: 'Gemini API Anahtarı',
            hintText: 'AIza... veya AQ... ile başlayan anahtar',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _anahtariKaydet(_geminiKeyCtrl.text);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚽ Futbol Analiz AI', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _evAdCtrl,
                            decoration: const InputDecoration(labelText: 'Ev Sahibi Takım'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _depAdCtrl,
                            decoration: const InputDecoration(labelText: 'Deplasman Takım'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _evAtilanCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Ev Gol Ort. (Atılan)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _evYenenCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Ev Gol Ort. (Yenen)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _depAtilanCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Dep Gol Ort. (Atılan)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _depYenenCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Dep Gol Ort. (Yenen)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _analizEt,
                        icon: const Icon(Icons.analytics),
                        label: const Text('MAÇI ANALİZ ET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                      const Text('📊 Matematiksel Olasılıklar (Poisson)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      const Divider(),
                      Text('Beklenen Gol (xG): ${_evAdCtrl.text} ${_sonuclar!['evBeklenen']} - ${_sonuclar!['depBeklenen']} ${_depAdCtrl.text}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _oranKutusu('MS 1', '%${_sonuclar!['ms1']}', Colors.green),
                          _oranKutusu('MS X', '%${_sonuclar!['ms0']}', Colors.orange),
                          _oranKutusu('MS 2', '%${_sonuclar!['ms2']}', Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _oranKutusu('2.5 ÜST', '%${_sonuclar!['ust25']}', Colors.purple),
                          _oranKutusu('2.5 ALT', '%${_sonuclar!['alt25']}', Colors.teal),
                          _oranKutusu('KG VAR', '%${_sonuclar!['kgVar']}', Colors.indigo),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('🎯 En Olası Skor: ${_sonuclar!['enOlasiSkor']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      if (_yukleniyor)
                        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
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
