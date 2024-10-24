import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:newz/auth.dart';
import 'package:newz/pages/favorite_topics_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VerticalSwipe extends StatelessWidget {
  const VerticalSwipe({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewZ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isDarkMode = false;
  List<dynamic> articles = [];
  Set<String> seenArticles = {};
  bool isLoading = false;
  int page = 1;
  List<String> favoriteTopics = [];
  List<String> previousFavorites = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkFavoriteChanges(); // Sayfa her göründüğünde kontrol et
  }

  Future<void> _checkFavoriteChanges() async {
    List<String> newFavorites = await _getFavoriteTopics();
    if (newFavorites.toString() != previousFavorites.toString()) {
      setState(() {
        favoriteTopics = newFavorites;
        previousFavorites = List.from(newFavorites); // Önceki favorileri güncelle
        articles.clear();
        page = 1;
        seenArticles.clear();
      });
      fetchNews(); // Favori konular değiştiği için haberleri yeniden çek
    }
  }
Future<List<String>> _getFavoriteTopics() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        return List<String>.from(data['favoriteTopics'] ?? []);
      }
    }
    return [];
  }

  Future<void> _loadFavorites() async {
    List<String> loadedFavorites = await _getFavoriteTopics();
    setState(() {
      favoriteTopics = loadedFavorites;
      previousFavorites = List.from(loadedFavorites);
    });
    fetchNews(); // İlk favori konulara göre haberleri yükle
  }

  Future<void> _navigateToFavoriteTopicsScreen() async {
    final updatedFavorites = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoriteTopicsScreen(),
      ),
    );

    if (updatedFavorites != null && updatedFavorites is List<String>) {
      setState(() {
        favoriteTopics = updatedFavorites;
        previousFavorites = List.from(updatedFavorites);
        articles.clear();
        page = 1;
        seenArticles.clear();
      });
      fetchNews();
    }
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Widget _signOutButton() {
    return ElevatedButton(
      onPressed: signOut,
      child: const Text('Sign Out'),
    );
  }

  Future<void> fetchNews() async {
  if (isLoading) return;

  setState(() {
    isLoading = true;
  });

  String apiKey = '56491c31b2d1407f83cc723cdfe6e4f7';
  String url;

  if (favoriteTopics.isNotEmpty) {
    // Favori konular seçilmişse, konulara göre haberleri çek
    String favoriteTopicsQuery = favoriteTopics.join(' OR '); // Favori konuları birleştir
    DateTime today = DateTime.now();
    DateTime oneWeekAgo = today.subtract(Duration(days: 7));
    String formattedToday = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    String formattedOneWeekAgo = "${oneWeekAgo.year}-${oneWeekAgo.month.toString().padLeft(2, '0')}-${oneWeekAgo.day.toString().padLeft(2, '0')}";

    url =
        'https://newsapi.org/v2/everything?q=$favoriteTopicsQuery&from=$formattedOneWeekAgo&to=$formattedToday&sortBy=publishedAt&page=$page&pageSize=10&language=en&apiKey=$apiKey';
  } else {
    // Favori konu seçilmemişse, karışık genel haberleri çek
    url =
        'https://newsapi.org/v2/top-headlines?country=us&page=$page&pageSize=10&apiKey=$apiKey';
  }

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      List<dynamic> newArticles = data['articles'];

      setState(() {
        for (var article in newArticles) {
          if (article['url'] != null && !seenArticles.contains(article['url'])) {
            // Eğer bu haber daha önce eklenmemişse, ekliyoruz
            articles.add(article);
            seenArticles.add(article['url']); // URL'yi kaydediyoruz
          }
        }
        page++;
      });
    } else {
      throw Exception('Failed to load news');
    }
  } catch (e) {
    print('Error fetching news: $e');
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haber Akışı'),
        actions: [
          _signOutButton(),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Implement user profile
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('Ayarlar'),
            ),
            ListTile(
              title: const Text('Aydınlık / Karanlık Mod'),
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) {
                  setState(() {
                    isDarkMode = value;
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('İlgi Alanları'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FavoriteTopicsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Dil Tercihi'),
              onTap: () {
                // TODO: Implement language selection
              },
            ),
          ],
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
              !isLoading) {
            fetchNews();
            return true;
          }
          return false;
        },
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: articles.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == articles.length) {
              return const Center(child: CircularProgressIndicator());
            }

            final article = articles[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewsDetailScreen(article: article),
                  ),
                );
              },
              child: NewsCard(
                title: article['title'] ?? 'Başlık Yok',
                summary: article['description'] ?? 'Açıklama Yok',
                imageUrl: article['urlToImage'] ?? '', // Add image URL
                onShare: () {
                  // TODO: Implement share functionality
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement AI-powered news summary
        },
        child: const Icon(Icons.mic),
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final String title;
  final String summary;
  final String imageUrl;
  final VoidCallback onShare;

  const NewsCard({
    Key? key,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImage(), // Görsel için özel yöntem
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.contains('Removed') ? 'This news may have been removed.' : title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: onShare,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Görsel için özel yapı
  Widget _buildImage() {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return _buildPlaceholder(); // URL geçerli değilse
    }

    // .webp uzantılı görsel kontrolü
    if (imageUrl.endsWith('.webp')) {
      return _buildPlaceholder(message: 'Image format not supported');
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      height: 200,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(message: 'Failed to load image'); // Yüklenemezse
      },
    );
  }

  // Görsel yerine geçecek yapıyı oluşturma
  Widget _buildPlaceholder({String message = 'No Image'}) {
    return Container(
      height: 200,
      color: Colors.grey,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}


class NewsDetailScreen extends StatefulWidget {
  final dynamic article;

  const NewsDetailScreen({Key? key, required this.article}) : super(key: key);

  @override
  _NewsDetailScreenState createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // JS modu ayarla
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _isLoading = false; // Sayfa yüklendiğinde durum değişir
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.article['url'])); // Haber URL'sini yükle
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article['source']['name'] ?? 'News Source'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(), // Yükleme göstergesi
            ),
        ],
      ),
    );
  }
}
