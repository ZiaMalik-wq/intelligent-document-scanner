import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/providers/camera_provider.dart';
import 'package:doc_scanner/ui/screens/image_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CameraProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraProvider>(
        builder: (context, camera, _) {
          if (!camera.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              // 1. Camera Preview
              Center(child: CameraPreview(camera.controller!)),

              // 2. Document Overlay Guide
              _buildOverlay(context),

              // 3. Top Controls (Back and Flash)
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: Icon(
                          camera.flashMode == FlashMode.torch
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: AppTheme.primaryColor,
                        ),
                        onPressed: () => camera.toggleFlash(),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Controls (Shutter)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    const Text(
                      "Align document within the frame",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Row with gallery button and shutter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Gallery button
                        IconButton(
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                          ),
                          tooltip: 'Pick from gallery',
                          onPressed: () async {
                            final picker = ImagePicker();
                            final XFile? file = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (file != null) {
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ImagePreviewScreen(imagePath: file.path),
                                ),
                              );
                            }
                          },
                        ),

                        const SizedBox(width: 24),

                        GestureDetector(
                          onTap: () async {
                            final XFile? file = await camera.takePicture();
                            if (file != null) {
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ImagePreviewScreen(imagePath: file.path),
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: Container(
                                height: 60,
                                width: 60,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              width: MediaQuery.of(context).size.width * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
