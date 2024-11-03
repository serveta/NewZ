import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Clipboard sınıfı için
import 'package:newz/auth.dart';
import 'package:newz/pages/favorite_topics_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VerticalSwipe extends StatelessWidget {
  const VerticalSwipe({super.key});

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
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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
    _checkFavoriteChanges(); 
  }

  Future<void> _checkFavoriteChanges() async {
    List<String> newFavorites = await _getFavoriteTopics();
    if (newFavorites.toString() != previousFavorites.toString()) {
      setState(() {
        favoriteTopics = newFavorites;
        previousFavorites = List.from(newFavorites);
        articles.clear();
        page = 1;
        seenArticles.clear();
      });
      fetchNews();
    }
  }

  Future<List<String>> _getFavoriteTopics() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(user.uid).get();
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
    fetchNews();
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

  Future<void> fetchNews() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    String apiKey = '56491c31b2d1407f83cc723cdfe6e4f7';
    String url;

    if (favoriteTopics.isNotEmpty) {
      String favoriteTopicsQuery = favoriteTopics.join(' OR ');
      DateTime today = DateTime.now();
      DateTime oneWeekAgo = today.subtract(Duration(days: 7));
      String formattedToday = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      String formattedOneWeekAgo = "${oneWeekAgo.year}-${oneWeekAgo.month.toString().padLeft(2, '0')}-${oneWeekAgo.day.toString().padLeft(2, '0')}";

      url = 'https://newsapi.org/v2/everything?q=$favoriteTopicsQuery&sources=bbc-news,daily-mail,national-geographic,mashable,the-wall-street-journal,forbes,the-economist,bbc-sport,fox-sports,cnn,nbc-news,france24,sky-news,abc-news,the-new-york-times,the-washington-post,al-jazeera-english,the-guardian&from=$formattedOneWeekAgo&to=$formattedToday&sortBy=publishedAt&page=$page&pageSize=10&language=en&apiKey=$apiKey';
    } else {
      url = 'https://newsapi.org/v2/top-headlines?country=us&page=$page&pageSize=10&apiKey=$apiKey';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List<dynamic> newArticles = data['articles'];

        setState(() {
          for (var article in newArticles) {
            if (article['url'] != null && !seenArticles.contains(article['url'])) {
              articles.add(article);
              seenArticles.add(article['url']);
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
        title: const Text('NewZ'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.red,
              ),
              child: Text('NewZ'),
            ),
            ListTile(
              leading: const Icon(Icons.topic),
              title: const Text('News Topics'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoriteTopicsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: signOut,
            ),
          ],
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent && !isLoading) {
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
                title: article['title'] ?? 'No title',
                summary: article['description'] ?? 'No description',
                imageUrl: article['urlToImage'] ?? '',
                source: article['source']['name'] ?? 'Unknown Source',
                onShare: () {
                  Clipboard.setData(ClipboardData(text: article['url'])).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  });
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final String title;
  final String summary;
  final String imageUrl;
  final String source;
  final VoidCallback onShare;

  const NewsCard({
    super.key,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.source,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              height: 200,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(summary, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Text("Source: $source", style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 158, 96, 3))),
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
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // JavaScript modu
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
