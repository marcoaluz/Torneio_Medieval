# Gera tests/shared/cenarios_servico_entrada.json (cenarios de paridade do servidor).
# Depois: bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/gravar_cenarios.gd
#   python -I tools/gerar_cenarios_entrada.py
import io
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DIA = 86400
BASE = 1790000000  # criado_em dos cenarios (tools/gravar_cenarios.gd)
PERS = {"nome": "Isolda", "nome_casa": "Casa Pardal", "corpo": "feminino", "rosto": "1", "cabelo": "1",
        "pele": "clara", "cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": "preto"}
BRASAO = {"forma": "classico", "divisao": "partido", "cor1": "verde_floresta", "cor2": "prata", "simbolo": "lua",
          "posicao": "centro", "cor_simbolo": "ouro_velho"}


def cmd(t, nome, *args):
    return {"t": t, "cmd": nome, "args": list(args)}


def set_(t, **kv):
    return {"t": t, "set": {k.replace("__", "."): v for k, v in kv.items()}}


cenarios = []

# 1. personagem, vila, treino e cavalos ---------------------------------------
p = []
p.append(cmd(0, "criar_personagem", {k: v for k, v in PERS.items() if k != "pele"}))
p.append(cmd(0, "criar_personagem", dict(PERS, nome="Porra Loca")))
p.append(cmd(0, "criar_personagem", dict(PERS, nome="X")))
p.append(cmd(0, "criar_personagem", dict(PERS, nome="Isolda 2")))
p.append(cmd(0, "criar_personagem", PERS))
p.append(cmd(1, "definir_brasao", BRASAO))
p.append(set_(2, inventario__ouro=5000, cavaleiro__nivel=10))
p.append(cmd(10, "melhorar_predio", "casa_senhorial"))          # primeiro dia: timer de 15 s
p.append(cmd(12, "concluir_timer", "@timer:0"))                 # ainda nao terminou
p.append(cmd(30, "concluir_timer", "@timer:0"))
p.append(cmd(31, "melhorar_predio", "casa_senhorial"))
p.append(cmd(31, "melhorar_predio", "casa_senhorial"))          # ja ocupado
p.append(cmd(32, "melhorar_predio", "estabulo"))
p.append(cmd(32, "melhorar_predio", "arena"))
p.append(cmd(32, "melhorar_predio", "nao_existe"))
p.append(cmd(33, "treinar_cavaleiro", "forca"))
p.append(cmd(34, "treinar_cavaleiro", "precisao"))              # sem vaga
p.append(cmd(34, "treinar_cavaleiro", "xyz"))
p.append(cmd(35, "treinar_cavalo", "@cavalo:0", "velocidade"))  # cavalo ativo
p.append(cmd(35, "adicionar_cavalo", "branco", {"velocidade": 55, "folego": 45, "temperamento": 60}))
p.append(cmd(36, "treinar_cavalo", "@cavalo:1", "velocidade"))
p.append(cmd(36, "treinar_cavalo", "@cavalo:1", "folego"))      # ja treinando
p.append(cmd(37, "usar_cavalo", "@cavalo:1"))                   # treinando: nao pode
p.append(cmd(37, "usar_cavalo", "zzz"))
p.append(cmd(200, "concluir_timer", "@timer:0"))
p.append(cmd(200, "concluir_timer", "@timer:0"))
p.append(cmd(200, "concluir_timer", "@timer:0"))
p.append(cmd(200, "concluir_timer", "@timer:0"))
p.append(cmd(200, "concluir_timer", "@timer:0"))
p.append(cmd(201, "usar_cavalo", "@cavalo:1"))
p.append(cmd(202, "registrar_justa", {"equipamento_final": {"elmo": {"durabilidade": 10}, "lanca": {"durabilidade": 20}}, "gasta_folego": True}))
p.append(cmd(203, "registrar_justa", {"equipamento_final": {}, "gasta_folego": False}))
p.append(cmd(204, "equipar", "@item:1"))
p.append(cmd(204, "equipar", "nao_existe"))
p.append(cmd(205, "definir_visual", "elmo", "@item:0"))
p.append(cmd(205, "definir_visual", "peitoral", "@item:0"))     # espaco errado
p.append(cmd(205, "definir_visual", "elmo", ""))
p.append(cmd(206, "equipar_habilidades", ["bloqueio"]))
p.append(cmd(206, "equipar_habilidades", ["investida", "golpe_pesado"]))
p.append(cmd(206, "equipar_habilidades", ["xyz"]))
p.append(set_(207, cavaleiro__nivel=20))
p.append(cmd(208, "equipar_habilidades", ["investida", "bloqueio"]))
# depois do primeiro dia: duracoes reais
p.append(cmd(DIA + 100, "melhorar_predio", "casa_senhorial"))
p.append(cmd(DIA + 100, "treinar_cavaleiro", "equilibrio"))
p.append(cmd(DIA + 5000, "concluir_timer", "@timer:0"))
p.append(cmd(DIA + 9000, "concluir_timer", "@timer:0"))
p.append(cmd(DIA + 9000, "concluir_timer", "@timer:0"))
cenarios.append({"nome": "personagem, vila, treino e cavalos", "passos": p})

