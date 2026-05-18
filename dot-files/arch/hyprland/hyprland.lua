-- vim: sts=4 ts=4 sw=4

hl.env("CLUTTER_BACKEND", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("PKCS11_MODULE_PATH", "/usr/lib/pkcs11/gnome-keyring-pkcs11.so")
hl.env("PASSWORD_STORE_BACKEND", "gnome-libsecret")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Amber")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("XCURSOR_THEME", "Bibata-Modern-Amber")
hl.env("XCURSOR_SIZE", "20")

require("monitors")

local terminal = "alacritty"
local fileManager = "nautilus"
local menu = 'rofi -show combi -modes combi -combi-modes "window,drun" -show-icons'
local mainMod = "SUPER"

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-clip-persist --clipboard both")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("swaync")
    hl.exec_cmd("snappy-switcher --daemon")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("wlsunset -l 51.1 -L 17.0")
    hl.exec_cmd("keyd-application-mapper -d")
    hl.exec_cmd(terminal .. " --option window.startup_mode=Fullscreen")
end)

hl.config({
    general = {
        gaps_in = 1,
        gaps_out = 1,
        border_size = 2,
        ["col.active_border"] = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle =  45},
        ["col.inactive_border"] = "rgba(595959aa)",
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    dwindle = {
        -- pseudotile = true,
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    decoration = {
        rounding = 6,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            size = 10,
            passes = 2,
            brightness = 0.8,
            contrast = 0.4,
            noise = 0.30,
        },
    },
    animations = {
        enabled = true,
    },
    cursor = {
        no_hardware_cursors = false,
        inactive_timeout = 3,
    },
    input = {
        kb_layout = "pl",
        kb_variant = "",
        kb_model = "",
        kb_options = "caps:ctrl_modifier",
        kb_rules = "",

        repeat_rate = 50,
        repeat_delay = 300,

        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },

        natural_scroll = false,
    },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,
        -- vfr = true,
    },
})

-- battery:
-- hl.config({ decoration = { blur = { enabled = false } } })
-- hl.config({ decoration = { shadow = { enabled = false } } })

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager) )
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("qalculate-gtk"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("gvim"))

hl.bind(mainMod .. " + CTRL + SPACE", function()
    hl.dispatch(hl.dsp.window.float({action = "toggle"}))
    hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 600 }))
    hl.dispatch(hl.dsp.window.center())
end)

hl.bind(mainMod .. " + CTRL + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + CTRL + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("systemctl suspend"))

hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd('cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy'))

hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"))

hl.bind(mainMod .. " + UP", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + F12", hl.dsp.window.fullscreen({ mode = "fullscreen"}))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + CTRL + left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + SHIFT + left",  hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }))
-- hl.bind("ALT + TAB",         hl.dsp.exec_cmd("~/.config/hypr/scripts/workspace-toggle.sh e+1"))
-- hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("~/.config/hypr/scripts/workspace-toggle.sh e-1"))

hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + TAB",   hl.dsp.exec_cmd("~/.config/hypr/scripts/workspace-toggle.sh previous"))
hl.bind("ALT + TAB", hl.dsp.exec_cmd("snappy-switcher next"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("snappy-switcher previous"))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + CTRL + mouse:272", hl.dsp.window.resize(), { mouse = true })

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --input-volume raise"), { repeating = true })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --input-volume lower"), { repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("~/.config/hypr/scripts/mic-mute-toggle.sh && swayosd-client --input-volume mute-toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("swayosd-client --brightness lower"), { repeating = true })

-- Requires playerctl
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

hl.window_rule({
    name = "no-gaps-wtv1",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding = 0,
})

hl.window_rule({
    name = "no-gaps-f1",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding = 0,
})

hl.window_rule({
    match = { class = ".*" },
    opacity = 0.92,
})

hl.window_rule({
    { "suppress_event maximize", "class:.*" }
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "image-viewer",
    match = { title = "^(Image Viewer)$" },
    float = true,
    size = "1200 800",
    center = true,
})

hl.window_rule({
    name = "nautilus",
    match = { class = "^(org.gnome.Nautilus)$" },
    float = true,
    size = "800 600",
})

hl.window_rule({
    name = "loupe",
    match = { class = "^(org.gnome.Loupe)$" },
    float = true,
    size = "800 600",
    center = true,
})

hl.window_rule({
    name = "qalculate",
    match = { class = "qalculate-gtk" },
    pseudo = true,
    size = "800 600",
})
