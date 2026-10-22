#!/usr/bin/env python3
"""Confere o plano de endereçamento contra os requisitos. Uso: python3 verifica_plano.py"""
import csv, ipaddress, math, sys

BLOCO = ipaddress.ip_network("10.20.0.0/16")
FOLGA = 1.3  # 30% de crescimento sobre os hosts pedidos

def ler(nome):
    with open(nome, newline="", encoding="utf-8") as f:
        return [{k.strip(): v.strip() for k, v in linha.items()} for linha in csv.DictReader(f)]

req = {(r["local"], r["segmento"]): int(r["hosts"]) for r in ler("requisitos.csv")}
plano, agregados, erros = {}, {}, []
for r in ler("plano.csv"):
    try:
        rede = ipaddress.ip_network(r["prefixo"])          # recusa prefixo com bits de host
    except ValueError:
        erros.append(f"{r['local']}/{r['segmento']}: {r['prefixo']} não começa no início de uma rede desse tamanho"); continue
    if r["segmento"] == "agregado":
        agregados[r["local"]] = rede
    else:
        plano[(r["local"], r["segmento"])] = rede

for chave, hosts in req.items():
    rede = plano.get(chave)
    if rede is None:
        erros.append(f"{chave[0]}/{chave[1]}: falta no plano"); continue
    precisa = math.ceil(hosts * FOLGA)
    uteis = rede.num_addresses - 2
    if not rede.subnet_of(BLOCO):
        erros.append(f"{chave[0]}/{chave[1]}: {rede} está fora de {BLOCO}")
    if uteis < precisa:
        erros.append(f"{chave[0]}/{chave[1]}: {rede} tem {uteis} endereços úteis; precisa de {precisa}")
    ag = agregados.get(chave[0])
    if ag is None:
        erros.append(f"{chave[0]}: falta a linha do agregado")
    elif not rede.subnet_of(ag):
        erros.append(f"{chave[0]}/{chave[1]}: {rede} está fora do agregado {ag}")

for nome, redes in (("segmentos", plano), ("agregados", agregados)):
    itens = list(redes.items())
    for i, (a, ra) in enumerate(itens):
        for b, rb in itens[i + 1:]:
            if ra.overlaps(rb):
                erros.append(f"sobreposição entre {nome}: {'/'.join(a) if isinstance(a, tuple) else a} {ra} e {'/'.join(b) if isinstance(b, tuple) else b} {rb}")

if erros:
    print("\n".join("ERRO  " + e for e in erros))
    sys.exit(1)
usado = sum(r.num_addresses for r in plano.values())
reservado = sum(r.num_addresses for r in agregados.values())
print(f"OK  {len(plano)} segmentos em {len(agregados)} agregados, sem sobreposição")
print(f"    endereços nos segmentos: {usado}; reservados nos agregados: {reservado} ({usado / reservado:.0%} em uso)")
