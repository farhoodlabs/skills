# MiniMax Image Generation Skill

Claude Code skill for generating images via the MiniMax API.
Wraps the MiniMax `/v1/image_generation` endpoint as a `/minimax-image-generation` slash command.

## Structure
- `SKILL.md` — skill definition + usage documentation
- `CLAUDE.md` — implementation notes

## Rules
- Set `MINIMAX_API_KEY` env var before use
- Images are written to disk as `output-0.jpeg`, `output-1.jpeg`, etc.

---
name: minimax-image-generation
version: "1.0.0"
description: "Generate images from MiniMax's image-01 model. Triggered by phrases like 'generate image', 'create picture', 'minimax image', 'text to image'."
argument-hint: '"a sunset over the ocean, cinematic" [--aspect-ratio=16:9]'
allowed-tools: Bash, Read, Write
user-invocable: true
metadata:
  openclaw:
    emoji: "🎨"
    category: "media"
    requires:
      env:
        - MINIMAX_API_KEY
      optionalEnv:
        - MINIMAX_API_BASE_URL
    bins:
      - curl
      - jq
      - base64
    primaryEnv: MINIMAX_API_KEY
    tags:
      - image
      - image-generation
      - generative-ai
      - minimax
      - text-to-image
---

# MiniMax Image Generation

> Generate images using MiniMax's `image-01` model via the `/v1/image_generation` API.

## Quick Start

```bash
export MINIMAX_API_KEY="your-minimax-api-key"
/minimax-image-generation "a cat wearing a spacesuit, cinematic photography"
```

---

## Parse User Intent

Extract from the user's input:

1. **PROMPT**: The image description (required)
2. **ASPECT_RATIO**: `16:9` (default), `1:1`, `9:16`, `4:3`, `3:4`

---

## API Call Example

```bash
# Verify credentials
if [ -z "${MINIMAX_API_KEY:-}" ]; then
  echo "ERROR: MINIMAX_API_KEY is not set."
  exit 1
fi

API_BASE_URL="${MINIMAX_API_BASE_URL:-https://api.minimax.io}"
PROMPT="<your prompt here>"
ASPECT_RATIO="16:9"

# Call the API
response=$(curl -s -X POST "${API_BASE_URL}/v1/image_generation" \
  -H "Authorization: Bearer ${MINIMAX_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"image-01\",
    \"prompt\": \"${PROMPT}\",
    \"aspect_ratio\": \"${ASPECT_RATIO}\",
    \"response_format\": \"base64\"
  }")

# Decode and save
images=$(echo "$response" | jq -r '.data.image_base64[]')
idx=0
for image_b64 in $images; do
  echo "$image_b64" | base64 -d > "output-${idx}.jpeg"
  echo "Saved: output-${idx}.jpeg"
  idx=$((idx + 1))
done
```

**Replace `<your prompt here>` with the user's image description.**

---

## Aspect Ratio Guide

| Ratio | Use Case |
|-------|----------|
| `16:9` | Widescreen (default) — desktop wallpaper, banners |
| `1:1` | Square — social media posts, profile images |
| `9:16` | Portrait — mobile wallpapers, stories |
| `4:3` | Standard — presentations, blog images |
| `3:4` | Portrait standard — posters, portraits |

---

## Configuration Reference

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MINIMAX_API_KEY` | Yes | Your MiniMax API key |
| `MINIMAX_API_BASE_URL` | No | API base URL (default: `https://api.minimax.io`) |

### API Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | string | `image-01` | Model to use |
| `prompt` | string | required | Image description |
| `aspect_ratio` | string | `16:9` | Image aspect ratio |
| `response_format` | string | `base64` | Output format |

---

## Example Output

```
🎨 MiniMax Image Generation
├─ Prompt: "a cat wearing a spacesuit, cinematic photography"
├─ Aspect ratio: 16:9
└─ Model: image-01

Saved: output-0.jpeg
Done.
```
