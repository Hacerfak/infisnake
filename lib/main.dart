import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// Constantes para configuração do jogo
const int colunas = 20;
const int linhas = 30;
const double tamanhoCelula = 20.0;
const int pontosPorNivel = 10;

// Enum para representar a direção da cobra
enum Direcao { cima, baixo, esquerda, direita }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InfiSnake',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: const MenuTela(), // A tela inicial agora é o Menu
    );
  }
}

// --- TELA DO MENU INICIAL ---
class MenuTela extends StatefulWidget {
  const MenuTela({super.key});

  @override
  State<MenuTela> createState() => _MenuTelaState();
}

class _MenuTelaState extends State<MenuTela> {
  int _recorde = 0;
  int _ultimaPontuacao = 0;

  // Variáveis para o banner ad
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // ID do anúncio (pode ser o mesmo do jogo)
  String get _bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-4241608895500197/7167523706'
      : 'ca-app-pub-4241608895500197/3364010068';

  @override
  void initState() {
    super.initState();
    _carregarPontuacoes();
    _carregarBannerAd(); // Carregar o anúncio
  }

  void _carregarBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _carregarPontuacoes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recorde = prefs.getInt('recorde') ?? 0;
      _ultimaPontuacao = prefs.getInt('ultimaPontuacao') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'InfiSnake',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('INICIAR'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JogoCobrinhaTela(),
                    ),
                  ).then((_) {
                    // Recarrega as pontuações quando volta do jogo
                    _carregarPontuacoes();
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.leaderboard),
                label: const Text('PLACAR'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  _mostrarScoreboard(context);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.exit_to_app),
                label: const Text('SAIR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () {
                  exit(0); // Fecha a aplicação
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isBannerAdLoaded
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : const SizedBox(height: 50),
    );
  }

  void _mostrarScoreboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Placar', style: TextStyle(color: Colors.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Última Pontuação: $_ultimaPontuacao',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Seu Recorde: $_recorde',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Fechar', style: TextStyle(color: Colors.cyan)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}

// --- TELA DO JOGO ---
class JogoCobrinhaTela extends StatefulWidget {
  const JogoCobrinhaTela({super.key});

  @override
  State<JogoCobrinhaTela> createState() => _JogoCobrinhaTelaState();
}

class _JogoCobrinhaTelaState extends State<JogoCobrinhaTela> {
  List<Point<int>> _cobra = [];
  Point<int> _comida = const Point(0, 0);
  Direcao _direcao = Direcao.direita;
  bool _jogando = false;
  int _pontos = 0;
  int _pontosNivel = 0;
  int _nivel = 1;
  int _vidas = 2;
  Timer? _timer;

  // Cor da borda do cenário

  Color _borderColor = Colors.cyan.withOpacity(0.7);

  final List<Color> _levelColors = [
    Colors.cyan.withOpacity(0.7),

    Colors.amber.withOpacity(0.7),

    Colors.lightGreen.withOpacity(0.7),

    Colors.purpleAccent.withOpacity(0.7),

    Colors.orange.withOpacity(0.7),

    Colors.pink.withOpacity(0.7),
  ];

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _rewardedAdReady = false;

  @override
  void initState() {
    super.initState();
    _carregarAnuncios();
    _iniciarJogo();
  }

  void _iniciarJogo() {
    // Define uma direção inicial aleatória
    final random = Random();
    final direcoes = Direcao.values;
    final direcaoAleatoria = direcoes[random.nextInt(direcoes.length)];

    setState(() {
      _pontos = 0;
      _pontosNivel = 0;
      _nivel = 1;
      _vidas = 2;
      _borderColor = _levelColors[0]; // Reseta a cor da borda

      // Define a posição inicial da cobra baseada na direção aleatória
      // para evitar colisão imediata.
      _direcao = direcaoAleatoria;
      Point<int> cabeca = const Point(
        colunas ~/ 2,
        linhas ~/ 2,
      ); // Começa no centro
      switch (_direcao) {
        case Direcao.direita:
          _cobra = [
            Point(cabeca.x - 2, cabeca.y),
            Point(cabeca.x - 1, cabeca.y),
            cabeca,
          ];
          break;
        case Direcao.esquerda:
          _cobra = [
            Point(cabeca.x + 2, cabeca.y),
            Point(cabeca.x + 1, cabeca.y),
            cabeca,
          ];
          break;
        case Direcao.baixo:
          _cobra = [
            Point(cabeca.x, cabeca.y - 2),
            Point(cabeca.x, cabeca.y - 1),
            cabeca,
          ];
          break;
        case Direcao.cima:
          _cobra = [
            Point(cabeca.x, cabeca.y + 2),
            Point(cabeca.x, cabeca.y + 1),
            cabeca,
          ];
          break;
      }

      _gerarComida();
      _jogando = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 300), _loopJogo);
  }

