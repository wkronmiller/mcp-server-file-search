#!/usr/bin/env bash
set -euo pipefail

BIN=".build/debug/mcp-file-search"
QUERY="Package.swift"
FILENAME_ONLY=false
LIMIT=5
ONLY_IN=()
MODE="all"   # all | init | tools | call

usage() {
  cat <<USAGE
Usage: $0 [options]
  --query <text>           Search text (default: Package.swift)
  --filename-only          Match filenames only (default: off)
  --limit <n>              Max results (default: 5)
  --only-in <dir>          Limit search to directory (repeatable)
  --init-only              Only send initialize
  --tools-only             Only list tools (after init)
  --call-only              Only call file-search (after init)
  -h, --help               Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) QUERY="$2"; shift 2;;
    --filename-only) FILENAME_ONLY=true; shift;;
    --limit) LIMIT="$2"; shift 2;;
    --only-in) ONLY_IN+=("$2"); shift 2;;
    --init-only) MODE="init"; shift;;
    --tools-only) MODE="tools"; shift;;
    --call-only) MODE="call"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

echo "[mcp] Ensuring binary is built..."
if [[ ! -x "$BIN" ]]; then
  swift build
fi

echo "[mcp] Starting server and sending JSON-RPC requests..."
python3 - "$BIN" "$QUERY" "$FILENAME_ONLY" "$LIMIT" ${ONLY_IN[@]:-} <<PY
import sys, json, subprocess, time, os, select, shlex

bin_path = sys.argv[1]
query = sys.argv[2]
filename_only = sys.argv[3].lower() == 'true'
limit = int(sys.argv[4])
only_in = sys.argv[5:]

MODE = os.environ.get('MODE', 'all')

def send(proc, obj, timeout=5.0):
    data = (json.dumps(obj) + "\n").encode("utf-8")
    proc.stdin.write(data)
    proc.stdin.flush()
    deadline = time.time() + timeout
    buf = bytearray()
    # Read until we see a closing brace or timeout
    fd = proc.stdout.fileno()
    while time.time() < deadline:
        rlist, _, _ = select.select([fd], [], [], 0.1)
        if rlist:
            try:
                chunk = os.read(fd, 4096)
            except BlockingIOError:
                continue
            if not chunk:
                break
            buf.extend(chunk)
            if b"}" in chunk:
                break
    return buf.decode("utf-8", errors="replace").strip()

proc = subprocess.Popen([bin_path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=False, bufsize=0)
time.sleep(0.5)

def pretty(obj):
    try:
        return json.dumps(json.loads(obj), indent=2)
    except Exception:
        return obj

try:
    # initialize
    init_req = {"jsonrpc":"2.0","method":"initialize","params":{"clientInfo":{"name":"cli-test","version":"1.0.0"},"capabilities":{}},"id":1}
    print("[mcp] -> initialize")
    resp = send(proc, init_req)
    print("[mcp] <-", pretty(resp))
    if MODE == 'init':
        sys.exit(0)

    # tools/list
    print("[mcp] -> tools/list")
    tools_req = {"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}
    resp = send(proc, tools_req)
    print("[mcp] <-", pretty(resp))
    if MODE == 'tools':
        sys.exit(0)

    # tools/call file-search
    args = {"query": query, "filenameOnly": filename_only, "limit": limit}
    if only_in:
        args["onlyIn"] = only_in
    search_req = {"jsonrpc":"2.0","method":"tools/call","params":{"name":"file-search","arguments": args},"id":3}
    print("[mcp] -> tools/call file-search", args)
    resp = send(proc, search_req, timeout=8.0)
    print("[mcp] <-", pretty(resp))

finally:
    try:
        proc.terminate()
        proc.wait(timeout=2.0)
    except Exception:
        proc.kill()
        proc.wait()

    err = proc.stderr.read()
    if err:
        sys.stderr.write("[mcp] stderr:\n" + err.decode("utf-8", errors="replace") + "\n")
PY

echo "[mcp] Done."
