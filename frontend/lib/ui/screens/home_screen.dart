import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/providers/auth_provider.dart';
import 'package:doc_scanner/ui/screens/camera_screen.dart';
import 'package:doc_scanner/ui/screens/document_detail_screen.dart';
import 'package:doc_scanner/services/document_service.dart';
import 'package:doc_scanner/core/theme.dart';
import 'package:doc_scanner/core/constants.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _documentService = DocumentService();
  List<dynamic> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _documentService.getDocuments();
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDocument(int id) async {
    try {
      await _documentService.deleteDocument(id);
      _fetchDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document deleted")),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("My Documents"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
            ? _buildEmptyState(auth)
            : _buildDocumentGrid(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
          _fetchDocuments(); // Refresh when coming back
        },
        label: const Text("Scan"),
        icon: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildEmptyState(AuthProvider auth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            "Welcome, ${auth.user?.name ?? 'User'}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your scanned documents will appear here.",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final date = DateTime.parse(doc['created_at']);
        final formattedDate = DateFormat.yMMMd().format(date);
        final imageUrl = '${AppConstants.baseUrl.replaceAll("/api/v1", "")}${doc['url']}';

        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(
                  document: doc,
                  imageUrl: imageUrl,
                ),
              ),
            );
            if (result == true) _fetchDocuments();
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['filename'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.surfaceColor,
                          title: const Text("Delete?", style: TextStyle(color: Colors.white)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteDocument(doc['id']);
                              }, 
                              child: const Text("Yes", style: TextStyle(color: Colors.red))
                            ),
                          ],
                        ),
                      );
                    },
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
