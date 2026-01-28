"""
APIM Access Test Application

Tests connectivity to Azure AI Foundry and KAITO models via APIM
using OpenAI SDK for API compatibility verification.
"""

import logging
import sys
from pathlib import Path

import yaml
from openai import OpenAI

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def load_config(config_path: Path = Path("config.yaml")) -> dict:
    """
    Load configuration from YAML file.
    
    Args:
        config_path: Path to the configuration file.
        
    Returns:
        Configuration dictionary with models and test prompt.
        
    Raises:
        FileNotFoundError: If config file doesn't exist.
        yaml.YAMLError: If config file is invalid YAML.
    """
    if not config_path.exists():
        raise FileNotFoundError(
            f"Config file not found: {config_path}\n"
            "Copy config.example.yml to config.yaml and fill in your values."
        )
    
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def test_model(name: str, url: str, key: str, deployment: str, prompt: str) -> None:
    """
    Test a single model via APIM using OpenAI SDK.
    
    Args:
        name: Display name of the model.
        url: APIM endpoint URL for the model.
        key: APIM subscription key.
        deployment: Model deployment name to use in API call.
        prompt: Test prompt to send.
    """
    logger.info(f"Testing model: {name}")
    logger.info(f"  URL: {url}")
    logger.info(f"  Deployment: {deployment}")
    
    try:
        client = OpenAI(
            base_url=url,
            api_key=key,
            default_headers={"api-key": key},
        )
        
        response = client.chat.completions.create(
            model=deployment,
            messages=[
                {"role": "user", "content": prompt}
            ],
            max_tokens=100,
        )
        
        answer = response.choices[0].message.content
        logger.info(f"  ✓ Response: {answer}")
        
    except Exception as e:
        logger.error(f"  ✗ Error: {e}")


def main() -> int:
    """
    Main entry point for APIM access testing.
    
    Returns:
        Exit code (0 for success, 1 for failure).
    """
    logger.info("=" * 60)
    logger.info("APIM Access Test - Foundry & KAITO Models")
    logger.info("=" * 60)
    
    try:
        config = load_config()
    except FileNotFoundError as e:
        logger.error(str(e))
        return 1
    except yaml.YAMLError as e:
        logger.error(f"Invalid YAML in config file: {e}")
        return 1
    
    models = config.get("models", {})
    if not models:
        logger.error("No models configured in config.yaml")
        return 1
    
    test_prompt = config.get("test_prompt", "Hello, how are you?")
    logger.info(f"Test prompt: {test_prompt}")
    logger.info("-" * 60)
    
    for model_name, model_config in models.items():
        url = model_config.get("url")
        key = model_config.get("key")
        deployment = model_config.get("deployment", model_name)
        
        if not url or not key:
            logger.warning(f"Skipping {model_name}: missing url or key")
            continue
        
        test_model(model_name, url, key, deployment, test_prompt)
        logger.info("-" * 60)
    
    logger.info("Testing complete!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
