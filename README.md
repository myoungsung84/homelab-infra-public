# Homelab Infrastructure

A Docker Compose + Kubernetes infrastructure playground for running containerized applications with shared database, cache, logging, and object storage services.

---

## 🚀 빠른 시작

### 이 프로젝트가 뭔가요?

개발 서버나 홈 서버에 필요한 데이터베이스, 캐시, 로그, 파일 저장소를 쉽게 설치하고 관리할 수 있는 도구입니다. Docker로 각 서비스를 묶어서 한 번에 띄우고, Kubernetes로 외부에서 HTTPS로 안전하게 접근할 수 있게 설정했습니다.

### 어떤 서비스가 들어있나요?

| 서비스 | 용도 | 포트 |
|--------|------|------|
| **MariaDB** | SQL 데이터베이스 | 3306 |
| **Redis** | 빠른 메모리 저장소 (캐시) | 6379 |
| **Elasticsearch** | 로그 저장 및 분석 | 9200 |
| **Kibana** | 로그 시각화 & 조회 | 5601 |
| **MinIO** | S3처럼 쓸 수 있는 파일 저장소 | 9000 (API) / 9001 (웹) |
| **Geo API** | IP Geo 조회 API | 9010 |

### 설정하는 방법

1️⃣ **비밀번호 설정**

```bash
# 각 디렉토리에 .env 파일 생성
compose/db/.env              # MariaDB 비밀번호
compose/elk/.env             # Elasticsearch 비밀번호
compose/minio/.env           # MinIO 비밀번호
```

2️⃣ **서비스 시작**

```bash
./scripts/homelab.sh up
```

3️⃣ **정상 실행 확인**

```bash
./scripts/homelab.sh status
```

### 자주 쓰는 명령어

```bash
# 모든 서비스 시작
./homelab.sh up

# 특정 서비스만 시작 (예: Elasticsearch + Kibana)
./homelab.sh up elk

# 모든 서비스 중지
./homelab.sh down

# 특정 서비스 재시작
./homelab.sh restart es

# 실시간 로그 보기
./homelab.sh logs kibana

# 상태 확인
./homelab.sh status
```

### 각 서비스 접속하기

**로컬 개발 환경에서:**
- Kibana (로그 보기): http://localhost:5601
- MinIO (파일 관리): http://localhost:9001
- 데이터베이스/Redis: 앱에서 `localhost:3306`, `localhost:6379`로 연결

**Kubernetes 통해서:**
- 실제 도메인으로 HTTPS 접속 가능 (도메인 설정 후)
- 예: https://es.example.com, https://kibana.example.com

---

## Architecture

```
┌─────────────────────────────────────┐
│   Docker Compose Services           │
├─────────────────────────────────────┤
│ • MariaDB (MySQL)                   │
│ • Redis Cache                       │
│ • Elasticsearch + Kibana (Logging)  │
│ • MinIO (S3-compatible Storage)     │
└─────────────────────────────────────┘
         ↕ (shared network: infra)
┌─────────────────────────────────────┐
│   Kubernetes (kind/k3s)             │
├─────────────────────────────────────┤
│ • Application Deployments           │
│ • Ingress Controller (nginx)        │
│ • Cert Manager (Let's Encrypt)      │
│ • Service Discovery                 │
└─────────────────────────────────────┘
```

## Services

### Docker Compose

| Service | Port | Image | Purpose |
|---------|------|-------|---------|
| MariaDB | 3306 | mariadb:11 | SQL Database |
| Redis | 6379 | redis:7 | In-memory Cache |
| Elasticsearch | 9200 | elasticsearch:8.11.3 | Log Indexing |
| Kibana | 5601 | kibana:8.11.3 | Log Visualization |
| MinIO | 9000/9001 | minio/minio:latest | S3-compatible Storage |
| Geo API | 9010 | geo-api (local build) | IP Geo Lookup API |

### Kubernetes

- **cert-manager**: Automatic TLS certificate management with Let's Encrypt
- **NGINX Ingress**: HTTP/HTTPS routing to backend services
- **Namespace: infra**: Isolated resource namespace

## Prerequisites

- Docker & Docker Compose
- Kubernetes cluster (kind, k3s, or kubectl)
- kubectl configured
- Kustomize (comes with kubectl)
- SSH access to remote server (for remote deployment)

## Installation

### 1. Clone Repository

```bash
git clone git@github.com:myoungsung84/homelab-infra-public.git
cd homelab-infra-public
```

