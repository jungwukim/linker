"""Vercel Python function: GET /api/youtube?v=<videoId>

Uses yt-dlp to reliably extract a YouTube video's transcript (with timestamps)
and storyboard preview frames (ready-to-crop), returning the JSON the Linker
iOS app consumes. This runs server-side because YouTube blocks the equivalent
requests from the app directly (consent walls, throttling, PoToken).
"""
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import json
import os
import tempfile
import urllib.request

import yt_dlp


def _fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return urllib.request.urlopen(req, timeout=20).read()


def _transcript(info: dict):
    auto = info.get("automatic_captions") or {}
    manual = info.get("subtitles") or {}
    tracks = None
    for src in (manual, auto):
        for lang in ("ko", "en"):
            if src.get(lang):
                tracks = src[lang]
                break
        if tracks:
            break
    if not tracks and auto:
        tracks = next(iter(auto.values()))
    if not tracks:
        return []
    track = next((t for t in tracks if t.get("ext") == "json3"), tracks[0])
    try:
        data = json.loads(_fetch(track["url"]))
    except Exception:
        return []
    cues = []
    for ev in data.get("events", []):
        segs = ev.get("segs")
        if not segs:
            continue
        text = "".join(s.get("utf8", "") for s in segs).replace("\n", " ").strip()
        if text:
            cues.append({"t": (ev.get("tStartMs", 0)) // 1000, "text": text})
    return cues


def _frames(info: dict, count: int = 12):
    sbs = [f for f in info.get("formats", [])
           if f.get("format_id", "").startswith("sb") and f.get("fragments")]
    if not sbs:
        return []
    sb = max(sbs, key=lambda f: f.get("width", 0) or 0)
    rows, cols = sb.get("rows", 0), sb.get("columns", 0)
    w, h = sb.get("width", 0), sb.get("height", 0)
    fps = sb.get("fps") or 1.0
    if not (rows and cols and w and h):
        return []
    per_sheet = rows * cols

    flat = []  # (t, url, cell)
    elapsed = 0.0
    for frag in sb["fragments"]:
        d = frag.get("duration") or 0.0
        n = min(per_sheet, max(1, round(d * fps))) if d else per_sheet
        for i in range(n):
            flat.append((elapsed + (i + 0.5) / fps, frag["url"], i))
        elapsed += d
    if not flat:
        return []

    total = len(flat)
    picks = sorted({int(total * (k + 0.5) / count) for k in range(min(count, total))})
    frames = []
    for idx in picks:
        t, url, cell = flat[min(idx, total - 1)]
        col, row = cell % cols, cell // cols
        frames.append({"t": round(t, 1), "url": url,
                       "x": col * w, "y": row * h, "w": w, "h": h})
    return frames


def extract(video_id: str) -> dict:
    opts = {
        "skip_download": True, "quiet": True, "no_warnings": True,
        # Datacenter IPs (Vercel) get "confirm you're not a bot" on the default
        # web client. These alternate clients are often not gated. yt-dlp tries
        # them in order. If all fail, set YT_COOKIES (see README).
        "extractor_args": {"youtube": {"player_client": ["tv", "ios", "mweb", "web_safari", "android"]}},
    }
    # Optional: pass logged-in cookies (Netscape format) via env to bypass
    # datacenter-IP bot checks. Set YT_COOKIES in the Vercel project.
    cookies = os.environ.get("YT_COOKIES")
    cookiefile = None
    if cookies:
        cookiefile = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
        cookiefile.write(cookies)
        cookiefile.flush()
        opts["cookiefile"] = cookiefile.name
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
    return {
        "title": info.get("title"),
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "transcript": _transcript(info),
        "frames": _frames(info),
    }


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        params = parse_qs(urlparse(self.path).query)
        video_id = (params.get("v") or [""])[0].strip()

        if not video_id:
            return self._send(400, {"error": "missing ?v=<videoId>"})
        try:
            result = extract(video_id)
        except Exception as exc:  # surface yt-dlp errors as JSON
            return self._send(502, {"error": str(exc)})
        self._send(200, result)

    def _send(self, status: int, payload: dict):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "public, max-age=600")
        self.end_headers()
        self.wfile.write(body)
