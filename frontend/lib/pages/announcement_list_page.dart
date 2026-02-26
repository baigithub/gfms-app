import 'package:flutter/material.dart';
import '../api/api_client.dart';
import 'announcement_detail_page.dart';

class AnnouncementListPage extends StatefulWidget {
  const AnnouncementListPage({super.key});

  @override
  State<AnnouncementListPage> createState() => _AnnouncementListPageState();
}

class _AnnouncementListPageState extends State<AnnouncementListPage> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    if (_isLoading && _currentPage == 1) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await ApiClient().getAnnouncements(
        page: _currentPage,
        pageSize: _pageSize,
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
          
          if (_currentPage == 1) {
            _announcements = items;
          } else {
            _announcements.addAll(items);
          }
          _hasMore = items.length >= _pageSize;
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

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _currentPage++;
    await _loadAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统公告'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading && _announcements.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _currentPage = 1;
                await _loadAnnouncements();
              },
              child: _announcements.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            '暂无公告',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollEndNotification) {
                          if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 100) {
                            _loadMore();
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _announcements.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _announcements.length) {
                            return _hasMore
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '没有更多了',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  );
                          }
                          return _buildAnnouncementItem(_announcements[index]);
                        },
                      ),
                    ),
                  ),
    );
  }

  Widget _buildAnnouncementItem(dynamic announcement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnnouncementDetailPage(
                announcementId: announcement['id'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面图
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: announcement['cover_image'] != null
                    ? Image.network(
                        announcement['cover_image'],
                        width: 80,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultCover(),
                      )
                    : _buildDefaultCover(),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      announcement['summary'] ?? announcement['content'] ?? '',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          announcement['publish_time'] ?? announcement['create_time'] ?? '',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                        const Spacer(),
                        Icon(Icons.visibility, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${announcement['view_count'] ?? 0}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.notifications,
        color: Color(0xFF667eea),
        size: 24,
      ),
    );
  }
}
