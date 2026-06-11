import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/gallery_service.dart';
import '../services/gcv_api_service.dart';
import '../widgets/garage/garage_car_canvas.dart';
import '../widgets/garage/garage_modification_status_panel.dart';
import '../widgets/garage/garage_profile_buttons.dart';
import '../widgets/garage/garage_side_bar.dart';
import '../widgets/garage/garage_top_bar.dart';
import '../widgets/garage_controls.dart';
import '../widgets/garage_welcome.dart';
import '../widgets/overlays/auth_overlay.dart';
import '../widgets/overlays/instructions_overlay.dart';
import 'profile_screen.dart';

class GCVGaragePage extends StatefulWidget {
  const GCVGaragePage({super.key});

  @override
  State<GCVGaragePage> createState() => _GCVGaragePageState();
}

class _GCVGaragePageState extends State<GCVGaragePage> {
  static const int _loopFactor = 10000;

  final Color _gcvBlue = Colors.blueAccent;

  final AuthService _authService = AuthService();
  final GalleryService _galleryService = GalleryService();
  final GCVApiService _apiService = GCVApiService();

  final ScreenshotController _screenshotController = ScreenshotController();

  final PageController _topBarController = PageController(
    viewportFraction: 0.25,
    initialPage: 5000,
  );

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  User? _currentUser;

  int _activeCategoryIndex = 0;
  int _activeOptionIndex = 0;

  bool _showMenus = true;
  bool _showInstructions = false;
  bool _showAuthOverlay = false;
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _isCapturing = false;
  bool _isPickingImage = false;
  bool _showPartDebug = false;
  bool _hasShownDebugInfo = false;
  bool _isApplyingModification = false;

  Color _pickerColor = Colors.blueAccent;

  Uint8List? _processedImage;
  Uint8List? _currentImage;

  String? _lastServiceSearch;

  final List<Uint8List> _history = [];
  final List<String> _statusHistory = [];
  List<dynamic> _parts = [];

  final Map<String, String> _modificationStatuses = { };

  final List<Map<String, dynamic>> _categories = [
    {
      "name": "PAINT",
      "icon": Icons.palette_outlined,
    },
    {
      "name": "WHEELS",
      "icon": Icons.adjust,
      "options": ["SPORT", "DEEP DISH", "OFF ROAD", "VINTAGE"],
    },
    {
      "name": "WINDOW",
      "icon": Icons.directions_car_filled_outlined,
    },
    {
      "name": "LIGHTS",
      "icon": Icons.highlight,
    },
    {
      "name": "AERO",
      "icon": Icons.air,
      "options": ["BODY KIT", "SPLITTER", "SPOILER", "DIFFUSER"],
    },
    {
      "name": "SUSPENSION",
      "icon": Icons.height,
      "options": ["LOW", "NORMAL", "HIGH"],
    },
  ];

