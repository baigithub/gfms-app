import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;
  
  static const String baseUrl = 'http://localhost:8000/api';
  static const String clientType = 'app'; // 客户端类型：pc, app, mini_program, official_account
  
  String? _token;
  late SharedPreferences _prefs;
  
  ApiClient._internal();
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString('token');
  }
  
  void setToken(String token) {
    _token = token;
    _prefs.setString('token', token);
  }
  
  void clearToken() {
    _token = null;
    _prefs.remove('token');
  }
  
  String? get token => _token;
  
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'X-Client-Type': clientType,
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }
  
  // 登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json', 'X-Client-Type': clientType},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final body = response.body;
      if (body.isEmpty) {
        throw Exception('登录失败：服务器返回空响应');
      }
      final data = jsonDecode(body);
      if (data['access_token'] != null) {
        setToken(data['access_token']);
        _prefs.setString('user_real_name', data['user']?['real_name'] ?? username);
      }
      return data;
    } else {
      final body = response.body;
      String errorMsg = '登录失败';
      if (body.isNotEmpty) {
        try {
          errorMsg = jsonDecode(body)['detail'] ?? errorMsg;
        } catch (_) {
          errorMsg = body;
        }
      }
      throw Exception(errorMsg);
    }
  }
  
  // 登出
  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      );
    } finally {
      clearToken();
      await _prefs.remove('user_real_name');
    }
  }
  
  // 获取用户信息
  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取用户信息失败');
    }
  }
  
  // 获取待办任务
  Future<dynamic> getPendingTasks({int page = 1, int pageSize = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/pending?skip=${(page-1)*pageSize}&limit=$pageSize'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取待办任务失败');
    }
  }
  
  // 获取已办任务
  Future<dynamic> getCompletedTasks({int page = 1, int pageSize = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/completed?skip=${(page-1)*pageSize}&limit=$pageSize'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取已办任务失败');
    }
  }
  
  // 获取办结任务
  Future<dynamic> getArchivedTasks({int page = 1, int pageSize = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/archived?skip=${(page-1)*pageSize}&limit=$pageSize'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取办结任务失败');
    }
  }
  
  // 获取任务详情
  Future<Map<String, dynamic>> getTaskDetail(int taskId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // 同时获取流程跟踪数据
      try {
        final workflowResponse = await http.get(
          Uri.parse('$baseUrl/identifications/$taskId/workflow'),
          headers: _headers,
        );
        if (workflowResponse.statusCode == 200) {
          data['workflow_history'] = jsonDecode(workflowResponse.body);
        }
      } catch (_) {}
      return data;
    } else {
      throw Exception('获取任务详情失败');
    }
  }
  
  // 获取流程跟踪
  Future<dynamic> getWorkflowHistory(int taskId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/identifications/$taskId/workflow'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }
  
  // 完成任务/审批
  Future<Map<String, dynamic>> completeTask(int taskId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/complete'),
      headers: _headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? '操作失败');
    }
  }

  // 暂存任务
  Future<Map<String, dynamic>> saveTask(int taskId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/save'),
      headers: _headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? '暂存失败');
    }
  }

  // 退回任务
  Future<Map<String, dynamic>> returnTask(int taskId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/return'),
      headers: _headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? '退回失败');
    }
  }

  // 获取绿色项目分类目录
  Future<dynamic> getGreenCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/green-categories'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }
  
  // 获取系统公告列表
  Future<dynamic> getAnnouncements({int page = 1, int pageSize = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/announcements?skip=${(page-1)*pageSize}&limit=$pageSize'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取公告列表失败');
    }
  }
  
  // 获取仪表盘数据
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取仪表盘数据失败');
    }
  }
}
