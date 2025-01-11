import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:newz/auth.dart';
import 'package:newz/pages/favorite_topics_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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
  Set<String> seenArticles = {};
  bool isLoading = false;
  int page = 1;
  List<String> favoriteTopics = [];
  List<String> previousFavorites = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late GenerativeModel generativeModel;

  @override
  void initState() {
    super.initState();
    generativeModel = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: 'AIzaSyAQAdcRtoDGiXTHEtp-tR-ZfvgAEPUWjxE',
    );
    _loadFavorites();
  }

  Future<String> summarizeArticle(String content) async {
    try {
      final prompt = 'Summarize the following news article:\n$content';
      final response = await generativeModel.generateContent([Content.text(prompt)]);
      return response.text ?? 'No summary available.';
    } catch (e) {
      print('Error summarizing article: $e');
      return 'Failed to generate summary.';
    }
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
    DateTime today = DateTime.now();
    DateTime oneWeekAgo = today.subtract(const Duration(days: 7));
    String formattedToday = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    String formattedOneWeekAgo = "${oneWeekAgo.year}-${oneWeekAgo.month.toString().padLeft(2, '0')}-${oneWeekAgo.day.toString().padLeft(2, '0')}";

    Map<String, String> categoryQueries = {
      'Entertainment': 'singer OR cinema OR movie OR famous OR character OR comedy OR book',
      'Sports': 'football OR basketball OR tennis OR sports OR soccer OR cricket OR rugby',
      'Technology': 'technology OR gadgets OR software OR hardware OR AI OR robotics OR innovation',
      'Health': 'health OR fitness OR wellness OR medicine OR healthcare OR disease OR mental',
      'Business': 'business OR finance OR economy OR stock OR market OR investment OR startup',
      'General': 'news OR updates OR general OR popular OR trending',
      'Science': 'science OR research OR discovery OR physics OR chemistry OR biology OR space',
    };

    List<List<dynamic>> allNews = [];

    for (String topic in favoriteTopics) {
      String query = categoryQueries[topic] ?? '';
      if (query.isNotEmpty) {
        String url = 'https://newsapi.org/v2/everything?q=$query&sources=bbc-news,daily-mail,national-geographic,mashable,the-wall-street-journal,forbes,the-economist,bbc-sport,fox-sports,cnn,nbc-news,france24,sky-news,the-new-york-times,the-washington-post,al-jazeera-english,the-guardian&from=$formattedOneWeekAgo&to=$formattedToday&sortBy=relevancy&page=$page&pageSize=5&language=en&apiKey=$apiKey';

        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            Map<String, dynamic> data = json.decode(response.body);
            List<dynamic> newArticles = data['articles'];
            allNews.add(newArticles);
          } else {
            throw Exception('Failed to load news for $topic');
          }
        } catch (e) {
          print('Error fetching news for $topic: $e');
        }
      }
    }

    List<dynamic> mergedNews = [];
    int maxLength = allNews.map((list) => list.length).fold(0, (prev, curr) => curr > prev ? curr : prev);

    for (int i = 0; i < maxLength; i++) {
      for (var categoryNews in allNews) {
        if (i < categoryNews.length) {
          if (!seenArticles.contains(categoryNews[i]['url'])) {
            mergedNews.add(categoryNews[i]);
            seenArticles.add(categoryNews[i]['url']);
          }
        }
      }
    }

    setState(() {
      articles.addAll(mergedNews);
      page++;
      isLoading = false;
    });
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
      body: PageView.builder(
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
              onSummarize: () async {
                final content = article['content'] ?? article['description'] ?? '';
                if (content.isEmpty) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Summary'),
                        content: const Text('No content available to summarize.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                final summary = await summarizeArticle(content);

                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Summary'),
                      content: Text('$summary\n\n- generated by Gemini'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
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
  final VoidCallback onSummarize;

  const NewsCard({
    Key? key,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.source,
    required this.onShare,
    required this.onSummarize,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: onShare,
                    ),
                    IconButton(
                      icon: const Icon(Icons.summarize),
                      onPressed: onSummarize,
                    ),
                  ],
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
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.article['url']));
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
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}