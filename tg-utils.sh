
. "$(dirname "$0")/json.sh"

_TG_BOT=
_TG_BOT_DATA=
_TG_API_KEY=
_TG_LAST_UPDATE=0
_TG_LAST_UPDATE_DATA=''
_TG_UNHANDLED_UPDATES='[]'

tg_init() {
    _TG_BOT=$1
    _TG_API_KEY=$2

    _TG_BOT_DATA=$(json_get "$_TG_BOT")
    [ "$_TG_BOT_DATA" ] || _TG_BOT_DATA='{}'

    [ "$_TG_API_KEY" ] || _TG_API_KEY=$(echo "$bot_data" | jq -r '.api_key')
    [ "$_TG_API_KEY" ] || {
        echo "ERROR: api_key is empty" >&2
        return 1
    }

    _TG_UNHANDLED_UPDATES=$(echo "$_TG_BOT_DATA" | jq -r 'if .unhandled_updates then .unhandled_updates else [] end')

    _TG_LAST_UPDATE=$(echo "$_TG_BOT_DATA" | jq -r 'if .last_update then .last_update else 0 end')
}

tg_save() {
    [ "$_TG_BOT" ] || {
        echo "ERROR: Telegram bot is not initialized" >&2
        return 1
    }

    echo "$_TG_BOT_DATA" | json_set "$_TG_BOT"
    jq -n \
        --argjson last_update "$_TG_LAST_UPDATE" \
        --argjson unhandled_updates "$_TG_UNHANDLED_UPDATES" \
        '$ARGS.named' | json_meld "$_TG_BOT"
}

tg_api() {
    local method=$1
    local api=$2
    shift 2
    curl -X "$method" "https://api.telegram.org/bot$_TG_API_KEY/$api" "$@" 2>/dev/null
}

tg_poll() {
    local handled_all=$(echo "$_TG_UNHANDLED_UPDATES" | jq -r '. | length == 0')
    if [ "$handled_all" = true ]; then
        local updates=$(tg_api GET getUpdates) || {
            echo "getUpdates: Request failed" >&2
            return 1
        }

        local ok=$(echo "$updates" | jq -r '.ok')
        [ "$ok" = true ] || {
            echo "getUpdates: $updates" >&2
            return 1
        }

        updates=$(echo "$updates" | jq --argjson last_update "$_TG_LAST_UPDATE" '.result | map(select(.update_id > $last_update))')

        _TG_UNHANDLED_UPDATES=$updates
        local handled_all=$(echo "$_TG_UNHANDLED_UPDATES" | jq -r '. | length == 0')
        [ "$handled_all" = true ] && return 1
    fi

    _TG_LAST_UPDATE_DATA=$(echo "$_TG_UNHANDLED_UPDATES" | jq first)
    return 0
}

tg_handle() {
    local handler=$1
    shift

    [ "$_TG_LAST_UPDATE_DATA" ] || {
        echo "ERROR: the update is already handled" >&2
        return 1
    }

    local data=$_TG_LAST_UPDATE_DATA
    _TG_LAST_UPDATE=$(echo "$_TG_LAST_UPDATE_DATA" | jq '.update_id')
    _TG_UNHANDLED_UPDATES=$(echo "$_TG_UNHANDLED_UPDATES" | jq '.[1:]')
    _TG_LAST_UPDATE_DATA=

    echo "$data" | "$handler" "$@"
}
