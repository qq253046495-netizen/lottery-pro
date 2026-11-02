#!/usr/bin/env python3
"""
彩票开奖数据抓取 -> 生成 App 可读取的 JSON
输出: data/dlt.json, data/ssq.json
格式: {"type":"dlt","draws":[{"issue":int,"date":"YYYY-MM-DD","front":[...],"back":[...]}]}

用法:
  python scripts/fetch_lottery.py                                   # 本地示例数据
  SOURCE_DLT=https://你的接口/dlt SOURCE_SSQ=https://你的接口/ssq \
      python scripts/fetch_lottery.py                              # 接真实数据源

接入真实数据: 把下方 fetch_remote() 换成你可信数据源的解析逻辑即可。
"""
import json
import os
import random
import datetime
import sys

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
DLT = {"front": (5, 35), "back": (2, 12)}
SSQ = {"front": (6, 33), "back": (1, 16)}


def gen_local(ctype: str, n: int = 200, seed: int = 20260602):
    """本地确定性示例数据（仅用于跑通链路）。"""
    rng = random.Random(seed + (1 if ctype == "dlt" else 1000))
    fn, fmax = (DLT if ctype == "dlt" else SSQ)["front"]
    bn, bmax = (DLT if ctype == "dlt" else SSQ)["back"]
    draws = []
    d = datetime.date(2024, 1, 1)
    step = 3 if ctype == "dlt" else 2
    for i in range(1, n + 1):
        front = sorted(random.sample(range(1, fmax + 1), fn))
        back = sorted(random.sample(range(1, bmax + 1), bn))
        draws.append({"issue": i, "date": d.isoformat(), "front": front, "back": back})
        d += datetime.timedelta(days=step)
    return draws


def fetch_remote(url: str, ctype: str):
    """
    接入真实数据源的占位函数。
    在此用 requests 抓取并解析为同样的 draw 列表，例如:
        import requests
        r = requests.get(url, timeout=20)
        data = r.json()
        return [{"issue":..., "date":..., "front":..., "back":...}, ...]
    国内官方站点普遍有反爬/证书限制，建议优先使用你已授权的稳定 API。
    """
    raise NotImplementedError("请在 fetch_remote() 中接入你的数据源")


def build(ctype: str):
    url = os.environ.get(f"SOURCE_{ctype.upper()}")
    draws = None
    if url:
        try:
            draws = fetch_remote(url, ctype)
            print(f"[{ctype}] 远程拉取 {len(draws)} 期")
        except Exception as e:  # noqa: BLE001
            print(f"[{ctype}] 远程失败: {e}，回退本地示例", file=sys.stderr)
    if not draws:
        draws = gen_local(ctype)
        print(f"[{ctype}] 本地示例 {len(draws)} 期")
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, f"{ctype}.json"), "w", encoding="utf-8") as f:
        json.dump({"type": ctype, "draws": draws}, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    build("dlt")
    build("ssq")
    print("已生成 data/dlt.json, data/ssq.json")
