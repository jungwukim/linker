# Linker YouTube backend

A single Vercel Python function that uses `yt-dlp` to extract a YouTube
video's transcript (timestamped) and storyboard preview frames.

This is a **fallback**: the app extracts on-device first (phone IP, no login),
and only calls this backend when direct extraction comes up empty. The backend
runs cookie-less by default and a working URL is already baked into the app, so
deploying your own is optional.

## Endpoint
`GET /api/youtube?v=<videoId>` →
```json
{ "title": "...", "duration": 59, "thumbnail": "...",
  "transcript": [{ "t": 0, "text": "..." }],
  "frames": [{ "t": 2.5, "url": "https://i.ytimg.com/sb/...", "x": 202, "y": 0, "w": 101, "h": 180 }] }
```

## Deploy
```bash
cd backend
vercel            # first run: log in + link a project (preview)
vercel --prod     # production URL
```
Then put the deployment URL into the Linker app: 설정 → "YouTube 백엔드 URL".

## If YouTube blocks the server IP
Datacenter IPs sometimes hit "Sign in to confirm you're not a bot". Most videos
still work cookie-less, and the app's on-device path covers the rest, so cookies
are usually unnecessary. If a specific video needs them, you *can* set login
cookies (Netscape format) as a Vercel env var:
```bash
vercel env add YT_COOKIES
```
The function passes them to yt-dlp automatically.

> ⚠️ **Security:** these are full login-session cookies. A leaked Vercel env var
> exposes the entire Google account session (Gmail/Drive/…) — no password or 2FA
> needed. **Never use your main account.** Use a throwaway account, or skip
> cookies entirely (the default).
