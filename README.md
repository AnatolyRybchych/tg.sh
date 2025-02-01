
## Install dependencies
```sh
sudo apt install -y python3 jq curl
```

## Usage
```sh
cat > .env<<ENV_FILE
TG_API_KEY="your_tg_api_key"
ENV_FILE

./bot
```