# 2. conserto, forja e fundição ----------------------------------------------
p = []
p.append(set_(0, inventario__ouro=30000, cavaleiro__nivel=15, vila__predios__casa_senhorial={"nivel": 5},
              vila__predios__armeiro={"nivel": 3}, vila__predios__ferreiro={"nivel": 3}, inventario__projetos=["vigia"],
              inventario__materiais={"sucata": 60, "lingote_ferro": 40, "lingote_aco": 12, "couro": 12, "tecido_nobre": 4,
                                     "ornamento": 3, "fragmentos": 300}))
p.append(cmd(1, "consertar", "@item:0"))                        # inteira
p.append(set_(2, inventario__itens__0__durabilidade=10, inventario__itens__1__durabilidade=0))
p.append(cmd(DIA + 10, "consertar", "@item:0"))
p.append(cmd(DIA + 11, "consertar", "@item:1"))
p.append(cmd(DIA + 12, "consertar", "@item:2"))                 # inteira
p.append(cmd(DIA + 30, "forjar", "nao_existe"))
p.append(cmd(DIA + 30, "forjar", "elmo_dragao"))                # sem projeto
p.append(cmd(DIA + 31, "forjar", "elmo_vigia"))
p.append(cmd(DIA + 32, "forjar", "peitoral_vigia"))
p.append(cmd(DIA + 33, "forjar", "escudo_vigia"))
p.append(cmd(DIA + 34, "fundir", "lingote_ferro", 5))
p.append(cmd(DIA + 34, "fundir", "lingote_aco", 2))
p.append(cmd(DIA + 34, "fundir", "lingote_ouro", 1))
p.append(cmd(DIA + 35, "fundir", "lingote_ferro", 0))
p.append(cmd(DIA + 20000, "concluir_timer", "@timer:0"))
p.append(cmd(DIA + 20000, "concluir_timer", "@timer:0"))
p.append(cmd(DIA + 20000, "concluir_timer", "@timer:0"))
p.append(cmd(DIA + 20000, "concluir_timer", "@timer:0"))
p.append(cmd(DIA + 20002, "forjar", "peitoral_vigia"))
p.append(cmd(DIA + 30000, "concluir_timer", "@timer:0"))
for i in range(11):
    p.append(cmd(DIA + 31000 + i, "melhorar_peca", "@item:0"))
p.append(cmd(DIA + 31100, "melhorar_peca", "nao_existe"))
p.append(set_(DIA + 31200, inventario__ouro=0))
p.append(cmd(DIA + 31201, "melhorar_peca", "@item:1"))
cenarios.append({"nome": "conserto, forja, fundicao e melhoria de peca", "passos": p})

# 3. baus, chaves, garantia e gemas ------------------------------------------
p = []
p.append(set_(0, cavaleiro__nivel=5, inventario__gemas=60))
for tipo in ["madeira", "ferro", "ouro", "real", "madeira", "xx"]:
    p.append(cmd(1, "ganhar_bau", tipo))
p.append(cmd(2, "abrir_bau", "@bau:0"))                        # fechado
p.append(cmd(3, "comecar_abrir", "@bau:0"))
p.append(cmd(3, "comecar_abrir", "@bau:0"))
p.append(cmd(4, "comecar_abrir", "@bau:1"))                    # outro abrindo
p.append(cmd(5, "pular_com_gemas", "@bau:0"))
p.append(cmd(6, "abrir_bau", "@bau:0"))
p.append(cmd(7, "abrir_bau", "@bau:0", True))                  # sem chave
p.append(set_(8, baus__chaves=30))
for i in range(6):
    p.append(cmd(9 + i, "abrir_bau", "@bau:0", True))
    p.append(cmd(9 + i, "ganhar_bau", "ferro"))
