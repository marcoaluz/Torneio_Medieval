# Gera supabase/seed/balanceamento.sql a partir dos JSON de dados do jogo
# (a tabela `balanceamento` que o servidor e o jogo leem, 3.3).
#   python -I tools/exportar_balanceamento.py
# Cada arquivo vira uma linha (nome, versao = 1, dados, ativa, publico). Depois de
# aplicada, o balanceamento é mudado no painel do Supabase: nova linha com
# versao + 1 e ativa = true (a anterior fica inativa), sem lançar versão do app.
import io
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRAS = {
    "historia": "game/data/historia/historia.json",
    "nomes_proibidos": "game/data/texto/nomes_proibidos.json",
    "acessibilidade": "game/data/ui/acessibilidade.json",
}
SAIDA = os.path.join(RAIZ, "supabase", "seed", "balanceamento.sql")
# Só a Edge Function lê estas (limites do anticheat e lista de palavras): publico = false.
PRIVADAS = {"servidor", "nomes_proibidos"}


def tabelas():
    r = {}
    pasta = os.path.join(RAIZ, "game", "data", "balance")
    for arq in sorted(os.listdir(pasta)):
        if arq.endswith(".json"):
            r[arq[:-5]] = os.path.join(pasta, arq)
    for nome, caminho in EXTRAS.items():
        r[nome] = os.path.join(RAIZ, *caminho.split("/"))
    return r


def main():
    linhas = []
    for nome, caminho in sorted(tabelas().items()):
        dados = json.load(io.open(caminho, encoding="utf-8"))
        texto = json.dumps(dados, ensure_ascii=False, separators=(",", ":"))
        assert "$json$" not in texto
        publico = "false" if nome in PRIVADAS else "true"
        linhas.append("\t('%s', 1, $json$%s$json$::jsonb, true, %s)" % (nome, texto, publico))
    sql = (
        "-- GERADO por tools/exportar_balanceamento.py a partir de game/data/. NÃO EDITAR À MÃO.\n"
        "-- Balanceamento remoto (3.3): uma linha por tabela de dados e versão. Aplicar depois da\n"
        "-- migração 20261013120000_servidor_completo.sql. Para mudar um número sem lançar versão:\n"
        "-- insira a linha com versao + 1 e ativa = true e desative a anterior (no mesmo comando).\n"
        "insert into public.balanceamento (nome, versao, dados, ativa, publico) values\n"
        + ",\n".join(linhas)
        + "\non conflict (nome, versao) do update set dados = excluded.dados, ativa = excluded.ativa,"
        " publico = excluded.publico;\n"
    )
    io.open(SAIDA, "w", encoding="utf-8", newline="\n").write(sql)
    print("gerado %s (%d tabelas)" % (os.path.relpath(SAIDA, RAIZ), len(linhas)))


main()
