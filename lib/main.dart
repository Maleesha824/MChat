import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MChatApp());
}

// Function to trigger notification when receiving a message
void showNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'mchat_high_importance_channel',
        'MChat High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        color: Colors.cyanAccent,
        playSound: true,
        enableVibration: true,
      );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecond,
    title,
    body,
    platformChannelSpecifics,
  );
}

class MChatApp extends StatelessWidget {
  const MChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.cyanAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.cyanAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.cyanAccent,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
          ),
        ),
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginScreen()
          : const HomeScreen(),
    );
  }
}

// 1. Login and Sign Up Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void authenticate() async {
    String email = emailController.text.trim().toLowerCase();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();
    String username = usernameController.text.trim();

    if (email.isEmpty ||
        !email.endsWith('@gmail.com') ||
        email == '@gmail.com') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email ending with @gmail.com'),
        ),
      );
      return;
    }

    if (!isLogin && username.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a username')));
      return;
    }

    if (!isLogin && password != confirmPassword) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        if (!mounted) return;
        if (querySnapshot.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Username already taken. Choose another.'),
            ),
          );
          setState(() {
            isLoading = false;
          });
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'email': email,
              'username': username,
              'profilePhoto': '',
              'about': '',
              'isProfileCompleted': false,
            });
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Error occurred')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.cyanAccent,
              ),
              const SizedBox(height: 20),
              Text(
                isLogin ? 'Welcome Back' : 'Create Account',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              if (!isLogin) ...[
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    hintText: 'Username',
                    prefixIcon: Icon(Icons.person, color: Colors.cyanAccent),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email (e.g. user@gmail.com)',
                  prefixIcon: Icon(Icons.email, color: Colors.cyanAccent),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),

              if (!isLogin) ...[
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm Password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.cyanAccent,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isLoading ? null : authenticate,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          isLogin ? 'Login' : 'Sign Up',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 15),

              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin
                      ? "Don't have an account? Sign Up"
                      : "Already have an account? Login",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  String searchQuery = "";
  String currentUsername = "Loading...";
  String profilePhoto = "";

  @override
  void initState() {
    super.initState();
    fetchCurrentUserData();
  }

  void fetchCurrentUserData() async {
    if (currentUser != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          currentUsername =
              doc.data()?['username'] ?? currentUser!.email ?? 'User';
          profilePhoto = doc.data()?['profilePhoto'] ?? '';
        });
      }
    }
  }

  void deleteChatRoom(String chatRoomId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Chat',
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: const Text(
          'Are you sure you want to delete this entire chat?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      var messagesQuery = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .get();

      for (var doc in messagesQuery.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            fetchCurrentUserData();
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.cyanAccent,
                radius: 18,
                backgroundImage: profilePhoto.isNotEmpty
                    ? (profilePhoto.startsWith('http')
                          ? NetworkImage(profilePhoto)
                          : MemoryImage(base64Decode(profilePhoto))
                                as ImageProvider)
                    : null,
                child: profilePhoto.isEmpty
                    ? const Icon(Icons.person, color: Colors.black, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MChat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    currentUsername,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.cyanAccent),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              fetchCurrentUserData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.cyanAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: Icon(Icons.search, color: Colors.cyanAccent),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 20,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .where('participants', arrayContains: currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading chats'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chatRooms = snapshot.data!.docs;

                if (chatRooms.isEmpty) {
                  return const Center(
                    child: Text(
                      'No chats yet.\nTap the + button below to chat with friends!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                chatRooms.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  Timestamp? timeA = dataA['lastMessageTime'] as Timestamp?;
                  Timestamp? timeB = dataB['lastMessageTime'] as Timestamp?;
                  if (timeA == null) return 1;
                  if (timeB == null) return -1;
                  return timeB.compareTo(timeA);
                });

                return ListView.builder(
                  itemCount: chatRooms.length,
                  itemBuilder: (context, index) {
                    var roomData =
                        chatRooms[index].data() as Map<String, dynamic>;
                    List participants = roomData['participants'] ?? [];

                    String otherUserId = participants.firstWhere(
                      (id) => id != currentUser!.uid,
                      orElse: () => '',
                    );

                    if (otherUserId.isEmpty) return const SizedBox.shrink();

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }
                        var userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;
                        if (userData == null) return const SizedBox.shrink();

                        String username =
                            userData['username'] ?? userData['email'] ?? 'User';
                        String userPic = userData['profilePhoto'] ?? '';
                        String about =
                            userData['about'] ?? 'Hey there! I am using MChat.';

                        if (searchQuery.isNotEmpty &&
                            !username.toLowerCase().contains(searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        String lastMessage =
                            roomData['lastMessage'] ?? 'Tap to chat';
                        if (roomData['messageType'] == 'image') {
                          lastMessage = '📷 Photo';
                        }

                        Timestamp? timestamp =
                            roomData['lastMessageTime'] as Timestamp?;
                        String timeString = '';
                        if (timestamp != null) {
                          timeString = DateFormat('hh:mm a')
                              .format(timestamp.toDate());
                        }

                        Map unreadMap = roomData['unreadCount'] ?? {};
                        int unreadCount = unreadMap[currentUser!.uid] ?? 0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.cyanAccent,
                            backgroundImage: userPic.isNotEmpty
                                ? (userPic.startsWith('http')
                                      ? NetworkImage(userPic)
                                      : MemoryImage(base64Decode(userPic))
                                            as ImageProvider)
                                : null,
                            child: userPic.isEmpty
                                ? const Icon(Icons.person, color: Colors.black)
                                : null,
                          ),
                          title: Text(
                            username,
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: unreadCount > 0
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: unreadCount > 0
                                  ? Colors.cyanAccent
                                  : Colors.grey,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeString,
                                style: TextStyle(
                                  color: unreadCount > 0
                                      ? Colors.cyanAccent
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 5),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.cyanAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('chat_rooms')
                                .doc(chatRooms[index].id)
                                .update({'unreadCount.${currentUser!.uid}': 0});

                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatRoomId: chatRooms[index].id,
                                  name: username,
                                  receiverUid: userData['uid'],
                                  receiverAbout: about,
                                  receiverPhoto: userPic,
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            deleteChatRoom(chatRooms[index].id);
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black, size: 30),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchUserScreen()),
          );
        },
      ),
    );
  }
}

