import 'package:flutter/material.dart';
import '../api/api_client.dart';
import 'task_detail_page.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingTasks = [];
  List<dynamic> _completedTasks = [];
  List<dynamic> _archivedTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final pendingData = await ApiClient.instance.getPendingTasks();
      final completedData = await ApiClient.instance.getCompletedTasks();
      final archivedData = await ApiClient.instance.getArchivedTasks();
      if (mounted) {
        setState(() {
          _pendingTasks = _extractItems(pendingData);
          _completedTasks = _extractItems(completedData);
          _archivedTasks = _extractItems(archivedData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List) return data;
    if (data is Map) return data['items'] ?? [];
    return [];
  }

  String _formatDate(dynamic value) {
    if (value == null || value == '') return '';
    final str = value.toString();
    if (str.length >= 10) {
      return '${str.substring(0, 4)}-${str.substring(5, 7)}-${str.substring(8, 10)}';
    }
    return str;
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value == '') return '';
    final str = value.toString();
    if (str.length >= 19) {
      return '${str.substring(0, 4)}-${str.substring(5, 7)}-${str.substring(8, 10)} ${str.substring(11, 19)}';
    } else if (str.length >= 10) {
      return '${str.substring(0, 4)}-${str.substring(5, 7)}-${str.substring(8, 10)}';
    }
    return str;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: '待处理 (${_pendingTasks.length})'),
            Tab(text: '已完成 (${_completedTasks.length})'),
            Tab(text: '已归档 (${_archivedTasks.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskListContent(_pendingTasks),
                _buildTaskListContent(_completedTasks),
                _buildTaskListContent(_archivedTasks),
              ],
            ),
    );
  }

  Widget _buildTaskListContent(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: Text('暂无任务'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final customerName = task['customer_name'] ?? task['title'] ?? '任务';
        final loanDate = _formatDate(task['disbursement_date'] ?? task['created_at'] ?? '');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(loanDate, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task['id']))),
          ),
        );
      },
    );
  }
}
