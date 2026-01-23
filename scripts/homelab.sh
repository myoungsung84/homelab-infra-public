#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Resolve real script path (works even when called via symlink)
# ------------------------------------------------------------
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# -------------------------
# Remote config (PC mode)
# -------------------------
HOST="${HOST:-home}"
REMOTE_DIR="${REMOTE_DIR:-/home/ubuntu/homelab-infra}"
RSYNC_FLAGS="${RSYNC_FLAGS:--az --delete}"

# -------------------------
# Local project paths
# -------------------------
COMPOSE_DIR="$ROOT_DIR/compose"
EDGE_DIR="$ROOT_DIR/edge"
SCRIPTS_DIR="$ROOT_DIR/scripts"

# Docker compose dirs (server side after sync)
DB_DIR="${REMOTE_DIR}/compose/db"
REDIS_DIR="${REMOTE_DIR}/compose/redis"
MINIO_DIR="${REMOTE_DIR}/compose/minio"
ELK_DIR="${REMOTE_DIR}/compose/elk"

DB_COMPOSE="${DB_DIR}/compose.yml"
REDIS_COMPOSE="${REDIS_DIR}/compose.yml"
MINIO_COMPOSE="${MINIO_DIR}/compose.yml"
ELK_COMPOSE="${ELK_DIR}/compose.yml"

NETWORK_NAME="${NETWORK_NAME:-infra}"

# Kustomize dirs (server side after sync)
MINIO_KUSTOMIZE_DIR_REL="${MINIO_KUSTOMIZE_DIR_REL:-edge/k8s/infra/minio-ingress}"
MINIO_KUSTOMIZE_DIR="${REMOTE_DIR}/${MINIO_KUSTOMIZE_DIR_REL}"

ELK_KUSTOMIZE_DIR_REL="${ELK_KUSTOMIZE_DIR_REL:-edge/k8s/infra/elk-ingress}"
ELK_KUSTOMIZE_DIR="${REMOTE_DIR}/${ELK_KUSTOMIZE_DIR_REL}"

# ✅ Observer (Filebeat DaemonSet)
FILEBEAT_KUSTOMIZE_DIR_REL="${FILEBEAT_KUSTOMIZE_DIR_REL:-edge/k8s/observer/filebeat}"
FILEBEAT_KUSTOMIZE_DIR="${REMOTE_DIR}/${FILEBEAT_KUSTOMIZE_DIR_REL}"

is_remote="${REMOTE_MODE:-0}" # 0=PC, 1=server

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' 명령이 없습니다."; exit 1; }
}

dc() {
  local dir="$1"
  local file="$2"
  shift 2
  (cd "$dir" && docker compose -f "$file" "$@")
}

ensure_network() {
  if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    echo "🧩 docker network '${NETWORK_NAME}' 없음 → 생성"
    docker network create "${NETWORK_NAME}" >/dev/null
  fi
}

ensure_paths_remote() {
  [[ -d "$DB_DIR" ]] || { echo "❌ DB_DIR 없음: $DB_DIR"; exit 1; }
  [[ -d "$REDIS_DIR" ]] || { echo "❌ REDIS_DIR 없음: $REDIS_DIR"; exit 1; }
  [[ -d "$MINIO_DIR" ]] || { echo "❌ MINIO_DIR 없음: $MINIO_DIR"; exit 1; }
  [[ -d "$ELK_DIR" ]] || { echo "❌ ELK_DIR 없음: $ELK_DIR"; exit 1; }

  [[ -f "$DB_COMPOSE" ]] || { echo "❌ DB compose 없음: $DB_COMPOSE"; exit 1; }
  [[ -f "$REDIS_COMPOSE" ]] || { echo "❌ Redis compose 없음: $REDIS_COMPOSE"; exit 1; }
  [[ -f "$MINIO_COMPOSE" ]] || { echo "❌ MinIO compose 없음: $MINIO_COMPOSE"; exit 1; }
  [[ -f "$ELK_COMPOSE" ]] || { echo "❌ ELK compose 없음: $ELK_COMPOSE"; exit 1; }

  [[ -d "$MINIO_KUSTOMIZE_DIR" ]] || { echo "❌ MinIO Kustomize dir 없음: $MINIO_KUSTOMIZE_DIR"; exit 1; }
  [[ -d "$ELK_KUSTOMIZE_DIR" ]] || { echo "❌ ELK Kustomize dir 없음: $ELK_KUSTOMIZE_DIR"; exit 1; }

  # ✅ observer/filebeat
  [[ -d "$FILEBEAT_KUSTOMIZE_DIR" ]] || { echo "❌ Filebeat Kustomize dir 없음: $FILEBEAT_KUSTOMIZE_DIR"; exit 1; }

  # ✅ kubeconfig (no root access for /etc/rancher/k3s/k3s.yaml)
  if [[ ! -f "${KUBECONFIG:-/home/ubuntu/.kube/config}" ]]; then
    echo "❌ kubeconfig 없음: ${KUBECONFIG:-/home/ubuntu/.kube/config}"
    echo "   서버에서 아래 실행 후 다시 시도:"
    echo "   sudo mkdir -p /home/ubuntu/.kube && sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config"
    echo "   sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube && sudo chmod 600 /home/ubuntu/.kube/config"
    exit 1
  fi
}

