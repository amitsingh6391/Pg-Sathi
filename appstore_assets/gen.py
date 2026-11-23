#!/usr/bin/env python3
"""Generate PG Sathi App Store creative assets (header, search results, screenshots).

Usage:  python3 appstore_assets/gen.py
Output: appstore_assets/out/**.png  (exact App Store pixel sizes)
"""
import os, subprocess, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent
SRC, HTML, OUT = ROOT / "src", ROOT / "html", ROOT / "out"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
EMBLEM = (SRC / "emblem.png").as_uri()
ICON = (SRC / "icon.png").as_uri()

# ───────────────────────── icons ─────────────────────────
ICONS = {
    "home": '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    "bed": '<path d="M3 19V6M3 14h18v5M21 14v-2a3 3 0 0 0-3-3h-7v5"/><circle cx="7" cy="11" r="2"/>',
    "users": '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.2A6 6 0 0 1 21.5 20"/>',
    "wallet": '<rect x="3" y="6" width="18" height="14" rx="2.5"/><path d="M3 10h18M16 15h2"/>',
    "grid": '<rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/>',
    "bell": '<path d="M6 16v-5a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 21a2 2 0 0 0 4 0"/>',
    "chart": '<path d="M5 20V11M11 20V5M17 20v-7M2 20h20"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "x": '<path d="M6 6l12 12M18 6L6 18"/>',
    "search": '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
    "send": '<path d="M4 12l16-8-6 17-3-7z"/>',
    "doc": '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5M9 13h7M9 17h5"/>',
    "chat": '<path d="M4 20l1.4-4.2A8 8 0 1 1 8.6 19z"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "rupee": '<path d="M7 5h10M7 9h10M13 5c3 0 3 8-1 8H8l7 7"/>',
    "megaphone": '<path d="M3 10v4h4l8 5V5L7 10z"/><path d="M18.5 9a4 4 0 0 1 0 6"/>',
    "trend": '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
    "back": '<path d="M15 5l-7 7 7 7"/>',
    "filter": '<path d="M4 6h16M7 12h10M10 18h4"/>',
    "qr": '<rect x="4" y="4" width="6" height="6"/><rect x="14" y="4" width="6" height="6"/><rect x="4" y="14" width="6" height="6"/><path d="M14 14h2v2M18 14h2M14 18v2h2M18 18h2v2"/>',
    "calendar": '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
    "shield": '<path d="M12 3l8 3v6c0 4.5-3.5 8-8 9-4.5-1-8-4.5-8-9V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/>',
}


def ic(name, size=20, color="currentColor", sw=2):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" style="flex:none">{ICONS[name]}</svg>')


