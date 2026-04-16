import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

late List<CameraDescription> cameras;

// Base path: /storage/emulated/0/DCIM/SnapFolder/
// Accessible via file explorer and gallery
String get basePath => '/storage/emulated/0/DCIM/SnapFolder';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const SnapFolderApp());
}

class SnapFolderApp extends StatelessWidget {
  const SnapFolderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapFolder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const ProjectListScreen(),
    );
  }
}

// ============ PROJECT LIST SCREEN ============
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  List<String> _projects = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request permissions
    final cameraStatus = await Permission.camera.request();
    final storageStatus = await Permission.storage.request();
    final manageStorage = await Permission.manageExternalStorage.request();

    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Create base directory
    final baseDir = Directory(basePath);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    setState(() {
      _hasPermission = true;
    });

    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);

    try {
      final baseDir = Directory(basePath);
      final List<String> projects = [];

      if (await baseDir.exists()) {
        await for (final entity in baseDir.list()) {
          if (entity is Directory) {
            final name = entity.path.split('/').last;
            // Exclude hidden folders
            if (!name.startsWith('.')) {
              projects.add(name);
            }
          }
        }
      }

      projects.sort((a, b) => b.compareTo(a)); // Newest first (alphabetically reverse)

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading projects: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewProject() async {
    final controller = TextEditingController();

    final projectName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('New Project', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter project name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (projectName != null && projectName.trim().isNotEmpty) {
      // Sanitize project name (remove invalid characters)
      final sanitized = projectName.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final projectPath = '$basePath/$sanitized';

      try {
        await Directory(projectPath).create(recursive: true);
        await _loadProjects();

        if (mounted) {
          _openProject(sanitized);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating project: $e')),
          );
        }
      }
    }
  }

  void _openProject(String projectName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          projectName: projectName,
          projectPath: '$basePath/$projectName',
        ),
      ),
    ).then((_) => _loadProjects()); // Refresh list when returning
  }

  Future<void> _deleteProject(String projectName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Project?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will delete "$projectName" and all its photos. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Directory('$basePath/$projectName').delete(recursive: true);
        await _loadProjects();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting project: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnapFolder'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text(
                        'Permissions Required',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Camera and storage access needed',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeApp,
                        child: const Text('Grant Permissions'),
                      ),
                    ],
                  ),
                )
              : _projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.folder_open,
                            size: 80,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Projects Yet',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first project to get started',
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _createNewProject,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Project'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.folder, color: Colors.amber),
                                SizedBox(height: 8),
                                Text(
                                  'Photos saved to:',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'DCIM/SnapFolder/',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.folder,
                              color: Colors.amber,
                              size: 40,
                            ),
                            title: Text(
                              project,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: FutureBuilder<int>(
                              future: _countPhotos(project),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Text(
                                  '$count photos',
                                  style: const TextStyle(color: Colors.white54),
                                );
                              },
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteProject(project),
                            ),
                            onTap: () => _openProject(project),
                          ),
                        );
                      },
                    ),
      floatingActionButton: _hasPermission && _projects.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createNewProject,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<int> _countPhotos(String projectName) async {
    int count = 0;
    try {
      final dir = Directory('$basePath/$projectName');
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          count++;
        }
      }
    } catch (_) {}
    return count;
  }
}

// ============ CAMERA SCREEN ============
class CameraScreen extends StatefulWidget {
  final String projectName;
  final String projectPath;

  const CameraScreen({
    super.key,
    required this.projectName,
    required this.projectPath,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.off;
  bool _previewEnabled = true;
  String _captureMode = 'root'; // 'root' or 'subfolder'
  String? _currentSubfolder;
  List<String> _subfolders = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadSubfolders();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _loadSubfolders() async {
    final dir = Directory(widget.projectPath);
    final List<String> folders = [];

    try {
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            final name = entity.path.split('/').last;
            // Match pattern like 001, 002, etc.
            if (RegExp(r'^\d{3}$').hasMatch(name)) {
              folders.add(name);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading subfolders: $e');
    }

    folders.sort();
    setState(() {
      _subfolders = folders;
      if (folders.isNotEmpty) {
        _currentSubfolder = folders.last; // Most recent
      }
    });
  }

  Future<void> _toggleFlash() async {
    FlashMode newMode;
    switch (_flashMode) {
      case FlashMode.off:
        newMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newMode = FlashMode.always;
        break;
      default:
        newMode = FlashMode.off;
    }

    await _controller.setFlashMode(newMode);
    setState(() => _flashMode = newMode);
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
  }

  Future<void> _createNewSubfolder() async {
    // Calculate next folder number
    int nextNum = 1;
    for (final folder in _subfolders) {
      final num = int.tryParse(folder) ?? 0;
      if (num >= nextNum) {
        nextNum = num + 1;
      }
    }

    final newFolderName = nextNum.toString().padLeft(3, '0');
    final newFolderPath = '${widget.projectPath}/$newFolderName';

    await Directory(newFolderPath).create(recursive: true);

    setState(() {
      _subfolders.add(newFolderName);
      _subfolders.sort();
      _currentSubfolder = newFolderName;
      _captureMode = 'subfolder';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created folder: $newFolderName')),
      );
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_controller.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _controller.takePicture();

      // Determine save path
      String savePath;
      if (_captureMode == 'subfolder' && _currentSubfolder != null) {
        savePath = '${widget.projectPath}/$_currentSubfolder';
      } else {
        savePath = widget.projectPath;
      }

      // Ensure directory exists
      await Directory(savePath).create(recursive: true);

      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'IMG_$timestamp.jpg';
      final fullPath = '$savePath/$fileName';

      if (_previewEnabled) {
        // Show preview
        if (mounted) {
          final bool? shouldSave = await _showPreviewDialog(photo.path);
          if (shouldSave == true) {
            await File(photo.path).copy(fullPath);
            _showSavedMessage();
          }
        }
      } else {
        // Save directly
        await File(photo.path).copy(fullPath);
        _showSavedMessage();
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _showSavedMessage() {
    if (mounted) {
      final folder = _captureMode == 'subfolder' && _currentSubfolder != null
          ? _currentSubfolder
          : 'project root';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $folder'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<bool?> _showPreviewDialog(String imagePath) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(
              File(imagePath),
              height: 400,
              fit: BoxFit.contain,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Retake', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_controller),
          ),

          // Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                  ),
                ),
                // Project Name
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.projectName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  children: [
                    // Flash Toggle
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(_getFlashIcon(), color: Colors.white, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Preview Toggle
                    IconButton(
                      onPressed: () => setState(() => _previewEnabled = !_previewEnabled),
                      icon: Icon(
                        _previewEnabled ? Icons.visibility : Icons.visibility_off,
                        color: _previewEnabled ? Colors.white : Colors.white54,
                        size: 28,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode and Folder Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mode Toggle
                        GestureDetector(
                          onTap: () {
                            if (_subfolders.isEmpty && _captureMode == 'root') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Create a subfolder first')),
                              );
                              return;
                            }
                            setState(() {
                              _captureMode = _captureMode == 'root' ? 'subfolder' : 'root';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _captureMode == 'root'
                                  ? 'Project Root'
                                  : 'Folder: ${_currentSubfolder ?? "none"}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // New Folder Button
                        IconButton(
                          onPressed: _createNewSubfolder,
                          icon: const Icon(Icons.create_new_folder, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Capture Button
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
