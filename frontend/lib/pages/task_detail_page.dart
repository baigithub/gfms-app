import 'package:flutter/material.dart';
import '../api/api_client.dart';

class TaskDetailPage extends StatefulWidget {
  final int taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _taskDetail = {};
  List<dynamic> _categoryOptions = [];
  List<dynamic> _selectedCategory = [];
  final TextEditingController _opinionController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTaskDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _opinionController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskDetail() async {
    try {
      final data = await ApiClient.instance.getTaskDetail(widget.taskId);
      final categories = await ApiClient.instance.getGreenCategories();
      if (mounted) {
        setState(() {
          _taskDetail = data is Map ? data : {};
          _categoryOptions = _buildCategoryTree(categories);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _buildCategoryTree(dynamic categories) {
    if (categories is! List) return [];
    
    final largeMap = <String, Map<String, dynamic>>{};
    
    for (var cat in categories) {
      final largeCode = cat['large_code']?.toString() ?? '';
      final largeName = cat['large_name']?.toString() ?? '';
      final mediumCode = cat['medium_code']?.toString() ?? '';
      final mediumName = cat['medium_name']?.toString() ?? '';
      final smallCode = cat['small_code']?.toString() ?? '';
      final smallName = cat['small_name']?.toString() ?? '';
      
      if (largeCode.isNotEmpty && largeName.isNotEmpty) {
        if (!largeMap.containsKey(largeCode)) {
          largeMap[largeCode] = {
            'value': largeCode,
            'label': '$largeCode $largeName',
            'children': <Map<String, dynamic>>[],
          };
        }
        
        if (mediumCode.isNotEmpty && mediumName.isNotEmpty) {
          final largeChildren = largeMap[largeCode]!['children'] as List;
          var mediumNode = largeChildren.firstWhere(
            (m) => m['value'] == mediumCode,
            orElse: () => null,
          );
          
          if (mediumNode == null) {
            mediumNode = {
              'value': mediumCode,
              'label': '$mediumCode $mediumName',
              'children': <Map<String, dynamic>>[],
            };
            largeChildren.add(mediumNode);
          }
          
          if (smallCode.isNotEmpty && smallName.isNotEmpty) {
            final mediumChildren = mediumNode['children'] as List;
            mediumChildren.add({
              'value': smallCode,
              'label': '$smallCode $smallName',
            });
          }
        }
      }
    }
    
    return largeMap.values.toList();
  }

  Future<void> _submitTask(String action) async {
    if (_isSubmitting) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final data = {
        'comment': _opinionController.text,
        'category_code': _selectedCategory.isNotEmpty ? _selectedCategory.last : null,
      };
      
      if (action == 'save') {
        await ApiClient.instance.saveTask(widget.taskId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂存成功')),
          );
        }
      } else if (action == 'return') {
        await ApiClient.instance.returnTask(widget.taskId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('退回成功')),
          );
          Navigator.pop(context);
        }
      } else if (action == 'complete') {
        await ApiClient.instance.completeTask(widget.taskId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('提交成功')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _canReturn {
    final history = _taskDetail['workflow_history'] as List<dynamic>? ?? [];
    final currentTask = history.firstWhere(
      (h) => h['status'] == '待处理',
      orElse: () => null,
    );
    if (currentTask == null) return false;
    final taskKey = currentTask['task_key']?.toString() ?? '';
    return taskKey != 'manager_identification';
  }

  bool get _isPendingTask {
    final status = _taskDetail['status']?.toString() ?? '';
    return status == '待处理' || status == '办理中';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('任务详情'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF667eea),
          indicatorWeight: 3,
          labelColor: const Color(0xFF667eea),
          unselectedLabelColor: const Color(0xFF999999),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: '业务信息'),
            Tab(text: '审批记录'),
            Tab(text: '流程跟踪'),
            Tab(text: '绿色分类'),
            Tab(text: '附件'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _error != ''
              ? Center(child: Text('加载失败: $_error', style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBusinessInfo(),
                          _buildApprovalRecords(),
                          _buildFlowTrack(),
                          _buildCategoryTrack(),
                          _buildAttachments(),
                        ],
                      ),
                    ),
                    if (_isPendingTask) _buildActionButtons(),
                  ],
                ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category, color: Color(0xFF4CAF50), size: 20),
              SizedBox(width: 8),
              Text('绿色金融支持项目目录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _buildCascaderSelector(),
        ],
      ),
    );
  }

