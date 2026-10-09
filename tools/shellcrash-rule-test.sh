#!/bin/sh
# ShellCrash/mihomo rule match tester.
# Copy this file to a ShellCrash device and run:
#   sh shellcrash-rule-test.sh example.com

set -u

usage() {
    cat <<'EOF'
Usage:
  shellcrash-rule-test.sh [options] <domain-or-url>

Options:
  -c, --controller URL  Controller URL, default from config or http://127.0.0.1:9999
  -s, --secret VALUE    Controller secret, default from config
  -p, --port PORT       Mixed proxy port, default from config
  -a, --auth USER:PASS  Mixed proxy auth, default from config
  -f, --config FILE     Runtime config path, default auto-detected
  -t, --timeout SEC     Request timeout, default 12
  -u, --url URL         URL to request; default https://<domain>/
  -h, --help            Show this help

The script uses only read-only mihomo APIs. It first tries to read a live
connection record, then falls back to rule hitCount differences. The fallback
is best effort because other concurrent traffic can also increase hitCount.
curl is preferred. wget is used as a best-effort fallback when curl is missing
or when a trimmed curl build rejects the required options.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

has_curl() {
    curl --version >/dev/null 2>&1 || curl -V >/dev/null 2>&1 || curl --help >/dev/null 2>&1
}

has_wget() {
    wget --help >/dev/null 2>&1 || wget --version >/dev/null 2>&1
}

has_wget_proxy_auth() {
    wget --help 2>&1 | grep -q -- '--proxy-user'
}

has_jq() {
    jq --version >/dev/null 2>&1
}

strip_quotes() {
    sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/^['\"]//;s/['\"]$//"
}

yaml_value() {
    key=$1
    [ -n "${CONFIG:-}" ] && [ -f "$CONFIG" ] || return 1
    awk -v key="$key" '
        $1 == key ":" {
            sub(/^[^:]*:[[:space:]]*/, "")
            print
            exit
        }
    ' "$CONFIG" | strip_quotes
}

yaml_first_auth() {
    [ -n "${CONFIG:-}" ] && [ -f "$CONFIG" ] || return 1
    awk '
        /^authentication:[[:space:]]*\[/ {
            line = $0
            sub(/^[^[]*\[/, "", line)
            sub(/\].*$/, "", line)
            gsub(/[[:space:]"'\''"]/, "", line)
            split(line, parts, ",")
            print parts[1]
            exit
        }
    ' "$CONFIG"
}

detect_config() {
    for file in \
        /tmp/ShellCrash/config.yaml \
        /etc/ShellCrash/config.yaml \
        /etc/ShellCrash/yamls/config.yaml \
        ./config.yaml
    do
        [ -f "$file" ] && {
            CONFIG=$file
            return 0
        }
    done
    return 1
}

normalize_controller() {
    value=$1
    value=$(printf '%s\n' "$value" | strip_quotes)
    [ -n "$value" ] || value=":9999"
    case "$value" in
    http://* | https://*)
        printf '%s\n' "$value"
        ;;
    :*)
        printf 'http://127.0.0.1%s\n' "$value"
        ;;
    *:*)
        port=$(printf '%s\n' "$value" | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')
        [ -n "$port" ] || port=9999
        printf 'http://127.0.0.1:%s\n' "$port"
        ;;
    *)
        printf 'http://127.0.0.1:%s\n' "$value"
        ;;
    esac
}

api_get() {
    path=$1
    rc=127
    if has_curl; then
        if [ -n "$SECRET" ]; then
            curl -fsS -H "Authorization: Bearer $SECRET" "$API$path"
            rc=$?
        else
            curl -fsS "$API$path"
            rc=$?
        fi
        [ "$rc" = 2 ] || return "$rc"
    fi
    if has_wget; then
        if [ -n "$SECRET" ]; then
            wget -q -O - --header="Authorization: Bearer $SECRET" "$API$path"
        else
            wget -q -O - "$API$path"
        fi
    else
        return 127
    fi
}

rules_to_hits() {
    file=$1
    sed 's/},{"index"/}\
{"index"/g' "$file" |
        sed -n 's/.*"index":\([0-9][0-9]*\).*"type":"\([^"]*\)".*"payload":"\([^"]*\)".*"proxy":"\([^"]*\)".*"hitCount":\([0-9][0-9]*\).*/\1|\2|\3|\4|\5/p'
}

print_hit_diff() {
    before_file=$1
    after_file=$2
    before_hits=$TMP_DIR/rules.before.hits
    after_hits=$TMP_DIR/rules.after.hits
    rules_to_hits "$before_file" >"$before_hits"
    rules_to_hits "$after_file" >"$after_hits"
    awk -F'|' '
        NR == FNR {
            before[$1] = $5 + 0
            next
        }
        ($5 + 0) > (before[$1] + 0) {
            printf "rule: %s %s -> %s (hitCount %s -> %s)\n", $2, $3, $4, before[$1] + 0, $5
            found = 1
        }
        END {
            if (!found) exit 1
        }
    ' "$before_hits" "$after_hits" | sed -n '1,8p'
}

json_string_field() {
    field=$1
    sed -n 's/.*"'"$field"'":"\([^"]*\)".*/\1/p'
}

print_connection_match() {
    file=$1
    if has_jq; then
        jq -r --arg host "$DOMAIN" '
            .connections[]
            | select(.metadata.host == $host or .metadata.remoteDestination == $host or .metadata.destinationIP == $host)
            | "source: live-connection\nhost: \(.metadata.host // "")\nnetwork: \(.metadata.network // "")/\(.metadata.type // "")\nrule: \(.rule) \(.rulePayload)\nchain: \(.chains | join(" -> "))"
        ' "$file" 2>/dev/null | sed '/^$/d'
        return 0
    fi

    line=$(sed 's/{"id"/\
{"id"/g' "$file" | grep -F "\"host\":\"$DOMAIN\"" | head -n 1)
    [ -n "$line" ] || return 1

    host=$(printf '%s\n' "$line" | json_string_field host)
    network=$(printf '%s\n' "$line" | json_string_field network)
    inbound=$(printf '%s\n' "$line" | json_string_field inboundName)
    rule=$(printf '%s\n' "$line" | json_string_field rule)
    rule_payload=$(printf '%s\n' "$line" | json_string_field rulePayload)
    chains=$(printf '%s\n' "$line" | sed -n 's/.*"chains":\[\(.*\)\],"providerChains".*/\1/p' |
        sed 's/^"//;s/"$//;s/","/ -> /g;s/\\"/"/g')

    echo "source: live-connection"
    [ -n "$host" ] && echo "host: $host"
    [ -n "$network$inbound" ] && echo "network: $network inbound=$inbound"
    [ -n "$rule$rule_payload" ] && echo "rule: $rule $rule_payload"
    [ -n "$chains" ] && echo "chain: $chains"
}

run_test_request() {
    proxy_url="http://127.0.0.1:$MIXED_PORT"
    rc=127
    if has_curl; then
        if [ -n "$AUTH" ]; then
            curl -k -L -sS -m "$TIMEOUT" -U "$AUTH" \
                -x "http://127.0.0.1:$MIXED_PORT" \
                -o /dev/null "$TEST_URL"
            rc=$?
        else
            curl -k -L -sS -m "$TIMEOUT" \
                -x "http://127.0.0.1:$MIXED_PORT" \
                -o /dev/null "$TEST_URL"
            rc=$?
        fi
        [ "$rc" = 2 ] || return "$rc"
    fi
    if has_wget; then
        if [ -n "$AUTH" ] && has_wget_proxy_auth; then
            proxy_user=${AUTH%%:*}
            proxy_pass=${AUTH#*:}
            http_proxy="$proxy_url" \
                https_proxy="$proxy_url" \
                wget -q -T "$TIMEOUT" --proxy-user="$proxy_user" --proxy-password="$proxy_pass" \
                -O /dev/null "$TEST_URL"
        elif [ -n "$AUTH" ]; then
            case "$AUTH" in
            *[!-A-Za-z0-9._~:]*)
                echo "wget fallback cannot safely pass proxy authentication" >&2
                return 127
                ;;
            esac
            http_proxy="http://$AUTH@127.0.0.1:$MIXED_PORT" \
                https_proxy="http://$AUTH@127.0.0.1:$MIXED_PORT" \
                wget -q -T "$TIMEOUT" -O /dev/null "$TEST_URL"
        else
            http_proxy="$proxy_url" \
                https_proxy="$proxy_url" \
                wget -q -T "$TIMEOUT" -O /dev/null "$TEST_URL"
        fi
    else
        echo "curl or wget is required for mixed-port requests" >&2
        return 127
    fi
}

CONFIG=${CRASH_CONFIG:-}
API=${SHELLCRASH_CONTROLLER:-}
SECRET=${SHELLCRASH_SECRET:-}
MIXED_PORT=${SHELLCRASH_MIXED_PORT:-}
AUTH=${SHELLCRASH_PROXY_AUTH:-}
TIMEOUT=12
TEST_URL=
TARGET=

while [ "$#" -gt 0 ]; do
    case "$1" in
    -c | --controller)
        [ "$#" -ge 2 ] || die "$1 needs a value"
        API=$2
        shift 2
        ;;
    -s | --secret)
        [ "$#" -ge 2 ] || die "$1 needs a value"
        SECRET=$2
        shift 2
        ;;
    -p | --port)
        [ "$#" -ge 2 ] || die "$1 needs a value"
        MIXED_PORT=$2
        shift 2
        ;;
    -a | --auth)
        [ "$#" -ge 2 ] || die "$1 needs a value"
        AUTH=$2
        shift 2
        ;;
    -f | --config)
        [ "$#" -ge 2 ] || die "$1 needs a value"
        CONFIG=$2
        shift 2
        ;;
    -t | --timeout)
        [ "$#" -ge 2 ] || die "$1 needs a value"
        TIMEOUT=$2
        shift 2
        ;;
    -u | --url)
        [ "$#" -ge 2 ] || die "$1 needs a value"
        TEST_URL=$2
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    -*)
        die "unknown option: $1"
        ;;
    *)
        [ -z "$TARGET" ] || die "only one domain or URL can be tested at a time"
        TARGET=$1
        shift
        ;;
    esac
