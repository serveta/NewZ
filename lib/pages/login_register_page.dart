import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  String? errorMessage = '';
  bool isLogin = false;
  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();
  final Auth _auth = Auth();

  Future<void> createUserWithEmailAndPassword() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
      // Hesap oluşturma başarılı olduğunda yapılacak işlemler
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> signInWithEmailAndPassword() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
      // Giriş başarılı olduğunda yapılacak işlemler
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _auth.signInWithGoogle();
      // Google ile giriş başarılı olduğunda yapılacak işlemler
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView( // Wrap the Column with SingleChildScrollView
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                Text(
                  isLogin ? 'Welcome\nBack' : 'Create\nAccount',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _controllerEmail,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controllerPassword,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 24),
                if (errorMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLogin
                        ? signInWithEmailAndPassword
                        : createUserWithEmailAndPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isLogin ? 'Log In' : 'Sign Up',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/google_logo.png',
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin
                          ? 'Don\'t have an account? '
                          : 'Already have an account? ',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                          errorMessage = '';
                        });
                      },
                      child: Text(
                        isLogin ? 'Sign Up' : 'Log In',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}