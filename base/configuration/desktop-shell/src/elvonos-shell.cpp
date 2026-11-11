// ElvonOS V1 — Desktop Shell (C++ GTK4 + LayerShell with QEMU fallback)
// ChromeOS-style UI: rounded pills, light theme, app grid launcher
// Build: g++ -std=c++17 -o elvonos-shell elvonos-shell.cpp $(pkg-config --cflags --libs gtk4 gtk4-layer-shell-0)

#include <gtk/gtk.h>
#include <gtk4-layer-shell/gtk4-layer-shell.h>
#include <glib.h>
#include <signal.h>
#include <iostream>
#include <fstream>
#include <cstdarg>
#include <cstdio>
#include <string>
#include <vector>
#include <algorithm>
#include <sstream>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <sys/wait.h>
#include <time.h>

// ---------- Mode ----------
static gboolean use_wayland = FALSE;

// ---------- Logging ----------
static std::ofstream shell_log;
static void log_msg(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    time_t now = time(nullptr);
    struct tm* tm = localtime(&now);
    char ts[32];
    strftime(ts, sizeof(ts), "%H:%M:%S", tm);
    if (shell_log.is_open()) {
        shell_log << "[" << ts << "] " << buf << std::endl;
        shell_log.flush();
    }
    std::cerr << "[" << ts << "] " << buf << std::endl;
}
#define LOG(...) log_msg(__VA_ARGS__)

// ---------- CSS ----------
static const char* CSS = R"css(
* {
    font-family: "Noto Sans", sans-serif;
    font-size: 13px;
}

window#taskbar {
    background-color: rgba(245, 246, 248, 0.94);
    border: 1px solid rgba(0, 0, 0, 0.08);
    border-radius: 22px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
    color: #202124;
}

window#startmenu {
    background-color: #ffffff;
    border: 1px solid rgba(0, 0, 0, 0.10);
    border-radius: 28px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.16);
    color: #202124;
}

window#desktop-icons {
    background-color: transparent;
}

window#widgets {
    background-color: rgba(255, 255, 255, 0.90);
    border: 1px solid rgba(0, 0, 0, 0.08);
    border-radius: 16px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.10);
    color: #202124;
}

.taskbar-start {
    background-color: #e8eaed;
    color: #202124;
    font-weight: 600;
    border-radius: 20px;
    min-width: 80px;
    min-height: 36px;
    border: none;
}

.taskbar-start:hover {
    background-color: #dadce0;
}

.taskbar-app {
    background-color: transparent;
    color: #5f6368;
    border-radius: 16px;
    min-width: 36px;
    min-height: 36px;
    border: none;
}

.taskbar-app:hover {
    background-color: rgba(0, 0, 0, 0.06);
    color: #202124;
}

.taskbar-app:active {
    background-color: rgba(0, 0, 0, 0.10);
}

.tray-btn {
    background-color: transparent;
    color: #5f6368;
    border-radius: 16px;
    min-width: 36px;
    min-height: 36px;
    border: none;
}

.tray-btn:hover {
    background-color: rgba(0, 0, 0, 0.06);
    color: #202124;
}

.clock-label {
    font-weight: 500;
    color: #202124;
    padding: 0 12px;
}

.startmenu-search {
    background-color: #f1f3f4;
    border: none;
    border-radius: 20px;
    padding: 10px 16px;
    font-size: 14px;
    color: #202124;
}

.startmenu-search:focus {
    background-color: #ffffff;
    border: 1px solid #1a73e8;
    outline: none;
}

.startmenu-grid-button {
    background-color: transparent;
    color: #202124;
    border-radius: 12px;
    min-width: 96px;
    min-height: 112px;
    border: none;
}

.startmenu-grid-button:hover {
    background-color: rgba(0, 0, 0, 0.04);
}

.startmenu-grid-icon {
    icon-size: 32px;
}

.startmenu-grid-label {
    font-size: 12px;
    font-weight: 500;
    padding-top: 6px;
}

.widget-label {
    font-size: 13px;
    font-weight: 500;
    color: #202124;
    padding: 2px 0;
}