  void _loopJogo(Timer timer) {
    if (!_jogando) return;
    final cabeca = _cobra.last;
    Point<int> novaCabeca;

    switch (_direcao) {
      case Direcao.cima:
        novaCabeca = Point(cabeca.x, cabeca.y - 1);
        break;
      case Direcao.baixo:
        novaCabeca = Point(cabeca.x, cabeca.y + 1);
        break;
      case Direcao.esquerda:
        novaCabeca = Point(cabeca.x - 1, cabeca.y);
        break;
      case Direcao.direita:
        novaCabeca = Point(cabeca.x + 1, cabeca.y);
        break;
    }

    if (novaCabeca.x < 0 ||
        novaCabeca.x >= colunas ||
        novaCabeca.y < 0 ||
        novaCabeca.y >= linhas ||
        _cobra.contains(novaCabeca)) {
      _perderVida();
      return;
    }

    setState(() {
      _cobra.add(novaCabeca);
      if (novaCabeca == _comida) {
        _pontos++;
        _pontosNivel++;
        if (_pontosNivel >= pontosPorNivel) _subirNivel();
        _gerarComida();
      } else {
        _cobra.removeAt(0);
      }
    });
  }

  void _gerarComida() {
    final random = Random();
    do {
      _comida = Point(random.nextInt(colunas), random.nextInt(linhas));
    } while (_cobra.contains(_comida));
  }

  void _subirNivel() {
    _nivel++;
    _pontosNivel = 0;
    _vidas = 2; // Restaura as vidas ao subir de nível

    // Muda a cor da borda ao subir de nível
    setState(() {
      _borderColor = _levelColors[(_nivel - 1) % _levelColors.length];
    });

    // Limita o tamanho da cobra para evitar crescimento excessivo
    if (_cobra.length > 3) {
      setState(() => _cobra = _cobra.sublist(_cobra.length - 3));
    }
    _timer?.cancel();
    final novaVelocidade = 300 - (_nivel * 20);
    _timer = Timer.periodic(
      Duration(milliseconds: max(50, novaVelocidade)),
      _loopJogo,
    );
  }

  void _perderVida() {
    setState(() {
      _vidas--;
      if (_vidas <= 0) {
        _gameOver();
      } else {
        // Lógica de reset aleatório
        final random = Random();
        final direcoes = Direcao.values;
        final direcaoAleatoria = direcoes[random.nextInt(direcoes.length)];

        _direcao = direcaoAleatoria;
        Point<int> cabeca = const Point(
          colunas ~/ 2,
          linhas ~/ 2,
        ); // Começa no centro
        switch (_direcao) {
          case Direcao.direita:
            _cobra = [
              Point(cabeca.x - 2, cabeca.y),
              Point(cabeca.x - 1, cabeca.y),
              cabeca,
            ];
            break;
          case Direcao.esquerda:
            _cobra = [
              Point(cabeca.x + 2, cabeca.y),
              Point(cabeca.x + 1, cabeca.y),
              cabeca,
            ];
            break;
          case Direcao.baixo:
            _cobra = [
              Point(cabeca.x, cabeca.y - 2),
              Point(cabeca.x, cabeca.y - 1),
              cabeca,
            ];
            break;
          case Direcao.cima:
            _cobra = [
              Point(cabeca.x, cabeca.y + 2),
              Point(cabeca.x, cabeca.y + 1),
              cabeca,
            ];
            break;
        }
      }
    });
  }

  Future<void> _salvarPontuacao() async {
    final prefs = await SharedPreferences.getInstance();
    int recordeAtual = prefs.getInt('recorde') ?? 0;
    if (_pontos > recordeAtual) await prefs.setInt('recorde', _pontos);
    await prefs.setInt('ultimaPontuacao', _pontos);
  }

  void _gameOver() async {
    _timer?.cancel();
    setState(() => _jogando = false);
    await _salvarPontuacao();
    _mostrarDialogoGameOver();
  }

  String get _bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-4241608895500197/7167523706'
      : 'ca-app-pub-4241608895500197/3364010068';

  String get _interstitialAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-4241608895500197/1148894359'
      : 'ca-app-pub-4241608895500197/7111683380';

  String get _rewardedAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-4241608895500197/6401236943'
      : 'ca-app-pub-4241608895500197/6482441071';

  void _carregarAnuncios() {
    _carregarBannerAd();
    _carregarInterstitialAd();
    _carregarRewardedAd();
  }

