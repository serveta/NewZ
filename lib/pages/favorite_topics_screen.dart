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
    'Events and Festivals'
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
  void _saveFavorites() async {
    User? user = _auth.currentUser;

    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'favoriteTopics': favoriteTopics,
        'hasSelectedFavorites': true,
      }, SetOptions(merge: true));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Select Your Favorite Topics',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select topics to personalize your news feed',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
          onPressed: _saveFavorites,
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