.desktop-icon-btn {
    background-color: transparent;
    border-radius: 10px;
    border: none;
    min-width: 80px;
    min-height: 88px;
}

.desktop-icon-btn:hover {
    background-color: rgba(0, 0, 0, 0.04);
}

.system-btn {
    background-color: #e8f0fe;
    color: #1a73e8;
    border-radius: 12px;
    min-width: 100px;
    min-height: 36px;
    border: none;
    font-weight: 500;
}

.system-btn:hover {
    background-color: #d2e3fc;
)css";

static void apply_css() {
    GtkCssProvider* provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, CSS, -1);
    GdkDisplay* display = gdk_display_get_default();
    gtk_style_context_add_provider_for_display(display, GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
}

// ---------- Desktop Entry Parser ----------
struct DesktopEntry {
    std::string name;
    std::string exec;
    std::string icon;
};

static DesktopEntry parse_desktop_file(const std::string& path) {
    DesktopEntry e;
    std::ifstream f(path);
    if (!f.is_open()) return e;
    std::string line;
    bool in_desktop = false;
    bool nodisplay = false, hidden = false;
    while (std::getline(f, line)) {
        while (!line.empty() && (line.back()=='\r'||line.back()=='\n')) line.pop_back();
        while (!line.empty() && (line.front()==' '||line.front()=='\t')) line.erase(line.begin());
        if (line.empty() || line[0]=='#') continue;
        if (line == "[Desktop Entry]") { in_desktop = true; continue; }
        if (line.front()=='[' && line.back()==']') { in_desktop = false; continue; }
        if (!in_desktop) continue;
        auto eq = line.find('=');
        if (eq == std::string::npos) continue;
        std::string key = line.substr(0, eq);
        std::string val = line.substr(eq+1);
        if (key == "Name") e.name = val;
        else if (key == "Exec") e.exec = val;
        else if (key == "Icon") e.icon = val;
        else if (key == "NoDisplay") nodisplay = (val == "true");
        else if (key == "Hidden") hidden = (val == "true");
    }
    if (nodisplay || hidden) e.name.clear();
    return e;
}

static std::vector<DesktopEntry> load_desktop_files(const std::vector<std::string>& dirs) {
    std::vector<DesktopEntry> items;
    for (const auto& d : dirs) {
        DIR* dir = opendir(d.c_str());
        if (!dir) { LOG("cannot open dir: %s", d.c_str()); continue; }
        struct dirent* ent;
        while ((ent = readdir(dir)) != nullptr) {
            std::string name = ent->d_name;
            if (name.size() < 9 || name.substr(name.size()-8) != ".desktop") continue;
            std::string full = d + "/" + name;
            DesktopEntry e = parse_desktop_file(full);
            if (!e.name.empty()) items.push_back(e);
        }
        closedir(dir);
    }
    std::sort(items.begin(), items.end(), [](const DesktopEntry&a, const DesktopEntry&b){ return a.name < b.name; });
    LOG("loaded %zu desktop files", items.size());
    return items;
}

static void launch_desktop(const DesktopEntry& e) {
    LOG("launching: %s (%s)", e.name.c_str(), e.exec.c_str());
    std::string cmd = e.exec;
    std::istringstream iss(cmd);
    std::vector<std::string> args;
    std::string token;
    while (iss >> token) args.push_back(token);
    if (args.empty()) return;
    pid_t pid = fork();
    if (pid == 0) {
        setsid();
        std::vector<char*> argv;
        for (auto& a : args) argv.push_back(const_cast<char*>(a.c_str()));
        argv.push_back(nullptr);
        execvp(argv[0], argv.data());
        _exit(127);
    }
    int status;
    waitpid(pid, &status, WNOHANG);
}

// ---------- Globals ----------
static GtkWidget* taskbar = nullptr;
static GtkWidget* startmenu = nullptr;
static GtkWidget* desktop_icons = nullptr;
static GtkWidget* widgets = nullptr;
static gboolean startmenu_visible = FALSE;
static gboolean widgets_visible = TRUE;

