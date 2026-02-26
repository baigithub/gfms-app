#!/bin/bash

#===============================================================================
# 绿色金融App服务重启脚本
# 功能：停止旧服务、清理缓存、重新构建、启动所有服务、自动验证
#===============================================================================

set -e

echo "=========================================="
echo "  绿色金融管理系统 - 服务重启脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目目录
PROJECT_DIR="/Users/bryant/Trae/gfms-app"
FRONTEND_DIR="$PROJECT_DIR/frontend"
PROXY_PORT=8080
WEB_PORT=8082

#===============================================================================
# 0. 强制杀死占用端口的进程
#===============================================================================
echo -e "${YELLOW}[0/6] 强制停止占用端口的进程...${NC}"

# 强制杀死8080端口进程
if lsof -i :$PROXY_PORT >/dev/null 2>&1; then
    PIDS=$(lsof -t -i :$PROXY_PORT)
    for pid in $PIDS; do
        kill -9 $pid 2>/dev/null || true
    done
    sleep 1
    echo -e "  ${GREEN}✓${NC} 端口 $PROXY_PORT 已释放"
fi

# 强制杀死8082端口进程
if lsof -i :$WEB_PORT >/dev/null 2>&1; then
    PIDS=$(lsof -t -i :$WEB_PORT)
    for pid in $PIDS; do
        kill -9 $pid 2>/dev/null || true
    done
    sleep 1
    echo -e "  ${GREEN}✓${NC} 端口 $WEB_PORT 已释放"
fi

# 停止可能存在的Flutter进程
pkill -f "flutter run" 2>/dev/null || true
pkill -f "http.server $WEB_PORT" 2>/dev/null || true
pkill -f "cors_proxy" 2>/dev/null || true

echo ""

#===============================================================================
# 1. 停止现有服务（确保完全停止）
#===============================================================================
echo -e "${YELLOW}[1/6] 验证服务已停止...${NC}"

# 等待端口释放
sleep 2

# 验证端口已释放
if lsof -i :$PROXY_PORT >/dev/null 2>&1; then
    echo -e "  ${RED}✗${NC} 端口 $PROXY_PORT 仍被占用，尝试强制杀死..."
    fuser -k $PROXY_PORT/tcp 2>/dev/null || true
    sleep 1
fi

if lsof -i :$WEB_PORT >/dev/null 2>&1; then
    echo -e "  ${RED}✗${NC} 端口 $WEB_PORT 仍被占用，尝试强制杀死..."
    fuser -k $WEB_PORT/tcp 2>/dev/null || true
    sleep 1
fi

echo -e "  ${GREEN}✓${NC} 端口已释放"
echo ""

#===============================================================================
# 2. 清理缓存
#===============================================================================
echo -e "${YELLOW}[2/6] 清理缓存...${NC}"

# 清理Flutter构建缓存
if [ -d "$FRONTEND_DIR/.dart_tool" ]; then
    rm -rf "$FRONTEND_DIR/.dart_tool"
    echo -e "  ${GREEN}✓${NC} Flutter .dart_tool 缓存已清理"
fi

# 清理Flutter web构建缓存
if [ -d "$FRONTEND_DIR/build/web" ]; then
    rm -rf "$FRONTEND_DIR/build/web"
    echo -e "  ${GREEN}✓${NC} Flutter web构建缓存已清理"
fi

# 清理pubspec.lock重新获取依赖
if [ -f "$FRONTEND_DIR/pubspec.lock" ]; then
    rm -f "$FRONTEND_DIR/pubspec.lock"
    echo -e "  ${GREEN}✓${NC} pubspec.lock 已清理"
fi

echo ""

#===============================================================================
# 3. 重新获取依赖
#===============================================================================
echo -e "${YELLOW}[3/6] 获取Flutter依赖...${NC}"
cd "$FRONTEND_DIR"
flutter pub get
echo ""

#===============================================================================
# 4. 构建Flutter Web应用
#===============================================================================
echo -e "${YELLOW}[4/6] 构建Flutter Web应用...${NC}"
flutter build web
echo ""

#===============================================================================
# 5. 启动服务
#===============================================================================
echo -e "${YELLOW}[5/6] 启动服务...${NC}"

# 启动CORS代理
cd "$PROJECT_DIR"
python3 cors_proxy.py > /tmp/cors_proxy.log 2>&1 &
echo -e "  ${GREEN}✓${NC} CORS代理已启动 (端口 $PROXY_PORT)"

