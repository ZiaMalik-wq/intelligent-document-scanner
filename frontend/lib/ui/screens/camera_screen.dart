import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/providers/camera_provider.dart';
import 'package:doc_scanner/ui/screens/image_preview_screen.dart';
import 'package:doc_scanner/ui/screens/batch_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  bool _isBatchMode = false;
  final List<String> _capturedImages = [];
  late CameraProvider _cameraProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraProvider = Provider.of<CameraProvider>(context, listen: false);
      _cameraProvider.reinitialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraProvider.disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraProvider.disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _cameraProvider.reinitialize();
    }
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
                    const SizedBox(height: 12),
                    
                    // Batch/Single Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isBatchMode = false),
                            child: Text(
                              "Single",
                              style: TextStyle(
                                color: !_isBatchMode ? AppTheme.primaryColor : Colors.white70,
                                fontWeight: !_isBatchMode ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => setState(() => _isBatchMode = true),
                            child: Text(
                              "Batch",
                              style: TextStyle(
                                color: _isBatchMode ? AppTheme.primaryColor : Colors.white70,
                                fontWeight: _isBatchMode ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
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
                          tooltip: _isBatchMode ? 'Add from gallery' : 'Pick from gallery',
                          onPressed: () async {
                            final picker = ImagePicker();
                            if (_isBatchMode) {
                              // Multi-pick for batch mode
                              final List<XFile> files = await picker.pickMultiImage();
                              if (files.isNotEmpty) {
                                setState(() {
                                  _capturedImages.addAll(files.map((f) => f.path));
                                });
                              }
                            } else {
                              final XFile? file = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (file != null) {
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ImagePreviewScreen(
                                      imagePath: file.path,
                                      enableAutoCrop: false,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),

                        const SizedBox(width: 24),

                        GestureDetector(
                          onTap: () async {
                            final XFile? file = await camera.takePicture();
                            if (file != null) {
                              if (!context.mounted) return;
                              if (_isBatchMode) {
                                setState(() {
                                  _capturedImages.add(file.path);
                                });
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ImagePreviewScreen(
                                      imagePath: file.path,
                                      enableAutoCrop: false,
                                    ),
                                  ),
                                );
                              }
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
                        
                        const SizedBox(width: 24),
                        
                        // Done button for Batch mode
                        SizedBox(
                          width: 48,
                          child: _isBatchMode && _capturedImages.isNotEmpty
                              ? GestureDetector(
                                  onTap: () async {
                                    if (_capturedImages.isNotEmpty) {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BatchPreviewScreen(
                                            imagePaths: List.from(_capturedImages),
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        if (context.mounted) Navigator.pop(context);
                                      } else if (result is List) {
                                        // User pressed back — update the list with remaining pages
                                        setState(() {
                                          _capturedImages.clear();
                                          _capturedImages.addAll(result.cast<String>());
                                        });
                                      }
                                    }
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 48),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${_capturedImages.length}',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(),
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
    final height = MediaQuery.of(context).size.height * 0.6;
    final width = MediaQuery.of(context).size.width * 0.85;

    return Stack(
      children: [
        // Darkened background with cutout
        ColorFiltered(
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
                  height: height,
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Grid Overlay
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: height,
            width: width,
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    // Draw vertical lines
    final double colWidth = size.width / 3;
    canvas.drawLine(Offset(colWidth, 0), Offset(colWidth, size.height), paint);
    canvas.drawLine(Offset(colWidth * 2, 0), Offset(colWidth * 2, size.height), paint);

    // Draw horizontal lines
    final double rowHeight = size.height / 3;
    canvas.drawLine(Offset(0, rowHeight), Offset(size.width, rowHeight), paint);
    canvas.drawLine(Offset(0, rowHeight * 2), Offset(size.width, rowHeight * 2), paint);
    
    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
      
    const double length = 30;
    
    // Top Left
    canvas.drawPath(
      Path()..moveTo(0, length)..lineTo(0, 0)..lineTo(length, 0),
      cornerPaint,
    );
    // Top Right
    canvas.drawPath(
      Path()..moveTo(size.width - length, 0)..lineTo(size.width, 0)..lineTo(size.width, length),
      cornerPaint,
    );
    // Bottom Left
    canvas.drawPath(
      Path()..moveTo(0, size.height - length)..lineTo(0, size.height)..lineTo(length, size.height),
      cornerPaint,
    );
    // Bottom Right
    canvas.drawPath(
      Path()..moveTo(size.width - length, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - length),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