// ---------- Callbacks ----------
static void on_start_clicked(GtkButton*, gpointer) {
    LOG("start button clicked");
    startmenu_visible = !startmenu_visible;
    if (startmenu_visible && startmenu)
        gtk_window_present(GTK_WINDOW(startmenu));
    else if (!startmenu_visible && startmenu)
        gtk_window_close(GTK_WINDOW(startmenu));
}

static void on_quick_launch(GtkButton*, gpointer cmd) {
    LOG("quick launch: %s", (const char*)cmd);
    std::string full = std::string((const char*)cmd) + " &";
    system(full.c_str());
}

static void on_power(GtkButton*, gpointer) {
    LOG("power off");
    system("systemctl poweroff 2>/dev/null || poweroff");
}

static void on_restart(GtkButton*, gpointer) {
    LOG("reboot");
    system("systemctl reboot 2>/dev/null || reboot");
}

static void on_desktop_icon_clicked(GtkButton*, gpointer data) {
    DesktopEntry* e = (DesktopEntry*)data;
    launch_desktop(*e);
    delete e;
}

static void on_startmenu_grid_clicked(GtkButton*, gpointer data) {
    DesktopEntry* e = (DesktopEntry*)data;
    launch_desktop(*e);
    startmenu_visible = FALSE;
    gtk_window_close(GTK_WINDOW(startmenu));
    delete e;
}

static gboolean on_clock_tick(gpointer label) {
    time_t now = time(nullptr);
    struct tm* tm = localtime(&now);
    char buf[64];
    strftime(buf, sizeof(buf), "%H:%M", tm);
    gtk_label_set_text(GTK_LABEL(label), buf);
    return G_SOURCE_CONTINUE;
}

static gboolean on_widgets_tick(gpointer labels) {
    GtkWidget** lbls = (GtkWidget**)labels;
    time_t now = time(nullptr);
    struct tm* tm = localtime(&now);
    char buf[64];
    strftime(buf, sizeof(buf), "%H:%M", tm);
    gtk_label_set_text(GTK_LABEL(lbls[0]), buf);
    std::ifstream bat("/sys/class/power_supply/BAT0/capacity");
    std::string cap;
    if (bat >> cap) {
        std::string text = "Akku " + cap + "%";
        gtk_label_set_text(GTK_LABEL(lbls[1]), text.c_str());
    } else {
        gtk_label_set_text(GTK_LABEL(lbls[1]), "Akku N/A");
    }
    gtk_label_set_text(GTK_LABEL(lbls[2]), "CPU --%");
    gtk_label_set_text(GTK_LABEL(lbls[3]), "RAM --%");
    return G_SOURCE_CONTINUE;
}

static gboolean on_desktop_refresh(gpointer grid_ptr) {
    GtkWidget* grid = GTK_WIDGET(grid_ptr);
    LOG("refreshing desktop icons");
    GtkWidget* child;
    while ((child = gtk_widget_get_first_child(grid)) != nullptr)
        gtk_widget_unparent(child);

    const char* home = g_getenv("HOME");
    std::vector<std::string> dirs;
    if (home) dirs.push_back(std::string(home) + "/Desktop");
    dirs.push_back("/usr/share/applications/elvonos");
    auto items = load_desktop_files(dirs);
    int col = 0, row = 0, max_col = 6;
    for (auto& item : items) {
        GtkWidget* btn = gtk_button_new();
        gtk_widget_add_css_class(btn, "desktop-icon-btn");
        GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
        gtk_widget_set_halign(vbox, GTK_ALIGN_CENTER);
        GtkWidget* img = gtk_image_new_from_icon_name(item.icon.empty() ? "application-x-executable" : item.icon.c_str());
        gtk_image_set_pixel_size(GTK_IMAGE(img), 40);
        gtk_box_append(GTK_BOX(vbox), img);
        GtkWidget* lbl = gtk_label_new(item.name.c_str());
        gtk_label_set_wrap(GTK_LABEL(lbl), TRUE);
        gtk_label_set_width_chars(GTK_LABEL(lbl), 10);
        gtk_box_append(GTK_BOX(vbox), lbl);
        gtk_button_set_child(GTK_BUTTON(btn), vbox);
        g_signal_connect(btn, "clicked", G_CALLBACK(on_desktop_icon_clicked), new DesktopEntry(item));
        gtk_grid_attach(GTK_GRID(grid), btn, col, row, 1, 1);
        col++;
        if (col >= max_col) { col = 0; row++; }
    }
    gtk_widget_set_visible(grid, TRUE);
    return G_SOURCE_REMOVE;
}

