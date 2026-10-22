#!/usr/bin/env python3
"""Mede quanto tempo o caixa da loja 1 fica sem resposta do ERP durante uma falha.
Roda um ping a cada 0,2 s, aplica a falha 3 s depois e mede o maior buraco entre respostas.

Uso: python3 mede_queda.py --falha "<comando>" [--desfaz "<comando>"] [--duracao 70]
Origem e destino: variáveis ORIGEM (padrão "docker exec clab-rede-caixa1") e ERP (padrão 10.20.2.10)."""
import argparse, os, re, shlex, subprocess, threading, time

p = argparse.ArgumentParser()
p.add_argument("--falha", required=True)
p.add_argument("--desfaz", default="")
p.add_argument("--duracao", type=int, default=70)
a = p.parse_args()

ORIGEM = shlex.split(os.environ.get("ORIGEM", "docker exec clab-rede-caixa1"))
ERP = os.environ.get("ERP", "10.20.2.10")
INTERVALO = 0.2

def falha():
    time.sleep(3)
    print(time.strftime("%H:%M:%S"), "falha aplicada:", a.falha, flush=True)
    subprocess.run(a.falha, shell=True)

threading.Thread(target=falha, daemon=True).start()
r = subprocess.run(ORIGEM + ["ping", "-D", "-n", "-i", str(INTERVALO), "-w", str(a.duracao), ERP],
                   capture_output=True, text=True)
if a.desfaz:
    subprocess.run(a.desfaz, shell=True)
    print(time.strftime("%H:%M:%S"), "falha desfeita:", a.desfaz)

seqs = [(int(s), float(t)) for t, s in re.findall(r"\[([\d.]+)\].*icmp_seq=(\d+)", r.stdout)]
enviados = re.search(r"(\d+) packets transmitted, (\d+) received", r.stdout)
if len(seqs) < 2:
    print("sem respostas suficientes para medir"); raise SystemExit(1)
pior = max(range(1, len(seqs)), key=lambda i: seqs[i][0] - seqs[i - 1][0])
perdidos_seguidos = seqs[pior][0] - seqs[pior - 1][0] - 1
print(enviados.group(0) if enviados else "")
print(f"maior sequência perdida: {perdidos_seguidos} pings seguidos "
      f"(icmp_seq {seqs[pior - 1][0] + 1} a {seqs[pior][0] - 1})")
print(f"TEMPO SEM RESPOSTA: {perdidos_seguidos * INTERVALO:.1f} s")
