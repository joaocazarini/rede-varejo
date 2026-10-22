#!/usr/bin/env bash
# Roda os testes de cada missão e grava a saída em evidencias/missaoN.txt
# Uso (na raiz do repositório, no terminal do Codespaces):
#   ./evidencias/coletar.sh            -> missões 1 a 5 e 7 (≈ 15 min)
#   ./evidencias/coletar.sh 3          -> só a missão 3
# A rede precisa estar no ar (a missão 2 sobe se não estiver).
set -u
cd "$(dirname "$0")/.."
RAIZ=$(pwd)
ERP=10.20.2.10
APP=10.20.32.10
SITE=100.64.200.10
TOPO=rede/rede.clab.yml

X(){ local n=$1; shift; docker exec "clab-rede-$n" "$@"; }
cab(){ echo; echo "### $*"; }
cmd(){ local c="$*"; echo "\$ ${c/#X /docker exec clab-rede-}"; "$@" 2>&1; echo; }
roda(){ # roda N: sobe a rede se preciso e grava a saída da missão N
  [ "$1" -ge 2 ] && { no_ar || sobe; espera_ospf; }
  { echo "Missão $1 · $(date '+%Y-%m-%d %H:%M:%S') · commit $(git rev-parse --short HEAD 2>/dev/null || echo '-')"
    "m$1"; } 2>&1 | tee "$RAIZ/evidencias/missao$1.txt"; }

no_ar(){ [ "$(docker ps -q -f name=clab-rede- | wc -l)" -ge 14 ]; }
sobe(){ (cd rede && sudo containerlab deploy -t rede.clab.yml "$@"); }
espera_ospf(){   # espera os vizinhos da loja 1 voltarem a Full (até 90 s)
  for _ in $(seq 1 45); do
    [ "$(X loja1 vtysh -c 'show ip ospf neighbor' 2>/dev/null | grep -c Full)" -ge 2 ] && sleep 3 && return 0
    sleep 2
  done; echo "(aviso: OSPF da loja 1 não voltou a Full em 90 s)"; }