static gboolean on_startmenu_populate(gpointer grid_ptr) {
    GtkGrid* grid = GTK_GRID(grid_ptr);
    LOG("populating startmenu grid");
    GtkWidget* child;
    while ((child = gtk_widget_get_first_child(GTK_WIDGET(grid))) != nullptr)
        gtk_widget_unparent(child);

    const char* home = g_getenv("HOME");
    std::vector<std::string> dirs;
    if (home) dirs.push_back(std::string(home) + "/Desktop");
    dirs.push_back("/usr/share/applications/elvonos");
    auto items = load_desktop_files(dirs);
    int col = 0, row = 0, max_col = 5;
    for (auto& item : items) {
        GtkWidget* btn = gtk_button_new();
        gtk_widget_add_css_class(btn, "startmenu-grid-button");
        GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
        gtk_widget_set_halign(vbox, GTK_ALIGN_CENTER);
        gtk_widget_set_valign(vbox, GTK_ALIGN_CENTER);
        GtkWidget* img = gtk_image_new_from_icon_name(item.icon.empty() ? "application-x-executable" : item.icon.c_str());
        gtk_image_set_pixel_size(GTK_IMAGE(img), 32);
        gtk_widget_add_css_class(img, "startmenu-grid-icon");
        gtk_box_append(GTK_BOX(vbox), img);
        GtkWidget* lbl = gtk_label_new(item.name.c_str());
        gtk_label_set_wrap(GTK_LABEL(lbl), TRUE);
        gtk_label_set_width_chars(GTK_LABEL(lbl), 10);
        gtk_widget_add_css_class(lbl, "startmenu-grid-label");
        gtk_box_append(GTK_BOX(vbox), lbl);
        gtk_button_set_child(GTK_BUTTON(btn), vbox);
        gtk_grid_attach(grid, btn, col, row, 1, 1);
        col++;
        if (col >= max_col) { col = 0; row++; }
    }
    gtk_widget_set_visible(GTK_WIDGET(grid), TRUE);
    return G_SOURCE_REMOVE;
}

// ---------- LayerShell helper ----------
static void layer_window(GtkWindow* win, GtkLayerShellLayer layer,
                         gboolean anchor_top, gboolean anchor_bottom,
                         gboolean anchor_left, gboolean anchor_right,
                         int exclusive_zone,
                         int margin_top, int margin_bottom, int margin_left, int margin_right) {
    if (!use_wayland) return;
    LOG("setting up layer window: layer=%d", (int)layer);
    gtk_layer_init_for_window(win);
    gtk_layer_set_layer(win, layer);
    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_TOP, anchor_top);
    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_BOTTOM, anchor_bottom);
    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_LEFT, anchor_left);
    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_RIGHT, anchor_right);
    if (exclusive_zone >= 0)
        gtk_layer_set_exclusive_zone(win, exclusive_zone);
    gtk_layer_set_margin(win, GTK_LAYER_SHELL_EDGE_TOP, margin_top);
    gtk_layer_set_margin(win, GTK_LAYER_SHELL_EDGE_BOTTOM, margin_bottom);
    gtk_layer_set_margin(win, GTK_LAYER_SHELL_EDGE_LEFT, margin_left);
    gtk_layer_set_margin(win, GTK_LAYER_SHELL_EDGE_RIGHT, margin_right);
    gtk_layer_set_keyboard_mode(win, GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
    LOG("layer window configured");
}

// ---------- Components ----------

