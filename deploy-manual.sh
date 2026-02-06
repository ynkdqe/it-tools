#!/bin/bash

# Script deploy thủ công lên VPS
# Sử dụng: ./deploy-manual.sh

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Bắt đầu deploy IT-Tools lên VPS...${NC}\n"

# Kiểm tra biến môi trường
if [ -z "$DOCKER_USERNAME" ]; then
    echo -e "${RED}❌ Lỗi: DOCKER_USERNAME chưa được set${NC}"
    echo -e "${YELLOW}Chạy: export DOCKER_USERNAME=your-docker-username${NC}"
    exit 1
fi

if [ -z "$VPS_HOST" ]; then
    echo -e "${RED}❌ Lỗi: VPS_HOST chưa được set${NC}"
    echo -e "${YELLOW}Chạy: export VPS_HOST=your-vps-ip${NC}"
    exit 1
fi

if [ -z "$VPS_USER" ]; then
    echo -e "${YELLOW}⚠️  VPS_USER chưa được set, sử dụng 'root' mặc định${NC}"
    VPS_USER="root"
fi

# Build Docker image
echo -e "${GREEN}📦 Building Docker image...${NC}"
docker build -t $DOCKER_USERNAME/it-tools:latest .

# Push to Docker Hub
echo -e "\n${GREEN}⬆️  Pushing to Docker Hub...${NC}"
docker push $DOCKER_USERNAME/it-tools:latest

# Deploy to VPS
echo -e "\n${GREEN}🚢 Deploying to VPS...${NC}"
ssh $VPS_USER@$VPS_HOST << 'ENDSSH'
    set -e
    
    echo "📥 Pulling latest image..."
    docker pull $DOCKER_USERNAME/it-tools:latest
    
    echo "🛑 Stopping old container..."
    docker stop it-tools 2>/dev/null || true
    docker rm it-tools 2>/dev/null || true
    
    echo "🚀 Starting new container..."
    docker run -d \
        --name it-tools \
        --restart unless-stopped \
        -p 3000:80 \
        $DOCKER_USERNAME/it-tools:latest
    
    echo "🧹 Cleaning up old images..."
    docker image prune -af
    
    echo "✅ Container status:"
    docker ps | grep it-tools
ENDSSH

echo -e "\n${GREEN}✅ Deploy thành công!${NC}"
echo -e "${YELLOW}🌐 Truy cập: http://$VPS_HOST${NC}"