# ───────────────────────── base CSS ─────────────────────────
CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{overflow:hidden}
body{font-family:-apple-system,"SF Pro Display","SF Pro Text","Helvetica Neue",Arial,sans-serif;-webkit-font-smoothing:antialiased;color:#0F172A}
.canvas{position:relative;overflow:hidden}
.row{display:flex;align-items:center}
.between{justify-content:space-between}
.col{display:flex;flex-direction:column}
/* device */
.phone{position:absolute;width:414px;height:868px;border-radius:64px;padding:12px;
  background:linear-gradient(150deg,#3b4252 0%,#0b0f19 30%,#141a26 70%,#3b4252 100%);
  box-shadow:0 50px 100px -20px rgba(2,10,40,.55),0 30px 60px -30px rgba(0,0,0,.5),inset 0 0 0 1.5px #5b6475}
.scr{position:relative;width:390px;height:844px;border-radius:52px;overflow:hidden;background:#F1F5F9}
.island{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:124px;height:36px;border-radius:20px;background:#000;z-index:20}
.sb{position:absolute;top:0;left:0;right:0;height:54px;z-index:15;display:flex;align-items:center;justify-content:space-between;
  padding:4px 34px 0 46px;font-weight:600;font-size:16.5px;letter-spacing:-.2px}
.sb .ind{display:flex;gap:6px;align-items:center}
.tablet{position:absolute;border-radius:44px;padding:16px;
  background:linear-gradient(150deg,#3b4252 0%,#0b0f19 30%,#141a26 70%,#3b4252 100%);
  box-shadow:0 50px 100px -20px rgba(2,10,40,.55),inset 0 0 0 1.5px #5b6475}
.tscr{position:relative;border-radius:28px;overflow:hidden;background:#F1F5F9;display:flex}
/* app ui */
.app{position:absolute;inset:0;display:flex;flex-direction:column;background:#F1F5F9}
.card{background:#fff;border-radius:18px;box-shadow:0 1px 2px rgba(15,23,42,.05),0 6px 18px rgba(15,23,42,.05)}
.ttl{padding:62px 20px 10px}
.ttl h1{font-size:30px;font-weight:800;letter-spacing:-.6px}
.ttl p{font-size:14px;color:#64748B;margin-top:2px}
.chip{display:inline-flex;align-items:center;gap:6px;height:32px;padding:0 13px;border-radius:16px;font-size:13.5px;font-weight:600;background:#fff;color:#334155;border:1px solid #E2E8F0;white-space:nowrap}
.chip.on{background:#1D4ED8;color:#fff;border-color:#1D4ED8}
.pill{display:inline-flex;align-items:center;height:24px;padding:0 10px;border-radius:12px;font-size:12px;font-weight:700}
.paid{background:#DCFCE7;color:#15803D}.due{background:#FEF3C7;color:#B45309}.over{background:#FEE2E2;color:#B91C1C}
.av{width:42px;height:42px;border-radius:21px;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:15px;color:#fff;flex:none}
.nav{position:absolute;left:0;right:0;bottom:0;height:86px;background:#fff;isolation:isolate;border-top:1px solid #E2E8F0;
  display:flex;justify-content:space-around;padding-top:10px;z-index:10}
.nav div{display:flex;flex-direction:column;align-items:center;gap:4px;font-size:11px;font-weight:600;color:#94A3B8;width:64px}
.nav div.on{color:#1D4ED8}
.nav:after{content:"";position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:134px;height:5px;border-radius:3px;background:#0F172A}
.sec{font-size:16px;font-weight:700;margin:18px 20px 10px;display:flex;justify-content:space-between;align-items:center}
.sec span{font-size:13px;color:#1D4ED8;font-weight:600}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;height:48px;border-radius:14px;font-weight:700;font-size:15.5px}
.fill{flex:1;overflow:hidden}
/* marketing */
.mk-h{color:#fff;font-weight:800;letter-spacing:-1.2px;line-height:1.06;text-align:center}
.mk-s{color:rgba(255,255,255,.86);font-weight:500;text-align:center;line-height:1.3}
.float{position:absolute;background:#fff;border-radius:20px;padding:14px 18px;display:flex;align-items:center;gap:12px;
  box-shadow:0 24px 50px -12px rgba(2,10,40,.45);z-index:30}
.float .fi{width:44px;height:44px;border-radius:13px;display:flex;align-items:center;justify-content:center;flex:none}
.float b{display:block;font-size:16px;font-weight:700;color:#0F172A;white-space:nowrap}
.float small{display:block;font-size:13px;color:#64748B;margin-top:1px;white-space:nowrap}
"""

BG = {
    "brand": "linear-gradient(160deg,#1E40AF 0%,#1D4ED8 35%,#0F766E 100%)",
    "blue": "linear-gradient(165deg,#1E3A8A 0%,#2563EB 60%,#3B82F6 100%)",
    "teal": "linear-gradient(165deg,#134E4A 0%,#0F766E 45%,#14B8A6 100%)",
    "indigo": "linear-gradient(165deg,#1E1B4B 0%,#3730A3 50%,#2563EB 100%)",
    "ocean": "linear-gradient(165deg,#0C4A6E 0%,#0369A1 50%,#0D9488 100%)",
}
DECOR = """<div style="position:absolute;inset:0;pointer-events:none;
 background:radial-gradient(circle at 15% 10%,rgba(255,255,255,.18),transparent 35%),
 radial-gradient(circle at 90% 85%,rgba(253,224,138,.22),transparent 40%),
 radial-gradient(circle at 85% 15%,rgba(45,212,191,.25),transparent 35%)"></div>
<div style="position:absolute;inset:0;pointer-events:none;opacity:.08;
 background-image:radial-gradient(#fff 1.2px,transparent 1.2px);background-size:26px 26px"></div>"""


def statusbar(light=False):
    c = "#fff" if light else "#0F172A"
    return f'''<div class="sb" style="color:{c}"><span>9:41</span><span class="ind">
<svg width="19" height="12" viewBox="0 0 19 12" fill="{c}"><rect x="0" y="8" width="3.2" height="4" rx="1"/><rect x="5" y="5.5" width="3.2" height="6.5" rx="1"/><rect x="10" y="3" width="3.2" height="9" rx="1"/><rect x="15" y="0" width="3.2" height="12" rx="1"/></svg>
<svg width="17" height="12" viewBox="0 0 17 12" fill="none" stroke="{c}" stroke-width="2" stroke-linecap="round"><path d="M1.5 4.5a10 10 0 0 1 14 0M4.2 7.3a6 6 0 0 1 8.6 0"/><circle cx="8.5" cy="10.2" r="1" fill="{c}"/></svg>
<svg width="28" height="13" viewBox="0 0 28 13"><rect x=".5" y=".5" width="24" height="12" rx="3.8" fill="none" stroke="{c}" stroke-opacity=".4"/><rect x="2.5" y="2.5" width="18" height="8" rx="2.2" fill="{c}"/><rect x="25.6" y="4.3" width="1.8" height="4.4" rx=".9" fill="{c}" fill-opacity=".4"/></svg>
</span></div>'''


def nav(active):
    items = [("home", "Home"), ("grid", "Rooms"), ("users", "Tenants"), ("wallet", "Payments"), ("chart", "Reports")]
    return '<div class="nav">' + "".join(
        f'<div class="{"on" if k == active else ""}">{ic(k, 24, sw=2.1)}{t}</div>' for k, t in items) + "</div>"


AVC = ["#2563EB", "#0D9488", "#7C3AED", "#DB2777", "#EA580C", "#0891B2", "#16A34A", "#4F46E5", "#B45309", "#BE123C"]


def av(initials, i, size=42):
    return f'<div class="av" style="background:{AVC[i % len(AVC)]};width:{size}px;height:{size}px;border-radius:{size/2}px">{initials}</div>'


# ───────────────────────── app screens ─────────────────────────
def scr_dashboard(phone=True):
    stats = [("bed", "120", "Total beds", "#2563EB", "#DBEAFE"), ("users", "102", "Occupied", "#0D9488", "#CCFBF1"),
             ("home", "18", "Vacant beds", "#16A34A", "#DCFCE7"), ("calendar", "14", "Rent due", "#D97706", "#FEF3C7")]
    acts = [("rupee", "#16A34A", "#DCFCE7", "UPI payment received", "Priya Sharma · Room 204-B", "+₹8,500"),
            ("bed", "#2563EB", "#DBEAFE", "New bed request", "Rahul Verma · Room 112-A", "Review"),
            ("megaphone", "#7C3AED", "#EDE9FE", "Notice sent on WhatsApp", "Delivered to 102 tenants", "Sent"),
            ("doc", "#0D9488", "#CCFBF1", "Invoice generated", "INV-1124 · Ankit Jain", "PDF"),
            ("rupee", "#16A34A", "#DCFCE7", "Cash payment recorded", "Sneha Reddy · Room 305-A", "+₹7,800"),
            ("users", "#DB2777", "#FCE7F3", "Tenant joined via QR", "Karan Mehta · Room 210-C", "New")]
    return f'''<div class="app">
<div style="background:linear-gradient(135deg,#1D4ED8,#0E8F86);padding:64px 20px 74px;color:#fff;position:relative;overflow:hidden">
 <div style="position:absolute;right:-40px;top:-30px;width:200px;height:200px;border-radius:50%;background:rgba(255,255,255,.08)"></div>
 <div class="row between"><div><div style="font-size:14px;opacity:.85">Good morning, Rajesh 👋</div>
 <div style="font-size:24px;font-weight:800;letter-spacing:-.4px;margin-top:2px">Sunrise PG</div>
 <div style="font-size:13px;opacity:.75;margin-top:1px">Koramangala, Bengaluru</div></div>
 <div style="width:44px;height:44px;border-radius:22px;background:rgba(255,255,255,.18);display:flex;align-items:center;justify-content:center;position:relative">{ic("bell", 22, "#fff")}
 <div style="position:absolute;top:9px;right:10px;width:9px;height:9px;border-radius:5px;background:#FBBF24;border:2px solid #1f6fb8"></div></div></div>
</div>
<div class="card" style="margin:-56px 16px 0;padding:18px;position:relative">
 <div class="row between"><div style="font-size:13.5px;color:#64748B;font-weight:600">Rent collected · November</div><div class="pill paid">+12%</div></div>
 <div style="font-size:34px;font-weight:800;letter-spacing:-1px;margin:4px 0 12px">₹4,82,500</div>
 <div style="height:10px;border-radius:5px;background:#E2E8F0;overflow:hidden"><div style="width:86%;height:100%;border-radius:5px;background:linear-gradient(90deg,#2563EB,#14B8A6)"></div></div>
 <div class="row between" style="margin-top:9px;font-size:13px;color:#64748B"><span><b style="color:#0F172A">86%</b> collected</span><span><b style="color:#D97706">₹78,000</b> pending</span></div>
</div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:14px 16px 0">
 {"".join(f'<div class="card" style="padding:14px"><div style="width:38px;height:38px;border-radius:11px;background:{bg};display:flex;align-items:center;justify-content:center">{ic(i, 21, c)}</div><div style="font-size:26px;font-weight:800;margin-top:10px;letter-spacing:-.5px">{n}</div><div style="font-size:13px;color:#64748B;font-weight:500">{l}</div></div>' for i, n, l, c, bg in stats)}
</div>
<div class="sec">Recent activity <span>See all</span></div>
<div class="fill" style="padding:0 16px"><div class="card" style="padding:4px 14px">
 {"".join(f'<div class="row" style="gap:12px;padding:11px 0;{"border-top:1px solid #F1F5F9" if k else ""}"><div style="width:40px;height:40px;border-radius:12px;background:{bg};display:flex;align-items:center;justify-content:center">{ic(i, 20, c)}</div><div style="flex:1;min-width:0"><div style="font-size:14.5px;font-weight:650">{t}</div><div style="font-size:12.5px;color:#64748B">{s}</div></div><div style="font-size:13.5px;font-weight:700;color:{c}">{v}</div></div>' for k, (i, c, bg, t, s, v) in enumerate(acts))}
</div></div>
{nav("home") if phone else ""}
</div>'''


def scr_rooms(phone=True):
    rooms = [("101", "Double", "8,500", "OO"), ("102", "Triple", "7,200", "OOV"), ("103", "Single", "11,000", "O"),
             ("104", "Double", "8,500", "OR"), ("105", "Triple", "7,200", "OOO"), ("106", "Double", "8,500", "VV"),
             ("107", "Single", "11,000", "O"), ("108", "Triple", "7,200", "ORV"), ("109", "Double", "8,500", "OO"),
             ("110", "Triple", "7,200", "OOV"), ("111", "Single", "11,000", "R"), ("112", "Double", "8,500", "OV")]
    sty = {"O": ("#1D4ED8", "#fff", "#1D4ED8"), "V": ("#F0FDF4", "#15803D", "#86EFAC"), "R": ("#FFFBEB", "#B45309", "#FCD34D")}

    def beds(s):
        return "".join(f'<div style="flex:1;height:40px;border-radius:10px;background:{sty[b][0]};color:{sty[b][1]};border:1.5px solid {sty[b][2]};display:flex;align-items:center;justify-content:center;gap:4px;font-size:13px;font-weight:700">{ic("bed", 15, sty[b][1])}{"ABC"[j]}</div>' for j, b in enumerate(s))
    return f'''<div class="app">
<div class="ttl"><div class="row between"><h1>Rooms &amp; Beds</h1><div style="width:42px;height:42px;border-radius:14px;background:#1D4ED8;display:flex;align-items:center;justify-content:center">{ic("plus", 22, "#fff", 2.4)}</div></div><p>Sunrise PG · 48 rooms · 120 beds</p></div>
<div class="row" style="gap:8px;padding:6px 20px 0"><div class="chip on">Ground floor</div><div class="chip">1st floor</div><div class="chip">2nd floor</div></div>
<div class="row" style="gap:10px;margin:14px 20px 4px">
 {"".join(f'<div class="card" style="flex:1;padding:10px 12px"><div class="row" style="gap:6px;font-size:12px;color:#64748B;font-weight:600"><span style="width:10px;height:10px;border-radius:3px;background:{c}"></span>{l}</div><div style="font-size:22px;font-weight:800;margin-top:2px">{n}</div></div>' for l, n, c in [("Occupied", "102", "#1D4ED8"), ("Vacant", "18", "#22C55E"), ("Reserved", "4", "#F59E0B")])}
</div>
<div class="fill" style="padding:10px 16px 0"><div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
 {"".join(f'<div class="card" style="padding:12px"><div class="row between"><div style="font-size:16px;font-weight:800">Room {n}</div><div style="font-size:11.5px;color:#64748B;font-weight:600">{t}</div></div><div style="font-size:12.5px;color:#64748B;margin:2px 0 10px">₹{p}/bed · month</div><div class="row" style="gap:6px">{beds(s)}</div></div>' for n, t, p, s in rooms)}
</div></div>
{nav("grid") if phone else ""}
</div>'''


TENANTS = [("PS", "Priya Sharma", "Room 204 · Bed B", "₹8,500", "Paid", "paid"),
           ("RV", "Rahul Verma", "Room 112 · Bed A", "₹8,500", "Due 5 Dec", "due"),
           ("AJ", "Ankit Jain", "Room 101 · Bed A", "₹8,500", "Paid", "paid"),
           ("SR", "Sneha Reddy", "Room 305 · Bed A", "₹7,800", "Paid", "paid"),
           ("KM", "Karan Mehta", "Room 210 · Bed C", "₹7,200", "Overdue", "over"),
           ("NG", "Neha Gupta", "Room 103 · Bed A", "₹11,000", "Paid", "paid"),
           ("VS", "Vikram Singh", "Room 108 · Bed B", "₹7,200", "Due 5 Dec", "due"),
           ("AK", "Aisha Khan", "Room 206 · Bed A", "₹8,500", "Paid", "paid"),
           ("RP", "Rohit Patil", "Room 302 · Bed C", "₹7,200", "Paid", "paid"),
           ("MI", "Meera Iyer", "Room 109 · Bed B", "₹8,500", "Paid", "paid"),
           ("DS", "Dev Sharma", "Room 110 · Bed A", "₹7,200", "Due 5 Dec", "due"),
           ("TN", "Tanvi Nair", "Room 211 · Bed B", "₹8,500", "Paid", "paid")]


def scr_tenants(phone=True):
    return f'''<div class="app">
<div class="ttl"><div class="row between"><h1>Tenants</h1><div class="row" style="gap:8px"><div style="width:42px;height:42px;border-radius:14px;background:#fff;border:1px solid #E2E8F0;display:flex;align-items:center;justify-content:center">{ic("qr", 21, "#1D4ED8")}</div><div style="width:42px;height:42px;border-radius:14px;background:#1D4ED8;display:flex;align-items:center;justify-content:center">{ic("plus", 22, "#fff", 2.4)}</div></div></div><p>102 active tenants</p></div>
<div style="margin:6px 20px 0;height:46px;border-radius:14px;background:#fff;border:1px solid #E2E8F0;display:flex;align-items:center;gap:10px;padding:0 14px;color:#94A3B8;font-size:15px">{ic("search", 20, "#94A3B8")}Search name, room or phone</div>
<div class="row" style="gap:8px;padding:12px 20px 4px"><div class="chip on">All · 102</div><div class="chip">Paid · 88</div><div class="chip">Due · 11</div><div class="chip">Overdue · 3</div></div>
<div class="fill" style="padding:8px 16px 0"><div class="card" style="padding:2px 14px">
 {"".join(f'<div class="row" style="gap:12px;padding:11px 0;{"border-top:1px solid #F1F5F9" if k else ""}">{av(a, k)}<div style="flex:1"><div style="font-size:15px;font-weight:650">{n}</div><div style="font-size:12.5px;color:#64748B">{r}</div></div><div style="text-align:right"><div style="font-size:14.5px;font-weight:700">{amt}</div><div class="pill {c}" style="margin-top:3px">{s}</div></div></div>' for k, (a, n, r, amt, s, c) in enumerate(TENANTS))}
</div></div>
{nav("users") if phone else ""}
</div>'''


def scr_payments(phone=True):
    reqs = [("PS", "Priya Sharma", "Room 204-B · November rent", "₹8,500", "UPI · Ref 4312 8890 1123", 0),
            ("VS", "Vikram Singh", "Room 108-B · November rent", "₹7,200", "UPI · Ref 4312 7765 0981", 6),
            ("KM", "Karan Mehta", "Room 210-C · Oct + Nov rent", "₹14,400", "Cash · paid at office", 4)]
    hist = [("Ankit Jain", "INV-1124", "₹8,500"), ("Sneha Reddy", "INV-1123", "₹7,800"), ("Neha Gupta", "INV-1122", "₹11,000"),
            ("Aisha Khan", "INV-1121", "₹8,500"), ("Rohit Patil", "INV-1120", "₹7,200")]
    return f'''<div class="app">
<div class="ttl"><h1>Payments</h1><p>Verify rent & auto-send invoices</p></div>
<div style="margin:6px 20px 0;padding:4px;border-radius:13px;background:#E2E8F0;display:flex;font-size:14px;font-weight:700">
 <div style="flex:1;height:36px;border-radius:10px;background:#fff;display:flex;align-items:center;justify-content:center;box-shadow:0 1px 3px rgba(0,0,0,.08)">Pending · 3</div>
 <div style="flex:1;height:36px;display:flex;align-items:center;justify-content:center;color:#64748B">History</div></div>
<div class="card" style="margin:14px 16px 0;padding:16px;background:linear-gradient(135deg,#1D4ED8,#0E8F86);color:#fff">
 <div style="font-size:13px;opacity:.85;font-weight:600">Awaiting your approval</div>
 <div style="font-size:30px;font-weight:800;letter-spacing:-.8px;margin-top:2px">₹30,100</div>
 <div style="font-size:12.5px;opacity:.8;margin-top:2px">Paid directly to your bank via UPI</div></div>
<div class="fill" style="padding:12px 16px 0">
 {"".join(f'<div class="card" style="padding:14px;margin-bottom:12px"><div class="row" style="gap:12px">{av(a, i)}<div style="flex:1"><div style="font-size:15px;font-weight:700">{n}</div><div style="font-size:12.5px;color:#64748B">{d}</div></div><div style="font-size:18px;font-weight:800">{amt}</div></div><div style="margin:10px 0 12px;padding:8px 10px;border-radius:10px;background:#F8FAFC;font-size:12.5px;color:#475569;font-weight:500" class="row">{ic("shield", 15, "#0D9488")}<span style="margin-left:6px">{ref}</span></div><div class="row" style="gap:10px"><div class="btn" style="flex:1;height:42px;background:#F1F5F9;color:#B91C1C;font-size:14.5px">{ic("x", 17, "#B91C1C", 2.4)}Reject</div><div class="btn" style="flex:1.4;height:42px;background:#16A34A;color:#fff;font-size:14.5px">{ic("check", 18, "#fff", 2.6)}Approve</div></div></div>' for a, n, d, amt, ref, i in reqs)}
 <div class="sec" style="margin:6px 4px 10px">Recent invoices <span>View all</span></div>
 <div class="card" style="padding:2px 14px">{"".join(f'<div class="row" style="gap:12px;padding:11px 0;{"border-top:1px solid #F1F5F9" if k else ""}"><div style="width:38px;height:38px;border-radius:11px;background:#FEE2E2;display:flex;align-items:center;justify-content:center">{ic("doc", 19, "#DC2626")}</div><div style="flex:1"><div style="font-size:14.5px;font-weight:650">{n}</div><div style="font-size:12.5px;color:#64748B">{inv} · PDF sent</div></div><div style="font-weight:700;font-size:14.5px">{a}</div></div>' for k, (n, inv, a) in enumerate(hist))}</div>
</div>
{nav("wallet") if phone else ""}
</div>'''


def scr_notice(phone=True):
    return f'''<div class="app">
<div class="ttl"><div class="row" style="gap:8px;color:#1D4ED8;font-size:15px;font-weight:600;margin-bottom:6px">{ic("back", 18, "#1D4ED8", 2.4)}Notices</div><h1>New notice</h1></div>
<div class="fill" style="padding:6px 16px 0">
<div class="card" style="padding:16px">
 <div style="font-size:12.5px;color:#64748B;font-weight:600;margin-bottom:6px">TITLE</div>
 <div style="font-size:17px;font-weight:700;padding-bottom:12px;border-bottom:1px solid #F1F5F9">Water supply maintenance</div>
 <div style="font-size:12.5px;color:#64748B;font-weight:600;margin:12px 0 6px">MESSAGE</div>
 <div style="font-size:15px;line-height:1.45;color:#334155">Water supply will be off on Sunday, 10 AM – 1 PM for tank cleaning. Please store water in advance. 🙏</div>
</div>
<div style="font-size:13px;color:#64748B;font-weight:700;margin:16px 4px 8px">SEND TO</div>
<div class="row" style="gap:8px;flex-wrap:wrap"><div class="chip on">{ic("check", 15, "#fff", 2.6)}All tenants · 102</div><div class="chip">Ground floor</div><div class="chip">Rent due</div></div>
<div style="font-size:13px;color:#64748B;font-weight:700;margin:16px 4px 8px">CHANNELS</div>
<div class="card" style="padding:2px 14px">
 {"".join(f'<div class="row" style="gap:12px;padding:12px 0;{"border-top:1px solid #F1F5F9" if k else ""}"><div style="width:38px;height:38px;border-radius:11px;background:{bg};display:flex;align-items:center;justify-content:center">{ic(i, 20, c)}</div><div style="flex:1"><div style="font-size:15px;font-weight:650">{t}</div><div style="font-size:12.5px;color:#64748B">{s}</div></div><div style="width:50px;height:30px;border-radius:15px;background:#22C55E;position:relative"><div style="position:absolute;right:2px;top:2px;width:26px;height:26px;border-radius:13px;background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.2)"></div></div></div>' for k, (i, c, bg, t, s) in enumerate([("bell", "#1D4ED8", "#DBEAFE", "In-app notification", "Push to tenant app"), ("chat", "#16A34A", "#DCFCE7", "WhatsApp", "Message every tenant's number")]))}
</div>
<div style="font-size:13px;color:#64748B;font-weight:700;margin:16px 4px 8px">WHATSAPP PREVIEW</div>
<div style="border-radius:18px;padding:14px;background:#E7DDD3;background-image:radial-gradient(rgba(0,0,0,.05) 1px,transparent 1px);background-size:12px 12px">
 <div style="max-width:88%;background:#D9FDD3;border-radius:12px 12px 12px 3px;padding:10px 12px;font-size:13.5px;line-height:1.4;color:#111;box-shadow:0 1px 1px rgba(0,0,0,.1)"><b>📢 Sunrise PG — Notice</b><br>Water supply will be off on Sunday, 10 AM – 1 PM for tank cleaning.<div style="text-align:right;font-size:11px;color:#667781;margin-top:2px">9:41 ✓✓</div></div>
</div>
<div class="btn" style="margin-top:16px;background:linear-gradient(90deg,#1D4ED8,#0E8F86);color:#fff">{ic("send", 18, "#fff", 2.2)}Send to 102 tenants</div>
</div>
</div>'''


def scr_analytics(phone=True):
    months = [("Jun", 62), ("Jul", 70), ("Aug", 74), ("Sep", 80), ("Oct", 86), ("Nov", 96)]
    exp = [("Food & groceries", "₹96,000", 80, "#2563EB"), ("Staff salaries", "₹72,000", 60, "#0D9488"),
           ("Electricity", "₹38,500", 32, "#F59E0B"), ("Maintenance", "₹21,000", 18, "#7C3AED")]
    return f'''<div class="app">
<div class="ttl"><h1>Reports</h1><p>Sunrise PG · Financial overview</p></div>
<div class="row" style="gap:8px;padding:4px 20px 0"><div class="chip">Week</div><div class="chip on">6 months</div><div class="chip">Year</div></div>
<div class="fill" style="padding:12px 16px 0">
<div class="card" style="padding:16px">
 <div class="row between"><div><div style="font-size:13px;color:#64748B;font-weight:600">Total revenue</div><div style="font-size:30px;font-weight:800;letter-spacing:-.8px">₹24.6L</div></div>
 <div class="row" style="gap:4px;color:#16A34A;font-weight:700;font-size:14px;background:#DCFCE7;padding:6px 10px;border-radius:10px">{ic("trend", 16, "#16A34A", 2.4)}18.4%</div></div>
 <div class="row" style="align-items:flex-end;gap:12px;height:150px;margin-top:14px;padding-bottom:4px;border-bottom:1px dashed #E2E8F0">
 {"".join(f'<div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%"><div style="width:100%;height:{h}%;border-radius:8px 8px 3px 3px;background:{"linear-gradient(180deg,#14B8A6,#1D4ED8)" if m == "Nov" else "#C7D7FE"}"></div></div>' for m, h in months)}
 </div>
 <div class="row" style="gap:12px;margin-top:6px">{"".join(f'<div style="flex:1;text-align:center;font-size:12px;color:#64748B;font-weight:600">{m}</div>' for m, _ in months)}</div>
</div>
<div class="row" style="gap:12px;margin-top:12px">
 <div class="card" style="flex:1;padding:14px"><div style="font-size:12.5px;color:#64748B;font-weight:600">Net profit</div><div style="font-size:22px;font-weight:800;color:#16A34A;margin-top:2px">₹2,55,000</div><div style="font-size:12px;color:#64748B">this month</div></div>
 <div class="card" style="flex:1;padding:14px"><div style="font-size:12.5px;color:#64748B;font-weight:600">Occupancy</div><div style="font-size:22px;font-weight:800;margin-top:2px">85%</div><div style="height:6px;border-radius:3px;background:#E2E8F0;margin-top:8px"><div style="width:85%;height:100%;border-radius:3px;background:#0D9488"></div></div></div>
</div>
<div class="card" style="padding:16px;margin-top:12px"><div class="row between" style="margin-bottom:6px"><div style="font-size:15px;font-weight:700">Expenses</div><div style="font-size:15px;font-weight:800">₹2,27,500</div></div>
 {"".join(f'<div style="margin-top:10px"><div class="row between" style="font-size:13.5px;margin-bottom:5px"><span style="color:#334155;font-weight:550">{n}</span><b>{v}</b></div><div style="height:8px;border-radius:4px;background:#F1F5F9"><div style="width:{w}%;height:100%;border-radius:4px;background:{c}"></div></div></div>' for n, v, w, c in exp)}
</div>
</div>
{nav("chart") if phone else ""}
</div>'''


def scr_tenant_app(phone=True):
    return f'''<div class="app" style="background:#F8FAFC">
<div style="padding:64px 20px 0"><div class="row between"><div><div style="font-size:14px;color:#64748B">Hi Priya 👋</div><div style="font-size:26px;font-weight:800;letter-spacing:-.5px">My PG</div></div>{av("PS", 0, 46)}</div></div>
<div style="margin:16px 16px 0;border-radius:24px;padding:20px;color:#fff;background:linear-gradient(135deg,#1D4ED8,#0E8F86);position:relative;overflow:hidden">
 <div style="position:absolute;right:-30px;bottom:-40px;width:170px;height:170px;border-radius:50%;background:rgba(255,255,255,.1)"></div>
 <div style="font-size:13px;opacity:.85;font-weight:600">Sunrise PG · Koramangala</div>
 <div class="row" style="gap:10px;margin-top:10px">{ic("bed", 30, "#fff", 1.9)}<div style="font-size:28px;font-weight:800;letter-spacing:-.5px">Room 204 · Bed B</div></div>
 <div class="row" style="gap:18px;margin-top:14px;font-size:13px"><div><div style="opacity:.75">Monthly rent</div><b style="font-size:16px">₹8,500</b></div><div><div style="opacity:.75">Deposit</div><b style="font-size:16px">₹17,000</b></div><div><div style="opacity:.75">Since</div><b style="font-size:16px">Mar 2026</b></div></div>
</div>
<div class="card" style="margin:14px 16px 0;padding:16px">
 <div class="row between"><div><div style="font-size:13px;color:#64748B;font-weight:600">December rent</div><div style="font-size:26px;font-weight:800">₹8,500</div></div><div class="pill due">Due in 5 days</div></div>
 <div class="btn" style="margin-top:12px;background:#1D4ED8;color:#fff">{ic("rupee", 18, "#fff", 2.4)}Pay via UPI</div>
 <div style="text-align:center;font-size:12.5px;color:#64748B;margin-top:8px">GPay · PhonePe · Paytm · or pay cash</div>
</div>
<div class="sec">Notices <span>2 new</span></div>
<div class="fill" style="padding:0 16px">
 {"".join(f'<div class="card row" style="gap:12px;padding:13px 14px;margin-bottom:10px"><div style="width:40px;height:40px;border-radius:12px;background:{bg};display:flex;align-items:center;justify-content:center">{ic(i, 20, c)}</div><div style="flex:1"><div style="font-size:14.5px;font-weight:650">{t}</div><div style="font-size:12.5px;color:#64748B">{s}</div></div></div>' for i, c, bg, t, s in [("megaphone", "#7C3AED", "#EDE9FE", "Water supply maintenance", "Sunday, 10 AM – 1 PM"), ("bell", "#D97706", "#FEF3C7", "Diwali dinner on Friday 🎉", "Rooftop · 8 PM"), ("doc", "#DC2626", "#FEE2E2", "November invoice ready", "INV-1098 · Download PDF"), ("check", "#16A34A", "#DCFCE7", "Rent received", "₹8,500 · 3 Nov")])}
</div>
</div>'''


SCREENS = {"dashboard": scr_dashboard, "rooms": scr_rooms, "tenants": scr_tenants, "payments": scr_payments,
           "notice": scr_notice, "analytics": scr_analytics, "tenant": scr_tenant_app}
LIGHT_SB = {"dashboard"}


def phone(screen, left, top, zoom=1.0, rotate=0, z=1):
    return (f'<div class="phone" style="left:{left}px;top:{top}px;zoom:{zoom};transform:rotate({rotate}deg);z-index:{z}">'
            f'<div class="scr">{SCREENS[screen]()}{statusbar(screen in LIGHT_SB)}<div class="island"></div></div></div>')


def floatcard(icon, c, bg, title, sub, style):
    return f'<div class="float" style="{style}"><div class="fi" style="background:{bg}">{ic(icon, 24, c, 2.2)}</div><div><b>{title}</b><small>{sub}</small></div></div>'


def page(w, h, body, bg):
    return (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}html,body{{width:{w}px;height:{h}px}}</style></head>'
            f'<body><div class="canvas" style="width:{w}px;height:{h}px;background:{bg}">{DECOR}{body}</div></body></html>')


def brand_chip(size=1.0):
    return (f'<div class="row" style="gap:{12*size}px;justify-content:center">'
            f'<img src="{ICON}" style="width:{52*size}px;height:{52*size}px;border-radius:{12*size}px;box-shadow:0 8px 20px rgba(0,0,0,.25)">'
            f'<div style="color:#fff;font-size:{30*size}px;font-weight:800;letter-spacing:-.5px">PG Sathi</div></div>')


# ───────────────────────── compositions ─────────────────────────
def header(W, H):
    """Wide key art. Everything important sits in a narrow centre column so it survives cropping."""
    u = H / 823  # base unit relative to 3840x1646 design
    pz = 0.74 * u
    pw, ph = 414 * pz, 868 * pz
    cx = W / 2
    top = H * 0.40
    body = f'''
<div style="position:absolute;left:50%;top:{H*0.075}px;transform:translateX(-50%);width:{820*u}px">
 {brand_chip(1.05*u)}
 <div class="mk-h" style="font-size:{66*u}px;margin-top:{22*u}px">Run your PG or hostel<br>from your phone</div>
 <div class="mk-s" style="font-size:{22*u}px;margin-top:{12*u}px">Rooms · Tenants · Rent · UPI · WhatsApp notices</div>
</div>
<div style="position:absolute;left:{cx-500*u}px;top:{top+40*u}px;width:{1000*u}px;height:{700*u}px;border-radius:50%;background:radial-gradient(closest-side,rgba(255,255,255,.28),transparent);"></div>'''
    # phones: centre hero + flanking pairs (outer ones may crop on narrow layouts)
    lay = [("rooms", -2.05, 0.20, 0.86, -8), ("tenants", -1.05, 0.08, 0.93, -4), ("payments", 1.05, 0.08, 0.93, 4),
           ("analytics", 2.05, 0.20, 0.86, 8)]
    for s, dx, dy, sc, rot in lay:
        z = pz * sc
        body += phone(s, (cx + dx * pw * 1.0 - 414 * z / 2) / z, (top + dy * ph) / z, z, rot)
    body += phone("dashboard", (cx - pw / 2) / pz, (top - 10 * u) / pz, pz, 0, 5)
    body += floatcard("check", "#16A34A", "#DCFCE7", "₹8,500 received", "UPI · Priya, Room 204-B",
                      f"left:{(cx+pw*0.38)/(u*1.05)}px;top:{(top+ph*0.66)/(u*1.05)}px;zoom:{u*1.05}")
    body += floatcard("chat", "#16A34A", "#DCFCE7", "Notice sent", "WhatsApp · 102 tenants",
                      f"right:{(W-(cx-pw*0.38))/(u*1.05)}px;top:{(top+ph*0.74)/(u*1.05)}px;zoom:{u*1.05}")
    return page(W, H, body, BG["brand"])


def search_results(W=1920, H=1280):
    u = H / 1280
    body = f'''
<div style="position:absolute;left:{120*u}px;top:{0}px;height:{H}px;width:{860*u}px;display:flex;flex-direction:column;justify-content:center">
 <div class="row" style="gap:{22*u}px"><img src="{ICON}" style="width:{120*u}px;height:{120*u}px;border-radius:{28*u}px;box-shadow:0 14px 34px rgba(0,0,0,.3)">
  <div><div style="color:#fff;font-size:{58*u}px;font-weight:800;letter-spacing:-1px">PG Sathi</div><div style="color:rgba(255,255,255,.8);font-size:{26*u}px;font-weight:600">PG &amp; Hostel Management</div></div></div>
 <div class="mk-h" style="text-align:left;font-size:{104*u}px;margin-top:{50*u}px;letter-spacing:-2.5px">Run your PG<br>from your phone</div>
 <div style="display:flex;flex-direction:column;gap:{18*u}px;margin-top:{48*u}px">
  {"".join(f'<div class="row" style="gap:{16*u}px;color:#fff;font-size:{34*u}px;font-weight:650"><div style="width:{52*u}px;height:{52*u}px;border-radius:{16*u}px;background:rgba(255,255,255,.16);display:flex;align-items:center;justify-content:center">{ic(i, 30*u, "#FDE68A", 2.2)}</div>{t}</div>' for i, t in [("grid", "Rooms &amp; beds at a glance"), ("rupee", "Collect rent via UPI"), ("chat", "Notices on WhatsApp")])}
 </div>
</div>'''
    pz = 1.12 * u
    body += phone("payments", (1500 * u) / pz - 0, (300 * u) / pz, pz * 0.94, 6)
    body += phone("dashboard", (1060 * u) / pz, (170 * u) / pz, pz, -3, 5)
    body += floatcard("check", "#16A34A", "#DCFCE7", "₹8,500 received", "UPI · Room 204-B",
                      f"left:{1000/1.45}px;top:{900/1.45}px;zoom:{1.45*u}")
    return page(W, H, body, BG["brand"])


IPHONE = [  # screen, headline, sub, bg, float
    ("dashboard", "Your whole PG,<br>at a glance", "Live rent collection, occupancy &amp; dues", "brand",
     ("check", "#16A34A", "#DCFCE7", "₹8,500 received", "UPI · Room 204-B", "right:14px;top:520px")),
    ("rooms", "Every room &amp; bed,<br>mapped", "See vacant, occupied &amp; reserved beds", "blue",
     ("bed", "#1D4ED8", "#DBEAFE", "Bed 106-A assigned", "Rahul Verma · ₹8,500/mo", "left:14px;top:640px")),
    ("tenants", "All your tenants<br>in one place", "Profiles, documents &amp; rent status", "ocean", None),
    ("payments", "Collect rent<br>via UPI", "Approve payments &amp; auto-send PDF invoices", "teal",
     ("doc", "#DC2626", "#FEE2E2", "Invoice sent", "INV-1124 · PDF on WhatsApp", "right:14px;top:760px")),
    ("notice", "Notices on app<br>&amp; WhatsApp", "Reach every tenant in one tap", "indigo", None),
    ("analytics", "Know your<br>real profit", "Revenue, expenses &amp; occupancy trends", "brand", None),
    ("tenant", "A simple app<br>for tenants too", "Pay rent, get receipts &amp; see notices", "ocean",
     ("rupee", "#1D4ED8", "#DBEAFE", "Rent paid via UPI", "Receipt sent instantly", "right:14px;top:610px")),
]


def iphone_shot(screen, head, sub, bg, flt):
    W, H = 440, 956
    body = f'''<div style="position:absolute;left:0;right:0;top:58px;padding:0 24px">
<div class="mk-h" style="font-size:42px">{head}</div><div class="mk-s" style="font-size:18px;margin-top:12px">{sub}</div></div>'''
    z = 0.84
    body += phone(screen, (W - 414 * z) / 2 / z, 212 / z, z)
    if flt:
        body += floatcard(*flt[:5], flt[5] + ";zoom:.92")
    return page(W, H, body, BG[bg])


IPAD = [
    (("dashboard", "rooms"), "Manage your entire PG<br>on a bigger screen", "brand"),
    (("tenants", "payments"), "Tenants &amp; rent,<br>side by side", "ocean"),
    (("notice", "analytics"), "Notices, reports<br>&amp; real profit", "indigo"),
    (("rooms", "tenant"), "Built for owners.<br>Loved by tenants.", "teal"),
]


def ipad_shot(panes, head, bg):
    W, H = 1032, 1376
    sw, sh = 834, 1112
    rail = 76
    items = ["home", "grid", "users", "wallet", "megaphone", "chart"]
    rail_html = (f'<div style="width:{rail}px;flex:none;background:#fff;border-right:1px solid #E2E8F0;display:flex;flex-direction:column;align-items:center;padding-top:30px;gap:22px">'
                 f'<img src="{ICON}" style="width:46px;height:46px;border-radius:12px;margin-bottom:10px">'
                 + "".join(f'<div style="width:48px;height:48px;border-radius:14px;display:flex;align-items:center;justify-content:center;background:{"#DBEAFE" if k == 0 else "transparent"}">{ic(i, 24, "#1D4ED8" if k == 0 else "#94A3B8")}</div>' for k, i in enumerate(items))
                 + "</div>")
    pw = (sw - rail) / 2
    pane_html = "".join(f'<div style="position:relative;width:{pw}px;height:{sh}px;{"border-left:1px solid #E2E8F0" if k else ""};overflow:hidden">{SCREENS[p](phone=False)}</div>' for k, p in enumerate(panes))
    z = 0.94
    left = (W - (sw + 32) * z) / 2 / z
    body = f'''<div style="position:absolute;left:0;right:0;top:64px"><div class="mk-h" style="font-size:58px">{head}</div></div>
<div class="tablet" style="left:{left}px;top:{250/z}px;zoom:{z}"><div class="tscr" style="width:{sw}px;height:{sh}px">{rail_html}{pane_html}
<div style="position:absolute;top:0;left:0;right:0;height:28px;display:flex;justify-content:space-between;padding:8px 26px 0;font-size:13px;font-weight:600;z-index:5"><span>9:41&nbsp;&nbsp;Mon 23 Nov</span><span>100% ▮</span></div></div></div>'''
    # status bars over the panes collide with ttl padding — ttl already has 62px top padding, fine.
    return page(W, H, body, BG[bg])


# ───────────────────────── render ─────────────────────────
def render(name, html, css_w, css_h, scale, final=None):
    HTML.mkdir(exist_ok=True)
    out = OUT / name
    out.parent.mkdir(parents=True, exist_ok=True)
    f = HTML / (name.replace("/", "__").replace(".png", ".html"))
    f.write_text(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--force-device-scale-factor={scale}", f"--window-size={css_w},{css_h}",
                    "--default-background-color=00000000", f"--screenshot={out}", f.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    im = Image.open(out).convert("RGB")  # App Store rejects alpha channels
    target = final or (round(css_w * scale), round(css_h * scale))
    if im.size != target:
        im = im.crop((0, 0) + target) if im.size[0] >= target[0] and im.size[1] >= target[1] else im.resize(target, Image.LANCZOS)
    im.save(out, "PNG")
    print(f"{out.relative_to(ROOT)}  {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    render("header/header_3840x1646.png", header(1920, 823), 1920, 823, 2, (3840, 1646))
    render("header/header_5244x2950.png", header(2622, 1475), 2622, 1475, 2, (5244, 2950))
    render("search_results/search_1920x1280.png", search_results(1920, 1280), 1920, 1280, 1)
    render("search_results/search_3840x2560.png", search_results(1920, 1280), 1920, 1280, 2)
    for i, s in enumerate(IPHONE, 1):
        render(f"screenshots_iphone_6.9/{i:02d}_{s[0]}.png", iphone_shot(*s), 440, 956, 3)
    for i, s in enumerate(IPAD, 1):
        render(f"screenshots_ipad_13/{i:02d}_{'_'.join(s[0])}.png", ipad_shot(*s), 1032, 1376, 2)
