#!/usr/bin/env python3
"""Resumo do custom_shaders_patch.log do SimOpenTrackDay (somente leitura).

Uso:
  python logsummary.py                       # resume o log atual do jogo
  python logsummary.py caminho\\do.log        # resume um log salvo
  python logsummary.py --cars 20 --skip 20   # normaliza por 10 carros*min, ignora os 20 s iniciais
  python logsummary.py A.log B.log           # compara duas sessoes (avisa se a comparacao e fragil)
  python logsummary.py --json                # saida em JSON

O CSP apaga o log a cada abertura do jogo: copie o log para uma pasta antes de abrir de novo
se quiser compara-lo depois. Use --save NOME: a copia vai para a pasta 'sot-saved', ao lado do log do jogo.
"""
import argparse
import json
import math
import os
import re
import sys
from collections import Counter

DEFAULT_LOG = os.path.join(os.path.expanduser("~"), "Documents", "Assetto Corsa", "logs",
                           "custom_shaders_patch.log")
LINE_RE = re.compile(r"^\s*(\d+)\s+(\S+)\s+(.*)$")  # ms desde o inicio do CSP, thread, resto
OBS_RE = re.compile(r"kind=(?P<kind>\S+) carRef=(?P<car>\d+) .*?detail=(?P<detail>.*?) seq=\d+ "
                    r".*?extra=(?P<extra>.*?) resource=(?P<res>.*)$")
NUM = r"(-?\d+(?:\.\d+)?)"
HEAVY_DROP_KMH = 20.0
LATE_ENGAGE_M = 20.0
RATE_LIMIT = 1.25


def num(text):
    try:
        v = float(text)
        return v if math.isfinite(v) else None
    except (TypeError, ValueError):
        return None


def parse(path, skip_s):
    recs, info = [], {"modes": {}, "errors": Counter(), "truncated": 0}
    first_app = last_app = live_ms = shutdown_ms = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            m = LINE_RE.match(raw.rstrip("\r\n"))
            if not m:
                continue
            ms, rest = int(m.group(1)), m.group(3)
            if shutdown_ms is None and "Sim::shutdown (CSP)" in rest:
                shutdown_ms = ms
            mrep = re.search(r"Save replay: AC_\d+-\d+_(\S+?)(?:,|$)", rest)
            if mrep:
                info["replay"] = mrep.group(1)
            if "SimOpenTrackDay" not in rest:
                continue
            first_app = ms if first_app is None else first_app
            last_app = ms
            mv = re.search(r"Checking SimOpenTrackDay v(\S+?)\.\s+Custom Shaders Patch: (\S+)", rest)
            if mv:
                info["app"], info["csp"] = mv.group(1), mv.group(2)
            mm = re.search(r"\[M1a-GATE\] mode=(\S+)", rest)
            if mm:
                info["modes"].setdefault(mm.group(1), ms)
                if mm.group(1) == "live" and live_ms is None:
                    live_ms = ms
            if "\U0001F6A8" in rest:  # sirene = erro do CSP
                msg = rest.split("] ", 1)[-1] if "] " in rest else rest
                info["errors"][re.sub(r"\d+", "N", msg)[:110]] += 1
            if "global output truncated" in rest:
                info["truncated"] += 1
            mo = OBS_RE.search(rest)
            if mo:
                recs.append(("obs", ms, mo.groupdict()))
                continue
            mz = re.search(r"(Declared|Removed) yellow flag zone #(\d+)", rest)
            if mz:
                recs.append(("zone", ms, {"op": mz.group(1), "id": mz.group(2)}))
                continue
            mc = re.search(r"Car #(\d+) COLLISION .* with car #(\d+)", rest)
            if mc:
                recs.append(("hit", ms, {"a": int(mc.group(1)), "b": int(mc.group(2))}))
                continue
            ml = re.search(r"\[LINE\] car=(\d+) mode=(\S+) x=(\S+) ai=(\S+) target=(\S+)(?: rate=(\S+))?", rest)
            if ml:
                recs.append(("line", ms, {"car": int(ml.group(1)), "mode": ml.group(2), "x": num(ml.group(3)),
                                          "ai": num(ml.group(4)), "rate": num(ml.group(6))}))
    start = live_ms if live_ms is not None else first_app
    end = shutdown_ms if shutdown_ms is not None else last_app
    if start is None or end is None or end <= start:
        return None, info
    t0 = start + int(skip_s * 1000)
    info["t0"], info["end"] = t0, end
    info["minutes"] = max((end - t0) / 60000.0, 1e-6)
    return [r for r in recs if r[1] >= t0], info