  @override
  void initState() {
    super.initState();

    _authService.authStateChanges().listen((user) {
      if (!mounted) return;

      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  void dispose() {
    _topBarController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int _colorValue(double value) {
    return (value * 255.0).round().clamp(0, 255);
  }

  String _rgbPrompt(String type) {
    return "$type RGB(${_colorValue(_pickerColor.r)}, ${_colorValue(_pickerColor.g)}, ${_colorValue(_pickerColor.b)})";
  }

  String _statusForCategory(String category, bool success) {
    if (!success) return 'bad';

    if (category == 'PAINT') return 'good';
    if (category == 'WINDOW') return 'good';
    if (category == 'LIGHTS') return 'good';
    if (category == 'SUSPENSION') return 'good';

    if (category == 'WHEELS') return 'partial';
    if (category == 'AERO') return 'partial';

    return 'partial';
  }

  void _resetModificationStatuses() {
    _modificationStatuses.clear();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _upload() async {
    if (_isPickingImage) return;

    _isPickingImage = true;

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    _isPickingImage = false;

    if (file == null) return;

    final bytes = await file.readAsBytes();

    setState(() {
      _processedImage = null;
      _currentImage = null;
      _history.clear();
      _statusHistory.clear();
      _parts = [];
      _lastServiceSearch = null;
      _isLoading = true;
      _isApplyingModification = false;
      _showMenus = true;
      _showPartDebug = false;
      _resetModificationStatuses();
    });

    final result = await _apiService.processCar(bytes);

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _processedImage = result.imageBytes;
        _currentImage = result.imageBytes;
        _parts = result.detections;
        _isLoading = false;
      });

      _showMessage("Car uploaded and background removed.");
    } else {
      setState(() {
        _currentImage = bytes;
        _isLoading = false;
      });

      _showMessage("Backend not connected. Showing original image for now.");
    }
  }

  String _partNameForCurrentCategory() {
    final String category = _categories[_activeCategoryIndex]['name'];

    if (category == "PAINT") return "body";
    if (category == "WINDOW") return "windows";
    if (category == "LIGHTS") return "left_light";
    if (category == "WHEELS") return "front_wheel";
    if (category == "AERO") return "body";
    if (category == "SUSPENSION") return "body";

    return "body";
  }

  Future<void> _applyModification() async {
    if (_isApplyingModification || _isLoading) return;
    if (_currentImage == null) return;

    final String currentCategory = _categories[_activeCategoryIndex]['name'];

    if (_parts.isEmpty) {
      _showMessage("Car detection is missing. Open eye mode or upload again.");
      return;
    }

    final String selectedPartName = _partNameForCurrentCategory();

    final Map<String, dynamic> part = Map<String, dynamic>.from(
      _parts.firstWhere(
        (p) => p is Map && p['part'] == selectedPartName,
        orElse: () => _parts.firstWhere(
          (p) => p is Map && p['part'] == 'body',
          orElse: () => _parts[0],
        ),
      ),
    );

    final Uint8List imageBeforeModification = _currentImage!;
    final String prompt = _buildPromptForCurrentSelection();

    debugPrint("==============================");
    debugPrint("APPLYING CUSTOMISATION");
    debugPrint("PROMPT: $prompt");
    debugPrint("SELECTED CATEGORY: $currentCategory");
    debugPrint("SELECTED PART: $selectedPartName");
    debugPrint("PART SENT: ${part['part']}");
    debugPrint("BOX SENT: ${part['box']}");
    debugPrint("ALL PARTS SENT: $_parts");

    setState(() {
      _isLoading = true;
      _isApplyingModification = true;
    });

    final result = await _apiService.applyModification(
      imageBytes: imageBeforeModification,
      prompt: prompt,
      part: part,
      parts: _parts,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _history.add(imageBeforeModification);
        _statusHistory.add(currentCategory);

        _currentImage = result;
        _modificationStatuses[currentCategory] =
            _statusForCategory(currentCategory, true);

        _isLoading = false;
        _isApplyingModification = false;
      });

      _showMessage("Customisation applied.");

    } else {
      setState(() {
        _modificationStatuses[currentCategory] =
            _statusForCategory(currentCategory, false);

        _isLoading = false;
        _isApplyingModification = false;
      });

      _showMessage("AI customisation failed. Check your backend.");
    }
  }

  String _buildPromptForCurrentSelection() {
    final String category = _categories[_activeCategoryIndex]['name'];

    if (category == "PAINT") {
      _lastServiceSearch = "car wrap and car paint service near me";
      return _rgbPrompt("PAINT_COLOR");
    }

    if (category == "WINDOW") {
      _lastServiceSearch = "car window tinting near me";
      return _rgbPrompt("WINDOW_TINT");
    }

    if (category == "LIGHTS") {
      _lastServiceSearch = "car lighting modification near me";
      return _rgbPrompt("LIGHT_COLOR");
    }

    if (category == "WHEELS") {
      final options = _getOptionsForCurrentCategory();

      final selectedOption = options.isNotEmpty
          ? options[_activeOptionIndex.clamp(0, options.length - 1)]
          : "SPORT";

      _lastServiceSearch = "alloy wheels fitting near me";
      return "WHEELS $selectedOption";
    }

    if (category == "AERO") {
      final options = _getOptionsForCurrentCategory();

      final selectedOption = options.isNotEmpty
          ? options[_activeOptionIndex.clamp(0, options.length - 1)]
          : "BODY KIT";

      if (selectedOption == "SPLITTER") {
        _lastServiceSearch = "car front splitter installation near me";
      } else if (selectedOption == "SPOILER") {
        _lastServiceSearch = "car spoiler installation near me";
      } else if (selectedOption == "DIFFUSER") {
        _lastServiceSearch = "car rear diffuser installation near me";
      } else {
        _lastServiceSearch = "car body kit installation near me";
      }

      return "AERO $selectedOption";
    }

    if (category == "SUSPENSION") {
      final options = _getOptionsForCurrentCategory();

      final selectedOption = options.isNotEmpty
          ? options[_activeOptionIndex.clamp(0, options.length - 1)]
          : "NORMAL";

      _lastServiceSearch = "car suspension lowering service near me";
      return "SUSPENSION $selectedOption";
    }

    return category;
  }

