import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'l10n/app_localizations.dart';

// Constantes para configuração do jogo
const int colunas = 20;
const int linhas = 30;
const double tamanhoCelula = 20.0;
const int pontosPorNivel = 10;
const int nivelInicioObstaculos = 5;

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
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,

      // Configuração da localização simplificada
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

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
      home: const MenuTela(),
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

  BannerAd? _topBannerAd;
  bool _isTopBannerAdLoaded = false;
  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdLoaded = false;
  bool _areBannersLoading = false;
  InterstitialAd? _interstitialAd;

  String get _bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-4241608895500197/7167523706'
      : 'ca-app-pub-4241608895500197/3364010068';

  String get _interstitialAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-4241608895500197/1148894359'
      : 'ca-app-pub-4241608895500197/7111683380';

  @override
  void initState() {
    super.initState();
    _carregarPontuacoes();
    _carregarInterstitialAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_areBannersLoading) {
      _areBannersLoading = true;
      _carregarBannersAdaptativos();
    }
  }

  Future<void> _carregarBannersAdaptativos() async {
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getAnchoredAdaptiveBannerAdSize(
          Orientation.portrait,
          MediaQuery.of(context).size.width.truncate(),
        );

    if (size == null) {
      return;
    }

    _topBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isTopBannerAdLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();

    _bottomBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isBottomBannerAdLoaded = true),
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

  void _mostrarInterstitialAdAposAcao(VoidCallback acaoAposAnuncio) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _carregarInterstitialAd();
          acaoAposAnuncio();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _carregarInterstitialAd();
          acaoAposAnuncio();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      acaoAposAnuncio();
    }
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
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          _isTopBannerAdLoaded ? _topBannerAd!.size.height.toDouble() : 0,
        ),
        child: SafeArea(
          bottom: false, // Aplica SafeArea apenas no topo
          child: _isTopBannerAdLoaded
              ? SizedBox(
                  height: _topBannerAd!.size.height.toDouble(),
                  width: _topBannerAd!.size.width.toDouble(),
                  child: AdWidget(ad: _topBannerAd!),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizations.gameTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(localizations.startGame),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JogoCobrinhaTela(),
                    ),
                  ).then((_) => _carregarPontuacoes());
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.leaderboard),
                label: Text(localizations.viewScoreboard),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () => _mostrarScoreboard(context),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.exit_to_app),
                label: Text(localizations.closeGame),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => exit(0),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false, // Aplica SafeArea apenas no fundo
        child: _isBottomBannerAdLoaded
            ? SizedBox(
                height: _bottomBannerAd!.size.height.toDouble(),
                width: _bottomBannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bottomBannerAd!),
              )
            : const SizedBox(height: 50),
      ),
    );
  }

  void _mostrarScoreboard(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          localizations.scoreboard,
          style: const TextStyle(color: Colors.cyan),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${localizations.lastScore}$_ultimaPontuacao',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              '${localizations.highScore}$_recorde',
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
            child: Text(
              localizations.close,
              style: const TextStyle(color: Colors.cyan),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _mostrarInterstitialAdAposAcao(() {});
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    _interstitialAd?.dispose();
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
  // Estado do jogo
  List<Point<int>> _cobra = [];
  Point<int> _comida = const Point(0, 0);
  Direcao _direcao = Direcao.direita;
  bool _jogando = false;
  int _pontos = 0;
  int _pontosNivel = 0;
  int _nivel = 0;
  int _vidas = 2;
  Timer? _timer;

  // Contador
  int _countdown = 3;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  // Estilos e Cores
  Color _borderColor = Colors.cyan.withOpacity(0.7);
  final List<Color> _levelColors = [
    Colors.cyan.withOpacity(0.7),
    Colors.amber.withOpacity(0.7),
    Colors.lightGreen.withOpacity(0.7),
    Colors.purpleAccent.withOpacity(0.7),
    Colors.orange.withOpacity(0.7),
    Colors.pink.withOpacity(0.7),
  ];
  Color _snakeBodyColor = Colors.cyan;
  Color _snakeHeadColor = Colors.cyanAccent;
  final List<Color> _snakeBodyColors = [
    Colors.cyan,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];
  final List<Color> _snakeHeadColors = [
    Colors.cyanAccent,
    Colors.lightGreenAccent,
    Colors.lightBlueAccent,
    Colors.yellowAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
  ];

  // Obstáculos
  List<Point<int>> _obstaculos = [];

  // Anúncios
  BannerAd? _topBannerAd;
  bool _isTopBannerAdLoaded = false;
  BannerAd? _bottomBannerAd;
  bool _isBottomBannerAdLoaded = false;
  bool _areBannersLoading = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _rewardedAdReady = false;
  bool _rewardGranted = false; // Flag para controlar a recompensa

  @override
  void initState() {
    super.initState();
    _iniciarJogo();
    _carregarInterstitialAd();
    _carregarRewardedAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_areBannersLoading) {
      _areBannersLoading = true;
      _carregarBannersAdaptativos();
    }
  }

  void _iniciarJogo() {
    final random = Random();
    final direcoes = Direcao.values;
    final direcaoAleatoria = direcoes[random.nextInt(direcoes.length)];

    setState(() {
      _pontos = 0;
      _pontosNivel = 0;
      _nivel = 0;
      _vidas = 2;
      _borderColor = _levelColors[0];
      _snakeBodyColor = _snakeBodyColors[0];
      _snakeHeadColor = _snakeHeadColors[0];
      _obstaculos.clear();

      _direcao = direcaoAleatoria;
      Point<int> cabeca = const Point(colunas ~/ 2, linhas ~/ 2);
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
      _jogando = false;
    });
    _timer?.cancel();
    _startCountdown();
  }

  void _loopJogo(Timer timer) {
    if (!_jogando || _isCountingDown) return;
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
        _cobra.contains(novaCabeca) ||
        _obstaculos.contains(novaCabeca)) {
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
    } while (_cobra.contains(_comida) || _obstaculos.contains(_comida));
  }

  void _subirNivel() {
    _nivel++;
    _pontosNivel = 0;
    setState(() {
      _borderColor = _levelColors[_nivel % _levelColors.length];
      _snakeBodyColor = _snakeBodyColors[_nivel % _snakeBodyColors.length];
      _snakeHeadColor = _snakeHeadColors[_nivel % _snakeHeadColors.length];
      _vidas = 2;
    });

    if (_nivel >= nivelInicioObstaculos) {
      _gerarObstaculos();
    }

    if (_cobra.length > 3)
      setState(() => _cobra = _cobra.sublist(_cobra.length - 3));
    _timer?.cancel();
    final novaVelocidade = 300 - (_nivel * 20);
    _timer = Timer.periodic(
      Duration(milliseconds: max(50, novaVelocidade)),
      _loopJogo,
    );
  }

  void _gerarObstaculos() {
    _obstaculos.clear();
    final random = Random();
    final int numeroDeObstaculos = _nivel - (nivelInicioObstaculos - 1);

    for (int i = 0; i < numeroDeObstaculos; i++) {
      final int largura = random.nextInt(3) + 1;
      final int altura = random.nextInt(3) + 1;

      bool obstaculoValido;
      Point<int> inicioObstaculo;
      List<Point<int>> novoObstaculo = [];

      int tentativas = 0;
      do {
        obstaculoValido = true;
        novoObstaculo.clear();
        inicioObstaculo = Point(
          random.nextInt(colunas - largura),
          random.nextInt(linhas - altura),
        );

        for (int y = 0; y < altura; y++) {
          for (int x = 0; x < largura; x++) {
            final ponto = Point(inicioObstaculo.x + x, inicioObstaculo.y + y);
            if (_cobra.contains(ponto)) {
              obstaculoValido = false;
              break;
            }
            novoObstaculo.add(ponto);
          }
          if (!obstaculoValido) break;
        }
        tentativas++;
      } while (!obstaculoValido && tentativas < 20);

      if (obstaculoValido) {
        _obstaculos.addAll(novoObstaculo);
      }
    }
  }

  void _resetSnakePosition() {
    final random = Random();

    Point<int> cabeca;
    Direcao direcaoAleatoria;
    bool localSeguro;
    int tentativas = 0;
    List<Point<int>> corpoTemporario = [];

    do {
      localSeguro = true;
      direcaoAleatoria = Direcao.values[random.nextInt(Direcao.values.length)];
      cabeca = Point(
        random.nextInt(colunas - 4) + 2,
        random.nextInt(linhas - 4) + 2,
      );

      switch (direcaoAleatoria) {
        case Direcao.direita:
          corpoTemporario = [
            Point(cabeca.x - 2, cabeca.y),
            Point(cabeca.x - 1, cabeca.y),
            cabeca,
          ];
          break;
        case Direcao.esquerda:
          corpoTemporario = [
            Point(cabeca.x + 2, cabeca.y),
            Point(cabeca.x + 1, cabeca.y),
            cabeca,
          ];
          break;
        case Direcao.baixo:
          corpoTemporario = [
            Point(cabeca.x, cabeca.y - 2),
            Point(cabeca.x, cabeca.y - 1),
            cabeca,
          ];
          break;
        case Direcao.cima:
          corpoTemporario = [
            Point(cabeca.x, cabeca.y + 2),
            Point(cabeca.x, cabeca.y + 1),
            cabeca,
          ];
          break;
      }

      if (corpoTemporario.any((ponto) => _obstaculos.contains(ponto))) {
        localSeguro = false;
      }

      tentativas++;
    } while (!localSeguro && tentativas < 50);

    if (localSeguro) {
      _cobra = corpoTemporario;
      _direcao = direcaoAleatoria;
    } else {
      _obstaculos.clear();
      _direcao = Direcao.values[random.nextInt(Direcao.values.length)];
      cabeca = const Point(colunas ~/ 2, linhas ~/ 2);
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
  }

  void _perderVida() {
    setState(() {
      _vidas--;
      if (_vidas <= 0) {
        _gameOver();
      } else {
        _timer?.cancel();
        _resetSnakePosition();
        _startCountdown();
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

  Future<void> _carregarBannersAdaptativos() async {
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getAnchoredAdaptiveBannerAdSize(
          Orientation.portrait,
          MediaQuery.of(context).size.width.truncate(),
        );

    if (size == null) {
      return;
    }

    _topBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isTopBannerAdLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();

    _bottomBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isBottomBannerAdLoaded = true),
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

  void _mostrarInterstitialAdAposAcao(VoidCallback acaoAposAnuncio) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _carregarInterstitialAd();
          acaoAposAnuncio();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _carregarInterstitialAd();
          acaoAposAnuncio();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      acaoAposAnuncio();
    }
  }

  void _mostrarRewardedAd() {
    if (_rewardedAd != null) {
      _rewardGranted = false;
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          if (_rewardGranted) {
            _resetSnakePosition();
            _startCountdown();
          }
          ad.dispose();
          _carregarRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          setState(() {
            _vidas = 1;
          });
          _rewardGranted = true;
        },
      );
      _rewardedAd = null;
    }
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _jogando = false;
      _countdown = 3;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
          _jogando = true;
        });
        _startGameLoop();
      }
    });
  }

  void _startGameLoop() {
    _timer?.cancel();
    final novaVelocidade = 300 - (_nivel * 20);
    _timer = Timer.periodic(
      Duration(milliseconds: max(50, novaVelocidade)),
      _loopJogo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          _isTopBannerAdLoaded ? _topBannerAd!.size.height.toDouble() : 0,
        ),
        child: SafeArea(
          bottom: false,
          child: _isTopBannerAdLoaded
              ? SizedBox(
                  height: _topBannerAd!.size.height.toDouble(),
                  width: _topBannerAd!.size.width.toDouble(),
                  child: AdWidget(ad: _topBannerAd!),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: Column(
        children: [
          AppBar(
            title: Text(
              '${localizations.points}$_pontos | ${localizations.level}$_nivel | ${localizations.lives}$_vidas',
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (_direcao != Direcao.cima && details.delta.dy > 0)
                  _direcao = Direcao.baixo;
                else if (_direcao != Direcao.baixo && details.delta.dy < 0)
                  _direcao = Direcao.cima;
              },
              onHorizontalDragUpdate: (details) {
                if (_direcao != Direcao.esquerda && details.delta.dx > 0)
                  _direcao = Direcao.direita;
                else if (_direcao != Direcao.direita && details.delta.dx < 0)
                  _direcao = Direcao.esquerda;
              },
              child: Center(
                child: Container(
                  width: colunas * tamanhoCelula,
                  height: linhas * tamanhoCelula,
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor, width: 2.0),
                    color: const Color(0xFF161B22),
                  ),
                  child: Stack(
                    children: [
                      ..._obstaculos.map(
                        (p) => Positioned(
                          left: p.x * tamanhoCelula,
                          top: p.y * tamanhoCelula,
                          child: Container(
                            width: tamanhoCelula,
                            height: tamanhoCelula,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 88, 93, 99),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      ..._cobra.map((p) {
                        final bool isHead = p == _cobra.last;
                        return Positioned(
                          left: p.x * tamanhoCelula,
                          top: p.y * tamanhoCelula,
                          child: Container(
                            width: tamanhoCelula,
                            height: tamanhoCelula,
                            decoration: BoxDecoration(
                              color: isHead ? _snakeHeadColor : _snakeBodyColor,
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
                      if (_isCountingDown)
                        Center(
                          child: Text(
                            '$_countdown',
                            style: const TextStyle(
                              fontSize: 80,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 10, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _isBottomBannerAdLoaded
            ? SizedBox(
                height: _bottomBannerAd!.size.height.toDouble(),
                width: _bottomBannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bottomBannerAd!),
              )
            : const SizedBox(height: 50),
      ),
    );
  }

  void _mostrarDialogoGameOver() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          localizations.gameOver,
          style: const TextStyle(color: Colors.cyan),
        ),
        content: Text(
          '${localizations.yourFinalScore}$_pontos',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_rewardedAdReady)
            TextButton.icon(
              icon: const Icon(Icons.videocam, color: Colors.amber),
              label: Text(
                localizations.getExtraLife,
                style: const TextStyle(color: Colors.amber),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _mostrarRewardedAd();
              },
            ),
          TextButton(
            child: Text(
              localizations.viewScoreboard,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _mostrarScoreboard();
            },
          ),
          TextButton(
            child: Text(
              localizations.playAgain,
              style: const TextStyle(color: Colors.cyan),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _iniciarJogo();
            },
          ),
          TextButton(
            child: Text(
              localizations.exitToMenu,
              style: const TextStyle(color: Colors.cyan),
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
    final localizations = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final recorde = prefs.getInt('recorde') ?? 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          localizations.scoreboard,
          style: const TextStyle(color: Colors.cyan),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${localizations.lastScore}$_pontos',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              '${localizations.highScore}$recorde',
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
            child: Text(
              localizations.close,
              style: const TextStyle(color: Colors.cyan),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Fecha o placar
              _mostrarInterstitialAdAposAcao(() {
                // Se o jogo não estiver ativo, significa que viemos do menu de game over.
                if (!_jogando) {
                  _mostrarDialogoGameOver();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