static void create_taskbar(GtkApplication* app) {
    LOG("creating taskbar (wayland=%d)", (int)use_wayland);
    taskbar = gtk_application_window_new(app);
    if (!taskbar) { LOG("FAILED to create taskbar window"); return; }
    gtk_window_set_title(GTK_WINDOW(taskbar), "ElvonOS Taskbar");
    gtk_window_set_decorated(GTK_WINDOW(taskbar), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(taskbar), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(taskbar), 1280, 48);
    gtk_widget_add_css_class(taskbar, "taskbar");

    layer_window(GTK_WINDOW(taskbar),
                 GTK_LAYER_SHELL_LAYER_BOTTOM,
                 FALSE, TRUE, TRUE, TRUE,
                 48, 0, 0, 0, 0);

    gtk_application_add_window(app, GTK_WINDOW(taskbar));

    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_hexpand(box, TRUE);
    gtk_widget_set_halign(box, GTK_ALIGN_FILL);
    gtk_widget_set_margin_start(box, 10);
    gtk_widget_set_margin_end(box, 10);
    gtk_widget_set_margin_top(box, 6);
    gtk_widget_set_margin_bottom(box, 6);
    gtk_window_set_child(GTK_WINDOW(taskbar), box);

    GtkWidget* start_btn = gtk_button_new_with_label("Start");
    gtk_widget_add_css_class(start_btn, "taskbar-start");
    gtk_widget_set_margin_start(start_btn, 4);
    gtk_widget_set_margin_end(start_btn, 4);
    g_signal_connect(start_btn, "clicked", G_CALLBACK(on_start_clicked), nullptr);
    gtk_box_append(GTK_BOX(box), start_btn);

    const char* apps[][2] = {
        {"\uf120", "foot"},
        {"\uf07b", "thunar"},
        {"\uf17b", "waydroid"},
    };
    for (auto& app_pair : apps) {
        GtkWidget* btn = gtk_button_new_with_label(app_pair[0]);
        gtk_widget_add_css_class(btn, "taskbar-app");
        gtk_widget_set_margin_start(btn, 2);
        gtk_widget_set_margin_end(btn, 2);
        g_signal_connect(btn, "clicked", G_CALLBACK(on_quick_launch), (gpointer)app_pair[1]);
        gtk_box_append(GTK_BOX(box), btn);
    }

    GtkWidget* separator = gtk_separator_new(GTK_ORIENTATION_VERTICAL);
    gtk_widget_set_margin_start(separator, 8);
    gtk_widget_set_margin_end(separator, 8);
    gtk_widget_set_valign(separator, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(box), separator);

    GtkWidget* spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_hexpand(spacer, TRUE);
    gtk_box_append(GTK_BOX(box), spacer);

    GtkWidget* right = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_widget_set_halign(right, GTK_ALIGN_END);
    gtk_widget_set_valign(right, GTK_ALIGN_CENTER);

    GtkWidget* vol = gtk_button_new_with_label("\uf028");
    gtk_widget_add_css_class(vol, "tray-btn");
    gtk_box_append(GTK_BOX(right), vol);

    GtkWidget* bat = gtk_button_new_with_label("\uf240");
    gtk_widget_add_css_class(bat, "tray-btn");
    gtk_box_append(GTK_BOX(right), bat);

    GtkWidget* net = gtk_button_new_with_label("\uf1eb");
    gtk_widget_add_css_class(net, "tray-btn");
    gtk_box_append(GTK_BOX(right), net);

    GtkWidget* clock = gtk_label_new("00:00");
    gtk_widget_add_css_class(clock, "clock-label");
    gtk_box_append(GTK_BOX(right), clock);
    gtk_box_append(GTK_BOX(box), right);

    g_timeout_add_seconds(1, on_clock_tick, clock);
    gtk_window_present(GTK_WINDOW(taskbar));
    LOG("taskbar presented");
}

