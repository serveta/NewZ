import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:newz/auth.dart';
import 'package:newz/pages/favorite_topics_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<dynamic> articles = [];
  bool isLoading = false;
  int page = 1;
  List<String> favoriteTopics = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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
        fetchNews();
      }
    }
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Future<void> fetchNews() async {
    if (isLoading || favoriteTopics.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    String apiKey = '56491c31b2d1407f83cc723cdfe6e4f7';
    String favoriteTopicsQuery = favoriteTopics.join(' OR ');
    String url =
        'https://newsapi.org/v2/everything?q=$favoriteTopicsQuery&page=$page&pageSize=10&language=en&apiKey=$apiKey';

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
                    builder: (context) => FavoriteTopicsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // TODO: Implement settings
              },
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
                title: article['title'] ?? 'No title',
                summary: article['description'] ?? 'No description',
                imageUrl: article['urlToImage'] ?? '',
                onShare: () {
                  // TODO: Implement share functionality
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
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              height: 200,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey,
                  child: const Center(child: Text('Failed to load image')),
                );
              },
            )
          else
            Container(
              height: 200,
              color: Colors.grey,
              child: const Center(child: Text('No image')),
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

  const NewsDetailScreen({Key? key, required this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article['urlToImage'] != null)
                Image.network(
                  article['urlToImage'],
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              const SizedBox(height: 16),
              Text(
                article['title'] ?? 'No Title',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Published: ${article['publishedAt'] != null ? DateTime.parse(article['publishedAt']).toLocal().toString() : 'No Date'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Author: ${article['author'] ?? 'Unknown'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Source: ${article['source']['name'] ?? 'No Source'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                article['content'] ?? 'No content available.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
