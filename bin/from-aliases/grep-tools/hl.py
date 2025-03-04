import json
import os
import re
import sys

config = {
    "colors_file": ".hl-colors.json",
    "regex_file": ".hl.json",
    "colors_basic": [ "blue", "cyan", "green", "red", "yellow", "purple", "gold" ],
}

only_matching = False
use_colors = None
verbose = 0

regex_def = {}
regex_file_default = {}
regex_file = {}
regex_cli = {}
regex_cli_no = 0
colors = {}
colors_basic_idx = 0
config_dir = None

def log(lvl, msg):
    if verbose < lvl: return
    print(msg, file=sys.stderr)

def load(a_file, a_dir = "."):
    if a_file.startswith("/"):
        a_dir = "/"
    if not a_dir: return ""
    if not os.path.exists(f"{a_dir}/{a_file}"): return ""
    log(1, f"loading data from {a_dir}/{a_file}")
    with open(f"{a_dir}/{a_file}") as f:
        return json.load(f)

def get_color(color):
    if not use_colors:
        return ""
    if not color in colors:
        return ""
    while color in colors:
        color = colors[color]
    return f"\033{color}"

def extract_markups(text):
    ret = []
    offset = 0
    for match in re.finditer(r"<<(S|E):.+?>>", text):
        ret.append((match.start() - offset, match.group()))
        offset += len(match.group())
    return ret

def merge_markups(input_text, preprocessed_texts):
    all_markups = []
    for text in preprocessed_texts:
        all_markups.extend(extract_markups(text))

    all_markups.sort(key=lambda x: x[0])

    output_text = list(input_text)
    offset = 0

    for start, markup in all_markups:
        adjusted_start = start + offset
        output_text[adjusted_start:adjusted_start] = list(markup)
        offset += len(markup)

    t = ''.join(output_text)
    log(1, f"merged: {t}")

    return t

def insert_markups(text, regex_map):
    text_with_markups = []
    to_skip = []
    keys = []
    for i, (regex, item) in enumerate(regex_map.items()):
        keys.append(regex)
        if item.get("name") in to_skip: continue
        t_repl = re.sub(f"({regex})", f"<<S:{i}>>\\1<<E:{i}>>", text)
        if t_repl != text:
            text_with_markups.append(t_repl)
            skip = item.get("skip")
            if skip: to_skip.extend(skip)

    if verbose >= 2:
        for tt in text_with_markups:
            log(2, f"t+markups: {tt}")

    return (text_with_markups, keys)

def colorize_text(text, regex_map):
    ( text_with_markups, keys ) = insert_markups(text, regex_map)
    if not text_with_markups:
        print("--> NOT match")
        return (text, False)

    t = merge_markups(text, text_with_markups)

    state_init = ("off", True)
    state = state_init
    stack = []
    out = ""
    end_last = 0
    for m in re.finditer(r"<<(S|E):(.+?)>>", t):
        out += t[end_last:m.start()]
        key = int(m.group(2))
        if m.group(1) == "S":
            item = regex_map[keys[key]]
            (c, ea) = state
            if ea or c == "off":
                c = item["color"]
                out += get_color(c)
            if not item["embedded"]:
                ea = False
            state = (c, ea)
            stack.append((key, state[1]))
        elif m.group(1) == "E":
            if stack[-1][0] == key:
                stack.pop()
                state = (regex_map[keys[stack[-1][0]]]["color"], stack[-1][1]) if stack else ("off", True)
                out += get_color(state[0])
            else:
                ea = state[1]
                for i in range(len(stack) - 1, -1, -1):
                    if stack[i][0] == key:
                        ea = stack.pop(i)[1]
                        break
                if not state[1] and ea:
                    state = state_init
                    out += get_color(state[0])

        end_last = m.end()

    out += t[end_last:]

    return (out, True)

def gen_regex_v(color, name, skip=[], embedded=True):
    return {
        "color": color,
        "name": name,
        "skip": skip,
        "embedded": embedded,
    }

def conv_regex_map(regex_map, name_prefix):
    for i, (k, v) in enumerate(regex_map.items()):
        vn = gen_regex_v(None, "{:}:{:03d}".format(name_prefix, i+1))
        vn.update(v if isinstance(v, dict) else { "color": v })
        if isinstance(vn["skip"], str): vn["skip"] = [ vn["skip"] ]
        regex_map[k] = vn
    return regex_map

config_dir = os.getenv("HL_CONFIG_DIR")
if not config_dir:
    cfgHome = os.getenv("XDG_CONFIG_HOME")
    if not cfgHome: cfgHome = f"{os.getenv('HOME')}/.config"
    config_dir = f"{cfgHome}/hl-python"

if os.path.exists(f"{config_dir}"):
    log(1, f"config dir: {config_dir}")
else:
    config_dir = None

config.update(load("config.json", config_dir))

