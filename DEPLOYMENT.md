# Hướng dẫn Deploy IT-Tools lên Digital Ocean VPS

## 📋 Yêu cầu

- VPS Digital Ocean đã cài Docker và Nginx
- Tài khoản Docker Hub (hoặc GitHub Container Registry)
- SSH key để truy cập VPS

## 🔧 Bước 1: Cấu hình GitHub Secrets

Vào repository GitHub của bạn: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Thêm các secrets sau:

### 1. Docker Hub Credentials

- `DOCKER_USERNAME`: Username Docker Hub của bạn
- `DOCKER_PASSWORD`: Password hoặc Access Token của Docker Hub

**Cách tạo Docker Hub Access Token:**

1. Đăng nhập vào https://hub.docker.com
2. Vào **Account Settings** → **Security** → **New Access Token**
3. Đặt tên token (ví dụ: `github-actions`)
4. Copy token và lưu vào `DOCKER_PASSWORD`

### 2. VPS Credentials

- `VPS_HOST`: IP address của VPS (ví dụ: `123.456.789.0`)
- `VPS_USERNAME`: Username SSH (thường là `root` hoặc `ubuntu`)
- `VPS_SSH_KEY`: Private SSH key để kết nối VPS

**Cách lấy SSH Key:**

```bash
# Trên máy local, tạo SSH key mới (nếu chưa có)
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions

# Copy public key lên VPS
ssh-copy-id -i ~/.ssh/github_actions.pub root@YOUR_VPS_IP

# Copy TOÀN BỘ nội dung private key
cat ~/.ssh/github_actions
# Copy output và paste vào GitHub Secret VPS_SSH_KEY
```

## 🚀 Bước 2: Cấu hình Nginx trên VPS

SSH vào VPS và tạo file cấu hình Nginx:

```bash
# SSH vào VPS
ssh root@YOUR_VPS_IP

# Tạo file cấu hình Nginx
sudo nano /etc/nginx/sites-available/it-tools
```

Paste nội dung sau:

```nginx
server {
    listen 80;
    server_name your-domain.com;  # Thay bằng domain của bạn hoặc IP

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Kích hoạt cấu hình:

```bash
# Tạo symbolic link
sudo ln -s /etc/nginx/sites-available/it-tools /etc/nginx/sites-enabled/

# Kiểm tra cấu hình
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

## 🔒 Bước 3: Cài đặt SSL (Tùy chọn nhưng khuyến nghị)

Nếu bạn có domain, cài đặt Let's Encrypt SSL:

```bash
# Cài đặt Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx -y

# Tạo SSL certificate
sudo certbot --nginx -d your-domain.com

# Certbot sẽ tự động cấu hình Nginx và redirect HTTP → HTTPS
```

## 🎯 Bước 4: Deploy

### Tự động deploy khi push code:

```bash
git add .
git commit -m "Setup deployment"
git push origin main
```

### Hoặc deploy thủ công:

1. Vào GitHub repository
2. Click tab **Actions**
3. Chọn workflow **Deploy to Digital Ocean VPS**
4. Click **Run workflow** → **Run workflow**

## 📊 Kiểm tra deployment

### Xem logs trên GitHub Actions:

- Vào tab **Actions** trên GitHub repository
- Click vào workflow run mới nhất
- Xem từng step để debug nếu có lỗi

### Kiểm tra trên VPS:

```bash
# SSH vào VPS
ssh root@YOUR_VPS_IP

# Kiểm tra container đang chạy
docker ps

# Xem logs của container
docker logs it-tools

# Xem logs realtime
docker logs -f it-tools
```

### Truy cập website:

- Không có domain: `http://YOUR_VPS_IP`
- Có domain: `http://your-domain.com` hoặc `https://your-domain.com` (nếu đã setup SSL)

## 🔧 Các lệnh hữu ích

### Trên VPS:

```bash
# Restart container
docker restart it-tools

# Stop container
docker stop it-tools

# Xem resource usage
docker stats it-tools

# Vào bên trong container
docker exec -it it-tools sh

# Pull và deploy phiên bản mới thủ công
docker pull YOUR_DOCKER_USERNAME/it-tools:latest
docker stop it-tools
docker rm it-tools
docker run -d --name it-tools --restart unless-stopped -p 3000:80 YOUR_DOCKER_USERNAME/it-tools:latest
```

### Dọn dẹp:

```bash
# Xóa images cũ
docker image prune -a

# Xóa containers đã stop
docker container prune

# Xóa tất cả (cẩn thận!)
docker system prune -a
```

## 🐛 Troubleshooting

### Lỗi: "Permission denied (publickey)"

- Kiểm tra lại `VPS_SSH_KEY` trong GitHub Secrets
- Đảm bảo public key đã được add vào VPS: `~/.ssh/authorized_keys`

### Lỗi: "Cannot connect to Docker daemon"

- Kiểm tra Docker đang chạy trên VPS: `sudo systemctl status docker`
- Khởi động Docker: `sudo systemctl start docker`

### Container không start được:

```bash
# Xem logs chi tiết
docker logs it-tools

# Kiểm tra port 3000 có bị chiếm không
sudo netstat -tulpn | grep 3000
```

### Nginx 502 Bad Gateway:

```bash
# Kiểm tra container có chạy không
docker ps | grep it-tools

# Kiểm tra logs Nginx
sudo tail -f /var/log/nginx/error.log
```

## 📝 Lưu ý

1. **Port 3000**: Workflow deploy container chạy trên port 3000, Nginx proxy từ port 80/443 → 3000
2. **Thay đổi port**: Nếu muốn đổi port, sửa trong file `deploy.yml` dòng `-p 3000:80`
3. **Multiple apps**: Nếu chạy nhiều app, đổi port khác nhau (3001, 3002, ...)
4. **Firewall**: Đảm bảo VPS mở port 80, 443 (và 22 cho SSH)

## 🎉 Hoàn thành!

Sau khi setup xong, mỗi lần bạn push code lên branch `main`, GitHub Actions sẽ tự động:

1. ✅ Build Docker image
2. ✅ Push lên Docker Hub
3. ✅ Deploy lên VPS
4. ✅ Restart container với code mới

Website của bạn sẽ tự động cập nhật! 🚀
