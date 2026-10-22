#!/usr/bin/env python3
"""Mede, uma vez por segundo, o tempo de ida e volta do caixa da loja 1 até o ERP
e avisa quando o caminho foge do normal. Uso: python3 monitora.py [destino] [--fechar-ciclo]

Linha de base (Missão 7): média e desvio das últimas 30 medições boas.
Alerta quando o tempo passa de média + 3 desvios (piso de 2 ms) ou quando há
3 perdas nas últimas 10 medições. Medições que alertam não entram na linha de base,
para o "normal" não aprender a degradação.

--fechar-ciclo (EXTRA): depois de 3 alertas seguidos, sobe para 500 o custo OSPF da
eth1 (MPLS) da loja 1 e o tráfego passa para a internet. A mudança definitiva
volta para o código (rede/loja1.conf) por pull request."""
import os, re, shlex, statistics, subprocess, sys, time

ORIGEM = shlex.split(os.environ.get("ORIGEM", "docker exec clab-rede-caixa1"))
ROTEADOR = shlex.split(os.environ.get("ROTEADOR", "docker exec clab-rede-loja1"))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
DESTINO = args[0] if args else "10.20.2.10"
FECHAR_CICLO = "--fechar-ciclo" in sys.argv

JANELA_BOA = 30      # medições boas que formam a linha de base
MINIMO_BOAS = 10     # antes disso, ainda está aprendendo o normal
DESVIOS = 3
PISO_MS = 2.0
JANELA_PERDA = 10
MAX_PERDAS = 3

def mede():
    r = subprocess.run(ORIGEM + ["ping", "-c", "1", "-W", "1", DESTINO],
                       capture_output=True, text=True)
    m = re.search(r"time=([\d.]+)", r.stdout)
    return float(m.group(1)) if m else None          # None = pacote perdido

def anomalia(historico, boas, rtt):
    """historico: últimas medições (com None para perdas); boas: últimas medições normais."""
    recentes = historico[-(JANELA_PERDA - 1):] + [rtt]
    if sum(1 for x in recentes if x is None) >= MAX_PERDAS:
        return True, "perda"
    if rtt is None or len(boas) < MINIMO_BOAS:
        return False, ""
    media = statistics.fmean(boas)
    desvio = statistics.pstdev(boas)
    limite = media + max(DESVIOS * desvio, PISO_MS)
    if rtt > limite:
        return True, f"acima de {limite:.1f} ms (normal {media:.1f} ms)"
    return False, ""

def fecha_ciclo():
    subprocess.run(ROTEADOR + ["vtysh", "-c", "conf t", "-c", "interface eth1",
                               "-c", "ip ospf cost 500"], capture_output=True)
    print(time.strftime("%H:%M:%S"), "AÇÃO: custo OSPF da eth1 da loja 1 -> 500 "
          "(tráfego vai para a internet)", flush=True)

def main():
    historico, boas, seguidos, agiu = [], [], 0, False
    while True:
        rtt = mede()
        alerta, motivo = anomalia(historico, boas, rtt)
        print(time.strftime("%H:%M:%S"), "perdido" if rtt is None else f"{rtt:.1f} ms",
              f"ANOMALIA ({motivo})" if alerta else "", flush=True)
        historico = (historico + [rtt])[-60:]
        if rtt is not None and not alerta:
            boas = (boas + [rtt])[-JANELA_BOA:]
        seguidos = seguidos + 1 if alerta else 0
        if FECHAR_CICLO and seguidos >= 3 and not agiu:
            fecha_ciclo()
            agiu, boas = True, []          # caminho novo: reaprende o normal
        time.sleep(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