def cosine(pairs):
    sxx = sum(x * x for x, _ in pairs)
    saa = sum(a * a for _, a in pairs)
    sxa = sum(x * a for x, a in pairs)
    return sxa / math.sqrt(sxx * saa) if sxx > 0 and saa > 0 else None


def mean(values):
    return sum(values) / len(values) if values else None


def summarize(path, skip_s):
    recs, info = parse(path, skip_s)
    if recs is None:
        return None
    S = {"arquivo": os.path.basename(path), "app": info.get("app"), "csp": info.get("csp"),
         "replay": re.sub(r"^O_", "", info.get("replay", "")) or None, "minutos": round(info["minutes"], 2)}
    contacts = [r for r in recs if r[0] == "obs" and r[2]["kind"].endswith("-contact")]
    drops = [num(re.search(r"drop=" + NUM, r[2]["detail"]).group(1)) if re.search(r"drop=" + NUM, r[2]["detail"]) else None
             for r in contacts]
    others = [(re.search(r"o=(\S+)", r[2]["extra"]) or [None, "?"])[1] for r in contacts]
    S["contatos"] = len(contacts)
    S["contatos_com_jogador"] = sum(1 for o in others if o == "0")
    S["contatos_com_pista"] = sum(1 for o in others if o == "track")
    S["contatos_ia_ia"] = len(contacts) - S["contatos_com_jogador"] - S["contatos_com_pista"]
    S["contatos_fortes"] = sum(1 for d in drops if d is not None and d >= HEAVY_DROP_KMH)
    hits = [r for r in recs if r[0] == "hit"]
    S["colisoes_app"] = len(hits)
    S["colisoes_com_jogador"] = sum(1 for r in hits if 0 in (r[2]["a"], r[2]["b"]))

    off = [r for r in recs if r[0] == "obs" and r[2]["kind"].endswith("-off-track")]
    wheels = [(re.search(r"w:(\w+) l:(\w+)", r[2]["extra"]) or [None, "?", "?"]) for r in off]
    S["saidas_pista"] = len(off)
    S["saidas_reais_3rodas"] = sum(1 for w in wheels if w[1] == "off")
    S["saidas_limite_de_pista"] = sum(1 for w in wheels if w[1] == "on" and w[2] == "off")
    for key, suffix in (("rodadas", "-spin"), ("contramao", "-wrong-way")):
        S[key] = sum(1 for r in recs if r[0] == "obs" and r[2]["kind"].endswith(suffix))
    stopped = [r for r in recs if r[0] == "obs" and r[2]["kind"].endswith("-stopped")]
    S["parados"] = len(stopped)
    S["parados_por_modo"] = dict(Counter((re.search(r"d=\S+s (\w+)", r[2]["detail"]) or [None, "?"])[1] for r in stopped))
    S["eventos_suprimidos_pelo_limite"] = sum(int(m.group(1)) for r in recs if r[0] == "obs"
                                                for m in [re.search(r"suppressed=(\d+)", r[2]["detail"])] if m)

    opened, durs = {}, []
    for r in recs:
        if r[0] != "zone":
            continue
        if r[2]["op"] == "Declared":
            opened[r[2]["id"]] = r[1]
        elif r[2]["id"] in opened:
            durs.append((r[1] - opened.pop(r[2]["id"])) / 1000.0)
    S["zonas_criadas"] = len(durs) + len(opened)
    S["zonas_abertas_no_fim"] = len(opened)
    S["zona_duracao_media_s"] = round(mean(durs), 1) if durs else None

    f13 = [r for r in recs if r[0] == "obs" and r[2]["kind"].startswith("f1-3-")]
    eng = [r for r in f13 if r[2]["kind"].endswith("-engaged")]
    dist = [num(m.group(1)) for r in eng for m in [re.search(r" d=(-?\d+)", r[2]["detail"])] if m]
    chk = [(num(m.group(1)), num(m.group(2))) for r in f13 for m in [re.search(r"req=" + NUM + r" act=" + NUM, r[2]["detail"])] if m]
    err = [abs(a - b) for a, b in chk if a is not None and b is not None]
    S["desvio_acionado"] = len(eng)
    S["desvio_distancia_media_m"] = round(mean(dist), 0) if dist else None
    S["desvio_tardio_menos_20m"] = sum(1 for d in dist if d < LATE_ENGAGE_M) if dist else None
    S["desvio_motivos"] = dict(Counter((re.search(r"reason=([\w-]+)", r[2]["detail"]) or [None, "?"])[1]
                                      for r in f13 if r[2]["kind"].endswith("-released")))
    S["desvio_erro_medio_m"] = round(mean(err), 2) if err else None
    S["desvio_dentro_de_1m_pct"] = round(100.0 * sum(1 for e in err if e <= 1.0) / len(err), 0) if err else None

    lines = [r[2] for r in recs if r[0] == "line" and r[2]["x"] is not None and r[2]["ai"] is not None]
    S["linha_amostras"] = len(lines)
    if lines:
        S["linha_modos"] = dict(Counter(l["mode"] for l in lines))
        S["linha_dist_media_ate_tracado"] = round(mean([abs(l["x"] - l["ai"]) for l in lines]), 2)
        S["linha_x_perto_de_0_pct"] = round(100.0 * sum(1 for l in lines if abs(l["x"]) < 0.1) / len(lines), 0)
        cs = cosine([(l["x"], l["ai"]) for l in lines])
        S["linha_similaridade_x_ai"] = round(cs, 2) if cs is not None else None
        rates = [abs(l["rate"]) for l in lines if l["rate"] is not None]
        S["taxa_lateral_media"] = round(mean(rates), 2) if rates else None
        S["taxa_lateral_max"] = round(max(rates), 2) if rates else None
        S["taxa_lateral_acima_limite"] = sum(1 for v in rates if v > RATE_LIMIT) if rates else None

    bins = Counter()
    for r in off + contacts:
        if r in off and not (re.search(r"w:(\w+)", r[2]["extra"]) or [0, ""])[1] == "off":
            continue
        ms_ = re.search(r"s=(\d\.\d+)", r[2]["res"])
        if ms_:
            bins[int(float(ms_.group(1)) * 20)] += 1
    S["pontos_quentes"] = [f"s={b / 20:.2f}-{(b + 1) / 20:.2f}: {n}" for b, n in bins.most_common(5)]

    S["erros_do_app"] = sum(info["errors"].values())
    S["erros_principais"] = [f"{n}x {m}" for m, n in info["errors"].most_common(3)]
    S["log_cortado"] = info["truncated"]
    S["fila_tempo_preso"] = "N/D (o log atual nao registra isso)"
    S["_minutos"] = info["minutes"]
    return S


