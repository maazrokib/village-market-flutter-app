import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:village_market/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoviScreen extends StatefulWidget {
  const CoviScreen({super.key});

  @override
  State<CoviScreen> createState() => _CoviScreenState();
}

class _CoviScreenState extends State<CoviScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _images = [];
  int _userId = 1;
  String _userRole = 'buyer';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id') ?? 1;
    try {
      final db = await DatabaseHelper().database;
      final me = await db.query('users', where: 'id = ?', whereArgs: [_userId]);
      if (me.isNotEmpty) {
        _userRole = me.first['role'] as String? ?? 'buyer';
      }
    } catch (_) {}
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery('''
        SELECT 
          c.*, 
          u.name as uploader_name,
          (SELECT COUNT(*) FROM covi_likes cl WHERE cl.covi_id = c.id) as like_count,
          (SELECT COUNT(*) FROM covi_likes cl2 WHERE cl2.covi_id = c.id AND cl2.user_id = ?) as liked
        FROM covi_images c
        LEFT JOIN users u ON c.uploader_id = u.id
        ORDER BY c.created_at DESC
      ''', [_userId]);
      setState(() {
        _images = result;
      });
    } catch (e) {
      _showError('Failed to load images: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndAddImage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final captionController = TextEditingController();
      final storyController = TextEditingController();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share to COVI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(
                    labelText: 'Caption (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: storyController,
                  decoration: const InputDecoration(
                    labelText: 'Your story (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      );
      if (confirmed != true) return;

      final db = await DatabaseHelper().database;
      await db.insert('covi_images', {
        'image_path': file.path,
        'caption': captionController.text,
        'story': storyController.text,
        'uploader_id': _userId,
        'uploader_role': _userRole,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccess('Image added');
      _loadImages();
    } catch (e) {
      _showError('Failed to add image: $e');
    }
  }

  Future<void> _deleteImage(int id) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('covi_images', where: 'id = ?', whereArgs: [id]);
      _showSuccess('Image deleted');
      _loadImages();
    } catch (e) {
      _showError('Failed to delete image: $e');
    }
  }

  Future<void> _toggleLike(int coviId, bool isLiked) async {
    try {
      final db = await DatabaseHelper().database;
      if (isLiked) {
        await db.delete('covi_likes', where: 'covi_id = ? AND user_id = ?', whereArgs: [coviId, _userId]);
      } else {
        await db.insert('covi_likes', {
          'covi_id': coviId,
          'user_id': _userId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      _loadImages();
    } catch (e) {
      _showError('Failed to update like: $e');
    }
  }

  bool _canDelete(Map<String, dynamic> image) {
    if (_userRole == 'admin') return true;
    final uploaderId = image['uploader_id'] as int?;
    return uploaderId == _userId;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COVI - Shared Gallery'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadImages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndAddImage,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Add Photo'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
              ? const Center(
                  child: Text(
                    'No images yet. Tap "Add Photo" to upload.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final img = _images[index];
                    final filePath = img['image_path'] as String?;
                    final caption = (img['caption'] as String?) ?? '';
                    final story = (img['story'] as String?) ?? '';
                    final role = (img['uploader_role'] as String?) ?? '';
                    final name = (img['uploader_name'] as String?) ?? 'User';
                    final likeCount = (img['like_count'] is int)
                        ? img['like_count'] as int
                        : ((img['like_count'] as num?)?.toInt() ?? 0);
                    final liked = ((img['liked'] is int)
                        ? (img['liked'] as int)
                        : ((img['liked'] as num?)?.toInt() ?? 0)) > 0;
                    return Card(
                      elevation: 3,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (filePath != null && File(filePath).existsSync())
                                    Image.file(File(filePath), fit: BoxFit.cover)
                                  else
                                    const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, size: 48))),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(role.toUpperCase()),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                            if (_canDelete(img))
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () async {
                                                  Navigator.pop(context);
                                                  _deleteImage(img['id'] as int);
                                                },
                                              ),
                                          ],
                                        ),
                                        if (caption.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(caption),
                                        ],
                                        if (story.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(story),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.grey[200],
                                child: filePath != null && File(filePath).existsSync()
                                    ? Image.file(File(filePath), fit: BoxFit.cover, width: double.infinity)
                                    : const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 10)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_canDelete(img))
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _deleteImage(img['id'] as int),
                                        ),
                                    ],
                                  ),
                                  if (caption.isNotEmpty)
                                    Text(
                                      caption,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (story.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      story,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : Colors.grey[700]),
                                        onPressed: () => _toggleLike(img['id'] as int, liked),
                                      ),
                                      Text(likeCount.toString()),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Story'),
                                              content: SingleChildScrollView(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 6),
                                                    if (caption.isNotEmpty) Text(caption),
                                                    const SizedBox(height: 10),
                                                    if (story.isNotEmpty) Text(story),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                              ],
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.menu_book),
                                        label: const Text('Read'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
