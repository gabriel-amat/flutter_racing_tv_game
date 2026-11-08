#!/bin/bash
set -e

# Cores retrô para o terminal
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║             🏁 INICIANDO RETRO RACING TV (90s ARCADE) 🏁           ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd "$(dirname "$0")"

# Gera certificados SSL locais se ainda não existirem (essencial para Safari iOS)
if [ ! -f cert.pem ] || [ ! -f key.pem ]; then
  echo -e "${YELLOW}🔐 Gerando certificado SSL local para liberar o Safari iOS...${NC}"
  openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=192.168.1.76" 2>/dev/null
fi

echo -e "${CYAN}📦 Passo 1/2: Compilando o Flutter Web...${NC}"
flutter build web --release

echo ""
echo -e "${GREEN}🚀 Passo 2/2: Iniciando os Servidores HTTP (TV) e HTTPS (Safari iOS)...${NC}"
dart run bin/server.dart
