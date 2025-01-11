import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:newz/pages/homeCurrent.dart'; // Ana sayfa (haber akışı) import edildi

class FavoriteTopicsScreen extends StatefulWidget {
  const FavoriteTopicsScreen({super.key});

  @override
  _FavoriteTopicsScreenState createState() => _FavoriteTopicsScreenState();
}

class _FavoriteTopicsScreenState extends State<FavoriteTopicsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> topics = [
    'Politics',
    'Technology',
    'Business',
    'Sports',
    'Entertainment',
    'Science',
    'Health',
    'World News',
    'Local News',
    'Education',
    'Environment',
    'Crime',
    'Lifestyle',
    'Travel',
    'Food',
    'Art and Culture',
    'Real Estate',
    'Automotive',
    'Fashion',
    'Startups',
    'Finance',
    'Gaming',
    'Space Exploration',
    'Opinion',
    'Celebrity News',
    'Weather',
    'History',
    'Social Issues',
    'Religion',
    'Events and Festivals',
    'Photography',
    'Music',
    'Books',
    'Movies',
    'TV Shows',
    'Economics',
    'Renewable Energy',
    'Artificial Intelligence',
    'Parenting',
    'Fitness and Wellness'
  ];
  List<String> favoriteTopics = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // Firestore'dan favori konuları yükleme
  void _loadFavorites() async {
    User? user = _auth.currentUser;

    if (user != null) {
      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          favoriteTopics = List<String>.from(data['favoriteTopics'] ?? []);
        });
      }
    }
  }

  // Firestore'a favori konuları kaydetme
  void _saveFavorites(List<String> selectedTopics) async {
    User? user = _auth.currentUser;

    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'favoriteTopics': selectedTopics,
      }, SetOptions(merge: true));
    }
  }

  void _syncAndNavigate() {
    _saveFavorites(favoriteTopics);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Favorite Topics')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: topics.length,
              itemBuilder: (context, index) {
                return CheckboxListTile(
                  title: Text(topics[index]),
                  value: favoriteTopics.contains(topics[index]),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        favoriteTopics.add(topics[index]);
                      } else {
                        favoriteTopics.remove(topics[index]);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _syncAndNavigate,
              child: const Text('Sync and Go to News Feed'),
            ),
          ),
        ],
      ),
    );
  }
}