p.append(cmd(30, "abrir_bau", "nao_existe", True))
p.append(cmd(31, "comecar_abrir", "@bau:0"))
p.append(cmd(DIA + 5000, "abrir_bau", "@bau:0"))
p.append(cmd(DIA + 5001, "pular_com_gemas", "nao_existe"))
p.append(set_(DIA + 5002, inventario__gemas=0))
p.append(cmd(DIA + 5003, "comecar_abrir", "@bau:0"))
p.append(cmd(DIA + 5004, "pular_com_gemas", "@bau:0"))         # gemas insuficientes
cenarios.append({"nome": "baus, chaves, garantia e gemas", "passos": p})

# 4. metas, missoes, login, conquistas, titulos ------------------------------
p = []
p.append(set_(0, inventario__ouro=9000, cavaleiro__nivel=8))
p.append(cmd(DIA + 10, "melhorar_predio", "casa_senhorial"))   # abre as missoes do dia e da semana
p.append(cmd(DIA + 11, "treinar_cavaleiro", "forca"))
p.append(set_(DIA + 12, metas__diarias__0__progresso=999, metas__semanais__0__progresso=999))
p.append(cmd(DIA + 13, "resgatar_missao", "@missao:diarias:0"))
p.append(cmd(DIA + 13, "resgatar_missao", "@missao:diarias:0"))  # ja resgatada
p.append(cmd(DIA + 14, "resgatar_missao", "@missao:semanais:0"))
p.append(cmd(DIA + 14, "resgatar_missao", "@missao:diarias:1"))  # incompleta
p.append(cmd(DIA + 14, "resgatar_missao", "nao_existe"))
p.append(cmd(DIA + 15, "resgatar_login"))
p.append(cmd(DIA + 16, "resgatar_login"))                       # mesmo dia
p.append(cmd(2 * DIA + 100, "resgatar_login"))
p.append(cmd(3 * DIA + 100, "resgatar_login"))
p.append(set_(3 * DIA + 200, metas__contadores__justa=100, metas__contadores__derrubada=30))
p.append(cmd(3 * DIA + 201, "registrar_justa", {"equipamento_final": {}, "gasta_folego": True}))
p.append(cmd(3 * DIA + 202, "definir_titulo", "veterano_da_lica"))
p.append(cmd(3 * DIA + 203, "definir_titulo", "inexistente"))
p.append(cmd(3 * DIA + 204, "definir_titulo", ""))
p.append(cmd(10 * DIA, "melhorar_predio", "estabulo"))           # semana nova: novas missoes
p.append(cmd(10 * DIA + 5, "marcar_cena_vista", "comeco"))
p.append(cmd(10 * DIA + 6, "marcar_cena_vista", "xyz"))
p.append(cmd(10 * DIA + 7, "marcar_cena_vista", "comeco"))
cenarios.append({"nome": "metas, missoes, login, conquistas e titulos", "passos": p})

# 5. loja, VIP, passe, ofertas e anuncios ------------------------------------
p = []
p.append(set_(0, cavaleiro__nivel=10, inventario__ouro=5000))
p.append(cmd(1, "comprar", "gemas_medio"))
p.append(cmd(1, "comprar", "vip_mensal"))
p.append(cmd(1, "comprar", "passe_premium"))
p.append(cmd(1, "comprar", "passe_premium"))
p.append(cmd(1, "comprar", "nao_existe"))
p.append(cmd(1, "comprar", "oferta_forja"))             # sem oferta ativa
p.append(set_(2, loja__ofertas=[{"id": "oferta_forja", "ate": BASE + 99999, "vista": False}]))
p.append(cmd(3, "marcar_oferta_vista", "oferta_forja"))
p.append(cmd(4, "comprar", "oferta_forja"))
p.append(cmd(5, "comprar_com_gemas", "frase_trovao"))
p.append(cmd(5, "comprar_com_gemas", "frase_trovao"))
p.append(cmd(5, "comprar_com_gemas", "lingote_aco"))
p.append(cmd(5, "comprar_com_gemas", "lingote_aco"))
p.append(cmd(5, "comprar_com_gemas", "lingote_aco"))
p.append(cmd(5, "comprar_com_gemas", "lingote_aco"))
p.append(cmd(6, "comprar_com_gemas", "nao_existe"))
p.append(cmd(7, "usar_cosmetico", "frase_trovao"))
p.append(cmd(7, "usar_cosmetico", "vitoria_dourada"))
p.append(cmd(7, "usar_cosmetico", ""))
for i in range(14):
    p.append(cmd(10 + i, "registrar_justa", {"equipamento_final": {}, "gasta_folego": True}))
