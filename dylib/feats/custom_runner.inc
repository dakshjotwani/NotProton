// steamplay-mac fork: custom Wine runners. Included at the end of compat.c so it can use
// the tool list's internals while compat.c itself carries only the include and one call.

// Runners under runners/ whose build ID starts with this are a custom Wine, not CrossOver.
#define NP_CUSTOM_BUILD_PREFIX "wine-"

// A custom Wine runner is runners/wine-<name>/ with a runner.json in it. It is not
// CrossOver, so the app does not list it; each one gets the tool notproton-wine-<name>.
// runner.json may give "display_name"; anything else in it is for the run script.
static int read_custom_display(const char *runner, const char *name, char *out, size_t size) {
    char path[768];
    snprintf(path, sizeof(path), "%s/runner.json", runner);
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    char buf[4096];
    size_t got = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[got] = '\0';

    snprintf(out, size, "Wine (%s)", name);
    const char *at = strstr(buf, "\"display_name\"");
    if (at && (at = strchr(at + 14, ':')) && (at = strchr(at, '"'))) {
        const char *end = strchr(++at, '"');
        if (end && end > at && (size_t)(end - at) < size) {
            char display[96];
            snprintf(display, sizeof(display), "%.*s", (int)(end - at), at);
            if (is_display(display)) snprintf(out, size, "%s", display);
        }
    }
    return 1;
}

int np_compat_load_custom_runners(const char *runners_dir, const char *tools_dir) {
    DIR *d = opendir(runners_dir);
    if (!d) return 0;
    int added = 0;
    struct dirent *e;
    while ((e = readdir(d))) {
        const char *build = e->d_name;
        if (strncmp(build, NP_CUSTOM_BUILD_PREFIX, strlen(NP_CUSTOM_BUILD_PREFIX)) != 0
            || !build[strlen(NP_CUSTOM_BUILD_PREFIX)] || !np_is_build_id(build))
            continue;

        tool_entry_t entry;
        memset(&entry, 0, sizeof(entry));
        if ((size_t)snprintf(entry.name, sizeof(entry.name), TOOL_DIR_NAME "-%s", build)
            >= sizeof(entry.name))
            continue;
        if (listed_tool(entry.name)) continue;

        char runner[640];
        snprintf(runner, sizeof(runner), "%s/%s", runners_dir, build);
        if (!read_custom_display(runner, build + strlen(NP_CUSTOM_BUILD_PREFIX),
                                 entry.display, sizeof(entry.display)))
            continue;
        snprintf(entry.build, sizeof(entry.build), "%s", build);
        snprintf(entry.flavor, sizeof(entry.flavor), "rosetta");
        snprintf(entry.dir, sizeof(entry.dir), "%s/%s", tools_dir, entry.name);

        if (g_tool_count == g_tool_cap) {
            int cap = g_tool_cap ? g_tool_cap * 2 : 8;
            tool_entry_t *grown = realloc(g_tools, (size_t)cap * sizeof(*grown));
            if (!grown) break;
            g_tools = grown;
            g_tool_cap = cap;
        }
        g_tools[g_tool_count++] = entry;
        g_tool_list_present = 1;
        added++;
        NP_LOG("np_compat_load_custom_runners: %s runs custom Wine %s (%s)", entry.name,
               build, entry.display);
    }
    closedir(d);
    return added;
}
