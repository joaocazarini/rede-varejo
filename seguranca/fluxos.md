# Matriz de fluxos permitidos

Política padrão: **negar**. Só passa o que está nesta tabela; as respostas de conexões já liberadas passam pela regra `ct state established,related accept`. As regras estão em `rede/loja1.nft` e `rede/loja2.nft`, na mesma ordem desta tabela.

| # | Origem | Destino | Serviço | Decisão | Motivo |
|---|---|---|---|---|---|
| 1 | convidados (10.20.8.0/24) | qualquer endereço da empresa (10.0.0.0/8) | qualquer | **bloquear** | Cliente nunca entra na rede interna. Fica antes da regra 5: com o MPLS fora, a rota para o ERP também sai pela internet da loja e seria aceita por ela |
| 2 | caixas (10.20.9.128/26) | servidores da matriz (10.20.2.0/25) | TCP 443 (HTTPS) | permitir | Venda: o caixa consulta preço e registra a venda no ERP |
| 3 | caixas (10.20.9.128/26) | servidores da matriz (10.20.2.0/25) | ICMP echo (ping) | permitir | Teste de conectividade e monitoração (Missão 7) |
| 4 | IoT (10.20.9.192/26) | servidores da matriz (10.20.2.0/25) | TCP 8554 | permitir | Sensores e câmeras mandam vídeo para o servidor; nada mais |
| 5 | convidados (10.20.8.0/24) | internet, pela eth2 da loja | qualquer | permitir, com NAT (100.64.2.5) | Wi-Fi de clientes sai direto, sem passar pela matriz |
| 6 | qualquer | qualquer outro destino | qualquer | **bloquear** (padrão) | Zero Trust: o que não está escrito é barrado |

Proteção do próprio roteador (cadeia `input`): convidados e IoT só falam com o próprio gateway (10.20.8.1 e 10.20.9.193). Sem isso, um convidado alcançaria outros endereços da empresa que moram no roteador, como 10.20.9.129, o gateway dos caixas, porque esse tráfego não passa pela cadeia `forward`.

Loja 2: só tem caixas (10.20.11.128/26), então só as regras 2, 3 e 6.

## Testes (evidencias/missao4.txt)

| Teste | Esperado | Regra que decide |
|---|---|---|
| caixa → ERP (HTTPS) | passa (200) | 2 |
| caixa → ping no ERP | passa | 3 |
| caixa → vídeo (8554) | barrado | 6 |
| caixa → site na internet | barrado | 6 |
| IoT → vídeo (8554) | passa (200) | 4 |
| IoT → ERP (HTTPS) | barrado | 6 |
| convidado → site na internet | passa (200), o site vê 100.64.2.5 | 5 |
| convidado → ERP | barrado, inclusive com o MPLS fora do ar | 1 |