def avisos(S, cars):
    out = []
    if S["erros_do_app"]:
        out.append(f"{S['erros_do_app']} erro(s) do app no log")
    if S["log_cortado"]:
        out.append("o log foi cortado pelo limite do logger: eventos podem ter se perdido")
    if S["eventos_suprimidos_pelo_limite"]:
        out.append(f"{S['eventos_suprimidos_pelo_limite']} evento(s) repetidos foram suprimidos pelo limite")
    if S["minutos"] < 3:
        out.append("sessao curta (menos de 3 min): os numeros sao instaveis")
    if not S.get("linha_amostras"):
        out.append("sem linhas [LINE]: ENABLE_LINE_LOG estava desligado")
    if cars is None:
        out.append("use --cars N para normalizar por carros*min")
    return out


def rate_text(count, minutes, cars):
    if count is None:
        return "-"
    per_min = count / minutes
    return f"{count:4d}  ({per_min:5.2f}/min" + (f", {10 * per_min / cars:5.2f}/10 carros*min)" if cars else ")")


ROWS = [("contatos", "Contatos (F1-1)"), ("contatos_com_jogador", "  com o jogador"),
        ("contatos_ia_ia", "  IA com IA"), ("contatos_com_pista", "  com a pista"),
        ("contatos_fortes", f"  fortes (queda >= {HEAVY_DROP_KMH:.0f} km/h)"),
        ("colisoes_app", "Colisoes (AccidentManager)"), ("colisoes_com_jogador", "  com o jogador"),
        ("saidas_pista", "Saidas de pista"), ("saidas_reais_3rodas", "  reais (3+ rodas)"),
        ("saidas_limite_de_pista", "  limite de pista (1-2 rodas)"), ("rodadas", "Rodadas"),
        ("parados", "Carros parados"), ("contramao", "Contramao"), ("zonas_criadas", "Zonas amarelas criadas"),
        ("desvio_acionado", "Desvios laterais (F1-3)"), ("desvio_tardio_menos_20m", "  tardios (< 20 m)")]


