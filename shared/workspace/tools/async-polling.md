# Async Job Polling (Video Gen, Long API Calls, etc.)

**Never poll in a loop inline.** When waiting for a job that takes minutes (video generation, long API calls), don't sit in a `process poll` loop — it blocks the conversation and burns context.

**Instead:** Fire off a self-contained background script that:

1. Polls the job status every N seconds
2. Downloads the result when complete
3. Sends the result to your preferred channel via the `message` tool

```bash
# Example: poll a video job and send when done
exec background=true:
while true; do
  STATUS=$(mcporter call x402scan.authed_call url="https://stablestudio.io/api/x402/jobs/$JOB_ID" method=GET 2>&1 | jq -r '.data.status')
  if [ "$STATUS" = "complete" ]; then
    URL=$(mcporter call x402scan.authed_call ... | jq -r '.data.result.videoUrl')
    curl -sL "$URL" -o /tmp/video.mp4
    # Send via gateway webhook or message tool
    break
  fi
  sleep 10
done
```

This frees you up to keep chatting while the job finishes in the background.
