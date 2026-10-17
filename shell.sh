#!/bin/bash
# Wan2GP Docker 部署脚本
# 所有文件都在项目目录中，通过 WSL2 挂载路径访问
# 使用方法: ./shell.sh [all|build|up|down|logs|restart]

echo -e "\033[32;40m========== Wan2GP Docker 部署 ==========\033[0m"

# 配置
PROJECT_DIR="/mnt/d/MyWork/Project/My/Wan2GP"
NETWORK_NAME="wan2gp-network"

# 确保项目中的必要目录存在
mkdir -p "$PROJECT_DIR"/{ckpts,outputs}

# 进入项目目录
cd "$PROJECT_DIR"

case $1 in
"down")
    echo -e "\033[31m 停止服务...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml down
    ;;

"up")
    echo -e "\033[32m 启动服务...\033[0m"
    docker network create "$NETWORK_NAME" 2>/dev/null || true
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml up -d
    echo -e "\033[32m✓ 服务已启动\033[0m"
    docker ps --filter "name=wan2gp"
    ;;

"build")
    echo -e "\033[33m 构建镜像...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml build --no-cache
    echo -e "\033[32m✓ 镜像构建完成\033[0m"
    ;;

"rebuild")
    echo -e "\033[33m 重新构建镜像（使用缓存）...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml build
    echo -e "\033[32m✓ 镜像构建完成\033[0m"
    ;;

"restart")
    echo -e "\033[33m 重启服务...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml restart
    echo -e "\033[32m✓ 服务已重启\033[0m"
    docker ps --filter "name=wan2gp"
    ;;

"quick")
    echo -e "\033[33m 快速更新（复制yml + 重启容器，不重新构建镜像）...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml down
    echo -e "\033[32m 启动服务...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml up -d
    echo -e "\033[32m✓ 快速更新完成！\033[0m"
    docker ps --filter "name=wan2gp"
    ;;

"logs")
    echo -e "\033[36m 查看日志 (Ctrl+C 退出)...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml logs -f
    ;;

"wheels")
    echo -e "\033[33m 准备 wheels（复用 LongLive + 下载 Wan2GP 特有）...\033[0m"
    bash "$PROJECT_DIR/download_wheels.sh"
    ;;

"all")
    echo -e "\033[32m 完整部署流程...\033[0m"

    # 检查 wheels 目录
    if [ ! -d "$PROJECT_DIR/wheels" ] || [ -z "$(ls -A "$PROJECT_DIR/wheels" 2>/dev/null)" ]; then
        echo -e "\033[33m wheels 目录不存在，先准备 wheels...\033[0m"
        bash "$PROJECT_DIR/download_wheels.sh"
    fi

    echo -e "\033[33m 检查网络...\033[0m"
    docker network create "$NETWORK_NAME" 2>/dev/null || true

    echo -e "\033[31m 停止旧容器...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml down

    echo -e "\033[33m 构建镜像...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml build --no-cache

    echo -e "\033[32m 启动服务...\033[0m"
    docker-compose -f /home/docker_yml/wan2gp/docker-compose.yml up -d

    echo -e "\033[33m 清理缓存...\033[0m"
    docker system prune -f

    echo -e "\033[32m✓ 部署完成！\033[0m"
    docker ps --filter "name=wan2gp"
    echo ""
    echo -e "\033[36m 挂载目录:\033[0m"
    echo "   ckpts   → $PROJECT_DIR/ckpts (模型权重, 只读)"
    echo "   outputs → $PROJECT_DIR/outputs (生成结果)"
    echo "   hf-cache → Docker volume (HF辅助文件缓存)"
    echo ""
    echo -e "\033[36m Web UI: http://localhost:7860\033[0m"
    echo -e "\033[36m 查看日志: ./shell.sh logs\033[0m"
    ;;

*)
    echo -e "\033[31m========== 使用方法 ==========\033[0m"
    echo "  ./shell.sh all      - 完整部署（停止+构建+启动）"
    echo "  ./shell.sh build    - 构建镜像（无缓存）"
    echo "  ./shell.sh rebuild  - 构建镜像（使用缓存）"
    echo "  ./shell.sh up       - 启动服务"
    echo "  ./shell.sh down     - 停止服务"
    echo "  ./shell.sh restart  - 重启服务"
    echo "  ./shell.sh quick    - 快速更新（只更新yml+重启，不构建镜像）"
    echo "  ./shell.sh logs     - 查看日志"
    echo "  ./shell.sh wheels   - 准备 Docker wheels（首次构建前执行）"
    echo -e "\033[31m================================\033[0m"
    exit 1
    ;;
esac