static void create_startmenu(GtkApplication* app) {
    LOG("creating startmenu (wayland=%d)", (int)use_wayland);
    startmenu = gtk_application_window_new(app);
    if (!startmenu) { LOG("FAILED to create startmenu window"); return; }
    gtk_window_set_title(GTK_WINDOW(startmenu), "Startmenü");
    gtk_window_set_decorated(GTK_WINDOW(startmenu), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(startmenu), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(startmenu), 640, 560);
    gtk_widget_add_css_class(startmenu, "startmenu");

    layer_window(GTK_WINDOW(startmenu),
                 GTK_LAYER_SHELL_LAYER_TOP,
                 FALSE, FALSE, FALSE, FALSE,
                 -1, 56, 0, 0, 0);

    gtk_application_add_window(app, GTK_WINDOW(startmenu));

    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_margin_start(box, 16);
    gtk_widget_set_margin_end(box, 16);
    gtk_widget_set_margin_top(box, 16);
    gtk_widget_set_margin_bottom(box, 16);
    gtk_window_set_child(GTK_WINDOW(startmenu), box);

    GtkWidget* search = gtk_search_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(search), "Suchen & Apps");
    gtk_widget_add_css_class(search, "startmenu-search");
    gtk_widget_set_hexpand(search, TRUE);
    gtk_box_append(GTK_BOX(box), search);

    GtkWidget* scrolled = gtk_scrolled_window_new();
    gtk_widget_set_hexpand(scrolled, TRUE);
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_box_append(GTK_BOX(box), scrolled);

    GtkWidget* grid = gtk_grid_new();
    gtk_grid_set_column_spacing(GTK_GRID(grid), 16);
    gtk_grid_set_row_spacing(GTK_GRID(grid), 16);
    gtk_widget_set_halign(grid, GTK_ALIGN_START);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), grid);

    g_idle_add(on_startmenu_populate, grid);

    GtkWidget* sys = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_widget_set_halign(sys, GTK_ALIGN_END);
    gtk_widget_set_margin_top(sys, 12);
    gtk_box_append(GTK_BOX(box), sys);

    GtkWidget* restart = gtk_button_new_with_label("Neustart");
    gtk_widget_add_css_class(restart, "system-btn");
    GtkWidget* power = gtk_button_new_with_label("Herunterfahren");
    gtk_widget_add_css_class(power, "system-btn");
    gtk_box_append(GTK_BOX(sys), restart);
    gtk_box_append(GTK_BOX(sys), power);
    g_signal_connect(power, "clicked", G_CALLBACK(on_power), nullptr);
    g_signal_connect(restart, "clicked", G_CALLBACK(on_restart), nullptr);
}

static void create_desktop_icons(GtkApplication* app) {
    LOG("creating desktop icons (wayland=%d)", (int)use_wayland);
    desktop_icons = gtk_application_window_new(app);
    if (!desktop_icons) { LOG("FAILED to create desktop icons window"); return; }
    gtk_window_set_title(GTK_WINDOW(desktop_icons), "Desktop Icons");
    gtk_window_set_decorated(GTK_WINDOW(desktop_icons), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(desktop_icons), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(desktop_icons), 1280, 720);
    gtk_widget_add_css_class(desktop_icons, "desktop-icons");

    layer_window(GTK_WINDOW(desktop_icons),
                 GTK_LAYER_SHELL_LAYER_BACKGROUND,
                 TRUE, TRUE, TRUE, TRUE,
                 -1, 56, 0, 20, 20);

    gtk_application_add_window(app, GTK_WINDOW(desktop_icons));

    GtkWidget* scrolled = gtk_scrolled_window_new();
    gtk_window_set_child(GTK_WINDOW(desktop_icons), scrolled);

    GtkWidget* grid = gtk_grid_new();
    gtk_grid_set_column_spacing(GTK_GRID(grid), 24);
    gtk_grid_set_row_spacing(GTK_GRID(grid), 24);
    gtk_widget_set_halign(grid, GTK_ALIGN_START);
    gtk_widget_set_valign(grid, GTK_ALIGN_START);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), grid);

    g_idle_add(on_desktop_refresh, grid);
}

