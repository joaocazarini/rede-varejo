#!/usr/bin/env python3
"""Copia os tempos medidos (evidencias/missao3.txt e missao7.txt) para o README,
no lugar dos marcadores ⟨XX⟩. Roda sozinho no fim de ./evidencias/coletar.sh."""
import pathlib, re

raiz = pathlib.Path(__file__).resolve().parent.parent
readme = raiz / "README.md"
texto = readme.read_text(encoding="utf-8")

def ler(nome):
    p = raiz / "evidencias" / nome
    return p.read_text(encoding="utf-8") if p.exists() else ""

m3 = re.findall(r"TEMPO SEM RESPOSTA: ([\d.]+) s", ler("missao3.txt"))
m7 = re.findall(r"TEMPO ATÉ O ALERTA: (\d+) s", ler("missao7.txt"))
virg = lambda x: x.replace(".", ",")

trocas = []
if len(m3) >= 2:
    queda, silenciosa = virg(m3[0]), virg(m3[1])
    trocas += [("Queda da interface do MPLS da loja 1 | ⟨XX⟩", f"Queda da interface do MPLS da loja 1 | {queda}"),
               ("Falha silenciosa no MPLS da loja 1 | ⟨XX⟩", f"Falha silenciosa no MPLS da loja 1 | {silenciosa}"),
               ("falha silenciosa de ⟨XX⟩ s", f"falha silenciosa de {silenciosa} s"),
               ("(⟨XX⟩ s no nosso teste)", f"({silenciosa} s no nosso teste)")]
if m7:
    trocas += [("alerta ⟨XX⟩ s depois", f"alerta {m7[0]} s depois"),
               ("Tempo até o alerta do monitor | ⟨XX⟩", f"Tempo até o alerta do monitor | {m7[0]}")]

for velho, novo in trocas:
    texto = texto.replace(velho, novo)
readme.write_text(texto, encoding="utf-8")
faltam = texto.count("⟨XX⟩")
print(f"README: {len(trocas)} marcadores preenchidos" + (f", {faltam} ainda em aberto" if faltam else ""))
