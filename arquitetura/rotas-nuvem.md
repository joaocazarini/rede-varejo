# Tabela de rotas da sub-rede privada, como no console de uma nuvem pública

VPC da empresa: 10.20.32.0/23 (agregado da nuvem no plano). Sub-rede privada 10.20.32.0/24, onde fica a aplicação (10.20.32.10); sub-rede pública 10.20.33.0/27, onde fica o NAT gateway.

## Sub-rede privada (10.20.32.0/24)

| Destino | Alvo | O que cobre | Observação |
|---|---|---|---|
| 10.20.32.0/23 | local | a própria VPC | criada pela nuvem, não dá para apagar |
| 10.20.0.0/22 | gateway do link dedicado (MPLS) | matriz | rota mais específica: ganha da /16 |
| 10.20.8.0/22 | gateway do link dedicado (MPLS) | lojas 1 e 2 (dois /23) | idem |
| 10.20.0.0/16 | gateway da VPN site a site | toda a empresa, de reserva | só vale quando as rotas do link dedicado somem |
| 0.0.0.0/0 | NAT gateway (na sub-rede pública) | internet | sai com o endereço público; nada de fora entra |

Não há rota 0.0.0.0/0 para o internet gateway nesta tabela: é isso que mantém a privada fora de alcance.

## Sub-rede pública (10.20.33.0/27)

| Destino | Alvo |
|---|---|
| 10.20.32.0/23 | local |
| 0.0.0.0/0 | internet gateway |

## Como o maior prefixo decide

| Destino | Rotas que casam | Vence | Sai por |
|---|---|---|---|
| 10.20.1.7 (usuário da matriz) | 0.0.0.0/0, 10.20.0.0/16, 10.20.0.0/22 | 10.20.0.0/22 | link dedicado |
| 10.20.9.130 (caixa da loja 1) | 0.0.0.0/0, 10.20.0.0/16, 10.20.8.0/22 | 10.20.8.0/22 | link dedicado |
| 10.20.40.5 (empresa, fora dos agregados) | 0.0.0.0/0, 10.20.0.0/16 | 10.20.0.0/16 | VPN |
| 100.64.200.10 (site na internet) | 0.0.0.0/0 | 0.0.0.0/0 | NAT gateway |
| 10.20.1.7 com o link dedicado fora | 0.0.0.0/0, 10.20.0.0/16 | 10.20.0.0/16 | VPN (reserva) |

## No laboratório

O roteador `nuvem` faz o papel dos três gateways: a `eth1` é o link dedicado, a `eth2` é a VPN e também a saída com NAT (`rede/nuvem.nft`). As rotas chegam pelo OSPF, com prefixos por segmento em vez dos agregados acima. O resultado é o mesmo: com a `eth1` de pé, a matriz é alcançada por 100.64.1.13; com ela fora, por 100.64.2.13 (`evidencias/missao5.txt`).
