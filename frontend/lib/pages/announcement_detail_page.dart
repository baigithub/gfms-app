import 'package:flutter/material.dart';
import '../api/api_client.dart';

class AnnouncementDetailPage extends StatefulWidget {
  final int announcementId;

  const AnnouncementDetailPage({super.key, required this.announcementId});

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  Map<String, dynamic> _announcement = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncementDetail();
  }

  Future<void> _loadAnnouncementDetail() async {
    try {
      final data = await ApiClient.instance.getAnnouncements(
        page: widget.announcementId,
        pageSize: 1,
      );

      if (mounted) {
        setState(() {
          List<dynamic> items;
          if (data is List) {
            items = data;
          } else if (data is Map) {
            items = data['items'] ?? [];
          } else {
            items = [];
          }
          
          _announcement = items.isNotEmpty == true ? items[0] : {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告详情'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面图
                  if (_announcement['cover_image'] != null)
                    Image.network(
                      _announcement['cover_image'],
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultCover(),
                    )
                  else
                    _buildDefaultCover(),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题
                        Text(
                          _announcement['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 元信息
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              _announcement['publish_time'] ?? _announcement['create_time'] ?? '',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.visibility, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              '${_announcement['view_count'] ?? 0} 阅读',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 正文内容
                        Text(
                          _announcement['content'] ?? _announcement['summary'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.8),
            const Color(0xFF764ba2).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.notifications,
        color: Colors.white,
        size: 64,
      ),
    );
  }
}
