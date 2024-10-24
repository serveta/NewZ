import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:newz/auth.dart';
import 'package:newz/pages/favorite_topics_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool isDarkMode = false;
  List<dynamic> articles = [];
  bool isLoading = false;
  int page = 1;
  List<String> favoriteTopics = []; // Favori konular burada tutulacak
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadFavorites(); // Favori konuları yükle
  }

  Future<void> _loadFavorites() async {
    User? user = _auth.currentUser;

    if (user != null) {
      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          favoriteTopics = List<String>.from(data['favoriteTopics'] ?? []);
        });
        fetchNews(); // Haberleri favori konulara göre çek
      }
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
    if (isLoading || favoriteTopics.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    String apiKey = '56491c31b2d1407f83cc723cdfe6e4f7';
    String favoriteTopicsQuery = favoriteTopics.join(' OR '); // Favori konuları birleştir
    String url =
        'https://newsapi.org/v2/everything?q=$favoriteTopicsQuery&page=$page&pageSize=10&language=tr&apiKey=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List<dynamic> newArticles = data['articles'];

        setState(() {
          articles.addAll(newArticles);
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
                    builder: (context) => const FavoriteTopicsScreen(),
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
    super.key,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                )
              : Container(
                  height: 200,
                  color: Colors.grey,
                  child: const Center(child: Text('Resim Yok')),
                ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
}

class NewsDetailScreen extends StatelessWidget {
  final dynamic article;

  const NewsDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haber Detayı'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // İçerik uzun olursa kaydırılabilir yapıyoruz
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              article['urlToImage'] != null
                  ? Image.network(article['urlToImage'])
                  : const SizedBox.shrink(),
              const SizedBox(height: 16),
              Text(
                article['title'] ?? 'Başlık Yok',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Yayınlanma Tarihi: ${article['publishedAt'] != null ? DateTime.parse(article['publishedAt']).toLocal().toString() : 'Tarih Yok'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Yazar: ${article['author'] ?? 'Bilinmiyor'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Kaynak: ${article['source']['name'] ?? 'Kaynak Yok'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                article['content'] ?? 'İçerik mevcut değil.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

