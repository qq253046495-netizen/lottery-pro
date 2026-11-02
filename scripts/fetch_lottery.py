#!/usr/bin/env python3
"""
彩票开奖数据抓取 -> 生成 App 可读取的 JSON
输出: data/dlt.json, data/ssq.json
格式: {"type":"dlt","draws":[{"issue":int,"date":"YYYY-MM-DD","front":[...],"back":[...]}]}

数据源（官网前端公开接口，非商用开放 API，仅个人低频使用）:
  福彩双色球: 中彩网 cwl.gov.cn  findDrawNotice
  体彩大乐透: 中国体彩网 webapi.sporttery.cn  getHistoryPageListV1

用法:
  python scripts/fetch_lottery.py                # 抓官网最新 150 期
  python scripts/fetch_lottery.py --n 300        # 自定义期数
  python scripts/fetch_lottery.py --no-fallback  # 抓取失败直接报错，绝不写示例数据（CI 用）

默认行为: 抓取失败时回退到本地确定性示例数据（仅本机调试方便）。
--no-fallback: 抓取失败 -> 不写文件 -> 退出码 2，保留仓库里已有的真实数据。
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
           "findDrawNotice?name={name}&pageNo={page}&pageSize={n}&systemType=PC")
SPORT_URL = ("https://webapi.sporttery.cn/gateway/lottery/getHistoryPageListV1.qry"
             "?gameNo=85&provinceId=0&pageSize={n}&pageNo={page}&isVerify=1")

# 号码结构约束（大乐透 5/35+2/12，双色球 6/33+1/16）
SPEC = {
    "dlt": {"front": (5, 35), "back": (2, 12)},
    "ssq": {"front": (6, 33), "back": (1, 16)},
}


def http_get(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=25) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_ssq(n):
    out = []
    page = 1
    while len(out) < n and page <= 10:
        data = http_get(CWL_URL.format(name="ssq", page=page, n=min(n, 100)),
                        {"User-Agent": UA,
                         "Referer": "https://www.cwl.gov.cn/ygkj/wqkjgg/ssq/"})
        batch = data.get("result") or []
        if not batch:
            break
        for it in batch:
            red = [int(x) for x in it["red"].split(",") if x.strip()]
            blue = [int(x) for x in it["blue"].split(",") if x.strip()]
            date = (it.get("date") or "").split("(")[0].strip()
            out.append({"issue": int(it["code"]), "date": date, "front": red, "back": blue})
        page += 1
    return out[:n]


def fetch_dlt(n):
    headers = {
        "User-Agent": UA,
        "Referer": "https://www.lottery.gov.cn/kj/kjlb.html?dlt",
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/json, text/javascript, */*; q=0.01",
    }
    out = []
    page = 1
    # 体彩接口单页上限 100，超过就翻页
    while len(out) < n and page <= 10:
        data = http_get(SPORT_URL.format(n=min(n, 100), page=page), headers)
        batch = (data.get("value") or {}).get("list") or []
        if not batch:
            break
        for it in batch:
            nums = [x for x in it["lotteryDrawResult"].split() if x.strip()]
            out.append({"issue": int(it["lotteryDrawNum"]),
                        "date": it["lotteryDrawTime"],
                        "front": [int(x) for x in nums[:5]],
                        "back": [int(x) for x in nums[5:7]]})
        page += 1
    return out[:n]


def fetch_remote(ctype, n):
    return fetch_ssq(n) if ctype == "ssq" else fetch_dlt(n)


def validate(ctype, draws):
    """结构校验：数量、去重、号码个数/范围、日期可解析。不通过直接抛异常。"""
    spec = SPEC[ctype]
    fn, fmax = spec["front"]
    bn, bmax = spec["back"]
    if not draws:
        raise ValueError("抓取结果为空")
    issues = [d["issue"] for d in draws]
    if len(set(issues)) != len(issues):
        raise ValueError("期号重复")
    for d in draws:
        if len(d["front"]) != fn or len(d["back"]) != bn:
            raise ValueError(f"期号 {d['issue']} 号码个数异常: {d['front']} {d['back']}")
        if not all(1 <= x <= fmax for x in d["front"]):
            raise ValueError(f"期号 {d['issue']} 前区越界: {d['front']}")
        if not all(1 <= x <= bmax for x in d["back"]):
            raise ValueError(f"期号 {d['issue']} 后区越界: {d['back']}")
        if len(set(d["front"])) != fn:
            raise ValueError(f"期号 {d['issue']} 前区重复: {d['front']}")
        datetime.date.fromisoformat(d["date"])
    newest = max(issues)
    if newest < 2000000 and ctype == "ssq":
        pass  # 双色球期号形如 2026125，本身合法
    return True


def gen_local(ctype, n=200, seed=20260602):
    """本地确定性示例数据（仅本机调试回退用，CI 里禁用）。"""
    rng = random.Random(seed + (1 if ctype == "dlt" else 1000))
    fn, fmax = (5, 35) if ctype == "dlt" else (6, 33)
    bn, bmax = (2, 12) if ctype == "dlt" else (1, 16)
    draws = []
    d = datetime.date(2024, 1, 1)
    step = 3 if ctype == "dlt" else 2
    for i in range(1, n + 1):
        draws.append({"issue": i, "date": d.isoformat(),
                      "front": sorted(rng.sample(range(1, fmax + 1), fn)),
                      "back": sorted(rng.sample(range(1, bmax + 1), bn))})
        d += datetime.timedelta(days=step)
    return draws


def load_existing(ctype):
    path = os.path.join(OUT_DIR, f"{ctype}.json")
    if not os.path.exists(path):
        return None, 0
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        draws = d.get("draws") or []
        return draws, max((x["issue"] for x in draws), default=0)
    except Exception:  # noqa: BLE001
        return None, 0


def build(ctype, n, allow_fallback=True):
    """返回 True 表示数据已是最新/已写入，False 表示失败且未写文件。"""
    try:
        draws = fetch_remote(ctype, n)
        validate(ctype, draws)
        print(f"[{ctype}] 官网拉取 {len(draws)} 期，最新 {max(d['issue'] for d in draws)}")
    except Exception as e:  # noqa: BLE001
        if not allow_fallback:
            print(f"[{ctype}] 抓取失败: {e} -> 保持现有数据不变", file=sys.stderr)
            return False
        old, old_max = load_existing(ctype)
        print(f"[{ctype}] 抓取失败: {e} -> 回退本地示例", file=sys.stderr)
        draws = gen_local(ctype)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{ctype}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"type": ctype, "draws": draws}, f, ensure_ascii=False, indent=2)
    return True


if __name__ == "__main__":
    n = 150
    allow_fallback = True
    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--n" and i + 1 < len(args):
            n = int(args[i + 1])
        elif a.startswith("--n="):
            n = int(a.split("=", 1)[1])
        elif a == "--no-fallback":
            allow_fallback = False

    ok = [build("dlt", n, allow_fallback), build("ssq", n, allow_fallback)]
    if not all(ok):
        print("部分彩种抓取失败，未覆盖已有数据", file=sys.stderr)
        sys.exit(2)
    print(f"已生成 data/dlt.json, data/ssq.json（各约 {n} 期）")
