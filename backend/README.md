# Linker YouTube backend

A single Vercel Python function that uses `yt-dlp` to reliably extract a
YouTube video's transcript (timestamped) and storyboard preview frames —
the things YouTube blocks the iOS app from fetching directly.

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
Datacenter IPs sometimes hit "Sign in to confirm you're not a bot". Export your
YouTube cookies (Netscape format) and set them as a Vercel env var:
```bash
vercel env add YT_COOKIES
```
The function passes them to yt-dlp automatically.
