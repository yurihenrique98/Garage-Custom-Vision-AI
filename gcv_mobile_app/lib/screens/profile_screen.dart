import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import '../services/gallery_service.dart';
import '../widgets/gcv_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final Color gcvBlue;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.gcvBlue,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final GalleryService _galleryService = GalleryService();

  final List<Map<String, dynamic>> _gallery = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadGallery() async {
    try {
      final builds = await _galleryService.loadGallery(widget.user.uid);

      if (!mounted) return;

      setState(() {
        _gallery
          ..clear()
          ..addAll(builds);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showMessage("Could not load gallery.");
    }
  }

  Future<void> _deleteBuild(String docId, int index) async {
    try {
      await _galleryService.deleteBuild(
        userId: widget.user.uid,
        docId: docId,
      );

      setState(() {
        _gallery.removeAt(index);
      });
    } catch (e) {
      _showMessage("Could not delete build.");
    }
  }

  Future<void> _logout() async {
    await _authService.logout();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _openSettings() {
    final nameController = TextEditingController(
      text: widget.user.displayName ?? "",
    );

    final emailController = TextEditingController(
      text: widget.user.email ?? "",
    );

    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "EDIT PROFILE",
            style: TextStyle(
              color: widget.gcvBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameController, "New Name", Icons.badge),
              const SizedBox(height: 10),
              _field(emailController, "New Email", Icons.email),
              const SizedBox(height: 10),
              _field(
                passwordController,
                "New Password",
                Icons.lock,
                obscure: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "CANCEL",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.gcvBlue,
              ),
              onPressed: () async {
                try {
                  await _authService.updateProfile(
                    name: nameController.text,
                    email: emailController.text,
                    password: passwordController.text,
                  );

                  if (!context.mounted) return;

                  Navigator.pop(context);
                  _showMessage("Profile updated.");
                  setState(() {});
                } catch (e) {
                  _showMessage(
                    "Profile update failed. You may need to login again.",
                  );
                }
              },
              child: const Text(
                "SAVE CHANGES",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: widget.gcvBlue),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withAlpha(25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String profileName = widget.user.displayName ??
        widget.user.email?.split('@')[0].toUpperCase() ??
        "GUEST";

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Text(
                  "GCV PROFILE",
                  style: TextStyle(
                    color: widget.gcvBlue,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.white54,
                  ),
                  onPressed: _openSettings,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 25,
              vertical: 20,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: widget.gcvBlue.withAlpha(25),
                  child: Icon(
                    Icons.person,
                    color: widget.gcvBlue,
                    size: 35,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.user.email ?? "",
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.blueAccent,
                    ),
                  )
                : _gallery.isEmpty
                    ? const Center(
                        child: Text(
                          "No saved builds yet.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: _gallery.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  _gallery[index]['url'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Row(
                                  children: [
                                    GCVCircleAction(
                                      icon: Icons.share,
                                      bg: Colors.black54,
                                      tap: () => Share.share(
                                        _gallery[index]['url'],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GCVCircleAction(
                                      icon: Icons.delete,
                                      bg: Colors.black54,
                                      tap: () => _deleteBuild(
                                        _gallery[index]['id'],
                                        index,
                                      ),
                                      iconColor: Colors.redAccent,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          TextButton(
            onPressed: _logout,
            child: const Text(
              "LOGOUT",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}