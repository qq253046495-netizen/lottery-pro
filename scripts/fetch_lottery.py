#!/usr/bin/env python3
"""
彩票开奖数据抓取 -> 生成 App 可读取的 JSON
输出: data/dlt.json, data/ssq.json
格式: {"type":"dlt","draws":[{"issue":int,"date":"YYYY-MM-DD","front":[...],"back":[...]}]}

数据源（官网前端公开接口，非商用开放 API，仅个人使用）:
  福彩双色球: 中彩网 cwl.gov.cn  findDrawNotice
  体彩大乐透: 中国体彩网 webapi.sporttery.cn  getHistoryPageListV1

用法:
  python scripts/fetch_lottery.py            # 抓官网最新 ~150 期
  python scripts/fetch_lottery.py --n 300    # 自定义期数
抓取失败自动回退到本地确定性示例数据。
"""
import json
import os
import random
import sys
import datetime
import urllib.request

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

CWL_URL = ("https://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/"
           "findDrawNotice?name={name}&pageNo=1&pageSize={n}&systemType=PC")
SPORT_URL = ("https://webapi.sporttery.cn/gateway/lottery/getHistoryPageListV1.qry"
             "?gameNo=85&provinceId=0&pageSize={n}&pageNo=1&isVerify=1")


def http_get(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=25) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_ssq(n):
    data = http_get(CWL_URL.format(name="ssq", n=n), {"User-Agent": UA})
    out = []
    for it in data.get("result", []):
        red = [int(x) for x in it["red"].split(",") if x.strip()]
        blue = [int(x) for x in it["blue"].split(",") if x.strip()]
        date = it.get("date", "").split("(")[0]
        out.append({"issue": int(it["code"]), "date": date, "front": red, "back": blue})
    return out


def fetch_dlt(n):
    headers = {
        "User-Agent": UA,
        "Referer": "https://www.lottery.gov.cn/kj/kjlb.html?dlt",
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/json, text/javascript, */*; q=0.01",
    }
    data = http_get(SPORT_URL.format(n=n), headers)
    out = []
    for it in data.get("value", {}).get("list", []):
        nums = it["lotteryDrawResult"].split()
        front = [int(x) for x in nums[:5]]
        back = [int(x) for x in nums[5:7]]
        out.append({"issue": int(it["lotteryDrawNum"]), "date": it["lotteryDrawTime"],
                    "front": front, "back": back})
    return out


def fetch_remote(ctype, n):
    if ctype == "ssq":
        return fetch_ssq(n)
    if ctype == "dlt":
        return fetch_dlt(n)
    raise ValueError(ctype)


def gen_local(ctype, n=200, seed=20260602):
    """本地确定性示例数据（仅抓官网失败时的回退）。"""
    rng = random.Random(seed + (1 if ctype == "dlt" else 1000))
    fn, fmax = (5, 35) if ctype == "dlt" else (6, 33)
    bn, bmax = (2, 12) if ctype == "dlt" else (1, 16)
    draws = []
    d = datetime.date(2024, 1, 1)
    step = 3 if ctype == "dlt" else 2
    for i in range(1, n + 1):
        front = sorted(rng.sample(range(1, fmax + 1), fn))
        back = sorted(rng.sample(range(1, bmax + 1), bn))
        draws.append({"issue": i, "date": d.isoformat(), "front": front, "back": back})
        d += datetime.timedelta(days=step)
    return draws


def build(ctype, n):
    draws = None
    try:
        draws = fetch_remote(ctype, n)
        print(f"[{ctype}] 官网拉取 {len(draws)} 期")
    except Exception as e:  # noqa: BLE001
        print(f"[{ctype}] 官网失败: {e}，回退本地示例", file=sys.stderr)
        draws = gen_local(ctype)
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, f"{ctype}.json"), "w", encoding="utf-8") as f:
        json.dump({"type": ctype, "draws": draws}, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    n = 150
    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--n" and i + 1 < len(args):
            n = int(args[i + 1])
        elif a.startswith("--n="):
            n = int(a.split("=", 1)[1])
    build("dlt", n)
    build("ssq", n)
    print(f"已生成 data/dlt.json, data/ssq.json（各约 {n} 期）")
