import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:newz/auth.dart';
import 'package:newz/pages/favorite_topics_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:newz/pages/home_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:newz/pages/profile_screen.dart';

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
  final List<String>? selectedTopics;
  const MainScreen({Key? key, this.selectedTopics}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool isLoading = false;
  List<dynamic> articles = [];
  List<String> favoriteTopics = [];
  Set<String> seenArticles = {};
  int page = 1;
  late GenerativeModel generativeModel;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Initialize generative model
    generativeModel = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: 'AIzaSyAQAdcRtoDGiXTHEtp-tR-ZfvgAEPUWjxE',
    );

    if (widget.selectedTopics != null && widget.selectedTopics!.isNotEmpty) {
      favoriteTopics = widget.selectedTopics!;
      fetchNews();
    } else {
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    print("Loading user favorites from Firestore...");
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          List<dynamic> favorites = userDoc['favoriteTopics'] ?? [];
          setState(() {
            favoriteTopics = favorites.cast<String>();
          });
          print("Favorite topics loaded: $favoriteTopics");
        } else {
          print("No favorite topics found for user. Fetching defaults...");
        }
      }
    } catch (e) {
      print("Error loading favorites: $e");
    }

    // Always fetch news once favorites are loaded or if empty
    await fetchNews();
  }

  Future<void> fetchNews() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });

    print("Fetching news... Favorites: $favoriteTopics");
    String apiKey =
        '658a350d8d594b5184c29f70e4633191'; // Replace with valid NewsAPI.org key
    DateTime today = DateTime.now();
    DateTime oneWeekAgo = today.subtract(const Duration(days: 7));
    String formattedToday =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    String formattedOneWeekAgo =
        "${oneWeekAgo.year}-${oneWeekAgo.month.toString().padLeft(2, '0')}-${oneWeekAgo.day.toString().padLeft(2, '0')}";

    Map<String, String> categoryQueries = {
      'Politics': 'politics OR government OR election OR policy',
      'Technology': 'technology OR software OR innovation OR digital',
      'Business': 'business OR economy OR market OR corporate',
      'Sports': 'sports OR football OR basketball OR olympics',
      'Entertainment': 'entertainment OR movie OR music OR celebrity',
      'Science': 'science OR research OR discovery OR breakthrough',
      'Health': 'health OR medical OR wellness OR healthcare',
      'World News': 'international OR global OR world OR foreign',
      'Local News': 'local OR community OR city OR municipal',
      'Education': 'education OR school OR university OR learning',
      'Environment': 'environment OR climate OR sustainability',
      'Crime': 'crime OR police OR law OR justice',
      'Lifestyle': 'lifestyle OR living OR wellness OR fashion',
      'Travel': 'travel OR tourism OR vacation OR destination',
      'Food': 'food OR cuisine OR restaurant OR cooking',
      'Art and Culture': 'art OR culture OR museum OR exhibition',
      'Real Estate': 'real estate OR property OR housing OR construction',
      'Automotive': 'automotive OR cars OR vehicles OR transportation',
      'Fashion': 'fashion OR style OR clothing OR design',
      'Startups': 'startup OR entrepreneur OR venture OR innovation',
      'Finance': 'finance OR banking OR investment OR stocks',
      'Gaming': 'gaming OR video games OR esports OR console',
      'Space Exploration': 'space OR nasa OR astronomy OR mars',
      'Opinion': 'opinion OR editorial OR analysis OR commentary',
      'Celebrity News': 'celebrity OR entertainment OR hollywood OR stars',
      'Weather': 'weather OR forecast OR climate OR meteorology',
      'History': 'history OR historical OR heritage OR civilization',
      'Social Issues': 'social OR society OR equality OR rights',
      'Religion': 'religion OR faith OR spiritual OR worship',
      'Events and Festivals': 'events OR festivals OR celebration OR cultural'
    };

    List<List<dynamic>> allNews = [];

    // Fetch for each favorite topic
    for (String topic in favoriteTopics) {
      String query = categoryQueries[topic] ?? '';
      if (query.isNotEmpty) {
        String url =
            'https://newsapi.org/v2/everything?q=$query&from=$formattedOneWeekAgo&to=$formattedToday&sortBy=relevancy&page=$page&pageSize=5&language=en&apiKey=$apiKey';
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            Map<String, dynamic> data = json.decode(response.body);
            List<dynamic> newArticles = data['articles'];
            print("Topic $topic -> ${newArticles.length} articles fetched.");
            allNews.add(newArticles);
          } else {
            print("Failed to load news for $topic -> ${response.statusCode}");
          }
        } catch (e) {
          print("Error fetching news for $topic: $e");
        }
      }
    }

    // Fallback if no favorites or empty
    if (favoriteTopics.isEmpty) {
      print("No favorites set. Fetching top headlines...");
      String topUrl =
          'https://newsapi.org/v2/top-headlines?country=us&apiKey=$apiKey';
      final response = await http.get(Uri.parse(topUrl));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        articles = data['articles'];
      } else {
        print("Failed to fetch top headlines: ${response.statusCode}");
      }
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Merge articles and deduplicate
    List<dynamic> mergedNews = [];
    int maxLength =
        allNews.map((list) => list.length).fold(0, (a, b) => b > a ? b : a);

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
      print("Total articles loaded: ${articles.length}");
    });
  }

  String formatDate(String date) {
    return date.split('T').first;
  }

  // Builds the vertical PageView of articles
  Widget _buildHomeContent() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
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
              source: article['source']['name'] ?? 'Unknown Source',
              author: article['author'] ?? 'Unknown Author',
              publishedDate: formatDate(article['publishedAt'] ?? ''),
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
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        content:
                            const Text('No content available to summarize.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
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
                            color: Colors.red),
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
                                  height: 1.5),
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
                                    color: Colors.grey),
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
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

  static final List<Widget> _widgetOptions = <Widget>[
    HomeContent(), // Calls _buildHomeContent
    const FavoriteTopicsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<String> summarizeArticle(String content) async {
    print("Summarizing article...");
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
  Widget build(BuildContext context) {
    print("Building MainScreen with selectedIndex=$_selectedIndex");
    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(color: Colors.white),
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
      body: _widgetOptions.elementAt(_selectedIndex),
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
          backgroundColor: Colors.white,
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
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
                child: Icon(Icons.favorite),
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

class HomeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Access the MainScreen state to call _buildHomeContent
    final mainState = context.findAncestorStateOfType<_MainScreenState>();
    return mainState?._buildHomeContent() ??
        const Center(child: Text('Loading...'));
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image,
                        size: 80, color: Colors.grey),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Published on: $publishedDate",
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54)),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.4)),
                  const SizedBox(height: 12),
                  Text("Author: $author",
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54)),
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  Text("Source: $source",
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onShare,
                          child: const Text(
                            'Copy Link',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onSummarize,
                          child: const Text(
                            'Summarize',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
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
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.article['url'] ?? 'https://example.com'));
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
        title: const Text(
          'Article Detail',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
