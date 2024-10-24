import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteTopicsScreen extends StatefulWidget {
  const FavoriteTopicsScreen({super.key});

  @override
  _FavoriteTopicsScreenState createState() => _FavoriteTopicsScreenState();
}

class _FavoriteTopicsScreenState extends State<FavoriteTopicsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> topics = [
    "Business",
    "Entertainment",
    "General",
    "Health",
    "Science",
    "Sports",
    "Technology"
  ];
  List<String> favoriteTopics = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // Load favorite topics from Firestore
  void _loadFavorites() async {
    User? user = _auth.currentUser;

    if (user != null) {
      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (snapshot.exists) {
        var data = snapshot.data()
            as Map<String, dynamic>; // Cast to Map<String, dynamic>
        setState(() {
          favoriteTopics = List<String>.from(
              data['favoriteTopics'] ?? []); // Access the data correctly
        });
      }
    }
  }

  // Save favorite topics to Firestore
  void _saveFavorites(List<String> selectedTopics) async {
    User? user = _auth.currentUser;

    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'favoriteTopics': selectedTopics,
      }, SetOptions(merge: true)); // Merge to avoid overwriting other fields

      // Reload favorites after saving
      _loadFavorites();
    }
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
                      _saveFavorites(
                          favoriteTopics); // Save changes to Firestore
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