sync_to_server() {
  echo "📤 sync(tar over ssh) → ${HOST}:${REMOTE_DIR}"
  ssh -t "$HOST" "mkdir -p '$REMOTE_DIR'"

  (cd "$ROOT_DIR" && tar -czf - \
      --exclude=".git" \
      --exclude="node_modules" \
      --exclude="dist" \
      --exclude="dist-electron" \
      compose edge scripts \
    ) | ssh "$HOST" "tar -xzf - -C '$REMOTE_DIR'"

  echo "✅ sync done"
}

run_remote() {
  local subcmd="$1"; shift || true
  sync_to_server
  ssh -t "$HOST" \
    "REMOTE_MODE=1 REMOTE_DIR='$REMOTE_DIR' NETWORK_NAME='$NETWORK_NAME' \
     KUBECONFIG='/home/ubuntu/.kube/config' \
     MINIO_KUSTOMIZE_DIR_REL='$MINIO_KUSTOMIZE_DIR_REL' ELK_KUSTOMIZE_DIR_REL='$ELK_KUSTOMIZE_DIR_REL' \
     FILEBEAT_KUSTOMIZE_DIR_REL='$FILEBEAT_KUSTOMIZE_DIR_REL' \
     bash '$REMOTE_DIR/scripts/homelab.sh' '$subcmd' $*"
}

usage() {
  cat <<EOF
사용법: homelab <command> [target]

targets:
  all (default)
  db | redis | minio | elk
  es | kibana   (restart/logs/status 용도)
  filebeat      (k8s DaemonSet)

commands:
  sync
  up [target]            : docker up (+ target ingress apply) + (filebeat는 edge apply)
  down [target]          : ingress delete(가능한 경우) + docker down + (filebeat는 edge delete)
  restart [target]       : docker restart (target만)
  status [target]        : docker ps + edge 리소스(필요 시)
  logs [target]          : docker logs -f

  docker-up [target]     : docker만 up (ingress 안 건드림)
  docker-down [target]   : docker만 down
  docker-status [target] : docker ps
  docker-pull [target]   : docker pull

  edge-up [target]       : kubectl apply -k (minio/elk/filebeat)
  edge-down [target]     : kubectl delete -k (minio/elk/filebeat)
  edge-status            : kubectl -n infra get ing,svc,endpointslices (+ observer filebeat)

예)
  homelab up
  homelab up elk
  homelab down elk
  homelab up filebeat
  homelab edge-up filebeat
  homelab restart es
  homelab logs kibana
EOF
}

cmd="${1:-}"; shift || true
target="${1:-all}"; shift || true

# -------------------------
# PC mode: orchestrate
# -------------------------
if [[ "$is_remote" != "1" ]]; then
  case "$cmd" in
    ""|-h|--help|help) usage; exit 0 ;;
    sync) sync_to_server; exit 0 ;;
    *) run_remote "$cmd" "$target" "$@"; exit 0 ;;
  esac
fi

# -------------------------
# REMOTE mode: do the work
# -------------------------
need_cmd docker
need_cmd kubectl

# ✅ force kubeconfig for k3s-symlinked kubectl
export KUBECONFIG="${KUBECONFIG:-/home/ubuntu/.kube/config}"

# ✅ kubectl wrapper (k3s symlink 'kubectl' tends to pick /etc/rancher/k3s/k3s.yaml if not explicit)
kc() {
  KUBECONFIG="$KUBECONFIG" kubectl "$@"
}

ensure_paths_remote

# -------------------------
# Helpers: docker actions by target
# -------------------------
docker_up_target() {
  local t="$1"
  ensure_network

  case "$t" in
    all)
      dc "$DB_DIR" "$DB_COMPOSE" up -d & pid1=$!
      dc "$REDIS_DIR" "$REDIS_COMPOSE" up -d & pid2=$!
      wait $pid1 $pid2
      dc "$MINIO_DIR" "$MINIO_COMPOSE" up -d
      dc "$ELK_DIR" "$ELK_COMPOSE" up -d
      ;;
    db) dc "$DB_DIR" "$DB_COMPOSE" up -d ;;
    redis) dc "$REDIS_DIR" "$REDIS_COMPOSE" up -d ;;
    minio) dc "$MINIO_DIR" "$MINIO_COMPOSE" up -d ;;
    elk) dc "$ELK_DIR" "$ELK_COMPOSE" up -d ;;
    *)
      echo "❌ up은 target=all|db|redis|minio|elk 만 지원합니다. (es/kibana는 elk로 올리세요)"
      exit 1
      ;;
  esac
}

