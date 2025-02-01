
[ "$JSON_IO" ] || JSON_IO="FS"

if [ "$JSON_IO" = FS ]; then
    json_io_read() {
        cat "$1.json"
    }

    json_io_write() {
        cat > "$1.json"
    }

    json_io_remove() {
        rm -f "$1.json"
    }
else
    echo "ERROR: JSON_IO has unknown target '$JSON_IO'" >&2
    exit 1
fi

json_get() {
    local db=$1
    shift

    [ -f "$db.json" ] || return 1
    local json=$(json_io_read "$db" | jq 'getpath($ARGS.positional)' --args "$@") || return 1
    echo "$json"
}

json_set() {
    local db=$1
    shift

    local data=$(cat)
    [ "$data" ] || data=null

    local json=$(json_io_read "$db")
    [ "$json" ] || json='{}'
    json=$(echo "$json" | jq '. | setpath($ARGS.positional; $obj)' --argjson obj "$data" --args "$@" | json_io_write "$db")
}

json_meld() {
    local db=$1
    shift

    local data=$(cat)
    [ "$data" ] || return 0

    local json=$(json_io_read "$db")
    [ "$json" ] || json='{}'
    json=$(echo "$json" | jq '(getpath($ARGS.positional)) as $prev 
        | setpath($ARGS.positional; $prev * $obj)' \
        --argjson obj "$data" --args "$@" | json_io_write "$db")
}