  Widget _buildCascaderSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildCategoryChips(),
          ),
          if (_categoryOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text('选择分类:', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
            const SizedBox(height: 8),
            _buildLargeCategorySelector(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCategoryChips() {
    if (_selectedCategory.isEmpty) return [];
    
    final chips = <Widget>[];
    for (int i = 0; i < _selectedCategory.length; i++) {
      final code = _selectedCategory[i];
      final label = _getCategoryLabel(code);
      chips.add(
        Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() {
              _selectedCategory = _selectedCategory.sublist(0, i);
            });
          },
          backgroundColor: const Color(0xFFE8F5E9),
          labelStyle: const TextStyle(color: Color(0xFF4CAF50)),
        ),
      );
    }
    return chips;
  }

  String _getCategoryLabel(String code) {
    for (var large in _categoryOptions) {
      if (large['value'] == code) return large['label'];
      if (large['children'] != null) {
        for (var medium in large['children']) {
          if (medium['value'] == code) return medium['label'];
          if (medium['children'] != null) {
            for (var small in medium['children']) {
              if (small['value'] == code) return small['label'];
            }
          }
        }
      }
    }
    return code;
  }

  Widget _buildLargeCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('一级分类', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoryOptions.map((large) {
            final isSelected = _selectedCategory.isNotEmpty && _selectedCategory[0] == large['value'];
            return ChoiceChip(
              label: Text(large['label']?.toString() ?? '', style: TextStyle(fontSize: 12)),
              selected: isSelected,
              selectedColor: const Color(0xFF667eea),
              onSelected: (selected) {
                setState(() {
                  if (selected && large['children'] != null && (large['children'] as List).isNotEmpty) {
                    _selectedCategory = [large['value']];
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_selectedCategory.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMediumCategorySelector(_selectedCategory[0]),
        ],
      ],
    );
  }

  Widget _buildMediumCategorySelector(String largeCode) {
    final large = _categoryOptions.firstWhere(
      (l) => l['value'] == largeCode,
      orElse: () => null,
    );
    if (large == null || large['children'] == null) return const SizedBox();
    
    final mediums = large['children'] as List;
    if (mediums.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('二级分类', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: mediums.map((medium) {
            final isSelected = _selectedCategory.length > 1 && _selectedCategory[1] == medium['value'];
            return ChoiceChip(
              label: Text(medium['label']?.toString() ?? '', style: TextStyle(fontSize: 12)),
              selected: isSelected,
              selectedColor: const Color(0xFF667eea),
              onSelected: (selected) {
                setState(() {
                  if (selected && medium['children'] != null && (medium['children'] as List).isNotEmpty) {
                    _selectedCategory = [largeCode, medium['value']];
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_selectedCategory.length > 1) ...[
          const SizedBox(height: 16),
          _buildSmallCategorySelector(largeCode, _selectedCategory[1]),
        ],
      ],
    );
  }

  Widget _buildSmallCategorySelector(String largeCode, String mediumCode) {
    final large = _categoryOptions.firstWhere(
      (l) => l['value'] == largeCode,
      orElse: () => null,
    );
    if (large == null || large['children'] == null) return const SizedBox();
    
    final mediums = large['children'] as List;
    final medium = mediums.firstWhere(
      (m) => m['value'] == mediumCode,
      orElse: () => null,
    );
    if (medium == null || medium['children'] == null) return const SizedBox();
    
    final smalls = medium['children'] as List;
    if (smalls.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('三级分类', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: smalls.map((small) {
            final isSelected = _selectedCategory.length > 2 && _selectedCategory[2] == small['value'];
            return ChoiceChip(
              label: Text(small['label']?.toString() ?? '', style: TextStyle(fontSize: 12)),
              selected: isSelected,
              selectedColor: const Color(0xFF4CAF50),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategory = [largeCode, mediumCode, small['value']];
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Map<String, dynamic>> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: const Color(0xFF667eea), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) => _buildInfoRow(item['label'], item['value'])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInfo() {
    final info = [
      {'label': '贷款编号', 'value': _safeToString(_taskDetail['loan_code'])},
      {'label': '客户名称', 'value': _safeToString(_taskDetail['customer_name'])},
      {'label': '业务品种', 'value': _safeToString(_taskDetail['business_type'])},
      {'label': '贷款账号', 'value': _safeToString(_taskDetail['loan_account'])},
      {'label': '放款金额', 'value': _formatAmount(_taskDetail['loan_amount'])},
      {'label': '放款日期', 'value': _formatDate(_taskDetail['disbursement_date'])},
      {'label': 'ESG风险等级', 'value': _safeToString(_taskDetail['esg_risk_level'])},
      {'label': 'ESG表现等级', 'value': _safeToString(_taskDetail['esg_performance_level'])},
      {'label': '办结时间', 'value': _formatDateTime(_taskDetail['completed_at'])},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        children: [
          _buildInfoCard('基本信息', info),
          _buildCategorySelector(),
          _buildOpinionInput(),
        ],
      ),
    );
  }

  Widget _buildOpinionInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.comment, color: Color(0xFF667eea), size: 20),
              SizedBox(width: 8),
              Text('办理意见', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _opinionController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '请输入办理意见',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF667eea)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('关闭'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _isSubmitting ? null : () => _submitTask('save'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: const BorderSide(color: Color(0xFF667eea)),
              foregroundColor: const Color(0xFF667eea),
            ),
            child: const Text('暂存'),
          ),
          const Spacer(),
          if (_canReturn) ...[
            OutlinedButton(
              onPressed: _isSubmitting ? null : () => _submitTask('return'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                side: const BorderSide(color: Color(0xFFFF9800)),
                foregroundColor: const Color(0xFFFF9800),
              ),
              child: const Text('退回'),
            ),
            const SizedBox(width: 12),
          ],
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => _submitTask('complete'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('提交审批'),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalRecords() {
    final history = _taskDetail['workflow_history'] as List<dynamic>? ?? [];
    final approvals = history.where((h) => h['status'] == '已完成' && h['approval_result'] != null).toList();

    if (approvals.isEmpty) {
      return _buildEmptyState('暂无审批记录', Icons.approval);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: approvals.asMap().entries.map((entry) {
          final index = entry.key;
          final a = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: const Color(0xFF667eea), borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_safeToString(a['task_name']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: a['status'] == '已完成' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _safeToString(a['status']),
                          style: TextStyle(color: a['status'] == '已完成' ? const Color(0xFF4CAF50) : const Color(0xFFFF9800), fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow('审批人姓名', _safeToString(a['assignee_name'])),
                      _buildInfoRow('审批人岗位', _safeToString(a['position_name'] ?? '-')),
                      _buildInfoRow('办理完成时间', _formatDateTime(a['completed_at'])),
                      if (a['approval_result'] != null) _buildInfoRow('审批结果', _safeToString(a['approval_result'])),
                      if (a['comment'] != null && a['comment'].toString().isNotEmpty) _buildInfoRow('审批意见', _safeToString(a['comment'])),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFlowTrack() {
    final history = _taskDetail['workflow_history'] as List<dynamic>? ?? [];
    
    if (history.isEmpty) {
      return _buildEmptyState('暂无流程跟踪', Icons.timeline);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: history.asMap().entries.map((entry) {
                final index = entry.key;
                final h = entry.value;
                final isLast = index == history.length - 1;
                final time = _formatDateTime(h['started_at']);
                final action = h['approval_result'] == '同意' ? '提交审批' : '退回';
                
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: h['status'] == '待处理' ? const Color(0xFFFF9800) : const Color(0xFF667eea),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 50,
                            color: const Color(0xFFE0E0E0),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '由${_safeToString(h['assignee_name'] ?? '-')}于$time $action',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTrack() {
    final history = _taskDetail['workflow_history'] as List<dynamic>? ?? [];
    final categoryHistory = history.where((h) => h['formatted_category'] != null && h['formatted_category'].toString().isNotEmpty).toList();

    if (categoryHistory.isEmpty) {
      return _buildEmptyState('暂无绿色分类变动', Icons.category);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: categoryHistory.map((h) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.category, color: Color(0xFF4CAF50), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_safeToString(h['task_name']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateTime(h['completed_at'] ?? h['started_at']),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _safeToString(h['status']),
                          style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('绿色分类', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Text(
                          _safeToString(h['formatted_category']),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttachments() {
    final attachments = _taskDetail['attachments'] as List<dynamic>? ?? [];

    if (attachments.isEmpty) {
      return _buildEmptyState('暂无附件', Icons.attach_file);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final a = entry.value;
                final isLast = index == attachments.length - 1;
                
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.insert_drive_file, color: Color(0xFF667eea), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _safeToString(a['original_filename']),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_safeToString(a['task_name'])} | ${_safeToString(a['file_size'])}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_safeToString(a['uploader_name']), style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                              const SizedBox(height: 4),
                              Text(_formatDateTime(a['created_at']), style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Color(0xFF667eea)),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFFE0E0E0)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16, color: Color(0xFF999999))),
        ],
      ),
    );
  }

  String _safeToString(dynamic value) {
    if (value == null) return '-';
    return value.toString();
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value == '') return '-';
    final str = value.toString();
    if (str.length >= 19) {
      return '${str.substring(0, 4)}-${str.substring(5, 7)}-${str.substring(8, 10)} ${str.substring(11, 19)}';
    } else if (str.length >= 10) {
      return '${str.substring(0, 4)}-${str.substring(5, 7)}-${str.substring(8, 10)}';
    }
    return str;
  }

  String _formatDate(dynamic value) {
    if (value == null || value == '') return '-';
    final str = value.toString();
    if (str.length >= 10) {
      return '${str.substring(0, 4)}-${str.substring(5, 7)}-${str.substring(8, 10)}';
    }
    return str;
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '-';
    if (value is num) return value.toStringAsFixed(2);
    final numValue = num.tryParse(value.toString());
    if (numValue == null) return value.toString();
    return numValue.toStringAsFixed(2);
  }
}