docker_down_target() {
  local t="$1"
  case "$t" in
    all)
      dc "$ELK_DIR" "$ELK_COMPOSE" down || true
      dc "$MINIO_DIR" "$MINIO_COMPOSE" down || true
      dc "$REDIS_DIR" "$REDIS_COMPOSE" down || true
      dc "$DB_DIR" "$DB_COMPOSE" down || true
      ;;
    db) dc "$DB_DIR" "$DB_COMPOSE" down || true ;;
    redis) dc "$REDIS_DIR" "$REDIS_COMPOSE" down || true ;;
    minio) dc "$MINIO_DIR" "$MINIO_COMPOSE" down || true ;;
    elk) dc "$ELK_DIR" "$ELK_COMPOSE" down || true ;;
    *)
      echo "❌ down은 target=all|db|redis|minio|elk 만 지원합니다."
      exit 1
      ;;
  esac
}

docker_restart_target() {
  local t="$1"
  case "$t" in
    all)
      docker restart db redis minio es kibana >/dev/null 2>&1 || true
      ;;
    db) docker restart db ;;
    redis) docker restart redis ;;
    minio) docker restart minio ;;
    elk) docker restart es kibana ;;
    es) docker restart es ;;
    kibana) docker restart kibana ;;
    *)
      echo "❌ restart target: all|db|redis|minio|elk|es|kibana"
      exit 1
      ;;
  esac
}

docker_status_target() {
  local t="$1"
  case "$t" in
    all)
      dc "$DB_DIR" "$DB_COMPOSE" ps || true
      dc "$REDIS_DIR" "$REDIS_COMPOSE" ps || true
      dc "$MINIO_DIR" "$MINIO_COMPOSE" ps || true
      dc "$ELK_DIR" "$ELK_COMPOSE" ps || true
      ;;
    db) dc "$DB_DIR" "$DB_COMPOSE" ps || true ;;
    redis) dc "$REDIS_DIR" "$REDIS_COMPOSE" ps || true ;;
    minio) dc "$MINIO_DIR" "$MINIO_COMPOSE" ps || true ;;
    elk) dc "$ELK_DIR" "$ELK_COMPOSE" ps || true ;;
    es) docker ps --filter "name=^/es$" ;;
    kibana) docker ps --filter "name=^/kibana$" ;;
    *)
      echo "❌ status target: all|db|redis|minio|elk|es|kibana"
      exit 1
      ;;
  esac
}

docker_logs_target() {
  local t="$1"
  case "$t" in
    all)
      (cd "$DB_DIR" && docker compose -f "$DB_COMPOSE" logs -f) & pid1=$!
      (cd "$REDIS_DIR" && docker compose -f "$REDIS_COMPOSE" logs -f) & pid2=$!
      (cd "$MINIO_DIR" && docker compose -f "$MINIO_COMPOSE" logs -f) & pid3=$!
      (cd "$ELK_DIR" && docker compose -f "$ELK_COMPOSE" logs -f) & pid4=$!
      trap 'kill $pid1 $pid2 $pid3 $pid4 2>/dev/null || true' INT TERM
      wait $pid1 $pid2 $pid3 $pid4
      ;;
    db) dc "$DB_DIR" "$DB_COMPOSE" logs -f ;;
    redis) dc "$REDIS_DIR" "$REDIS_COMPOSE" logs -f ;;
    minio) dc "$MINIO_DIR" "$MINIO_COMPOSE" logs -f ;;
    elk) dc "$ELK_DIR" "$ELK_COMPOSE" logs -f ;;
    es) docker logs -f es ;;
    kibana) docker logs -f kibana ;;
    *)
      echo "❌ logs target: all|db|redis|minio|elk|es|kibana"
      exit 1
      ;;
  esac
}

edge_apply_target() {
  local t="$1"
  case "$t" in
    all)
      kc apply -k "$MINIO_KUSTOMIZE_DIR"
      kc apply -k "$ELK_KUSTOMIZE_DIR"
      kc apply -k "$FILEBEAT_KUSTOMIZE_DIR"
      ;;
    minio) kc apply -k "$MINIO_KUSTOMIZE_DIR" ;;
    elk) kc apply -k "$ELK_KUSTOMIZE_DIR" ;;
    filebeat) kc apply -k "$FILEBEAT_KUSTOMIZE_DIR" ;;
    *)
      echo "❌ edge-up target: all|minio|elk|filebeat"
      exit 1
      ;;
  esac
}