for a_dir in [config_dir, os.getenv("BASHRC_RUNTIME_PATH")]:
    colors.update(load("colors.json", a_dir))
colors.update(load(config["colors_file"]))
config["colors_basic"] = [c for c in config["colors_basic"] if c in colors]

regex_def.update(load("regs-default.json", config_dir))
regex_file_default.update(load(config["regex_file"]))

args = sys.argv
cmd = os.path.basename(args.pop(0))
last_reg = None
while len(args) > 0:
    arg = args.pop(0)
    if False:
        None
    elif arg == "---util-get-colors":
        print(" ".join([ c for c in colors.keys() if c not in [ "off", "COff" ] ]))
        exit(0)
    elif arg == "--no-default" or arg == "-D":
        regex_def = {}
    elif arg == "--reg-file" or arg == "-f":
        f = args.pop(0)
        if f != "-":
            regex_file.update(load(f))
        else:
            regex_file_default = {}
    elif arg == "--only-matching" or arg == "-m":
        only_matching = True
    elif arg == "--colors" or arg == "-c":
        use_colors = True
    elif arg == "--no-colors" or arg == "-C":
        use_colors = False
    elif arg == "--name":
        v = args.pop(0)
        if last_reg: regex_cli[last_reg]["name"] = v
    elif arg == "--skip":
        v = args.pop(0)
        if last_reg:
            try:
                regex_cli[last_reg]["skip"].extend(json.loads(v))
            except:
                regex_cli[last_reg]["skip"].extend([v])
    elif arg == "--no-embed":
        if last_reg: regex_cli[last_reg]["embedded"] = False
    elif arg == '-p':
        (c, last_reg) = (args.pop(0), args.pop(0))
        regex_cli_no += 1
        regex_cli[last_reg] = gen_regex_v(c, "CLI-P:{:03d}".format(regex_cli_no))
    elif arg == "-v" or arg == "-vv" or arg == "-vvv":
        verbose = arg.count('v')
    elif arg == "--help" or arg == "-h":
        print(f"""
SYNOPSIS
    {cmd} [<options>] [<REG-EXPR> ... ]

OPTIONS
    -D, --no-default
        Do not use default highlighters
    -f <JSON-FILE>, --reg-file <JSON-FILE>
        Load highlighters from a JSON-FILE
    -m, --only-matching
        Print only matching lines
    -c, --colors
        Force to color
    -C, --no-colors
        Do not color
    --name <NAME>
        Name the last one provided reg-expr
    --skip <NAME | <[ NAME ...]>
        Skip processing given reg-exprs when the last one provided is found
    --no-embed
        Do not embed other reg-exprs inside the last one provided
    -p <COLOR> <REG-EXPR>
    -v, -vv
        Verbosity level
    -h, --help
        This message

    <REG-EXPR> ...

""")
        exit(0)
    else:
        last_reg = arg
        regex_cli_no += 1
        regex_cli[last_reg] = gen_regex_v(config["colors_basic"][colors_basic_idx], "CLI-B:{:03d}".format(regex_cli_no))
        colors_basic_idx = (colors_basic_idx + 1) % len(config["colors_basic"])

regex_map = {}
if regex_def:
    regex_map.update(conv_regex_map(regex_def, "DEF"))
if regex_file_default:
    regex_map.update(conv_regex_map(regex_file_default, "F-DEF"))
if regex_file:
    regex_map.update(conv_regex_map(regex_file, "FILE"))
if regex_cli:
    regex_map.update(regex_cli)
regex_map = conv_regex_map(regex_map, "HMM")

if not use_colors:
    use_colors = os.isatty(sys.stdout.fileno())

if verbose >= 1:
    if verbose >= 2:
        log(2, f"regs-full={json.dumps(regex_map, indent=2)}")
    log(1, "regs={")
    for i, (k, v) in enumerate(regex_map.items()):
        cn = v["color"]
        c = get_color(cn)
        if c:
            log(1, "  {:3}: {:60}: {:15} {:40}".format(i, f"\"{k}\"", f"\"{cn}\",", "{:}### {:8} ###{:}".format(c, cn, get_color('off'))))
        else:
            log(1, "  {:3}: {:60}: {:15} {:40}".format(i, f"\"{k}\"", f"\"{cn}\",", "!!! {:8} !!!".format("NOT-DEF")))
    log(1, "}")
    if verbose >= 3:
        log(2, "colors={")
        for c in sorted(colors):
            log(2, "  {:15}: {:15} {:20}".format(f"\"{c}\"", f"\"{colors[c]}\",", f"{get_color(c)}### COLOURED-TEXT ###{get_color('off')}"))
        log(2, "}")

if os.isatty(sys.stdin.fileno()):
    log(0, "stdin must be piped")
    exit(1)

log(1, "")

for l in sys.stdin:
    l = l.rstrip('\n')
    (out, modified) = colorize_text(l, regex_map)
    if modified or not only_matching:
        print(out)