teste(){ # teste "descrição" "esperado" comando...
  local d=$1 e=$2; shift 2; local r; r=$("$@" 2>/dev/null); [ -z "$r" ] && r="000"
  local ok="ERRADO"; [ "$r" = "$e" ] && ok="ok"
  printf "%s%*s esperado %-4s obtido %-4s %s\n" "$d" $((42 - ${#d})) "" "$e" "$r" "$ok"; }
http(){ local n=$1; shift; X "$n" curl -sk -m 3 -o /dev/null -w "%{http_code}" "$@"; }
pinga(){ X "$1" ping -c 2 -W 1 "$2" >/dev/null 2>&1 && echo ok || echo nao; }
netem_ok(){ sudo containerlab tools netem set -n clab-rede-loja1 -i eth1 --delay 1ms >/dev/null 2>&1 &&
  sudo containerlab tools netem set -n clab-rede-loja1 -i eth1 >/dev/null 2>&1; }

m1(){
  cab "Verificador do plano"; (cd enderecamento && cmd python3 verifica_plano.py)
  cab "Plano"; cat enderecamento/plano.csv; }

m2(){
  cab "Nós em execução"; cmd sudo containerlab inspect -t $TOPO
  espera_ospf
  cab "Vizinhos OSPF da loja 1"; cmd X loja1 vtysh -c "show ip ospf neighbor"
  cab "Caixa da loja 1 -> ERP"; cmd X caixa1 ping -c 3 $ERP
  cab "Mudança manual na loja 2 (vtysh): caixas passam para 10.20.11.1/26"
  X loja2 vtysh -c "conf t" -c "interface eth3" -c "no ip address 10.20.11.129/26" -c "ip address 10.20.11.1/26" >/dev/null
  cmd X loja2 vtysh -c "show interface brief"
  cab "deploy --reconfigure"; (cd rede && sudo containerlab deploy -t rede.clab.yml --reconfigure >/dev/null 2>&1); espera_ospf
  cmd X loja2 vtysh -c "show interface brief"
  echo "Resultado: o endereço voltou a 10.20.11.129/26, o que está em rede/loja2.conf. A mudança manual sumiu."
  }

m3(){
  cab "Custos OSPF da loja 1"; cmd X loja1 vtysh -c "show ip ospf interface"
  cab "Caminho normal: caixa da loja 1 -> ERP (MPLS)"; cmd X caixa1 traceroute -I -n -w 1 $ERP
  cab "Queda da interface do MPLS da loja 1"
  cmd python3 evidencias/mede_queda.py --duracao 15 \
      --falha "docker exec clab-rede-loja1 ip link set eth1 down" \
      --desfaz "docker exec clab-rede-loja1 ip link set eth1 up"
  X loja1 ip link set eth1 down; sleep 2
  cab "Caminho com o MPLS fora (internet)"; cmd X caixa1 traceroute -I -n -w 1 $ERP
  X loja1 ip link set eth1 up; espera_ospf
  cab "Falha silenciosa: o link continua aceso e nada do que a loja manda chega"
  if netem_ok; then
    cmd python3 evidencias/mede_queda.py --duracao 70 \
      --falha "sudo containerlab tools netem set -n clab-rede-loja1 -i eth1 --loss 100" \
      --desfaz "sudo containerlab tools netem set -n clab-rede-loja1 -i eth1"
  else
    echo "(kernel sem netem: falha aplicada com uma regra no provedor)"
    cmd python3 evidencias/mede_queda.py --duracao 70 \
      --falha "docker exec clab-rede-mpls sh -c 'apk add --no-cache nftables >/dev/null && nft add table inet falha && nft add chain inet falha f \"{ type filter hook prerouting priority -300; }\" && nft add rule inet falha f iifname eth2 drop'" \
      --desfaz "docker exec clab-rede-mpls nft delete table inet falha"
  fi
  espera_ospf; }

m4(){
  cab "Os oito testes da matriz de fluxos"
  teste "caixa -> ERP (HTTPS)"            200 http caixa1 https://$ERP
  teste "caixa -> ping no ERP"            ok  pinga caixa1 $ERP
  teste "caixa -> vídeo"                  000 http caixa1 http://$ERP:8554
  teste "caixa -> site na internet"       000 http caixa1 http://$SITE
  teste "IoT -> vídeo"                    200 http iot1 http://$ERP:8554
  teste "IoT -> ERP"                      000 http iot1 https://$ERP
  teste "convidado -> site na internet"   200 http conv1 http://$SITE
  teste "convidado -> ERP"                000 http conv1 https://$ERP
  cab "Endereço que o site vê quando o convidado acessa (NAT)"
  X internet timeout 8 tcpdump -n -l -i eth1 -c 1 'tcp port 80 and tcp[tcpflags] & tcp-syn != 0' 2>/dev/null &
  sleep 2; http conv1 http://$SITE >/dev/null; wait
  cab "Com o MPLS da loja 1 fora do ar"
  X loja1 ip link set eth1 down; sleep 2
  teste "convidado -> ERP (MPLS fora)"    000 http conv1 https://$ERP
  teste "caixa -> ERP (MPLS fora)"        200 http caixa1 https://$ERP
  X loja1 ip link set eth1 up; espera_ospf
  cab "Loja 2"
  teste "caixa2 -> ERP (HTTPS)"           200 http caixa2 https://$ERP
  teste "caixa2 -> vídeo"                 000 http caixa2 http://$ERP:8554
  teste "caixa2 -> site na internet"      000 http caixa2 http://$SITE
  cab "Regras carregadas na loja 1"; cmd X loja1 nft list ruleset
  }

m5(){
  cab "Saída da privada para a internet"
  teste "app -> site na internet (com NAT)" 200 http app http://$SITE
  H=$(X nuvem nft -a list chain inet nuvem postrouting | grep masquerade | sed 's/.*handle //')
  X nuvem nft delete rule inet nuvem postrouting handle "$H"
  teste "app -> site na internet (sem NAT)" 000 http app http://$SITE
  X nuvem nft -f /etc/regras.nft
  cab "Alguém de fora ganha uma rota para a privada"
  X internet ip route add 10.20.32.0/24 via 100.64.200.1
  cmd X internet ping -c 2 -W 1 $APP
  X internet ip route del 10.20.32.0/24 via 100.64.200.1
  cab "Matriz -> aplicação, com o link dedicado da nuvem no ar"; cmd X pcm traceroute -I -n -w 1 $APP
  X nuvem ip link set eth1 down; sleep 2
  cab "Matriz -> aplicação, com o link dedicado da nuvem fora"; cmd X pcm traceroute -I -n -w 1 $APP
  teste "pcm -> app com o link fora (ping)" ok pinga pcm $APP
  X nuvem ip link set eth1 up; sleep 15
  cab "Regras carregadas na nuvem"; cmd X nuvem nft list ruleset
  }

m7(){
  LOG=$(mktemp)
  cab "Monitor com linha de base: 40 s normais, depois o MPLS da loja 1 degrada"
  python3 -u operacao/monitora.py $ERP > "$LOG" 2>&1 & MON=$!
  sleep 40
  if netem_ok; then
    echo "degradação: 80 ms de atraso, 10 ms de variação e 5% de perda (netem)"
    sudo containerlab tools netem set -n clab-rede-loja1 -i eth1 --delay 80ms --jitter 10ms --loss 5 >/dev/null
    DESFAZ="sudo containerlab tools netem set -n clab-rede-loja1 -i eth1"
  else
    echo "degradação: 20% de perda (kernel sem netem, nftables)"
    X loja1 sh -c 'nft add table inet degrada && nft add chain inet degrada f "{ type filter hook postrouting priority 0; }" && nft add rule inet degrada f oifname eth1 numgen random mod 100 "<" 20 drop'
    DESFAZ="docker exec clab-rede-loja1 nft delete table inet degrada"
  fi
  T0=$(date +%s); sleep 25
  cab "Caminho durante a degradação (o OSPF não troca: continua no MPLS)"; cmd X caixa1 traceroute -I -n -w 1 $ERP
  $DESFAZ >/dev/null 2>&1; kill $MON; wait $MON 2>/dev/null
  cat "$LOG"
  for t in $(grep ANOMALIA "$LOG" | cut -d' ' -f1); do
    s=$(date -d "$t" +%s)
    if [ "$s" -ge "$T0" ]; then echo; echo "TEMPO ATÉ O ALERTA: $((s - T0)) s depois da degradação"; break; fi
  done
  cab "Cinco minutos sem degradação"
  timeout 300 python3 -u operacao/monitora.py $ERP > "$LOG" 2>&1
  echo "medições: $(grep -c ' ms\|perdido' "$LOG")   alertas: $(grep -c ANOMALIA "$LOG")"
  grep ANOMALIA "$LOG" || echo "nenhum alerta"
  rm -f "$LOG"; }

alvo=${1:-todas}
case $alvo in
  1|2|3|4|5|7) roda "$alvo";;
  todas) for n in 1 2 3 4 5 7; do roda $n; done; python3 evidencias/preenche_readme.py;;
  *) echo "uso: $0 [1|2|3|4|5|7|todas]"; exit 1;;
esac
echo; echo "Evidências em evidencias/missao*.txt"
