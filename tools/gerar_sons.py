# Gera os sons do catalogo game/data/audio/sons.json no ElevenLabs (skill som).
#
#   python -I tools/gerar_sons.py --simular              lista o que falta, sem gastar credito
#   python -I tools/gerar_sons.py                        gera tudo o que falta (efeitos, musicas, arauto)
#   python -I tools/gerar_sons.py --so galope,botao      so estes ids
#   python -I tools/gerar_sons.py --grupo sons|musicas|voz
#   python -I tools/gerar_sons.py --voz-id <id>          voz do arauto ja criada (senao cria pela descricao)
#
# A chave NUNCA vai no repositorio nem na conversa: variavel de ambiente
# ELEVENLABS_API_KEY, ou o arquivo .chaves.env na raiz (ignorado pelo git) com
# a linha ELEVENLABS_API_KEY=...
#
# Nao sobrescreve arquivo existente (gerar de novo = apagar o arquivo antes).
# Sons curtos (ate formatos.curto_ate_s) saem em WAV (latencia), o resto em MP3.
# Cada prompt recebe o sufixo de estilo do catalogo, para os sons combinarem.
# Depois de gerar: ouvir, apagar as variacoes ruins e rodar o import do Godot.
import argparse
import json
import os
import struct
import sys
import time
import urllib.error
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOGO = os.path.join(RAIZ, "game", "data", "audio", "sons.json")
AUDIO = os.path.join(RAIZ, "game", "audio")
API = "https://api.elevenlabs.io"
TAXA_PCM = 44100


def chave():
    k = os.environ.get("ELEVENLABS_API_KEY", "")
    arq = os.path.join(RAIZ, ".chaves.env")
    if not k and os.path.exists(arq):
        for linha in open(arq, encoding="utf-8"):
            if linha.strip().startswith("ELEVENLABS_API_KEY="):
                k = linha.split("=", 1)[1].strip().strip('"')
    return k


def pedir(caminho, corpo, k, consulta=""):
    url = API + caminho + (("?" + consulta) if consulta else "")
    req = urllib.request.Request(url, data=json.dumps(corpo).encode("utf-8"), method="POST",
                                 headers={"xi-api-key": k, "Content-Type": "application/json"})
    for tentativa in range(3):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return r.read(), r.headers.get("Content-Type", "")
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", "replace")[:300]
            if e.code in (429, 500, 502, 503) and tentativa < 2:
                time.sleep(5 * (tentativa + 1))
                continue
            raise RuntimeError("HTTP %d em %s: %s" % (e.code, caminho, msg))
    raise RuntimeError("sem resposta: " + caminho)


def wav_de_pcm(pcm, caminho):
    with open(caminho, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, TAXA_PCM, TAXA_PCM * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(pcm)) + pcm)


def arquivos_existentes(pasta, nome):
    d = os.path.join(AUDIO, pasta)
    if not os.path.isdir(d):
        return []
    return [a for a in os.listdir(d) if a.startswith(nome + "_") and a.split(".")[-1] in ("ogg", "mp3", "wav")]


def plano(cat, grupos, so):
    """Lista de (grupo, id, pasta, nome_arquivo_sem_ext, numero, entrada) que faltam."""
    falta = []
    curto = float(cat["formatos"]["curto_ate_s"])
    for grupo in ("sons", "musicas"):
        if grupo not in grupos:
            continue
        for id_, e in cat[grupo].items():
            if so and id_ not in so:
                continue
            n = int(e.get("variacoes", 1))
            ja = arquivos_existentes(e["pasta"], id_)
            for i in range(1, n + 1):
                base = "%s_%02d" % (id_, i)
                if any(a.startswith(base + ".") for a in ja):
                    continue
                ext = "wav" if grupo == "sons" and float(e["duracao_s"]) <= curto else "mp3"
                falta.append((grupo, id_, e["pasta"], base, ext, e))
    if "voz" in grupos:
        v = cat["voz"]
        for id_, falas in v["falas"].items():
            if so and id_ not in so:
                continue
            for idioma, texto in falas.items():
                pasta = "%s/%s" % (v["pasta"], idioma)
                base = "arauto_%s_01" % id_
                if any(a.startswith(base + ".") for a in arquivos_existentes(pasta, "arauto_" + id_)):
                    continue
                falta.append(("voz", id_, pasta, base, "mp3", {"texto": texto, "idioma": idioma}))
    return falta