done

[ -n "$TARGET" ] || {
    usage
    exit 1
}

has_curl || has_wget || die "curl or wget is required"

if [ -z "$CONFIG" ]; then
    detect_config || true
fi

if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
    [ -n "$API" ] || API=$(normalize_controller "$(yaml_value external-controller || true)")
    [ -n "$SECRET" ] || SECRET=$(yaml_value secret || true)
    [ -n "$MIXED_PORT" ] || MIXED_PORT=$(yaml_value mixed-port || true)
    [ -n "$AUTH" ] || AUTH=$(yaml_first_auth || true)
fi

[ -n "$API" ] || API="http://127.0.0.1:9999"
case "$API" in
http://* | https://*) ;;
*) API=$(normalize_controller "$API") ;;
esac

[ -n "$MIXED_PORT" ] || MIXED_PORT=7890

case "$TARGET" in
http://* | https://*)
    [ -n "$TEST_URL" ] || TEST_URL=$TARGET
    DOMAIN=$(printf '%s\n' "$TARGET" | sed 's#^[^/]*//##;s#/.*##;s/:.*##')
    ;;
*)
    DOMAIN=$TARGET
    [ -n "$TEST_URL" ] || TEST_URL="https://$DOMAIN/"
    ;;
esac

TMP_DIR=${TMPDIR:-/tmp}/shellcrash-rule-test.$$
mkdir -p "$TMP_DIR" || die "failed to create temp dir: $TMP_DIR"
cleanup() {
    [ -n "${REQ_PID:-}" ] && kill "$REQ_PID" >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

echo "target: $DOMAIN"
echo "url: $TEST_URL"
echo "controller: $API"
echo "mixed-port: $MIXED_PORT"
[ -n "$CONFIG" ] && echo "config: $CONFIG"

version_json=$TMP_DIR/version.json
api_get /version >"$version_json" || die "controller is not reachable or secret is wrong"
echo "core: $(sed -n 's/.*"version":"\([^"]*\)".*/\1/p' "$version_json")"

dns_json=$TMP_DIR/dns.json
if api_get "/dns/query?name=$DOMAIN&type=A" >"$dns_json" 2>/dev/null; then
    echo "dns-api-answer:"
    grep -o '"data":"[^"]*"' "$dns_json" |
        sed 's/^"data":"//;s/"$//' |
        sed -n '1,8{s/^/  /;p;}'
else
    echo "dns-api-answer: unavailable"
fi

before_rules=$TMP_DIR/rules.before.json
after_rules=$TMP_DIR/rules.after.json
api_get /rules >"$before_rules" 2>/dev/null || true

run_test_request >"$TMP_DIR/request.out" 2>"$TMP_DIR/request.err" &
REQ_PID=$!

conn_file=$TMP_DIR/connections.json
found_connection=0
i=0
while [ "$i" -lt "$TIMEOUT" ]; do
    if api_get /connections >"$conn_file" 2>/dev/null &&
        print_connection_match "$conn_file" >"$TMP_DIR/connection.match"; then
        if [ -s "$TMP_DIR/connection.match" ]; then
            found_connection=1
            break
        fi
    fi
    if ! kill -0 "$REQ_PID" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

wait "$REQ_PID" >/dev/null 2>&1 || true
REQ_PID=

echo "match:"
if [ "$found_connection" -eq 1 ]; then
    sed 's/^/  /' "$TMP_DIR/connection.match"
else
    api_get /rules >"$after_rules" 2>/dev/null || true
    if [ -s "$before_rules" ] && [ -s "$after_rules" ] &&
        print_hit_diff "$before_rules" "$after_rules" >"$TMP_DIR/hit.diff"; then
        echo "  source: rule-hit-delta (best effort)"
        sed 's/^/  /' "$TMP_DIR/hit.diff"
    else
        echo "  no live connection or rule hit delta captured"
        echo "  try a URL that keeps the connection open longer, or increase --timeout"
    fi
fi

if [ -s "$TMP_DIR/request.err" ]; then
    echo "request-note:"
    sed -n '1,3{s/^/  /;p;}' "$TMP_DIR/request.err"
fi