// 3. Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  String base64Image = "";
  bool isProfileCompleted = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  void loadUserData() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    if (doc.exists && mounted) {
      String aboutText = doc.data()?['about'] ?? '';
      String photo = doc.data()?['profilePhoto'] ?? '';
      bool completed = doc.data()?['isProfileCompleted'] ?? false;

      if (aboutText.isNotEmpty && aboutText != 'Hey there! I am using MChat.') {
        completed = true;
      }

      setState(() {
        usernameController.text = doc.data()?['username'] ?? '';
        aboutController.text = aboutText;
        base64Image = photo;
        isProfileCompleted = completed;
      });
    }
  }

  Future<void> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      File imageFile = File(image.path);
      bytes = await imageFile.readAsBytes();
      setState(() {
        base64Image = base64Encode(bytes);
      });
    }
  }

  List<int> bytes = [];

  void updateProfile() async {
    setState(() {
      isLoading = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
            'username': usernameController.text.trim(),
            'about': aboutController.text.trim(),
            'profilePhoto': base64Image,
            'isProfileCompleted': true,
          });
      if (!mounted) return;
      setState(() {
        isProfileCompleted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: pickImageFromGallery,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.cyanAccent,
                      backgroundImage: base64Image.isNotEmpty
                          ? (base64Image.startsWith('http')
                                ? NetworkImage(base64Image)
                                : MemoryImage(base64Decode(base64Image))
                                      as ImageProvider)
                          : null,
                      child: base64Image.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.black,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.cyanAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap profile picture to change from gallery',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person, color: Colors.cyanAccent),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: aboutController,
              decoration: const InputDecoration(
                labelText: 'About (Bio)',
                prefixIcon: Icon(Icons.info_outline, color: Colors.cyanAccent),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: isLoading ? null : updateProfile,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        isProfileCompleted ? 'Edit Profile' : 'Save Changes',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Search Screen
class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search username...',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value.trim().toLowerCase();
            });
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading users'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          final filteredUsers = users.where((doc) {
            var userData = doc.data() as Map<String, dynamic>?;
            if (userData == null) return false;

            String username = (userData['username'] ?? userData['email'] ?? '')
                .toLowerCase();
            if (userData['uid'] == currentUser!.uid) {
              return false;
            }
            return username.contains(searchQuery);
          }).toList();

          if (filteredUsers.isEmpty) {
            return const Center(
              child: Text(
                'No users found',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              var userData =
                  filteredUsers[index].data() as Map<String, dynamic>;
              String username =
                  userData['username'] ?? userData['email'] ?? 'User';
              String userPic = userData['profilePhoto'] ?? '';
              String about =
                  userData['about'] ?? 'Hey there! I am using MChat.';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.cyanAccent,
                  backgroundImage: userPic.isNotEmpty
                      ? (userPic.startsWith('http')
                            ? NetworkImage(userPic)
                            : MemoryImage(base64Decode(userPic))
                                  as ImageProvider)
                      : null,
                  child: userPic.isEmpty
                      ? const Icon(Icons.person, color: Colors.black)
                      : null,
                ),
                title: Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  about,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  List<String> ids = [currentUser!.uid, userData['uid']];
                  ids.sort();
                  String chatRoomId = ids.join('_');

                  final roomDoc = await FirebaseFirestore.instance
                      .collection('chat_rooms')
                      .doc(chatRoomId)
                      .get();
                  if (!roomDoc.exists) {
                    await FirebaseFirestore.instance
                        .collection('chat_rooms')
                        .doc(chatRoomId)
                        .set({
                          'participants': [currentUser.uid, userData['uid']],
                          'lastMessage': '',
                          'lastMessageTime': FieldValue.serverTimestamp(),
                          'unreadCount': {
                            currentUser.uid: 0,
                            userData['uid']: 0,
                          },
                        });
                  }

                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatRoomId: chatRoomId,
                        name: username,
                        receiverUid: userData['uid'],
                        receiverAbout: about,
                        receiverPhoto: userPic,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// 5. Chat Screen with Text & Photo Support
class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String name;
  final String receiverUid;
  final String receiverAbout;
  final String receiverPhoto;
  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.name,
    required this.receiverUid,
    required this.receiverAbout,
    required this.receiverPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    markMessagesAsRead();
  }

  void markMessagesAsRead() async {
    var msgDocs = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.receiverUid)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in msgDocs.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  // Send Message (Text or Image)
  void sendMessage({String messageType = 'text', String content = ''}) async {
    String textToSend = content.isEmpty
        ? messageController.text.trim()
        : content;
    if (textToSend.isEmpty) return;

    if (content.isEmpty) {
      messageController.clear();
    }

    var roomRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId);
    var roomDoc = await roomRef.get();

    int currentReceiverUnread = 0;
    if (roomDoc.exists) {
      Map unreadMap = roomDoc.data()!['unreadCount'] ?? {};
      currentReceiverUnread = unreadMap[widget.receiverUid] ?? 0;
    } else {
      await roomRef.set({
        'participants': [currentUser!.uid, widget.receiverUid],
      });
    }

    await roomRef.collection('messages').add({
      'senderId': currentUser!.uid,
      'senderEmail': currentUser!.email,
      'receiverId': widget.receiverUid,
      'message': textToSend,
      'messageType': messageType, // text, image
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    String lastMsgDisplay = textToSend;
    if (messageType == 'image') {
      lastMsgDisplay = '📷 Photo';
    }

    await roomRef.update({
      'lastMessage': lastMsgDisplay,
      'messageType': messageType,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.${widget.receiverUid}': currentReceiverUnread + 1,
    });
  }

  // Pick and Send Image from Gallery
  void sendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      File imageFile = File(image.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      sendMessage(messageType: 'image', content: base64Image);
    }
  }

  void deleteMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.cyanAccent,
              radius: 18,
              backgroundImage: widget.receiverPhoto.isNotEmpty
                  ? (widget.receiverPhoto.startsWith('http')
                        ? NetworkImage(widget.receiverPhoto)
                        : MemoryImage(base64Decode(widget.receiverPhoto))
                              as ImageProvider)
                  : null,
              child: widget.receiverPhoto.isEmpty
                  ? const Icon(Icons.person, color: Colors.black, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.receiverAbout,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isNotEmpty) {
                  var latestMsg = messages.first.data() as Map<String, dynamic>;
                  if (latestMsg['senderId'] == widget.receiverUid &&
                      (latestMsg['isNotified'] == null ||
                          latestMsg['isNotified'] == false)) {
                    showNotification(
                      widget.name,
                      latestMsg['messageType'] == 'image'
                          ? '📷 Photo'
                          : latestMsg['message'],
                    );
                    messages.first.reference.update({'isNotified': true});
                  }
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    bool isMe = messageData['senderId'] == currentUser!.uid;
                    bool isRead = messageData['isRead'] ?? false;
                    String messageId = messages[index].id;
                    String msgType = messageData['messageType'] ?? 'text';

                    String messageTime = '';
                    Timestamp? timestamp =
                        messageData['timestamp'] as Timestamp?;
                    if (timestamp != null) {
                      messageTime = DateFormat('hh:mm a')
                          .format(timestamp.toDate());
                    }

                    return GestureDetector(
                      onLongPress: () {
                        if (isMe) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text(
                                'Delete Message',
                                style: TextStyle(color: Colors.cyanAccent),
                              ),
                              content: const Text(
                                'Do you want to delete this message?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    deleteMessage(messageId);
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 5,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.cyanAccent
                                : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: isMe
                                  ? const Radius.circular(20)
                                  : Radius.zero,
                              bottomRight: isMe
                                  ? Radius.zero
                                  : const Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (msgType == 'text')
                                Text(
                                  messageData['message'],
                                  style: TextStyle(
                                    color: isMe ? Colors.black : Colors.white,
                                    fontSize: 16,
                                  ),
                                )
                              else if (msgType == 'image')
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.memory(
                                    base64Decode(messageData['message']),
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    messageTime,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.black54
                                          : Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: isRead
                                          ? Colors.blue
                                          : Colors.black45,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input Field with Gallery and Send buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.cyanAccent),
                  onPressed: sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.cyanAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: () => sendMessage(messageType: 'text'),
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
