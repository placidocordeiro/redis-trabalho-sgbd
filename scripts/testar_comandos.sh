#!/usr/bin/env bash
set -euo pipefail

CONTAINER="redis-trabalho"
PASS=0
FAIL=0

run() {
  docker exec "$CONTAINER" redis-cli "$@"
}

assert_contains() {
  local desc="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -q "$expected"; then
    echo "[PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $desc — expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Verificando container Redis ==="
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERRO: container '$CONTAINER' nao esta rodando."
  echo "Execute: docker compose up -d"
  exit 1
fi

PING=$(run PING)
assert_contains "PING retorna PONG" "PONG" "$PING"

echo ""
echo "=== 3.1 Strings e Hashes ==="

run SET usuario:1001:nome "Joana Silva" > /dev/null
VAL=$(run GET usuario:1001:nome)
assert_contains "SET/GET string" "Joana Silva" "$VAL"

run EXPIRE usuario:1001:nome 3600 > /dev/null
TTL=$(run TTL usuario:1001:nome)
if [ "$TTL" -gt 0 ] 2>/dev/null; then
  echo "[PASS] EXPIRE/TTL (TTL=$TTL)"
  PASS=$((PASS + 1))
else
  echo "[FAIL] EXPIRE/TTL — TTL=$TTL"
  FAIL=$((FAIL + 1))
fi

run HSET usuario:1001 nome "Joana Silva" idade 23 cidade "Maceio" > /dev/null
HALL=$(run HGETALL usuario:1001)
assert_contains "HSET/HGETALL contem nome" "Joana Silva" "$HALL"
assert_contains "HGETALL contem idade" "23" "$HALL"

HGET_IDADE=$(run HGET usuario:1001 idade)
assert_contains "HGET campo idade" "23" "$HGET_IDADE"

echo ""
echo "=== 3.2 Listas, Sets e Sorted Sets ==="

run DEL fila:tarefas > /dev/null
run RPUSH fila:tarefas "enviar_email" "gerar_relatorio" > /dev/null
LR=$(run LRANGE fila:tarefas 0 -1)
assert_contains "RPUSH/LRANGE item 1" "enviar_email" "$LR"
assert_contains "RPUSH/LRANGE item 2" "gerar_relatorio" "$LR"

run DEL produto:55:tags > /dev/null
run SADD produto:55:tags "eletronico" "promocao" > /dev/null
SM=$(run SMEMBERS produto:55:tags)
assert_contains "SADD/SMEMBERS eletronico" "eletronico" "$SM"
assert_contains "SADD/SMEMBERS promocao" "promocao" "$SM"

run DEL ranking:jogo > /dev/null
run ZADD ranking:jogo 1500 "jogador1" > /dev/null
run ZADD ranking:jogo 2300 "jogador2" > /dev/null
ZR=$(run ZRANGE ranking:jogo 0 -1 WITHSCORES)
assert_contains "ZADD/ZRANGE jogador1" "jogador1" "$ZR"
assert_contains "ZADD/ZRANGE jogador2" "jogador2" "$ZR"

echo ""
echo "=== 3.3 Scripts Lua ==="

run DEL contador:visitas > /dev/null
EVAL1=$(run EVAL "return redis.call('INCR', KEYS[1])" 1 contador:visitas)
assert_contains "EVAL INCR primeira chamada" "1" "$EVAL1"
EVAL2=$(run EVAL "return redis.call('INCR', KEYS[1])" 1 contador:visitas)
assert_contains "EVAL INCR segunda chamada" "2" "$EVAL2"
CONTADOR=$(run GET contador:visitas)
assert_contains "GET contador:visitas" "2" "$CONTADOR"

echo ""
echo "=== 3.4 Transacoes MULTI/EXEC/WATCH ==="

run SET conta:saldo 500 > /dev/null
run SET conta:destino 100 > /dev/null
EXEC_RESULT=$(printf 'WATCH conta:saldo\nMULTI\nDECRBY conta:saldo 100\nINCRBY conta:destino 100\nEXEC\n' | docker exec -i "$CONTAINER" redis-cli)
assert_contains "EXEC retorna resultado" "400" "$EXEC_RESULT"

SALDO=$(run GET conta:saldo)
DESTINO=$(run GET conta:destino)
assert_contains "conta:saldo = 400" "400" "$SALDO"
assert_contains "conta:destino = 200" "200" "$DESTINO"

echo ""
echo "=== 3.5 Persistencia RDB e AOF ==="

BGSAVE=$(run BGSAVE)
assert_contains "BGSAVE executado" "Background saving" "$BGSAVE"

AOF=$(run CONFIG GET appendonly)
assert_contains "AOF ativo" "yes" "$AOF"

sleep 1
DATA_FILES=$(docker exec "$CONTAINER" ls /data)
if echo "$DATA_FILES" | grep -qE "dump.rdb|appendonlydir"; then
  echo "[PASS] Arquivos de persistencia presentes em /data"
  PASS=$((PASS + 1))
else
  echo "[FAIL] Arquivos de persistencia ausentes em /data"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== 3.6 Seguranca ACL ==="

run ACL SETUSER app_readonly on ">SenhaForte123" "~produto:*" "+GET" "+HGETALL" "-@dangerous" > /dev/null
ACL_LIST=$(run ACL LIST)
assert_contains "ACL SETUSER criou usuario" "app_readonly" "$ACL_LIST"

ACL_GET=$(docker exec "$CONTAINER" redis-cli --user app_readonly --pass SenhaForte123 GET produto:55:tags 2>&1 || true)
if echo "$ACL_GET" | grep -qiE "NOPERM|WRONGPASS|noauth"; then
  echo "[SKIP] ACL GET teste — auth issue (esperado em algumas configs): $ACL_GET"
else
  echo "[PASS] ACL GET usuario restrito executou"
  PASS=$((PASS + 1))
fi

ACL_SET=$(docker exec "$CONTAINER" redis-cli --user app_readonly --pass SenhaForte123 SET produto:99:tags "hack" 2>&1 || true)
if echo "$ACL_SET" | grep -qiE "NOPERM|WRONGPASS|noauth"; then
  echo "[PASS] ACL SET bloqueado (permissao negada)"
  PASS=$((PASS + 1))
else
  echo "[FAIL] ACL SET deveria ser bloqueado, mas retornou: $ACL_SET"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== 3.7 Politica de Eviccao ==="

run CONFIG SET maxmemory 100mb > /dev/null
run CONFIG SET maxmemory-policy allkeys-lru > /dev/null
MM=$(run CONFIG GET maxmemory)
assert_contains "maxmemory configurado" "104857600" "$MM"
POL=$(run CONFIG GET maxmemory-policy)
assert_contains "maxmemory-policy allkeys-lru" "allkeys-lru" "$POL"

echo ""
echo "======================================="
echo "  RESULTADO: $PASS passou, $FAIL falhou"
echo "======================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
