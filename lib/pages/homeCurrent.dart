import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:newz/auth.dart';
import 'package:newz/pages/favorite_topics_screen.dart';

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

        Future<void> signOut() async {
    await Auth().signOut();
  }

    Widget _signOutButton(){
    return ElevatedButton(onPressed: signOut, child: const Text('Sign Out'),);
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
                    // TODO: Implement theme change
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
        builder: (context) => FavoriteTopicsScreen(), // Navigate to FavoriteTopicsScreen
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
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          return NewsCard(
            title: 'Haber Başlığı $index',
            summary: 'Bu haber özeti $index numaralı habere aittir.',
            onShare: () {
              // TODO: Implement share functionality
            },
          );
        },
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
  final VoidCallback onShare;

  const NewsCard({
    Key? key,
    required this.title,
    required this.summary,
    required this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
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
    );
  }
}
