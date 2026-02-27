#!/bin/bash

# 短信同步服务器快速部署脚本
# 使用方法: chmod +x deploy.sh && ./deploy.sh

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  短信同步服务器快速部署${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. 进入项目目录
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}首次部署，将安装依赖...${NC}"
fi

# 2. 安装依赖
echo -e "${GREEN}[1/5] 安装依赖...${NC}"
npm install --production

if [ $? -ne 0 ]; then
    echo -e "${RED}依赖安装失败！${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 依赖安装完成${NC}"
echo ""

# 3. 停止旧进程
echo -e "${GREEN}[2/5] 停止旧进程...${NC}"
pm2 stop sms-sync-server 2>/dev/null
pm2 delete sms-sync-server 2>/dev/null
echo -e "${GREEN}✓ 旧进程已清理${NC}"
echo ""

# 4. 启动新进程
echo -e "${GREEN}[3/5] 启动服务...${NC}"
pm2 start index.js --name sms-sync-server

if [ $? -ne 0 ]; then
    echo -e "${RED}服务启动失败！${NC}"
    echo -e "${YELLOW}查看错误日志: pm2 logs sms-sync-server --err${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 服务已启动${NC}"
echo ""

# 5. 保存 PM2 配置
echo -e "${GREEN}[4/5] 保存 PM2 配置...${NC}"
pm2 save
echo -e "${GREEN}✓ PM2 配置已保存${NC}"
echo ""

# 6. 配置防火墙
echo -e "${GREEN}[5/5] 配置防火墙...${NC}"
sudo ufw allow 8004/tcp 2>/dev/null || echo "防火墙配置需要手动执行: sudo ufw allow 8004/tcp"
echo -e "${GREEN}✓ 防火墙已配置${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "服务地址: ${YELLOW}ws://$(curl -s ifconfig.me):8004${NC}"
echo ""
echo -e "常用命令："
echo -e "  查看状态: ${YELLOW}pm2 status${NC}"
echo -e "  查看日志: ${YELLOW}pm2 logs sms-sync-server --lines 100 -f${NC}"
echo -e "  重启服务: ${YELLOW}pm2 restart sms-sync-server${NC}"
echo -e "  停止服务: ${YELLOW}pm2 stop sms-sync-server${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo ""

# 显示服务状态
pm2 status