  Future<void> _saveProject() async {
    if (_currentImage == null) {
      _showMessage("Upload a car first.");
      return;
    }

    if (_currentUser == null) {
      setState(() {
        _showAuthOverlay = true;
      });

      _showMessage("Please login or register to save your build.");
      return;
    }

    setState(() {
      _isLoading = true;
      _showMenus = false;
      _isCapturing = true;
    });

    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final Uint8List? image = await _screenshotController.capture();

      if (image == null) {
        throw Exception("Screenshot failed");
      }

      await _galleryService.saveBuild(
        userId: _currentUser!.uid,
        imageBytes: image,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isCapturing = false;
        _showMenus = true;
      });

      _showMessage("Build saved to your profile.");
      await _askFindNearbyService();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isCapturing = false;
        _showMenus = true;
      });

      _showMessage("Save failed. Check Firebase setup.");
    }
  }

  Future<void> _askFindNearbyService() async {
    if (_lastServiceSearch == null) return;
    if (!mounted) return;

    final bool? openMap = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "FIND SERVICE NEARBY?",
            style: TextStyle(
              color: _gcvBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Would you like to find nearby places that can perform this modification?",
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "NO",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "OPEN MAPS",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (openMap == true) {
      await _openNearbyServiceMap();
    }
  }

  Future<void> _openNearbyServiceMap() async {
    final String query = Uri.encodeComponent(
      _lastServiceSearch ?? "car modification near me",
    );

    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      _showMessage("Could not open Google Maps.");
    }
  }

  Future<void> _handleAuth() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegistering) {
        await _authService.register(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await _authService.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      setState(() {
        _showAuthOverlay = false;
        _isLoading = false;
      });

      _showMessage(_isRegistering ? "Account created." : "Logged in.");
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage("Login/register failed. Check email and password.");
    }
  }

  void _openProfile() {
    if (_currentUser == null) {
      setState(() {
        _showAuthOverlay = true;
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ProfileScreen(
          user: _currentUser!,
          gcvBlue: _gcvBlue,
        );
      },
    );
  }

  Future<void> _confirmLeaveGarage() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "LEAVE GARAGE?",
            style: TextStyle(
              color: _gcvBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Your current customisation will be cleared if it has not been saved. Do you want to leave the garage?",
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "CANCEL",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "LEAVE",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _askFindNearbyService();
      _resetGarage();
    }
  }

  void _resetGarage() {
    setState(() {
      _processedImage = null;
      _currentImage = null;
      _history.clear();
      _statusHistory.clear();
      _parts = [];
      _lastServiceSearch = null;
      _showMenus = true;
      _showPartDebug = false;
      _isApplyingModification = false;
      _activeCategoryIndex = 0;
      _activeOptionIndex = 0;
      
      _resetModificationStatuses();
    });
  }

  void _undoPreviousModification() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentImage = _history.removeLast();

        if (_statusHistory.isNotEmpty) {
          final String lastStatus = _statusHistory.removeLast();
          _modificationStatuses.remove(lastStatus);
        }
      });

      _showMessage("Previous customisation restored.");
      return;
    }

    if (_processedImage != null) {
      setState(() {
        _currentImage = _processedImage;
        _statusHistory.clear();
        _modificationStatuses.clear();
      });

      _showMessage("Returned to clean uploaded car.");
      return;
    }

    _showMessage("No previous image available.");
  }

  Future<void> _togglePartDebug() async {
    if (!_showPartDebug && !_hasShownDebugInfo) {
      _hasShownDebugInfo = true;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "AI PART DETECTION",
              style: TextStyle(
                color: _gcvBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              "This mode shows where GCV-AI thinks the car parts are.\n\n"
              "The blue boxes are estimated areas for wheels, windows, lights and body.\n\n"
              "You can drag the boxes to correct them if the AI estimate is wrong.\n\n"
              "Tap the check button when finished.",
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "GOT IT",
                  style: TextStyle(color: _gcvBlue),
                ),
              ),
            ],
          );
        },
      );
    }

    setState(() {
      _showPartDebug = !_showPartDebug;
    });

    if (_showPartDebug) {
      _showMessage("AI detection mode active. Drag boxes to adjust parts.");
    } else {
      _showMessage("AI detection saved.");
    }
  }

  List<String> _getOptionsForCurrentCategory() {
    final category = _categories[_activeCategoryIndex];

    if (category['options'] == null) {
      return [];
    }

    return List<String>.from(category['options']);
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _pickerColor,
              onColorChanged: (color) {
                setState(() {
                  _pickerColor = color;
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'DONE',
                style: TextStyle(color: _gcvBlue),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final bool isLandscape = orientation == Orientation.landscape;

        final double topBarTop = isLandscape ? 20 : 65;
        final double topBarLeft = isLandscape ? 70 : 25;
        final double topBarRight = isLandscape ? 170 : 95;

        final double statusPanelTop = isLandscape ? 120 : 168;
        final double statusPanelLeft = isLandscape ? 88 : 24;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.black,
          body: Screenshot(
            controller: _screenshotController,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    "assets/GCV_Garage.png",
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.black);
                    },
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withAlpha(
                      _currentImage == null ? 100 : 150,
                    ),
                  ),
                ),
                GarageCarCanvas(
                  currentImage: _currentImage,
                  parts: _parts,
                  showPartDebug: _showPartDebug,
                  adjustPartsMode: _showPartDebug,
                  isLandscape: isLandscape,
                  onPartsChanged: (updatedParts) {
                    setState(() {
                      _parts = updatedParts;
                    });
                  },
                  onDoneAdjusting: _togglePartDebug,
                ),
                if (!_showPartDebug)
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_showAuthOverlay) return;
                      if (_currentImage == null) return;

                      setState(() {
                        _showMenus = !_showMenus;
                        _showInstructions = false;
                      });
                    },
                  ),
                if (_currentImage == null)
                  GarageWelcome(
                    gcvBlue: _gcvBlue,
                    onEnterGarage: _upload,
                    onHelpTap: () {
                      setState(() {
                        _showInstructions = true;
                      });
                    },
                  ),
                if (_currentImage != null &&
                    _showMenus &&
                    !_isCapturing &&
                    !_showPartDebug) ...[
                  GarageTopBar(
                    controller: _topBarController,
                    categories: _categories,
                    activeCategoryIndex: _activeCategoryIndex,
                    loopFactor: _loopFactor,
                    top: topBarTop,
                    left: topBarLeft,
                    right: topBarRight,
                    gcvBlue: _gcvBlue,
                    onCategoryChanged: (index) {
                      setState(() {
                        _activeCategoryIndex = index;
                        _activeOptionIndex = 0;
                      });
                    },
                  ),

                  if (_modificationStatuses.isNotEmpty)
                    GarageModificationStatusPanel(
                      statuses: _modificationStatuses,
                      gcvBlue: _gcvBlue,
                      top: statusPanelTop,
                      left: statusPanelLeft,
                    ),

                  GarageSideBar(
                    category: _categories[_activeCategoryIndex]['name'],
                    options: _getOptionsForCurrentCategory(),
                    activeOptionIndex: _activeOptionIndex,
                    isLandscape: isLandscape,
                    gcvBlue: _gcvBlue,
                    pickerColor: _pickerColor,
                    onColorTap: _openColorPicker,
                    onOptionSelected: (index) {
                      setState(() {
                        _activeOptionIndex = index;
                      });
                    },
                  ),
                  GarageControls(
                    gcvBlue: _gcvBlue,
                    canSave: _currentImage != null,
                    isBusy: _isLoading || _isApplyingModification,
                    onUndo: _undoPreviousModification,
                    onApply: _applyModification,
                    onSave: _saveProject,
                    onClose: _confirmLeaveGarage,
                  ),
                ],
                GarageProfileButtons(
                  isLandscape: isLandscape,
                  showMenus: _showMenus,
                  isCapturing: _isCapturing,
                  hasImage: _currentImage != null,
                  isLoggedIn: _currentUser != null,
                  showPartDebug: _showPartDebug,
                  gcvBlue: _gcvBlue,
                  onProfileTap: _openProfile,
                  onDebugTap: _togglePartDebug,
                ),
                if (_showInstructions)
                  InstructionsOverlay(
                    gcvBlue: _gcvBlue,
                    onClose: () {
                      setState(() {
                        _showInstructions = false;
                      });
                    },
                  ),
                if (_showAuthOverlay)
                  AuthOverlay(
                    gcvBlue: _gcvBlue,
                    isRegistering: _isRegistering,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    onSubmit: _handleAuth,
                    onToggleMode: () {
                      setState(() {
                        _isRegistering = !_isRegistering;
                      });
                    },
                    onClose: () {
                      setState(() {
                        _showAuthOverlay = false;
                      });
                    },
                  ),
                if (_isLoading && !_isCapturing)
                  Container(
                    color: Colors.black.withAlpha(130),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}