p.append(cmd(30, "resgatar_passe", 1, "gratis"))
p.append(cmd(30, "resgatar_passe", 1, "gratis"))
p.append(cmd(30, "resgatar_passe", 1, "premium"))
p.append(cmd(30, "resgatar_passe", 30, "premium"))
p.append(set_(31, loja__passe__xp=4000))
for n in [6, 15, 30]:
    p.append(cmd(32, "resgatar_passe", n, "premium"))
    p.append(cmd(32, "resgatar_passe", n, "gratis"))
# anuncios
p.append(cmd(DIA + 10, "melhorar_predio", "casa_senhorial"))
p.append(cmd(DIA + 11, "recompensa_anuncio", "cortar_timer", "@timer:0", ""))
p.append(cmd(DIA + 11, "recompensa_anuncio", "cortar_timer", "@timer:0", "tok1"))
p.append(cmd(DIA + 12, "recompensa_anuncio", "cortar_timer", "@timer:0", "tok2"))
p.append(cmd(DIA + 12, "recompensa_anuncio", "dobrar_vitoria", "", "tok3"))
p.append(set_(DIA + 13, anuncios__ultima_vitoria={"ouro": 120, "quando": BASE + DIA + 13, "usada": False}))
p.append(cmd(DIA + 14, "recompensa_anuncio", "dobrar_vitoria", "", "tok4"))
p.append(cmd(DIA + 15, "recompensa_anuncio", "dobrar_vitoria", "", "tok5"))
p.append(set_(DIA + 19, baus__espacos=[]))
for i in range(5):
    p.append(cmd(DIA + 20 + i, "recompensa_anuncio", "bau_madeira_extra", "", "tokb%d" % i))
p.append(cmd(DIA + 30, "recompensa_anuncio", "tipo_novo", "", "tok"))
p.append(cmd(2 * DIA + 500, "recompensa_anuncio", "bau_madeira_extra", "", "tokc"))
p.append(cmd(2 * DIA + 600, "definir_config", "texto", "grande"))
p.append(cmd(2 * DIA + 600, "definir_config", "texto", "gigante"))
p.append(cmd(2 * DIA + 600, "definir_config", "idioma", "en"))
p.append(cmd(2 * DIA + 600, "definir_config", "outra", 1))
p.append(cmd(2 * DIA + 600, "definir_notificacao", "bau", False))
cenarios.append({"nome": "loja, vip, passe, ofertas e anuncios", "passos": p})

# 6. PvE: disputa automatica, conclusao com eventos e tutorial ---------------
EV_VITORIA_3 = [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": False}},
                {"tipo": "fim", "vencedor": 1, "motivo": "derrubada", "placar_jogador": 2, "placar_rival": 0}]
EV_VITORIA_1 = [{"tipo": "impacto", "jogador": {"zona": "erro", "falta": False}},
                {"tipo": "fim", "vencedor": 1, "motivo": "pontos", "placar_jogador": 3, "placar_rival": 1}]
EV_DERROTA = [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": False}},
              {"tipo": "fim", "vencedor": 2, "motivo": "pontos", "placar_jogador": 1, "placar_rival": 2}]
