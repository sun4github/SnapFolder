# SnapFolder

SnapFolder is a Flutter-based camera application designed for organized photo capture. Instead of saving all photos to a single gallery, it allows users to categorize photos into specific "Projects" and further organize them into numbered subfolders.

## Features

- **Project-Based Organization:** Create, name, and delete top-level project folders.
- **Hierarchical Storage:** Support for subfolders within projects (automatically numbered, e.g., `001`, `002`).
- **Direct File System Access:** Photos are saved directly to `/storage/emulated/0/DCIM/SnapFolder/`, making them immediately accessible via the device's native file explorer and gallery.
- **Flexible Capture Workflow:**
  - Toggle between saving to the project root or a specific subfolder.
  - Optional "Preview" mode to review and confirm photos before saving.
- **Camera Controls:** Integrated flash toggle and high-resolution capture.

## How to Use

1. **Grant Permissions:** On first launch, the app requests Camera and Storage permissions.
2. **Project Management:** 
   - Start at the **Project List Screen**.
   - Create a new project by providing a name.
   - Tap an existing project to open the camera interface for that project.
3. **Capturing Photos:**
   - In the **Camera Screen**, take a photo to save it to the project root.
   - Create a new numbered subfolder (e.g., `001`) and switch the capture mode to save photos into that specific folder.
   - Toggle flash or preview settings as needed.
4. **Review & Save:** If preview is enabled, you can choose to "Save" or "Retake" the photo.

## Architecture

### Tech Stack
- **Framework:** Flutter (Dart)
- **Key Dependencies:** 
  - `camera`: For hardware integration and image capture.
  - `path_provider` & `dart:io`: For Android file system manipulation.
  - `permission_handler`: For managing runtime permissions.

### Design
- **UI Structure:** A simple two-screen navigation flow (`ProjectListScreen` $\rightarrow$ `CameraScreen`).
- **State Management:** Uses `StatefulWidget` and `setState` for local state management.
- **Storage Pattern:** Uses a hardcoded base path in the DCIM directory to ensure photos are visible to other system apps.
- **Structure:** The core logic is currently contained within `lib/main.dart`.
