# APIM Access Test

Simple Python application to test access to Azure AI Foundry and KAITO models via APIM using OpenAI SDK.

## Setup

1. Install dependencies using uv:
   ```bash
   uv sync
   ```

2. Copy the example configuration:
   ```bash
   cp config.example.yml config.yaml
   ```

3. Edit `config.yaml` with your actual APIM URLs and subscription keys.

## Configuration

The `config.yaml` file contains a map of models to test:

```yaml
models:
  foundry-gpt4o:
    url: "https://your-apim.azure-api.net/foundry"
    key: "your-subscription-key"
  
  kaito-phi4:
    url: "https://your-apim.azure-api.net/kaito-phi4"
    key: "your-subscription-key"

test_prompt: "What is 2+2? Answer briefly."
```

## Run

```bash
uv run python main.py
```

## Output

The application will test each configured model and print the response:

```
2026-01-27 10:00:00 - INFO - ============================================================
2026-01-27 10:00:00 - INFO - APIM Access Test - Foundry & KAITO Models
2026-01-27 10:00:00 - INFO - ============================================================
2026-01-27 10:00:00 - INFO - Test prompt: What is 2+2? Answer briefly.
2026-01-27 10:00:00 - INFO - ------------------------------------------------------------
2026-01-27 10:00:00 - INFO - Testing model: foundry-gpt4o
2026-01-27 10:00:00 - INFO -   URL: https://your-apim.azure-api.net/foundry
2026-01-27 10:00:01 - INFO -   ✓ Response: 2+2 equals 4.
2026-01-27 10:00:01 - INFO - ------------------------------------------------------------
2026-01-27 10:00:01 - INFO - Testing complete!
```
