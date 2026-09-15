# Redis — Trabalho de SGBD

Trabalho prático sobre o banco de dados **Redis** para a disciplina de Sistemas de Gerenciamento de Banco de Dados (SGBD).

## Integrantes

- Plácido Augustus de Oliveira Cordeiro
- Gabriela Pontes de Miranda Ramos Soares
- Júlia Gonçalves dos Santos
- José Gabriel de Almeida Vieira

## Visão Geral

Este repositório contém todo o ambiente necessário para demonstrar os principais recursos do Redis:

- **Modelo de dados**: Strings, Hashes, Lists, Sets, Sorted Sets
- **Scripts Lua**: execução atômica no servidor
- **Transações**: MULTI/EXEC com WATCH (controle de concorrência otimista)
- **Persistência**: snapshots RDB e Append-Only File (AOF)
- **Segurança**: controle de acesso via ACL
- **Otimização**: políticas de evicção de memória

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) e [Docker Compose](https://docs.docker.com/compose/install/)
- Terminal (bash/zsh/PowerShell)

## Estrutura do Projeto

```
redis-trabalho-sgbd/
├── docker-compose.yml        # Configuração do container Redis
├── comandos_video.txt        # Roteiro de comandos para gravação do vídeo
├── scripts/
│   └── testar_comandos.sh    # Script de testes automatizados
├── evidencias/               # Pasta para prints/logs das evidências
└── README.md                 # Este arquivo
```

## Como Usar

### 1. Subir o Redis

```bash
docker compose up -d
```

Verificar se o container está rodando:

```bash
docker ps
```

### 2. Conectar ao Redis CLI

```bash
docker exec -it redis-trabalho redis-cli
```

Teste básico:

```bash
PING
# Saída esperada: PONG
```

### 3. Executar os Testes Automatizados

O script `scripts/testar_comandos.sh` executa todos os comandos do plano de implementação e verifica se os resultados estão corretos:

```bash
chmod +x scripts/testar_comandos.sh
./scripts/testar_comandos.sh
```

O script testa todas as seções do relatório:

| Seção | Conteúdo Testado |
|-------|-----------------|
| 3.1 | Strings e Hashes (SET, GET, HSET, HGETALL, EXPIRE, TTL) |
| 3.2 | Listas, Sets e Sorted Sets (RPUSH, LRANGE, SADD, SMEMBERS, ZADD, ZRANGE) |
| 3.3 | Scripts Lua (EVAL com INCR) |
| 3.4 | Transações (MULTI, EXEC, WATCH, DECRBY, INCRBY) |
| 3.5 | Persistência (BGSAVE, CONFIG GET appendonly, arquivos em /data) |
| 3.6 | Segurança ACL (ACL SETUSER, ACL LIST, permissões GET/SET) |
| 3.7 | Política de Evicção (maxmemory, maxmemory-policy) |

### 4. Executar Comandos Manualmente

Para seguir o roteiro seção por seção, conecte-se ao CLI e execute os comandos do arquivo `comandos_video.txt`:

```bash
docker exec -it redis-trabalho redis-cli
```

#### Strings e Hashes

```bash
SET usuario:1001:nome "Joana Silva"
GET usuario:1001:nome
EXPIRE usuario:1001:nome 3600
TTL usuario:1001:nome

HSET usuario:1001 nome "Joana Silva" idade 23 cidade "Maceio"
HGETALL usuario:1001
HGET usuario:1001 idade
```

#### Listas, Sets e Sorted Sets

```bash
RPUSH fila:tarefas "enviar_email" "gerar_relatorio"
LRANGE fila:tarefas 0 -1

SADD produto:55:tags "eletronico" "promocao"
SMEMBERS produto:55:tags

ZADD ranking:jogo 1500 "jogador1"
ZADD ranking:jogo 2300 "jogador2"
ZRANGE ranking:jogo 0 -1 WITHSCORES
```

#### Scripts Lua

```bash
EVAL "return redis.call('INCR', KEYS[1])" 1 contador:visitas
EVAL "return redis.call('INCR', KEYS[1])" 1 contador:visitas
GET contador:visitas
```

#### Transações

```bash
SET conta:saldo 500
SET conta:destino 100
WATCH conta:saldo
MULTI
DECRBY conta:saldo 100
INCRBY conta:destino 100
EXEC
GET conta:saldo
GET conta:destino
```

#### Persistência

```bash
BGSAVE
CONFIG GET appendonly
INFO persistence
```

Verificar arquivos de persistência no container:

```bash
docker exec -it redis-trabalho ls -la /data
```

#### Segurança (ACL)

```bash
ACL SETUSER app_readonly on >SenhaForte123 ~produto:* +GET +HGETALL -@dangerous
ACL LIST
```

Testar usuário restrito (em outro terminal):

```bash
docker exec -it redis-trabalho redis-cli --user app_readonly --pass SenhaForte123 GET produto:55:tags
docker exec -it redis-trabalho redis-cli --user app_readonly --pass SenhaForte123 SET produto:55:tags "hack"
```

O segundo comando deve falhar com erro `NOPERM`.

#### Política de Evicção

```bash
CONFIG SET maxmemory 100mb
CONFIG SET maxmemory-policy allkeys-lru
CONFIG GET maxmemory
CONFIG GET maxmemory-policy
```

### 5. Encerrar o Ambiente

```bash
docker compose down
```

Para remover também os dados persistidos:

```bash
docker compose down -v
```

## Configuração do Docker

O `docker-compose.yml` configura o Redis com:

- **Imagem**: `redis:latest` (oficial)
- **Porta**: `6379:6379` (padrão Redis)
- **Volume**: `redis-data` para persistência entre reinícios
- **AOF ativo**: `--appendonly yes` para durabilidade dos dados
- **Restart**: `unless-stopped` para manter o container rodando

## Referências

- [Redis Documentation](https://redis.io/docs/)
- [Redis Commands](https://redis.io/commands)
- [Redis ACL](https://redis.io/docs/management/security/acl/)
- [Redis Persistence](https://redis.io/docs/management/persistence/)