static void create_widgets(GtkApplication* app) {
    LOG("creating widgets (wayland=%d)", (int)use_wayland);
    widgets = gtk_application_window_new(app);
    if (!widgets) { LOG("FAILED to create widgets window"); return; }
    gtk_window_set_title(GTK_WINDOW(widgets), "Widgets");
    gtk_window_set_decorated(GTK_WINDOW(widgets), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(widgets), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(widgets), 180, 200);
    gtk_widget_add_css_class(widgets, "widgets");

    layer_window(GTK_WINDOW(widgets),
                 GTK_LAYER_SHELL_LAYER_TOP,
                 TRUE, FALSE, FALSE, TRUE,
                 -1, 60, 0, 0, 20);

    gtk_application_add_window(app, GTK_WINDOW(widgets));

    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_margin_start(box, 14);
    gtk_widget_set_margin_end(box, 14);
    gtk_widget_set_margin_top(box, 14);
    gtk_widget_set_margin_bottom(box, 14);
    gtk_window_set_child(GTK_WINDOW(widgets), box);

    GtkWidget* clock_lbl = gtk_label_new("00:00");
    gtk_widget_add_css_class(clock_lbl, "widget-label");
    gtk_widget_set_halign(clock_lbl, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(box), clock_lbl);

    GtkWidget* bat_lbl = gtk_label_new("Akku N/A");
    gtk_widget_add_css_class(bat_lbl, "widget-label");
    gtk_widget_set_halign(bat_lbl, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(box), bat_lbl);

    GtkWidget* cpu_lbl = gtk_label_new("CPU --%");
    gtk_widget_add_css_class(cpu_lbl, "widget-label");
    gtk_widget_set_halign(cpu_lbl, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(box), cpu_lbl);

    GtkWidget* mem_lbl = gtk_label_new("RAM --%");
    gtk_widget_add_css_class(mem_lbl, "widget-label");
    gtk_widget_set_halign(mem_lbl, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(box), mem_lbl);

    GtkWidget* labels[4] = {clock_lbl, bat_lbl, cpu_lbl, mem_lbl};
    on_widgets_tick(labels);
    g_timeout_add_seconds(1, on_widgets_tick, labels);
}

static void on_signal_startmenu(int sig) {
    (void)sig;
    LOG("SIGUSR1: toggle startmenu");
    startmenu_visible = !startmenu_visible;
    if (startmenu_visible && startmenu)
        gtk_window_present(GTK_WINDOW(startmenu));
    else if (!startmenu_visible && startmenu)
        gtk_window_close(GTK_WINDOW(startmenu));
}

static void on_signal_widgets(int sig) {
    (void)sig;
    LOG("SIGUSR2: toggle widgets");
    widgets_visible = !widgets_visible;
    if (widgets_visible && widgets)
        gtk_window_present(GTK_WINDOW(widgets));
    else if (!widgets_visible && widgets)
        gtk_window_close(GTK_WINDOW(widgets));
}

// ---------- Main ----------

static void on_activate(GtkApplication* app, gpointer user_data) {
    LOG("=== ElvonOS Desktop Shell starting (wayland=%d) ===", (int)use_wayland);
    apply_css();
    create_taskbar(app);
    create_startmenu(app);
    create_desktop_icons(app);
    create_widgets(app);

    signal(SIGUSR1, on_signal_startmenu);
    signal(SIGUSR2, on_signal_widgets);

    LOG("=== ElvonOS Desktop Shell ready ===");
}

int main(int argc, char** argv) {
    const char* home = g_getenv("HOME");
    std::string logpath = (home ? home : "/tmp") + std::string("/elvonos-shell.log");
    shell_log.open(logpath, std::ios::out | std::ios::trunc);
    LOG("ElvonOS Shell PID=%d, HOME=%s, log=%s", getpid(), home ? home : "(null)", logpath.c_str());
    const char* wl_display = g_getenv("WAYLAND_DISPLAY");
    LOG("Wayland display: %s", wl_display ? wl_display : "(null)");

    if (wl_display && wl_display[0] != '\0') {
        use_wayland = TRUE;
        LOG("Mode: Wayland + LayerShell (real hardware)");
    } else {
        use_wayland = FALSE;
        LOG("Mode: QEMU fallback (no Wayland display, plain GTK4 windows)");
        LOG("       Desktop will render in normal GTK4 windows.");
    }

    GdkDisplay* gdk_display = gdk_display_get_default();
    if (!gdk_display) {
        LOG("FATAL: No GDK display available. Cannot initialize GTK4.");
        if (shell_log.is_open()) shell_log.close();
        return 1;
    }

    GtkApplication* app = gtk_application_new("org.elvonos.shell", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), nullptr);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    if (shell_log.is_open()) shell_log.close();
    return status;
}