### 2. Configure Environment Variables

Create `.env` files in each service directory:

```bash
# compose/db/.env
MARIADB_ROOT_PASSWORD=your-secure-password

# compose/elk/.env
ELASTICSEARCH_HOSTS=http://es:9200
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=your-secure-password

# compose/minio/.env
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your-secure-password

# compose/redis/.env
REDIS_PASSWORD=your-secure-password

# compose/geo/.env
GEOIPUPDATE_ACCOUNT_ID=your-account-id
GEOIPUPDATE_LICENSE_KEY=your-license-key
```

### 3. Update Domain Names

Edit ingress files to use your actual domain:

```bash
# edge/k8s/infra/elk-ingress/ingress-*.yaml
# edge/k8s/infra/minio-ingress/ingress.yaml
# Replace es.example.com, kibana.example.com, image.example.com with your domains
```

### 4. Update Let's Encrypt Email

Edit `edge/k8s/infra/cert/clusterissuer-letsencrypt-http01.yaml`:

```yaml
spec:
  acme:
    email: your-actual-email@example.com
```

## Usage

### Start Services Locally

```bash
./scripts/homelab.sh up                    # Start all services
./scripts/homelab.sh up db                 # Start specific service
./scripts/homelab.sh up geo                # Start Geo API
./scripts/homelab.sh down                  # Stop all services
./scripts/homelab.sh restart es            # Restart service
./scripts/homelab.sh logs geo              # View Geo API logs
./scripts/homelab.sh logs kibana           # View logs
./scripts/homelab.sh status                # Check status
```

### Deploy to Remote Server

```bash
./scripts/homelab.sh sync                  # Sync code to remote
./scripts/homelab.sh up all                # Deploy all services
```

### Access Services

- MariaDB: `localhost:3306` (configure in app)
- Redis: `localhost:6379` (configure in app)
- Elasticsearch: `http://localhost:9200`
- Kibana: `http://localhost:5601`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`
- Geo API: `http://localhost:9010` (endpoints: `/health`, `/geo/me`, `/geo/ip?ip=1.1.1.1`)

### Kubernetes Ingress

Once deployed to Kubernetes:

```bash
# Check ingress status
kubectl -n infra get ingress

# Watch cert provisioning
kubectl -n infra describe certificate es-tls

# Access services via domain
# https://es.example.com
# https://kibana.example.com
# https://image.example.com (MinIO S3)
# https://image-console.example.com (MinIO Console)
```

## Project Structure

```
homelab-infra-public/
├── README.md                                    # This file
├── compose/                                     # Docker Compose configs
│   ├── db/                                      # MariaDB
│   │   ├── compose.yml
│   │   └── .env.example
│   ├── redis/                                   # Redis Cache
│   ├── elk/                                     # Elasticsearch + Kibana
│   └── minio/                                   # MinIO Object Storage
│   └── geo/                                     # Geo API + GeoIP Update
├── edge/                                        # Kubernetes configs
│   └── k8s/
│       ├── cert-manager/                        # TLS Certificate Manager
│       └── infra/
│           ├── cert/                            # Let's Encrypt ClusterIssuer
│           ├── elk-ingress/                     # Elasticsearch + Kibana Ingress
│           └── minio-ingress/                   # MinIO Ingress
└── scripts/
    └── homelab.sh                               # Orchestration script

```

## Security Considerations

⚠️ **Important**: This is a development/homelab setup. For production use:

- [ ] Keep `.env` files in `.gitignore` (already configured)
- [ ] Use strong passwords (not default values)
- [ ] Enable authentication on all services
- [ ] Use HTTPS/TLS for all connections
- [ ] Implement network policies for pod-to-pod communication
- [ ] Set resource limits and requests
- [ ] Regular backups of database and storage volumes
- [ ] Monitor logs and metrics
- [ ] Keep container images updated

## Troubleshooting

### Docker Network Issues

```bash
# Verify infra network exists
docker network inspect infra

# Recreate if needed
docker network create infra
```

### Kubernetes Certificate Issues

```bash
# Check certificate status
kubectl -n infra get certificate

# View cert-manager logs
kubectl -n cert-manager logs -f deploy/cert-manager
```

### Service Connectivity

```bash
# Test from pod
kubectl -n infra run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod: nc -zv es 9200
```

## Contributing

Contributions are welcome! Please submit issues and pull requests.

## License

MIT

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [cert-manager Documentation](https://cert-manager.io/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/)
- [MinIO Documentation](https://min.io/docs/)