def gerar_efeito(cat, e, ext, k):
    estilo = cat["estilo"]["ambiente" if e.get("loop") else ("interface" if e["bus"] == "UI" else "efeito")]
    corpo = {"text": "%s. %s" % (e["prompt"], estilo), "duration_seconds": max(0.5, min(30.0, float(e["duracao_s"]))),
             "prompt_influence": 0.5}
    if e.get("loop"):
        corpo["loop"] = True
    fmt = "pcm_44100" if ext == "wav" else "mp3_44100_128"
    try:
        dados, _ = pedir("/v1/sound-generation", corpo, k, "output_format=" + fmt)
    except RuntimeError as erro:
        if "loop" in corpo and "422" in str(erro):
            del corpo["loop"]  # modelo sem loop nativo: o loop vem da importacao
            dados, _ = pedir("/v1/sound-generation", corpo, k, "output_format=" + fmt)
        else:
            raise
    return dados


def gerar_musica(cat, e, k):
    corpo = {"prompt": "%s. %s" % (e["prompt"], cat["estilo"]["musica"]),
             "music_length_ms": int(float(e["duracao_s"]) * 1000)}
    dados, _ = pedir("/v1/music", corpo, k, "output_format=mp3_44100_128")
    return dados


def criar_voz(cat, k):
    v = cat["voz"]
    amostra = " ".join(f["en"] for f in list(v["falas"].values())[:6])
    corpo = {"voice_description": v["descricao_voz"], "text": amostra}
    dados, _ = pedir("/v1/text-to-voice/create-previews", corpo, k)
    previews = json.loads(dados)["previews"]
    gid = previews[0]["generated_voice_id"]
    corpo = {"voice_name": "Arauto Torneio Medieval", "voice_description": v["descricao_voz"], "generated_voice_id": gid}
    dados, _ = pedir("/v1/text-to-voice/create-voice-from-preview", corpo, k)
    return json.loads(dados)["voice_id"]


def gerar_fala(voz_id, texto, k):
    corpo = {"text": texto, "model_id": "eleven_multilingual_v2",
             "voice_settings": {"stability": 0.45, "similarity_boost": 0.8, "style": 0.6, "use_speaker_boost": True}}
    dados, _ = pedir("/v1/text-to-speech/" + voz_id, corpo, k, "output_format=mp3_44100_128")
    return dados


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--simular", action="store_true")
    ap.add_argument("--so", default="")
    ap.add_argument("--grupo", default="sons,musicas,voz")
    ap.add_argument("--voz-id", default="")
    a = ap.parse_args()
    cat = json.load(open(CATALOGO, encoding="utf-8"))
    so = set(x for x in a.so.split(",") if x)
    falta = plano(cat, set(a.grupo.split(",")), so)
    segundos = sum(float(f[5].get("duracao_s", 2)) for f in falta if f[0] != "voz")
    falas = sum(1 for f in falta if f[0] == "voz")
    print("faltam %d arquivos: %d efeitos/musicas (%.0f s de audio) e %d falas" % (len(falta), len(falta) - falas, segundos, falas))
    if a.simular:
        for f in falta:
            print("  %-8s %s/%s.%s" % (f[0], f[2], f[3], f[4]))
        return 0
    k = chave()
    if not k:
        print("sem ELEVENLABS_API_KEY (variavel de ambiente ou .chaves.env na raiz)")
        return 2
    voz_id = a.voz_id
    feitos = 0
    for grupo, id_, pasta, base, ext, e in falta:
        destino_dir = os.path.join(AUDIO, *pasta.split("/"))
        os.makedirs(destino_dir, exist_ok=True)
        destino = os.path.join(destino_dir, base + "." + ext)
        try:
            if grupo == "sons":
                dados = gerar_efeito(cat, e, ext, k)
            elif grupo == "musicas":
                dados = gerar_musica(cat, e, k)
            else:
                if not voz_id:
                    voz_id = criar_voz(cat, k)
                    print("voz do arauto criada: %s (guarde: --voz-id %s)" % (voz_id, voz_id))
                dados = gerar_fala(voz_id, e["texto"], k)
        except RuntimeError as erro:
            print("FALHOU %s: %s" % (base, erro))
            if "401" in str(erro) or "quota" in str(erro).lower():
                return 1
            continue
        if ext == "wav":
            wav_de_pcm(dados, destino)
        else:
            open(destino, "wb").write(dados)
        feitos += 1
        print("ok %s/%s.%s" % (pasta, base, ext))
    print("gerados %d de %d" % (feitos, len(falta)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
