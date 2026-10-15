# Cliente mínimo da API do PixelLab (v1 e v2) para as ferramentas de arte.
# Rodar com `python -E -P` (o Pillow está na pasta do usuário; -I a ignora).
#
# - chave: PIXELLAB_API_KEY ou .chaves.env na raiz (fora do git); nunca impressa.
# - cache: cada pedido é guardado por um hash do corpo em game/art/fontes/cache/
#   (pasta com .gdignore). Pedido repetido não gasta geração de novo.
# - trabalhos em segundo plano (v2): envia, espera `GET /v2/background-jobs/{id}`
#   e devolve a última resposta.
import base64
import hashlib
import io
import json
import os
import time
import urllib.error
import urllib.request

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V1 = "https://api.pixellab.ai/v1"
V2 = "https://api.pixellab.ai/v2"
CACHE = os.path.join(RAIZ, "game", "art", "fontes", "cache")


def chave():
    k = os.environ.get("PIXELLAB_API_KEY", "")
    arq = os.path.join(RAIZ, ".chaves.env")
    if not k and os.path.exists(arq):
        for linha in open(arq, encoding="utf-8-sig"):
            if linha.strip().startswith("PIXELLAB_API_KEY="):
                k = linha.split("=", 1)[1].strip().strip('"')
    if not k:
        raise SystemExit("sem PIXELLAB_API_KEY (variavel de ambiente ou .chaves.env na raiz)")
    return k


def _http(metodo, url, corpo=None):
    dados = json.dumps(corpo).encode("utf-8") if corpo is not None else None
    req = urllib.request.Request(url, data=dados, method=metodo,
                                 headers={"Authorization": "Bearer " + chave(), "Content-Type": "application/json"})
    for tentativa in range(5):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", "replace")[:400]
            if e.code in (429, 500, 502, 503, 504) and tentativa < 4:
                time.sleep(8 * (tentativa + 1))
                continue
            raise RuntimeError("HTTP %d %s: %s" % (e.code, url.split(".ai")[-1], msg))
        except (urllib.error.URLError, TimeoutError) as e:
            if tentativa < 4:
                time.sleep(8 * (tentativa + 1))
                continue
            raise RuntimeError("rede: %s" % e)
    raise RuntimeError("sem resposta: " + url)


def saldo():
    return _http("GET", V2 + "/balance")


def _hash(caminho, corpo):
    return hashlib.sha256((caminho + json.dumps(corpo, sort_keys=True)).encode("utf-8")).hexdigest()[:24]


def pedir(caminho, corpo, versao=2, assincrono=True, rotulo=""):
    """POST com cache. Assíncrono: espera o trabalho e devolve last_response."""
    os.makedirs(CACHE, exist_ok=True)
    h = _hash(caminho, corpo)
    arq = os.path.join(CACHE, h + ".json")
    if os.path.exists(arq):
        return json.load(open(arq, encoding="utf-8"))
    base = V2 if versao == 2 else V1
    for tentativa in range(4):
        r = _http("POST", base + caminho, corpo)
        if not (assincrono and "background_job_id" in r):
            break
        job = r["background_job_id"]
        inicio = time.time()
        falhou = None
        while True:
            time.sleep(6)
            j = _http("GET", V2 + "/background-jobs/" + job)
            if j["status"] == "completed":
                r = j.get("last_response") or {}
                r["_usage"] = j.get("usage")
                break
            if j["status"] == "failed":
                falhou = json.dumps(j.get("last_response"))[:300]
                break
            if time.time() - inicio > 1800:
                falhou = "demorou demais"
                break
        if falhou is None:
            break
        # Falha do servidor (tempo esgotado, GPU): reenvia; erro do pedido: desiste.
        if tentativa == 3 or not any(t in falhou for t in ("504", "timed out", "demorou", "502", "503", "500")):
            raise RuntimeError("trabalho falhou (%s): %s" % (rotulo, falhou))
        print("  (servidor falhou em %s, reenviando)" % rotulo)
        time.sleep(10)
    json.dump(r, open(arq, "w", encoding="utf-8"))
    return r


# ---------------------------------------------------------------- imagens

def b64_de(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def img_b64(img):
    """Formato Base64Image da API."""
    return {"type": "base64", "base64": b64_de(img)}


def quadro(img):
    """Formato FrameImage (edit-animation-v2, transfer-outfit-v2, interpolation-v2)."""
    return {"image": img_b64(img), "size": {"width": img.width, "height": img.height}}


def referencia(img):
    """Formato ReferenceImage (transfer-outfit-v2)."""
    return quadro(img)


def _decodificar(item):
    if isinstance(item, dict):
        if "base64" in item:
            s = item["base64"]
        elif "image" in item:
            return _decodificar(item["image"])
        elif "url" in item or "image_url" in item:
            with urllib.request.urlopen(item.get("url") or item.get("image_url"), timeout=120) as r:
                return Image.open(io.BytesIO(r.read())).convert("RGBA")
        else:
            raise RuntimeError("imagem sem base64: %s" % list(item.keys()))
    else:
        s = item
    if s.startswith("data:"):
        s = s.split(",", 1)[1]
    return Image.open(io.BytesIO(base64.b64decode(s))).convert("RGBA")


def imagens(resposta):
    """Lista de imagens PIL de uma resposta (images, image, frames...)."""
    for chave_lista in ("images", "frames"):
        if chave_lista in resposta and resposta[chave_lista]:
            return [_decodificar(x) for x in resposta[chave_lista]]
    if "image" in resposta:
        return [_decodificar(resposta["image"])]
    if "image_url" in resposta:
        return [_decodificar({"url": resposta["image_url"]})]
    raise RuntimeError("resposta sem imagens: %s" % list(resposta.keys()))