edge_delete_target() {
  local t="$1"
  case "$t" in
    all)
      kc delete -k "$FILEBEAT_KUSTOMIZE_DIR" --ignore-not-found || true
      kc delete -k "$ELK_KUSTOMIZE_DIR" --ignore-not-found || true
      kc delete -k "$MINIO_KUSTOMIZE_DIR" --ignore-not-found || true
      ;;
    minio) kc delete -k "$MINIO_KUSTOMIZE_DIR" --ignore-not-found || true ;;
    elk) kc delete -k "$ELK_KUSTOMIZE_DIR" --ignore-not-found || true ;;
    filebeat) kc delete -k "$FILEBEAT_KUSTOMIZE_DIR" --ignore-not-found || true ;;
    *)
      echo "❌ edge-down target: all|minio|elk|filebeat"
      exit 1
      ;;
  esac
}

# -------------------------
# Commands
# -------------------------
case "$cmd" in
  up)
    # filebeat는 docker target이 아님 → docker는 스킵하고 edge만
    if [[ "$target" != "filebeat" ]]; then
      echo "🚀 [docker] up ($target)"
      docker_up_target "$target"
    fi

    # 🔥 k8s 리소스 apply (ingress + observer)
    echo "🚀 [edge] apply (auto)"
    case "$target" in
      all) edge_apply_target all ;;
      minio) edge_apply_target minio ;;
      elk) edge_apply_target elk ;;
      filebeat) edge_apply_target filebeat ;;
      *) : ;; # db/redis/es/kibana는 edge 없음
    esac

    echo "✅ up done"
    ;;

  down)
    # 🔥 k8s 리소스 delete (ingress + observer)
    echo "🧹 [edge] delete (auto)"
    case "$target" in
      all) edge_delete_target all ;;
      minio) edge_delete_target minio ;;
      elk) edge_delete_target elk ;;
      filebeat) edge_delete_target filebeat ;;
      *) : ;;
    esac

    # filebeat는 docker target이 아님 → docker는 스킵
    if [[ "$target" != "filebeat" ]]; then
      echo "🧹 [docker] down ($target)"
      docker_down_target "$target"
    fi

    echo "✅ down done"
    ;;

  restart)
    echo "🔄 [docker] restart ($target)"
    docker_restart_target "$target"
    echo "✅ restart done"
    ;;

  status)
    echo "📦 [docker] status ($target)"
    docker_status_target "$target"

    echo
    echo "📦 [edge] resources (ns=infra)"
    kc -n infra get ing,svc,endpointslices || true

    echo
    echo "📦 [observer] filebeat"
    kc -n observer get ds,pods -l app=filebeat -o wide || true
    ;;

  logs)
    docker_logs_target "$target"
    ;;

  docker-up)
    echo "🚀 [docker] up only ($target)"
    docker_up_target "$target"
    ;;

  docker-down)
    echo "🧹 [docker] down only ($target)"
    docker_down_target "$target"
    ;;

  docker-restart)
    echo "🔄 [docker] restart only ($target)"
    docker_restart_target "$target"
    ;;

  docker-status)
    docker_status_target "$target"
    ;;

  docker-pull)
    case "$target" in
      all)
        dc "$DB_DIR" "$DB_COMPOSE" pull || true
        dc "$REDIS_DIR" "$REDIS_COMPOSE" pull || true
        dc "$MINIO_DIR" "$MINIO_COMPOSE" pull || true
        dc "$ELK_DIR" "$ELK_COMPOSE" pull || true
        ;;
      db) dc "$DB_DIR" "$DB_COMPOSE" pull || true ;;
      redis) dc "$REDIS_DIR" "$REDIS_COMPOSE" pull || true ;;
      minio) dc "$MINIO_DIR" "$MINIO_COMPOSE" pull || true ;;
      elk) dc "$ELK_DIR" "$ELK_COMPOSE" pull || true ;;
      *)
        echo "❌ docker-pull target: all|db|redis|minio|elk"
        exit 1
        ;;
    esac
    ;;

  edge-up)
    edge_apply_target "$target"
    ;;

  edge-down)
    edge_delete_target "$target"
    ;;

  edge-status)
    kc -n infra get ing,svc,endpointslices || true
    echo
    kc -n observer get ds,pods -l app=filebeat -o wide || true
    ;;

  ""|-h|--help|help)
    usage
    ;;

  *)
    echo "❌ unknown command: $cmd"
    usage
    exit 1
    ;;
esac
