import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import 'task_list_page.dart';
import 'task_detail_page.dart';
import 'announcement_list_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  Map<String, dynamic> _dashboardData = {};
  List<dynamic> _pendingTasksList = [];
  List<dynamic> _announcements = [];
  int _currentAnnouncementIndex = 0;
  String _userName = '用户';
  bool _isLoading = true;
  List<dynamic> _loanBalanceTrend = [];
  List<dynamic> _disbursementTrend = [];
  List<dynamic> _greenCategoryDistribution = [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDashboard();
    _loadAnnouncements();
    _loadPendingTasks();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_real_name') ?? '用户';
    if (mounted) {
      setState(() => _userName = name);
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await ApiClient.instance.getDashboard();
      if (mounted) {
        setState(() {
          _dashboardData = data is Map ? data : {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      final data = await ApiClient.instance.getAnnouncements(page: 1, pageSize: 5);
      if (mounted && data is List && data.isNotEmpty) {
        setState(() {
          _announcements = data;
        });
      }
    } catch (e) {
      // ignore
    }
  }
  
  Future<void> _loadPendingTasks() async {
    try {
      final data = await ApiClient.instance.getPendingTasks(page: 1, pageSize: 5);
      if (mounted) {
        setState(() {
          _pendingTasksList = data is Map ? (data['items'] ?? []) : [];
        });
      }
    } catch (e) {
      // ignore
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF667eea),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: '任务'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: '公告'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 0) {
      return _buildDashboard();
    } else if (_currentIndex == 1) {
      return const TaskListPage();
    } else if (_currentIndex == 2) {
      return const AnnouncementListPage();
    } else {
      return const ProfilePage();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnnouncementBanner(),
          const SizedBox(height: 16),
          _buildWelcomeSection(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildPendingTasksList(),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBanner() {
    final announcement = _announcements.isNotEmpty 
        ? _announcements[_currentAnnouncementIndex] 
        : {'title': '欢迎使用绿色金融管理系统', 'created_at': '', 'view_count': 0};
    
    return GestureDetector(
      onTap: () {
        if (_announcements.isNotEmpty) {
          setState(() => _currentIndex = 2);
        }
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.campaign, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('系统公告', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(announcement['created_at']),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement['title'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                const Icon(Icons.visibility, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${announcement['view_count'] ?? 0}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_announcements.length > 1) ...[
                  const SizedBox(width: 16),
                  Text(
                    '${_currentAnnouncementIndex + 1}/${_announcements.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null || value == '') return '';
    final str = value.toString();
    if (str.length >= 10) {
      return '${str.substring(0, 4)}-${str.substring(5, 7)}-${str.substring(8, 10)}';
    }
    return str;
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _userName,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat(Icons.assignment_turned_in, '待办', _dashboardData['pending_count'] ?? 0),
              const SizedBox(width: 24),
              _buildMiniStat(Icons.check_circle, '已办', _dashboardData['completed_count'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, dynamic value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          '$label ${value is int ? value : 0}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'icon': Icons.account_balance, 'title': '绿色贷款余额', 'value': _dashboardData['green_loan_balance'] ?? '0', 'color': const Color(0xFF4CAF50)},
      {'icon': Icons.business_center, 'title': '绿色租赁', 'value': _dashboardData['green_leasing'] ?? '0', 'color': const Color(0xFF667eea)},
      {'icon': Icons.account_balance_wallet, 'title': '绿色理财', 'value': _dashboardData['green_wealth_management'] ?? '0', 'color': const Color(0xFF764ba2)},
      {'icon': Icons.trending_up, 'title': '绿色承销', 'value': _dashboardData['green_underwriting'] ?? '0', 'color': const Color(0xFF4DD0E1)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (stat['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stat['title'] as String,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                '${stat['value']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingTasksList() {
    if (_pendingTasksList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('暂无待办事项', style: TextStyle(color: Color(0xFF999999))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('待办事项 (${_pendingTasksList.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 1),
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingTasksList.length > 5 ? 5 : _pendingTasksList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final task = _pendingTasksList[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment, color: Color(0xFFFF9800), size: 20),
                ),
                title: Text(
                  '${task['customer_name'] ?? task['title'] ?? '任务'} ${_formatDate(task['disbursement_date'])}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  task['business_type'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskDetailPage(taskId: task['task_id'] ?? task['id'] ?? 0),
                    ),
                  );
                  if (result == true) {
                    _loadPendingTasks();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
