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
    'Sports',
    'Technology',
    'Health',
    'Business',
    'Entertainment',
    'General',
    'Science'
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
          if (favoriteTopics.isEmpty) {
            favoriteTopics.add('General');
          }
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: const Text(
            'Favorite Topics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.black,
              shadows: [
                Shadow(
                  color: Colors.grey,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
        centerTitle: false,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select your favorite topics to get personalized news',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: topics.length,
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final isSelected = favoriteTopics.contains(topic);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          favoriteTopics.remove(topic);
                        } else {
                          favoriteTopics.add(topic);
                        }
                      });
                    },
                    child: Card(
                      color: isSelected ? Colors.red : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 4,
                      child: Center(
                        child: Text(
                          topic,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 50,
        child: ElevatedButton(
          onPressed: _syncAndNavigate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
            elevation: 5,
            shadowColor: Colors.black.withOpacity(0.5),
          ),
          child: const Text(
            'Save & Continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