# 等待代理启动
sleep 2

# 启动Web服务器
cd "$FRONTEND_DIR/build/web"
python3 -m http.server $WEB_PORT > /tmp/web_server.log 2>&1 &
echo -e "  ${GREEN}✓${NC} Web服务器已启动 (端口 $WEB_PORT)"

# 等待Web服务器启动
sleep 1

echo ""

#===============================================================================
# 6. 验证服务
#===============================================================================
echo -e "${YELLOW}[6/6] 验证服务...${NC}"

# 验证Web服务器
WEB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$WEB_PORT/ 2>/dev/null || echo "000")
if [ "$WEB_STATUS" = "200" ]; then
    echo -e "  ${GREEN}✓${NC} Web服务器正常 (HTTP $WEB_STATUS)"
else
    echo -e "  ${RED}✗${NC} Web服务器异常 (HTTP $WEB_STATUS)"
    exit 1
fi

# 验证CORS代理 - 测试OPTIONS请求
OPTIONS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PROXY_PORT/api/auth/login -X OPTIONS 2>/dev/null || echo "000")
if [ "$OPTIONS_STATUS" = "200" ]; then
    echo -e "  ${GREEN}✓${NC} CORS代理OPTIONS正常 (HTTP $OPTIONS_STATUS)"
else
    echo -e "  ${RED}✗${NC} CORS代理OPTIONS异常 (HTTP $OPTIONS_STATUS)"
    exit 1
fi

# 验证CORS代理 - 测试POST请求
echo -e "  ${BLUE}→${NC} 测试登录API..."

# 使用curl获取完整响应头
RESPONSE=$(curl -s -i -X POST http://localhost:$PROXY_PORT/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' 2>/dev/null)

# 分离响应头和响应体
RESPONSE_HEADERS=$(echo "$RESPONSE" | sed -n '1,/^\r*$/p')
RESPONSE_BODY=$(echo "$RESPONSE" | sed '1,/^\r*$/d')

# 检查响应头是否有重复
DUPLICATE_COUNT=$(echo "$RESPONSE_HEADERS" | grep -i "^content-type:" | wc -l)
CONTENT_TYPE_COUNT=$(echo "$RESPONSE_HEADERS" | grep -i "^Content-Type:" | wc -l)

if [ "$DUPLICATE_COUNT" -gt 1 ] || [ "$CONTENT_TYPE_COUNT" -gt 1 ]; then
    echo -e "  ${RED}✗${NC} 响应头有重复的Content-Type！"
    echo "  响应头："
    echo "$RESPONSE_HEADERS"
    exit 1
fi

# 检查Content-Type头
if echo "$RESPONSE_HEADERS" | grep -qi "^content-type:.*application/json"; then
    echo -e "  ${GREEN}✓${NC} CORS代理返回正确的Content-Type头"
else
    echo -e "  ${RED}✗${NC} CORS代理缺少Content-Type头！"
    echo "  响应头："
    echo "$RESPONSE_HEADERS"
    exit 1
fi

# 检查Content-Length头是否重复
DUPLICATE_LENGTH=$(echo "$RESPONSE_HEADERS" | grep -i "^content-length:" | wc -l)
if [ "$DUPLICATE_LENGTH" -gt 1 ]; then
    echo -e "  ${RED}✗${NC} 响应头有重复的Content-Length！"
    echo "  响应头："
    echo "$RESPONSE_HEADERS"
    exit 1
fi

# 测试实际登录
if echo "$RESPONSE_BODY" | grep -q "access_token"; then
    echo -e "  ${GREEN}✓${NC} 登录API返回正确 (包含access_token)"
else
    echo -e "  ${RED}✗${NC} 登录API返回异常"
    echo "  响应：$RESPONSE_BODY"
    exit 1
fi

echo ""

#===============================================================================
# 完成
#===============================================================================
echo "=========================================="
echo -e "${GREEN}  所有服务启动并验证通过！${NC}"
echo "=========================================="
echo ""
echo "访问地址: ${BLUE}http://localhost:$WEB_PORT${NC}"
echo ""
echo "日志查看:"
echo "  - CORS代理: ${BLUE}tail -f /tmp/cors_proxy.log${NC}"
echo "  - Web服务器: ${BLUE}tail -f /tmp/web_server.log${NC}"
echo ""
echo "Flutter日志:"
echo "  - 页面右下角有 Console 按钮可查看日志"
echo ""