p = []
p.append(set_(0, cavaleiro__nivel=20))
p.append(cmd(1, "recompensa_tutorial"))
p.append(cmd(1, "recompensa_tutorial"))
p.append(cmd(2, "definir_passo_tutorial", 3))
p.append(cmd(2, "definir_passo_tutorial", 9))
p.append(cmd(3, "concluir_disputa", "feira_moinho", 1, EV_VITORIA_1))   # bloqueada
p.append(cmd(3, "concluir_disputa", "feira_moinho", 0, EV_DERROTA))
p.append(cmd(4, "concluir_disputa", "feira_moinho", 0, EV_VITORIA_1))
p.append(cmd(5, "concluir_disputa", "feira_moinho", 0, EV_VITORIA_3))
p.append(cmd(6, "concluir_disputa", "feira_moinho", 1, EV_VITORIA_3))
p.append(cmd(7, "concluir_disputa", "feira_moinho", 2, EV_VITORIA_3))   # fecha o torneio
p.append(cmd(8, "concluir_disputa", "feira_ponte", 0, EV_VITORIA_3))
p.append(cmd(9, "concluir_disputa", "feira_ponte", 9, EV_VITORIA_3))
p.append(cmd(10, "concluir_disputa", "nao_existe", 0, EV_VITORIA_3))
p.append(cmd(11, "disputa_automatica", "feira_moinho", 0, 4242))
p.append(cmd(12, "disputa_automatica", "feira_moinho", 1, 99))
p.append(cmd(13, "disputa_automatica", "feira_ponte", 1, 99))          # precisa 3 estrelas
p.append(set_(14, pve__torneios__feira_ponte={"proxima": 2, "concluido": False, "estrelas": {"0": 3, "1": 3}}))
p.append(cmd(15, "disputa_automatica", "feira_ponte", 1, 12345))
p.append(cmd(16, "disputa_automatica", "feira_ponte", 0, 777))
p.append(cmd(17, "disputa_automatica", "feira_ponte", 0, 778))
p.append(cmd(18, "concluir_disputa", "feira_ponte", 2, EV_DERROTA))
p.append(cmd(19, "concluir_disputa", "feira_ponte", 2, EV_VITORIA_3))
p.append(cmd(20, "adicionar_cavalo", "alazao", {"velocidade": 40, "folego": 40, "temperamento": 40}))
p.append(cmd(21, "ganhar_bau", "ferro"))
cenarios.append({"nome": "pve, tutorial e disputa automatica", "passos": p})

# 7. Campeões: troféu, peça de troféu e revanche heroica ---------------------
p = []
FEIRAS = {"proxima": 9, "concluido": True, "estrelas": {"0": 3}}
p.append(set_(0, cavaleiro__nivel=20, pve__torneios__feira_moinho=FEIRAS, pve__torneios__feira_ponte=FEIRAS,
              pve__torneios__feira_mercado=FEIRAS, pve__torneios__feira_colheita=FEIRAS,
              pve__torneios__feira_grande={"proxima": 4, "concluido": False, "estrelas": {}}))
p.append(cmd(1, "concluir_revanche", "campeao_valdemar", EV_VITORIA_3))        # ainda sem troféu
p.append(cmd(2, "concluir_disputa", "feira_grande", 4, EV_DERROTA))             # perder não dá troféu
p.append(cmd(3, "concluir_disputa", "feira_grande", 4, EV_VITORIA_3))           # troféu + peça
p.append(cmd(4, "concluir_disputa", "feira_grande", 4, EV_VITORIA_3))           # repetir não dá outro
p.append(cmd(5, "usar_peca_trofeu", "estandarte", "trofeu_campeao_valdemar"))
p.append(cmd(5, "usar_peca_trofeu", "cimeira", "trofeu_campeao_valdemar"))      # espaço errado
p.append(cmd(5, "usar_peca_trofeu", "cimeira", "trofeu_martim_martelo"))        # não conquistada
p.append(cmd(5, "usar_peca_trofeu", "cimeira", "nao_existe"))
p.append(cmd(6, "concluir_revanche", "campeao_valdemar", EV_VITORIA_3))
p.append(cmd(7, "concluir_revanche", "campeao_valdemar", EV_VITORIA_3))        # uma por dia
p.append(cmd(DIA + 7, "concluir_revanche", "campeao_valdemar", EV_DERROTA))    # perder gasta a do dia
p.append(cmd(2 * DIA + 7, "concluir_revanche", "campeao_valdemar", EV_VITORIA_3))
p.append(cmd(2 * DIA + 8, "concluir_revanche", "martim_martelo", EV_VITORIA_3))  # sem troféu
p.append(cmd(2 * DIA + 8, "concluir_revanche", "cavaleiro_negro", EV_VITORIA_3))  # não é campeão
p.append(cmd(2 * DIA + 9, "usar_peca_trofeu", "estandarte", ""))
cenarios.append({"nome": "campeoes: trofeu, peca e revanche", "passos": p})

io.open("D:/DEV/Torneio_Medieval/tests/shared/cenarios_servico_entrada.json", "w", encoding="utf-8", newline="\n").write(
    json.dumps({"versao": 1, "cenarios": cenarios}, ensure_ascii=False, indent=1) + "\n")
print(sum(len(c["passos"]) for c in cenarios), "passos")