  void _carregarBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  void _carregarInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  void _carregarRewardedAd() {
    setState(() => _rewardedAdReady = false);
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          setState(() => _rewardedAdReady = true);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          setState(() => _rewardedAdReady = false);
        },
      ),
    );
  }

  void _mostrarInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _carregarInterstitialAd();
          _mostrarScoreboard();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _carregarInterstitialAd();
          _mostrarScoreboard();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      _mostrarScoreboard();
    }
  }

  void _mostrarRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _carregarRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          setState(() {
            _vidas = 1; // Dá a vida extra
            _jogando = true; // Define o jogo como ativo

            // Lógica de reset aleatório para a cobra
            final random = Random();
            final direcoes = Direcao.values;
            final direcaoAleatoria = direcoes[random.nextInt(direcoes.length)];

            _direcao = direcaoAleatoria;
            Point<int> cabeca = const Point(
              colunas ~/ 2,
              linhas ~/ 2,
            ); // Começa no centro
            switch (_direcao) {
              case Direcao.direita:
                _cobra = [
                  Point(cabeca.x - 2, cabeca.y),
                  Point(cabeca.x - 1, cabeca.y),
                  cabeca,
                ];
                break;
              case Direcao.esquerda:
                _cobra = [
                  Point(cabeca.x + 2, cabeca.y),
                  Point(cabeca.x + 1, cabeca.y),
                  cabeca,
                ];
                break;
              case Direcao.baixo:
                _cobra = [
                  Point(cabeca.x, cabeca.y - 2),
                  Point(cabeca.x, cabeca.y - 1),
                  cabeca,
                ];
                break;
              case Direcao.cima:
                _cobra = [
                  Point(cabeca.x, cabeca.y + 2),
                  Point(cabeca.x, cabeca.y + 1),
                  cabeca,
                ];
                break;
            }
          });

          // Reinicia o timer com a velocidade correspondente ao nível atual
          _timer?.cancel();
          final novaVelocidade = 300 - (_nivel * 20);
          _timer = Timer.periodic(
            Duration(milliseconds: max(50, novaVelocidade)),
            _loopJogo,
          );
        },
      );
      _rewardedAd = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pontos: $_pontos | Nível: $_nivel | Vidas: $_vidas'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (_direcao != Direcao.cima && details.delta.dy > 0) {
            _direcao = Direcao.baixo;
          } else if (_direcao != Direcao.baixo && details.delta.dy < 0)
            _direcao = Direcao.cima;
        },
        onHorizontalDragUpdate: (details) {
          if (_direcao != Direcao.esquerda && details.delta.dx > 0) {
            _direcao = Direcao.direita;
          } else if (_direcao != Direcao.direita && details.delta.dx < 0)
            _direcao = Direcao.esquerda;
        },
        child: Center(
          child: Container(
            width: colunas * tamanhoCelula,
            height: linhas * tamanhoCelula,
            decoration: BoxDecoration(
              border: Border.all(
                color: _borderColor,
                width: 2.0,
              ), // Usa a cor da borda do estado
              color: const Color(0xFF161B22),
            ),
            child: Stack(
              children: [
                // Desenha o corpo e a cabeça da cobra com cores diferentes
                ..._cobra.map((p) {
                  final bool isHead = p == _cobra.last;
                  return Positioned(
                    left: p.x * tamanhoCelula,
                    top: p.y * tamanhoCelula,
                    child: Container(
                      width: tamanhoCelula,
                      height: tamanhoCelula,
                      decoration: BoxDecoration(
                        color: isHead ? Colors.cyanAccent : Colors.cyan,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
                Positioned(
                  left: _comida.x * tamanhoCelula,
                  top: _comida.y * tamanhoCelula,
                  child: Container(
                    width: tamanhoCelula,
                    height: tamanhoCelula,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _isBannerAdLoaded
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : const SizedBox(height: 50),
    );
  }

  void _mostrarDialogoGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Fim de Jogo!', style: TextStyle(color: Colors.cyan)),
        content: Text(
          'Sua pontuação final foi: $_pontos',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_vidas <= 0 && _rewardedAdReady)
            TextButton.icon(
              icon: const Icon(Icons.videocam, color: Colors.amber),
              label: const Text(
                'GANHAR +1 VIDA',
                style: TextStyle(color: Colors.amber),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _mostrarRewardedAd();
              },
            ),
          TextButton(
            child: const Text(
              'Ver Placar',
              style: TextStyle(color: Colors.deepOrangeAccent),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _mostrarInterstitialAd();
            },
          ),
          TextButton(
            child: const Text(
              'Reiniciar Jogo',
              style: TextStyle(color: Colors.cyan),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _iniciarJogo();
            },
          ),
          TextButton(
            child: const Text(
              'Sair para o Menu',
              style: TextStyle(color: Colors.redAccent),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _mostrarScoreboard() async {
    final prefs = await SharedPreferences.getInstance();
    final recorde = prefs.getInt('recorde') ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Placar', style: TextStyle(color: Colors.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Última Pontuação: $_pontos',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Seu Recorde: $recorde',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text(
              'Voltar ao Menu',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text(
              'Jogar Novamente',
              style: TextStyle(color: Colors.cyan),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _iniciarJogo();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