def show(S, cars):
    m = S["_minutos"]
    print(f"== {S['arquivo']}  | app v{S['app']}  CSP {S['csp']}  | {S['minutos']:.1f} min analisados"
          + (f"  | {S['replay']}" if S["replay"] else ""))
    for key, label in ROWS:
        print(f"  {label:34s} {rate_text(S[key], m, cars)}")
    print(f"  Zonas: duracao media {S['zona_duracao_media_s']} s, abertas no fim {S['zonas_abertas_no_fim']}")
    print(f"  Parados por modo: {S['parados_por_modo']}")
    if S["desvio_acionado"]:
        print(f"  Desvio: distancia media {S['desvio_distancia_media_m']} m, erro medio pedido x real "
              f"{S['desvio_erro_medio_m']} m, dentro de 1 m {S['desvio_dentro_de_1m_pct']}%, motivos {S['desvio_motivos']}")
    if S.get("linha_amostras"):
        print(f"  [LINE] {S['linha_amostras']} amostras {S['linha_modos']}: dist. media ate o tracado "
              f"{S['linha_dist_media_ate_tracado']}, x perto de 0 em {S['linha_x_perto_de_0_pct']}%, "
              f"similaridade x~ai {S['linha_similaridade_x_ai']}, taxa lateral media/max "
              f"{S.get('taxa_lateral_media')}/{S.get('taxa_lateral_max')} m/s (acima do limite: {S.get('taxa_lateral_acima_limite')})")
    print(f"  Pontos quentes (saidas reais + contatos): {S['pontos_quentes']}")
    print(f"  Fila (trenzinho): {S['fila_tempo_preso']}")
    for e in S["erros_principais"]:
        print(f"  ERRO {e}")
    for a in avisos(S, cars):
        print(f"  ! {a}")


def compare(A, B, cars):
    print(f"A = {A['arquivo']}   B = {B['arquivo']}")
    problems = []
    if abs(A["minutos"] - B["minutos"]) > 0.3 * max(A["minutos"], B["minutos"]):
        problems.append(f"duracoes muito diferentes ({A['minutos']:.1f} x {B['minutos']:.1f} min)")
    if A["csp"] != B["csp"]:
        problems.append(f"builds do CSP diferentes ({A['csp']} x {B['csp']})")
    if A["app"] != B["app"]:
        problems.append(f"versoes do app diferentes ({A['app']} x {B['app']})")
    if A["replay"] and B["replay"] and A["replay"] != B["replay"]:
        problems.append("pista/carro diferentes pelo nome do replay")
    for p in problems:
        print(f"  ! COMPARACAO FRAGIL: {p}")
    print("  ! O log nao grava as opcoes do app: confirme por conta propria que so UMA coisa mudou entre A e B.")
    print(f"  {'':34s} {'A (por min)':>14s} {'B (por min)':>14s}  variacao")
    for key, label in ROWS:
        a, b = A[key] / A["_minutos"], B[key] / B["_minutos"]
        delta = f"{100 * (b - a) / a:+.0f}%" if a > 0 else ("novo" if b > 0 else "=")
        print(f"  {label:34s} {a:14.2f} {b:14.2f}  {delta}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("logs", nargs="*", help="um log (resume) ou dois (compara). Padrao: log atual do jogo")
    ap.add_argument("--skip", type=float, default=15.0, help="segundos iniciais a ignorar (padrao 15)")
    ap.add_argument("--cars", type=int, default=None, help="numero de carros de IA, para normalizar")
    ap.add_argument("--json", action="store_true", help="saida em JSON")
    ap.add_argument("--save", metavar="NOME", help="copia o log atual do jogo para a pasta sot-saved (ao lado do log) e sai "
                    "(faca isso ANTES de abrir o jogo de novo: o CSP apaga o log)")
    args = ap.parse_args()
    if args.save:
        import shutil
        import time
        dest_dir = os.path.join(os.path.dirname(DEFAULT_LOG), "sot-saved")
        os.makedirs(dest_dir, exist_ok=True)
        safe = re.sub(r"[^\w.-]+", "-", args.save)
        dest = os.path.join(dest_dir, time.strftime("%Y%m%d-%H%M") + "-" + safe + ".log")
        shutil.copy2(DEFAULT_LOG, dest)
        print("log salvo em", dest)
        return
    paths = args.logs or [DEFAULT_LOG]
    if len(paths) > 2:
        sys.exit("passe no maximo dois logs")
    results = []
    for p in paths:
        if not os.path.isfile(p):
            sys.exit(f"arquivo nao encontrado: {p}")
        s = summarize(p, args.skip)
        if s is None:
            sys.exit(f"{p}: nenhuma sessao do SimOpenTrackDay encontrada (o app carregou? o log foi sobrescrito?)")
        results.append(s)
    if args.json:
        print(json.dumps([{k: v for k, v in s.items() if not k.startswith("_")} for s in results],
                         ensure_ascii=False, indent=2))
    elif len(results) == 2:
        compare(results[0], results[1], args.cars)
    else:
        show(results[0], args.cars)


if __name__ == "__main__":
    main()
