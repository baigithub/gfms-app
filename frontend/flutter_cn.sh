#!/bin/bash
# Flutter依赖下载加速脚本

# 配置Flutter镜像
export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
export PUB_CACHE=~/.pub-cache
export PUB_HOSTED_URL=https://pub.flutter-io.cn

echo "=== Flutter 镜像配置 ==="
echo "Flutter: https://mirrors.tuna.tsinghua.edu.cn/flutter"
echo "Pub: https://pub.flutter-io.cn"
echo ""

# 进入项目目录
cd "$(dirname "$0")"

# 运行flutter命令
flutter "$@"
