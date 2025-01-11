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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    generativeModel = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: 'AIzaSyAQAdcRtoDGiXTHEtp-tR-ZfvgAEPUWjxE',
    );
    _loadFavorites();
  }

  static const List<Widget> _widgetOptions = <Widget>[
    Center(child: Text('Home')),
    FavoriteTopicsScreen(),
    Center(child: Text('Profile')),
  ];

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FavoriteTopicsScreen(),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<String> summarizeArticle(String content) async {
    try {
      final prompt = 'Summarize the following news article:\n$content';
      final response =
          await generativeModel.generateContent([Content.text(prompt)]);
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
    String formattedToday =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    String formattedOneWeekAgo =
        "${oneWeekAgo.year}-${oneWeekAgo.month.toString().padLeft(2, '0')}-${oneWeekAgo.day.toString().padLeft(2, '0')}";

    Map<String, String> categoryQueries = {
      'Entertainment':
          'singer OR cinema OR movie OR famous OR character OR comedy OR book',
      'Sports':
          'football OR basketball OR tennis OR sports OR soccer OR cricket OR rugby',
      'Technology':
          'technology OR gadgets OR software OR hardware OR AI OR robotics OR innovation',
      'Health':
          'health OR fitness OR wellness OR medicine OR healthcare OR disease OR mental',
      'Business':
          'business OR finance OR economy OR stock OR market OR investment OR startup',
      'General': 'news OR updates OR general OR popular OR trending',
      'Science':
          'science OR research OR discovery OR physics OR chemistry OR biology OR space',
    };

    List<List<dynamic>> allNews = [];

    for (String topic in favoriteTopics) {
      String query = categoryQueries[topic] ?? '';
      if (query.isNotEmpty) {
        String url =
            'https://newsapi.org/v2/everything?q=$query&sources=bbc-news,daily-mail,national-geographic,mashable,the-wall-street-journal,forbes,the-economist,bbc-sport,fox-sports,cnn,nbc-news,france24,sky-news,the-new-york-times,the-washington-post,al-jazeera-english,the-guardian&from=$formattedOneWeekAgo&to=$formattedToday&sortBy=relevancy&page=$page&pageSize=5&language=en&apiKey=$apiKey';

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
    int maxLength = allNews
        .map((list) => list.length)
        .fold(0, (prev, curr) => curr > prev ? curr : prev);

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

  String formatDate(String date) {
    return date.split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.black,
              ),
            ),
            Text(
              'Z',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.red,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
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
                author: article['author'] ?? article['source'],
                publishedDate: formatDate(article['publishedAt']) ?? 'Unknown',
                onShare: () {
                  Clipboard.setData(ClipboardData(text: article['url']))
                      .then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  });
                },
                onSummarize: () async {
                  final content =
                      article['content'] ?? article['description'] ?? '';
                  if (content.isEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content:
                              const Text('No content available to summarize.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.white,
                        title: const Text(
                          'Summary',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        content: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                summary,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '- Generated by Gemini',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        actionsPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.favorite_outline),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.favorite),
              ),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person_outline),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person),
              ),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
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
  final String author;
  final String publishedDate;
  final VoidCallback onShare;
  final VoidCallback onSummarize;

  const NewsCard({
    Key? key,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.source,
    required this.author,
    required this.publishedDate,
    required this.onShare,
    required this.onSummarize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 3,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      height: 220,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 220,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image,
                            size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    "Published on: $publishedDate",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Author: $author",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Source: $source",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onShare,
                          child: const Text(
                            'Copy Link',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onSummarize,
                          child: const Text(
                            'Summarize',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red, Colors.redAccent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: Text(
          'Article Detail',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 3,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
