import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;
  
  static const String baseUrl = '/api';
  static const String clientType = 'app';
  
  String? _token;
  late SharedPreferences _prefs;
  http.Client? _client;
  
  static GlobalKey<NavigatorState>? navigatorKey;
  
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }
  
  http.Client get client {
    _client ??= http.Client();
    return _client!;
  }
  
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
  
  void handleUnauthorized() {
    clearToken();
    navigatorKey?.currentState?.pushReplacementNamed('/login');
  }
  
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
  
  String _getErrorMessage(dynamic response) {
    try {
      if (response is http.Response) {
        final body = jsonDecode(response.body);
        return body['detail'] ?? '操作失败';
      }
    } catch (e) {
      return '操作失败';
    }
    return '操作失败';
  }

  // 登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json', 'X-Client-Type': clientType},
      body: jsonEncode({'username': username, 'password': password}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['access_token'] != null) {
        setToken(data['access_token']);
        await _prefs.setString('token', data['access_token']);
        _prefs.setString('user_real_name', data['user']?['real_name'] ?? username);
      }
      return data;
    } else {
      throw Exception('登录失败: ${response.statusCode}');
    }
  }
  
  // 登出
  Future<void> logout() async {
    try {
      await client.post(
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
    final response = await client.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取用户信息失败');
    }
  }
  
  // 获取待办任务
  Future<dynamic> getPendingTasks({int page = 1, int pageSize = 20}) async {
    final response = await client.get(
      Uri.parse('$baseUrl/tasks/pending?page=$page&page_size=$pageSize'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取待办任务失败: ${response.statusCode}');
    }
  }
  
  // 获取已办任务
  Future<dynamic> getCompletedTasks({int page = 1, int pageSize = 20}) async {
    final response = await client.get(
      Uri.parse('$baseUrl/tasks/completed?page=$page&page_size=$pageSize'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取已办任务失败: ${response.statusCode}');
    }
  }
  
  // 获取办结任务
  Future<dynamic> getArchivedTasks({int page = 1, int pageSize = 20}) async {
    final response = await client.get(
      Uri.parse('$baseUrl/tasks/archived?page=$page&page_size=$pageSize'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取办结任务失败: ${response.statusCode}');
    }
  }
  
  // 获取任务详情
  Future<Map<String, dynamic>> getTaskDetail(int taskId) async {
    print('getTaskDetail called with taskId: $taskId');
    print('baseUrl: $baseUrl');
    final response = await client.get(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: _headers,
    );
    print('Task response status: ${response.statusCode}');
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Task data status field: ${data['status']}');
      try {
        final identificationId = data['identification_id'] ?? taskId;
        print('Fetching workflow for identificationId: $identificationId');
        final workflowResponse = await client.get(
          Uri.parse('$baseUrl/identifications/$identificationId/workflow'),
          headers: _headers,
        );
        print('Workflow response status: ${workflowResponse.statusCode}');
        if (workflowResponse.statusCode == 200) {
          data['workflow_history'] = jsonDecode(workflowResponse.body);
          print('Workflow history loaded: ${data['workflow_history']}');
        }
      } catch (e) {
        print('获取工作流历史失败: $e');
      }
      return data;
    } else {
      throw Exception('获取任务详情失败');
    }
  }
  
  // 获取流程跟踪
  Future<dynamic> getWorkflowHistory(int taskId) async {
    final response = await client.get(
      Uri.parse('$baseUrl/identifications/$taskId/workflow'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  // 完成任务/审批
  Future<Map<String, dynamic>> completeTask(int taskId, Map<String, dynamic> data) async {
    final response = await client.post(
      Uri.parse('$baseUrl/tasks/$taskId/complete'),
      headers: _headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // 暂存任务
  Future<Map<String, dynamic>> saveTask(int taskId, Map<String, dynamic> data) async {
    final response = await client.post(
      Uri.parse('$baseUrl/tasks/$taskId/save'),
      headers: _headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // 退回任务
  Future<Map<String, dynamic>> returnTask(int taskId, Map<String, dynamic> data) async {
    final response = await client.post(
      Uri.parse('$baseUrl/tasks/$taskId/return'),
      headers: _headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // 撤回任务
  Future<Map<String, dynamic>> withdrawTask(int taskId) async {
    final response = await client.post(
      Uri.parse('$baseUrl/tasks/$taskId/withdraw'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // 获取绿色项目分类目录
  Future<dynamic> getGreenCategories() async {
    final response = await client.get(
      Uri.parse('$baseUrl/green-categories'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取分类目录失败');
    }
  }
  
  // 获取系统公告列表
  Future<dynamic> getAnnouncements({int page = 1, int pageSize = 20}) async {
    try {
      final url = '$baseUrl/announcements/?skip=${(page-1)*pageSize}&limit=$pageSize';
      final response = await client.get(
        Uri.parse(url),
        headers: _headers,
      );
      
      if (response.statusCode == 401) {
        handleUnauthorized();
        throw Exception('登录已过期，请重新登录');
      }
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('获取公告列表失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // 获取仪表盘数据
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await client.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取仪表盘数据失败');
    }
  }
  
  // 获取贷款余额趋势
  Future<List<dynamic>> getLoanBalanceTrend() async {
    final response = await client.get(
      Uri.parse('$baseUrl/charts/loan-balance-trend'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取贷款余额趋势失败');
    }
  }
  
  // 获取放款趋势
  Future<List<dynamic>> getDisbursementTrend() async {
    final response = await client.get(
      Uri.parse('$baseUrl/charts/disbursement-trend'),
      headers: _headers,
    );
    
    if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception('登录已过期，请重新登录');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取放款趋势失败');
    }
  }
  
  // 获取绿色分类分布
  Future<List<dynamic>> getGreenCategoryDistribution() async {
    final response = await client.get(
      Uri.parse('$baseUrl/charts/green-category-distribution'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取绿色分类分布失败');
    }
  }
}
