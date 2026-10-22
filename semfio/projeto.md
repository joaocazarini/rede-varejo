# Projeto sem fio das lojas

Cada SSID é entregue pelo ponto de acesso em uma VLAN, e cada VLAN chega ao roteador da loja como um segmento do plano (`enderecamento/plano.csv`). Os números de VLAN são os mesmos nas duas lojas; muda só a sub-rede.

## SSIDs

| SSID | Autenticação | VLAN | Sub-rede loja 1 | Sub-rede loja 2 | Regra (Missão 4) |
|---|---|---|---|---|---|
| loja-corp | WPA3-Enterprise (802.1X), usuário próprio de cada funcionário | 20 | wifi-corp 10.20.9.0/25 | wifi-corp 10.20.11.0/25 | Não está na matriz de fluxos, então é negado por padrão. Quando entrar, a proposta é igual à dos caixas: ERP em TCP 443 |
| loja-clientes | portal cativo, isolamento entre clientes | 30 | convidados 10.20.8.0/24 | convidados 10.20.10.0/24 | Só internet, com NAT pela internet da loja; bloqueio explícito de 10.0.0.0/8 (regras 1 e 5 de `seguranca/fluxos.md`) |
| loja-sensores | WPA3-Personal, chave só dos sensores | 40 | iot 10.20.9.192/26 | iot 10.20.11.192/26 | Só o servidor de vídeo, TCP 8554 (regra 4) |

Os caixas são cabeados, na VLAN 10 (10.20.9.128/26 na loja 1, 10.20.11.128/26 na loja 2).

Conferência com o firewall: a VLAN 30 (loja-clientes) é a mesma sub-rede 10.20.8.0/24 que o `rede/loja1.nft` trata como `CONVIDADOS`, na `eth4`. A VLAN 40 é a `eth5` (`IOT`).

Por que cada autenticação:
- **802.1X no corporativo:** cada funcionário entra com o próprio usuário. Quando alguém sai da empresa, desativa-se a conta dele e ninguém troca senha.
- **Portal e isolamento nos clientes:** o cliente aceita os termos e não enxerga os outros aparelhos da mesma rede.
- **Chave própria nos sensores:** sensor não tem como digitar usuário e senha; a chave fica só neles, e o firewall limita o que fazem.

## Quantos pontos de acesso

| Critério | Conta | Pontos |
|---|---|---|
| Pela área | 600 m² ÷ 150 m² por ponto | 4 |
| Pela capacidade | (120 clientes + 20 funcionários + 25 sensores) ÷ 30 por ponto = 165 ÷ 30 = 5,5 | 6 |
| **Adotado** | vale o maior | **6** |

## Canais

Seis pontos em duas fileiras de três. Vizinhos: lado a lado e um em frente ao outro.

```
  AP1 ── AP2 ── AP3
   │      │      │
  AP4 ── AP5 ── AP6
```

| | AP1 | AP2 | AP3 | AP4 | AP5 | AP6 |
|---|---|---|---|---|---|---|
| 2,4 GHz | 1 | 6 | 11 | 6 | 11 | 1 |
| 5 GHz | 36 | 40 | 44 | 48 | 149 | 153 |

Em 2,4 GHz só os canais 1, 6 e 11 não se sobrepõem; alternando a ordem entre as fileiras, nenhum par de vizinhos fica no mesmo canal. Em 5 GHz cada ponto tem o seu canal.

Conferência (pares vizinhos em 2,4 GHz): AP1–AP2 1/6, AP2–AP3 6/11, AP4–AP5 6/11, AP5–AP6 11/1, AP1–AP4 1/6, AP2–AP5 6/11, AP3–AP6 11/1. Nenhum conflito.
