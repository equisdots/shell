// ═══════════════════════════════════════════════════════════════════════════
// davinci · ui — DavinciPicker
//
// The wallpaper picker root. It owns the STATE and LOGIC (models, filters,
// focus, search/apply orchestration) and composes the view components:
//   - views/ → one modular presentation per view mode (coverflow, grid,
//     library, stage, palette), sharing the same model and apply path
//   - components/filter/DavinciFilterBar → top bar (status, monitors, controls,
//     color chips, search)
// Pure helpers live in lib/ (constants.js, color.js) and the headless engine
// in ../kernel/. Components receive the picker root as `ctx` plus the Colors
// instance as `theme`.
// ═══════════════════════════════════════════════════════════════════════════
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import Qt.labs.folderlistmodel
import QtMultimedia
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../../core/Personalization.js" as Personalization
import "../../bar"
import "lib/constants.js" as C
import "components"
import "components/grid"
import "components/filter"
import "views"
import "lib/color.js" as Color

Item {
    id: window
    width: Screen.width

    Caching { id: paths }
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    // Resolve the kernel CLI. The probe runs once on open and leaves the
    // optimistic ~/.local/bin/davinci path in place while it resolves.
    property string cli: Quickshell.env("HOME") + "/.local/bin/davinci"

    Process {
        id: cliProbe
        command: ["bash", "-c",
            "for p in \"$HOME/.local/bin/davinci\" " +
            "\"$HOME/.local/share/equisdots/davinci/davinci.sh\"; do " +
            "[ -x \"$p\" ] && { printf '%s\\n' \"$p\"; exit 0; }; done; true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let p = this.text.trim();
                if (p !== "") window.cli = p;
            }
        }
    }

    function resolveCli() {
        let env = Quickshell.env("DAVINCI_CLI") || "";
        if (env !== "") {
            window.cli = env;
            return;
        }
        cliProbe.running = true;
    }

    function cliPath() {
        return window.cli;
    }

    Colors { id: _theme }

    // ── Personalization-backed options ─────────────────────────────────────
    // Everything below is stored in settings.json under the "davinci" section
    // and is safe to edit from the main settings panel. `Config.rev` is read
    // so bindings refresh after an in-place settings write.
    readonly property var davinci: (Config.rev, Personalization.normalize("davinci", Config.rawSettings.davinci))
    readonly property string viewMode: {
        let v = String(davinci.viewMode || "coverflow");
        return ["coverflow", "grid", "library", "stage", "palette"].indexOf(v) !== -1
            ? v : "coverflow";
    }
    readonly property int gridColumns: Math.max(2, Math.min(8, Number(davinci.gridColumns) || 4))
    readonly property bool showFilterBar: davinci.showFilterBar !== false
    readonly property bool showStatus: davinci.showStatus !== false
    readonly property bool showMonitors: davinci.showMonitors !== false
    readonly property bool showColorFilters: davinci.showColorFilters !== false
    readonly property bool showTransition: davinci.showTransition !== false
    readonly property bool showSlideshow: davinci.showSlideshow !== false
    readonly property bool showPalettePreview: davinci.showPalettePreview !== false
    readonly property bool showSearch: davinci.showSearch !== false
    readonly property bool showKeys: davinci.showKeys !== false
    readonly property bool showFilmstrip: davinci.showFilmstrip !== false
    readonly property bool showSidebar: davinci.showSidebar !== false
    readonly property bool showInspector: davinci.showInspector !== false
    readonly property bool showMetadata: davinci.showMetadata !== false
    readonly property bool showShortcuts: davinci.showShortcuts !== false

    property bool _loadingPrefs: false
    property bool _settingsReady: false

    function davinciRaw() {
        let raw = Config.rawSettings.davinci;
        return (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    }

    function saveDavinciOption(key, value) {
        if (_loadingPrefs) return;
        let raw = Object.assign({}, davinciRaw());
        raw[key] = value;
        Config.setSetting("davinci", raw);
    }

    function applyPersonalization() {
        let raw = davinciRaw();
        let cfg = Personalization.normalize("davinci", raw);
        _loadingPrefs = true;
        gridOrientation = cfg.gridOrientation === "vertical" ? "vertical" : "horizontal";
        cardShape = C.SHAPES.indexOf(cfg.cardShape) !== -1 ? cfg.cardShape : "rect";
        roundedThumbs = cfg.roundedThumbs !== false;
        transition = cfg.transition || "random";
        slideshowInterval = Math.max(60, Math.min(3600, Number(cfg.slideshowInterval) || 300));
        searchSource = cfg.searchSource || "ddg";
        searchKind = cfg.searchKind === "video" ? "video" : "image";
        favoriteNames = Array.isArray(raw.favorites) ? raw.favorites.slice() : [];
        _loadingPrefs = false;
        _settingsReady = true;
    }

    property string widgetArg: ""
    property string targetWallName: ""
    property bool initialFocusSet: false
    property int visibleItemCount: -1
    property int scrollAccum: 0
    property real scrollThreshold: window.s(300)

    property string currentFilter: "All"
    property string _lastFilter: "All"
    property string searchQuery: ""
    property bool isOnlineSearch: false
    property bool isSearchPaused: false
    property bool hasSearched: false
    property var colorMap: ({})
    property int cacheVersion: 0

    property bool isDownloadingWallpaper: false
    property string currentDownloadName: ""

    property bool isApplying: false
    property bool isMonitorSelectorOpen: false
    // Set by the search component while its TextInput has focus (Return shortcut).
    property bool searchInputFocused: false

    // Separate flag so add-animations fire on new arrivals
    // even before the first focus snap has happened
    property bool allowAddAnimation: false

    Timer {
        id: applyUnlockTimer
        interval: 250
        onTriggered: window.isApplying = false
    }

    property bool isStartup: localFolderModel.status === FolderListModel.Loading || srcModel.status === FolderListModel.Loading
    property bool isReady: visible && localFolderModel.status === FolderListModel.Ready
    property bool isSearchActive: window.currentFilter === "Search" && window.hasSearched && searchFolderModel.status === FolderListModel.Loading

    property string lastSearchName: ""
    property bool isModelChanging: false
    property bool searchIndexRestored: false

    property bool isScrollingBlocked: window.currentFilter === "Search" && window.hasSearched && window.isSearchActive && !window.isSearchPaused
    property bool jumpToLastOnFilterChange: false

    readonly property var filterData: C.FILTERS
    readonly property var transitions: C.TRANSITIONS

    ListModel { id: monitorModel }

    Process {
        id: monitorProc
        command: Compositor.monitorListCommand
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let response = this.text;

                if (response && response.trim().length > 0) {
                    try {
                        var monitors = Compositor.monitorsFromOutput(response);
                        monitorModel.clear();
                        for (var i = 0; i < monitors.length; i++) {
                            monitorModel.append({ "name": monitors[i].name, "selected": true });
                        }
                    } catch (e) {}
                }
            }
        }
    }

    function loadMonitors() {
        monitorProc.running = true;
    }

    // Slideshow: pregunta al kernel si el daemon está corriendo (al abrir).
    Process {
        id: slideshowStatusProc
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let on = this.text.trim() === "running";
                window.slideshowOn = on;
            }
        }
    }

    // API keys: el kernel es la fuente (keys list → NAME|label|where|0-1).
    Process {
        id: keysListProc
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let rows = [];
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let p = lines[i].split("|");
                    if (p.length >= 4) {
                        rows.push({ name: p[0], label: p[1], where: p[2], set: p[3] === "1" });
                    }
                }
                window.providerKeys = rows;
            }
        }
    }

    Timer { id: keysRefreshTimer; interval: 400; onTriggered: window.refreshProviderKeys() }

    function refreshProviderKeys() {
        keysListProc.command = [window.cliPath(), "keys", "list"];
        keysListProc.running = true;
    }

    function saveProviderKey(name, value) {
        if (!name || value.trim() === "") return;
        Quickshell.execDetached([window.cliPath(), "keys", "set", name, value.trim()]);
        keysRefreshTimer.restart();
    }

    function toggleKeysPanel() {
        window.keysPanelOpen = !window.keysPanelOpen;
        if (window.keysPanelOpen) window.refreshProviderKeys();
    }

    function getMonitorOutputs() {
        if (monitorModel.count <= 1) return "all";

        let selected = [];
        for (let i = 0; i < monitorModel.count; i++) {
            if (monitorModel.get(i).selected) {
                selected.push(monitorModel.get(i).name);
            }
        }

        if (selected.length === 0) return "none";
        if (selected.length === monitorModel.count) return "all";

        return selected.join(",");
    }

    // Apply a wallpaper through the davinci CLI (kernel layer): the UI
    // decides WHAT to apply; download/convert/cache/apply live in kernel/.
    function applyWallpaper(safeFileName, isVideo) {
        if (!safeFileName || window.isApplying) return;

        let outputs = window.getMonitorOutputs();
        if (outputs === "none") return;

        window.isApplying = true;
        applyUnlockTimer.restart();
        window.targetWallName = safeFileName;

        let cli = window.cliPath();
        let transition = window.transition;

        if (window.currentFilter === "Search" && window.hasSearched) {
            let destFile = window.srcDir + "/" + safeFileName;
            let finalThumb = decodeURIComponent(window.thumbDir.replace("file://", "")) + "/" + safeFileName;

            if (window.isDownloaded(safeFileName)) {
                Quickshell.execDetached([cli, "set", destFile,
                                         "--monitors", outputs,
                                         "--transition", transition,
                                         "--notify"]);
            } else {
                window.isDownloadingWallpaper = true;
                window.currentDownloadName = safeFileName;
                let tempThumb = decodeURIComponent(window.searchDir.replace("file://", "")) + "/" + safeFileName;
                let mapFile = paths.getCacheDir("wallpaper_picker") + "/search_map.txt";
                Quickshell.execDetached([cli, "fetch",
                                         "--name", safeFileName,
                                         "--map", mapFile,
                                         "--dest", destFile,
                                         "--thumb-in", tempThumb,
                                         "--thumb-out", finalThumb,
                                         "--monitors", outputs,
                                         "--transition", transition]);
            }
            return;
        }

        let originalFile = window.srcDir + "/" + window.getCleanName(safeFileName);
        let thumbFile = paths.getCacheDir("wallpaper_picker") + "/thumbs/" + safeFileName;
        let args = [cli, "set", originalFile,
                    "--monitors", outputs,
                    "--transition", transition];
        if (isVideo) args.push("--video", "--thumb", thumbFile);
        Quickshell.execDetached(args);
    }

    Settings {
        id: searchState
        location: "file://" + Quickshell.statePath("davinci-search.ini")
        category: "QS_Davinci"
        property string query: ""
        property bool searched: false
        property string lastName: ""
    }

    onIsSearchPausedChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + (isSearchPaused ? "pause" : "run") + "' > " + paths.getRunDir("wallpaper_picker") + "/ddg_search_control"]);
    }

    onVisibleChanged: {
        if (!visible) {
            window.initialFocusSet = false;
            window.allowAddAnimation = false;
            window.searchIndexRestored = false;
            window.isApplying = false;
            window.isMonitorSelectorOpen = false;

            if (window.hasSearched) {
                window.isSearchPaused = true;
            }
        } else {
            window.isFilterAnimating = true;
            filterAnimationTimer.restart();

            if (window.currentFilter !== "Search") {
                window.applyFilters(true);
            } else if (window.hasSearched) {
                window.searchIndexRestored = false;
                window.isSearchPaused = true;
                window.trySearchFocus();
                window.syncSearchModel();
            }
        }
    }

    property bool isLoading: localFolderModel.status === FolderListModel.Loading ||
                             srcModel.status === FolderListModel.Loading ||
                             (window.currentFilter === "Search" && searchFolderModel.status === FolderListModel.Loading)

    property bool showSpinner: window.isDownloadingWallpaper ||
                               (window.currentFilter === "Search" && window.hasSearched && !window.isSearchPaused) ||
                               (window.currentFilter !== "Search" && window.isLoading)

    property string currentNotification: {
        if (window.isDownloadingWallpaper) return "Downloading wallpaper...";

        if (window.currentFilter === "Search") {
            if (!window.hasSearched) return "Type something to search...";
            if (window.isSearchPaused) return "Search Paused";
            if (window.visibleItemCount === 0) return "Searching " + window.sourceLabel(window.searchSource) + " (FHD+)...";
            return "Generating thumbnails...";
        }

        if (isLoading) return "Generating thumbnails...";
        if (window.visibleItemCount === 0) return "No wallpapers found";

        if (window.currentFilter === "All") return "";
        if (window.currentFilter === "Video") return "Videos";

        return window.currentFilter;
    }

    property bool showNotification: !window.isStartup && currentNotification !== ""

    // Thumb name → source path relative to the wallpaper dir. Prefixes:
    // "000_" video, "scn_" interactive scene (thumb is scn_<dir>.jpg); "__"
    // is the flattened separator for nested paths ("a/b.jpg" → "a__b.jpg").
    function getCleanName(name) {
        if (!name) return "";
        let clean = String(name);
        if (clean.startsWith("scn_")) {
            clean = clean.substring(4).replace(/\.jpg$/i, "");
        } else if (clean.startsWith("000_")) {
            clean = clean.substring(4);
        }
        return clean.split("__").join("/");
    }

    function isDownloaded(name) {
        if (!name) return false;
        for (let i = 0; i < srcModel.count; i++) {
            if (srcModel.get(i, "fileName") === name) return true;
        }
        return false;
    }

    // ── View modes: setters + persistence in settings.json ─────────────────
    function saveViewPrefs() {
        if (window._loadingPrefs) return;
        let raw = Object.assign({}, window.davinciRaw());
        raw.gridOrientation = window.gridOrientation;
        raw.cardShape = window.cardShape;
        raw.favorites = window.favoriteNames.slice();
        Config.setSetting("davinci", raw);
    }

    function setOrientation(v) {
        if (v === "horizontal" || v === "vertical") {
            window.gridOrientation = v;
            window.saveViewPrefs();
        }
    }

    function setCardShape(v) {
        if (C.SHAPES.indexOf(v) !== -1) {
            window.cardShape = v;
            window.saveViewPrefs();
        }
    }

    // ── Favorites ──────────────────────────────────────────────────────────
    function isFavorite(name) {
        if (!name) return false;
        return window.favoriteNames.indexOf(String(name)) !== -1;
    }

    function toggleFavorite(name) {
        if (!name || window.isApplying) return;
        let s = String(name);
        let idx = window.favoriteNames.indexOf(s);
        if (idx !== -1) {
            window.favoriteNames.splice(idx, 1);
        } else {
            window.favoriteNames.push(s);
        }
        window.saveViewPrefs();
        // Re-evalúa los filtros de las tarjetas y el contador visible.
        window.cacheVersion++;
        window.updateVisibleCount();
    }

    // ── Slideshow ───────────────────────────────────────────────────────────
    function refreshSlideshowState() {
        let cli = window.cliPath();
        slideshowStatusProc.command = [cli, "slideshow", "status"];
        slideshowStatusProc.running = true;
    }

    function toggleSlideshow() {
        if (window.isApplying) return;
        let cli = window.cliPath();
        let action = window.slideshowOn ? "stop" : "start " + window.slideshowInterval;
        Quickshell.execDetached(["bash", "-c", '"' + cli + '" slideshow ' + action]);
        window.slideshowOn = !window.slideshowOn;
    }

    // ── Delete (with confirmation) ──────────────────────────────────────────
    function requestDelete() {
        if (window.isApplying || window.confirmOpen) return;
        if (window.currentFilter === "Search") return; // resultados de búsqueda: no se borran
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (viewHost.currentIndex < 0 || viewHost.currentIndex >= targetModel.count) return;
        let fname = targetModel.get(viewHost.currentIndex).fileName;
        if (!fname) return;
        window.confirmTarget = String(fname);
        window.confirmOpen = true;
    }

    function confirmDelete() {
        window.confirmOpen = false;
        let name = window.confirmTarget;
        window.confirmTarget = "";
        let cli = window.cliPath();
        Quickshell.execDetached([cli, "rm", window.getCleanName(name)]);
    }

    function cancelDelete() {
        window.confirmOpen = false;
        window.confirmTarget = "";
    }

    // Import is CLI-only (davinci.sh import); the UI does not
    // expone para no depender de herramientas externas (rofi/zenity) que
    // rompen la estética del shell.

    // ── Search: next page of results (keeps the current cache) ──────────────
    function loadMoreSearch() {
        if (!window.hasSearched || window.searchQuery === "") return;
        window.isSearchPaused = false;
        let cli = window.cliPath();
        Quickshell.execDetached([cli, "search", "--continue", "--source", window.searchSource, window.searchQuery]);
    }

    onWidgetArgChanged: {
        if (widgetArg !== "") {
            targetWallName = widgetArg;
            initialFocusSet = false;
            tryFocus();
        }
    }

    function executeFocusRestore(targetIndex, isSearchRestore, requirePositioning) {
        let targetModel = window.getModelForFilter(window.currentFilter);

        if (targetIndex !== -1 && targetIndex < targetModel.count) {
            window.isModelChanging = true;

            viewHost.setCurrentIndex(targetIndex);

            // Position AFTER the index is current: the first focus can arrive
            // before the view has received its model, in which case an earlier
            // centerView() is a no-op and the first card would stay clipped at
            // the leading edge.
            if (requirePositioning) {
                viewHost.forceLayout();
                viewHost.centerView(targetIndex);
            }

            if (isSearchRestore) {
                window.searchIndexRestored = true;
            }

            window.isModelChanging = false;
            window.initialFocusSet = true;

            // Allow add-animations for future incremental arrivals
            // Use a short delay so the initial snap itself isn't animated
            allowAddAnimationTimer.restart();
        } else if (isSearchRestore) {
            window.searchIndexRestored = true;
        }
    }

    Timer {
        id: allowAddAnimationTimer
        interval: 600
        onTriggered: window.allowAddAnimation = true
    }

    function tryFocus() {
        if (initialFocusSet) return;

        if (localProxyModel.count > 0) {
            let foundIndex = -1;
            let cleanTarget = window.getCleanName(targetWallName);

            if (cleanTarget !== "") {
                for (let i = 0; i < localProxyModel.count; i++) {
                    let fname = localProxyModel.get(i).fileName || "";
                    if (window.getCleanName(fname) === cleanTarget) {
                        foundIndex = i;
                        break;
                    }
                }
            }

            let finalIndex = foundIndex !== -1 ? foundIndex : 0;
            window.executeFocusRestore(finalIndex, false, true);
        }
    }

    function trySearchFocus() {
        if (window.searchIndexRestored || searchProxyModel.count === 0) return;

        if (window.lastSearchName === "") {
            window.searchIndexRestored = true;
            return;
        }

        for (let i = 0; i < searchProxyModel.count; i++) {
            let fname = searchProxyModel.get(i).fileName || "";
            if (fname === window.lastSearchName) {
                window.executeFocusRestore(i, true, true);
                return;
            }
        }

        if (searchFolderModel.status === FolderListModel.Ready && searchProxyModel.count === searchFolderModel.count) {
            window.searchIndexRestored = true;
        }
    }

    function getModelForFilter(filter) {
        return filter === "Search" ? searchProxyModel : localProxyModel;
    }

    function updateVisibleCount() {
        let targetModel = window.getModelForFilter(window.currentFilter);

        if (!targetModel || targetModel.count === 0) {
            window.visibleItemCount = 0;
            return;
        }
        let count = 0;
        for (let i = 0; i < targetModel.count; i++) {
            let fname = targetModel.get(i).fileName || "";
            let isVid = fname.startsWith("000_");
            if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                count++;
            }
        }
        window.visibleItemCount = count;
    }

    // Start a DuckDuckGo search (called by the search component on submit).
    function submitSearch(query) {
        window.isModelChanging = true;
        searchProxyModel.clear();
        window.lastSearchName = "";
        searchState.lastName = "";

        if (window.currentFilter === "Search") {
            viewHost.setCurrentIndex(0);
            viewHost.centerView(0);
        }
        window.isModelChanging = false;

        window.searchIndexRestored = true;
        window.isOnlineSearch = true;
        window.hasSearched = true;

        window.visibleItemCount = 0;

        searchState.searched = true;
        searchState.query = query;

        window.isSearchPaused = false;
        window.searchQuery = query;

        // The CLI stops the previous search, clears its cache and starts the new one.
        let cli = window.cliPath();
        Quickshell.execDetached([cli, "search", "--source", window.searchSource, window.searchQuery]);
    }

    readonly property string homeDir: "file://" + Quickshell.env("HOME")
    readonly property string thumbDir: "file://" + paths.getCacheDir("wallpaper_picker") + "/thumbs"
    readonly property string searchDir: "file://" + paths.getCacheDir("wallpaper_picker") + "/search_thumbs"
    readonly property string srcDir: Config.wallpaperDir

    // User-selected transition (cycles via the header button; "random" picks one).
    property string transition: "random"
    // Thumbnail corners: rounded vs square.
    property bool roundedThumbs: true
    property int thumbRadius: roundedThumbs ? Theme.radiusMd : 0

    // ── View modes (persisted in settings.json under "davinci")
    property string gridOrientation: "horizontal"
    property string cardShape: "rect"
    readonly property var shapeOrder: C.SHAPES
    property bool slideshowOn: false
    property int slideshowInterval: 300
    property var favoriteNames: []

    // Search provider (kernel providers/: ddg | wallhaven | pexels | pixabay).
    property string searchSource: "ddg"
    property string searchKind: "image"   // image | video
    readonly property var searchSources: C.SEARCH_SOURCES

    onTransitionChanged: if (_settingsReady && !_loadingPrefs) saveDavinciOption("transition", transition)
    onSlideshowIntervalChanged: if (_settingsReady && !_loadingPrefs) saveDavinciOption("slideshowInterval", slideshowInterval)
    onSearchSourceChanged: if (_settingsReady && !_loadingPrefs) saveDavinciOption("searchSource", searchSource)
    onSearchKindChanged: if (_settingsReady && !_loadingPrefs) saveDavinciOption("searchKind", searchKind)
    onRoundedThumbsChanged: if (_settingsReady && !_loadingPrefs) saveDavinciOption("roundedThumbs", roundedThumbs)

    // API keys de proveedores (panel de la tuerca; fuente: kernel `keys list`).
    property bool keysPanelOpen: false
    property var providerKeys: []
    readonly property var activeSearchSources: window.searchSources.filter(function(s) {
        return s.kind === window.searchKind;
    })

    function sourceLabel(id) {
        for (let i = 0; i < window.searchSources.length; i++) {
            if (window.searchSources[i].id === id) return window.searchSources[i].label;
        }
        return String(id).toUpperCase();
    }

    function sourceIsOfKind(id, kind) {
        for (let i = 0; i < window.searchSources.length; i++) {
            let s = window.searchSources[i];
            if (s.id === id) return s.kind === kind;
        }
        return false;
    }

    // Abre la búsqueda en modo imagen o vídeo (elige fuente por defecto).
    function openSearch(kind) {
        window.searchKind = kind;
        if (!window.sourceIsOfKind(window.searchSource, kind)) {
            window.searchSource = kind === "video" ? "pexels" : "ddg";
        }
        window.currentFilter = "Search";
    }

    // ── Delete confirmation state ────────────────────────────────────────────
    property bool confirmOpen: false
    property string confirmTarget: ""

    readonly property real itemWidth: window.s(400)
    readonly property real itemHeight: window.s(420)
    readonly property real borderWidth: window.s(3)
    readonly property real spacing: window.s(10)
    readonly property real skewFactor: -0.35

    // Keep the picker tools visually independent from the wallpapers: the
    // floating filter bar sits on the wallpaper, and the lens + grid begin
    // below it with a small breathing gap.
    readonly property real toolbarClearance: Compositor.isNiri ? 0 : (window.s(40) + window.s(56) + window.s(12))

    Timer {
        id: scrollThrottle
        interval: 150
    }

    property bool isFilterAnimating: false
    Timer {
        id: filterAnimationTimer
        interval: 800
        onTriggered: window.isFilterAnimating = false
    }

    property bool isItemAnimating: false
    Timer {
        id: itemAnimationTimer
        interval: 500
        onTriggered: window.isItemAnimating = false
    }

    function checkItemMatchesFilter(fileName, isVid, cv, filter) {
        if (filter === "Search") return true;
        if (filter === "All") return true;
        if (filter === "Video") return isVid;
        if (filter === "Favorites") return window.isFavorite(String(fileName));

        let hexColor = window.colorMap[String(fileName)];
        if (!hexColor) return filter === "Monochrome";

        return Color.hexBucket(hexColor) === filter;
    }

    FolderListModel {
        id: markerModel
        folder: "file://" + paths.getCacheDir("wallpaper_picker") + "/colors_markers"
        showDirs: false
        nameFilters: ["*_HEX_*"]

        onCountChanged: window.processMarkers()
        onStatusChanged: {
            if (status === FolderListModel.Ready) window.processMarkers()
        }
    }

    FolderListModel {
        id: srcModel
        folder: "file://" + window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false

        onCountChanged: {
            if (window.isDownloadingWallpaper && window.isDownloaded(window.currentDownloadName)) {
                window.isDownloadingWallpaper = false;
            }
        }
    }

    function processMarkers() {
        let newMap = {};
        for (let i = 0; i < markerModel.count; i++) {
            let markerName = markerModel.get(i, "fileName") || "";
            if (!markerName) continue;

            let splitIdx = markerName.lastIndexOf("_HEX_");
            if (splitIdx !== -1) {
                let fName = markerName.substring(0, splitIdx);
                let hexCode = markerName.substring(splitIdx + 5);
                newMap[fName] = "#" + hexCode;
            }
        }
        window.colorMap = newMap;
        window.cacheVersion++;
        window.updateVisibleCount();
    }

    function triggerColorExtraction() {
        const extractScript = `
            COLOR_DIR="${paths.getCacheDir('wallpaper_picker')}/colors_markers"
            THUMBS="${paths.getCacheDir('wallpaper_picker')}/thumbs"
            CSV="${paths.getCacheDir('wallpaper_picker')}/colors.csv"

            mkdir -p "$COLOR_DIR"

            if [ -f "$CSV" ]; then
                while IFS=, read -r fname hexcode; do
                    cleanhex=$(echo "$hexcode" | tr -d '\r#' | cut -c 1-6)
                    if [ -n "$cleanhex" ] && [ -n "$fname" ]; then
                        touch "$COLOR_DIR/$fname""_HEX_$cleanhex" 2>/dev/null
                    fi
                done < "$CSV"
                mv "$CSV" "$CSV.bak" 2>/dev/null
            fi

            if command -v magick &> /dev/null; then CMD="magick"; else CMD="convert"; fi

            for file in "$THUMBS"/*; do
                if [ -f "$file" ]; then
                    filename=$(basename "$file")
                    found=0
                    for marker in "$COLOR_DIR/$filename"_HEX_*; do
                        if [ -e "$marker" ]; then found=1; break; fi
                    done

                    if [ $found -eq 0 ]; then
                        hex=$($CMD "$file" -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oE '[0-9A-Fa-f]{6}' | head -n 1)
                        if [ -n "$hex" ]; then
                            touch "$COLOR_DIR/$filename""_HEX_$hex"
                        fi
                    fi
                fi
            done
        `;
        Quickshell.execDetached(["bash", "-c", extractScript]);
    }

    function stepToNextValidIndex(direction) {
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (!targetModel || targetModel.count === 0) return;

        let start = viewHost.currentIndex;
        let found = -1;

        if (direction === 1) {
            for (let i = start + 1; i < targetModel.count; i++) {
                let fname = targetModel.get(i).fileName || "";
                let isVid = fname.startsWith("000_");
                if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                    found = i; break;
                }
            }
        } else {
            for (let i = start - 1; i >= 0; i--) {
                let fname = targetModel.get(i).fileName || "";
                let isVid = fname.startsWith("000_");
                if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                    found = i; break;
                }
            }
        }

        if (found !== -1) {
            viewHost.setCurrentIndex(found);
            return;
        }

        let currentFilterIdx = C.FILTER_ORDER.indexOf(window.currentFilter);

        if (currentFilterIdx === -1) {
            let current = start;
            for (let i = 0; i < targetModel.count; i++) {
                current = (current + direction + targetModel.count) % targetModel.count;
                let fname = targetModel.get(current).fileName || "";
                let isVid = fname.startsWith("000_");

                if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                    viewHost.setCurrentIndex(current);
                    return;
                }
            }
            return;
        }

        let nextFilterIdx = currentFilterIdx + direction;

        if (nextFilterIdx >= 0 && nextFilterIdx < C.FILTER_ORDER.length) {
            window.jumpToLastOnFilterChange = (direction === -1);
            window.currentFilter = C.FILTER_ORDER[nextFilterIdx];
        }
    }

    function cycleFilter(direction) {
        let currentIdx = -1;
        for (let i = 0; i < window.filterData.length; i++) {
            if (window.filterData[i].name === window.currentFilter) {
                currentIdx = i;
                break;
            }
        }

        if (currentIdx !== -1) {
            let nextIdx = (currentIdx + direction + window.filterData.length) % window.filterData.length;
            window.currentFilter = window.filterData[nextIdx].name;
        }
    }

    function applyFilters(forceSnap) {
        let targetModel = window.getModelForFilter(window.currentFilter);

        if (!targetModel || targetModel.count === 0) {
            window.updateVisibleCount();
            return;
        }

        if (window.currentFilter === "Search") {
            window.updateVisibleCount();
            return;
        }

        let firstValidIndex = -1;
        let lastValidIndex = -1;
        let cleanTarget = window.getCleanName(window.targetWallName);
        let targetIndex = -1;

        for (let i = 0; i < targetModel.count; i++) {
            let fname = targetModel.get(i).fileName || "";
            let isVid = fname.startsWith("000_");

            if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                if (firstValidIndex === -1) {
                    firstValidIndex = i;
                }
                lastValidIndex = i;

                if (cleanTarget !== "" && window.getCleanName(fname) === cleanTarget) {
                    targetIndex = i;
                }
            }
        }

        let indexToFocus = -1;

        if (targetIndex !== -1) {
            indexToFocus = targetIndex;
        } else if (window.jumpToLastOnFilterChange && lastValidIndex !== -1) {
            indexToFocus = lastValidIndex;
        } else if (firstValidIndex !== -1) {
            indexToFocus = firstValidIndex;
        }

        window.jumpToLastOnFilterChange = false;

        if (indexToFocus !== -1) {
            window.executeFocusRestore(indexToFocus, false, forceSnap === true);
        }

        window.updateVisibleCount();
    }

    onCurrentFilterChanged: {
        window.isFilterAnimating = true;
        filterAnimationTimer.restart();
        window.isModelChanging = true;
        let returningFromSearch = (window._lastFilter === "Search" && window.currentFilter !== "Search");
        window._lastFilter = window.currentFilter;

        if (returningFromSearch) {
            window.searchIndexRestored = false;
        }

        Qt.callLater(() => {
            viewHost.forceActiveFocus();

            if (window.currentFilter === "Search") {
                if (window.hasSearched) {
                    window.searchIndexRestored = false;
                    window.trySearchFocus();
                }
            } else {
                window.applyFilters(returningFromSearch);
            }
            window.isModelChanging = false;
        });
    }

    Shortcut {
        sequence: "Left"
        enabled: !window.isScrollingBlocked && !window.isApplying && !window.confirmOpen && !window.keysPanelOpen
        onActivated: window.stepToNextValidIndex(-1)
    }
    Shortcut {
        sequence: "Right"
        enabled: !window.isScrollingBlocked && !window.isApplying && !window.confirmOpen && !window.keysPanelOpen
        onActivated: window.stepToNextValidIndex(1)
    }

    Shortcut {
        sequence: "Return"
        enabled: !window.searchInputFocused && !window.isScrollingBlocked && !window.isApplying && !window.confirmOpen && !window.keysPanelOpen
        onActivated: {
            let targetModel = window.getModelForFilter(window.currentFilter);
            if (viewHost.currentIndex >= 0 && viewHost.currentIndex < targetModel.count) {
                let fname = targetModel.get(viewHost.currentIndex).fileName;
                if (fname) {
                    let isVid = String(fname).startsWith("000_");
                    window.applyWallpaper(String(fname), isVid);
                }
            }
        }
    }

    Shortcut {
        sequence: "Delete"
        enabled: !window.isApplying && !window.confirmOpen && !window.keysPanelOpen && !window.searchInputFocused
        onActivated: window.requestDelete()
    }

    Shortcut { sequence: "Escape"; enabled: !window.isApplying && !window.confirmOpen && !window.keysPanelOpen; onActivated: { if (window.currentFilter === "Search") { window.currentFilter = "All"; } } }
    Shortcut { sequence: "Tab"; enabled: !window.isApplying && !window.confirmOpen && !window.keysPanelOpen; onActivated: window.cycleFilter(1) }
    Shortcut { sequence: "Backtab"; enabled: !window.isApplying && !window.confirmOpen && !window.keysPanelOpen; onActivated: window.cycleFilter(-1) }

    ListModel { id: localProxyModel }
    ListModel { id: searchProxyModel }

    readonly property var activeModel: window.currentFilter === "Search" ? searchProxyModel : localProxyModel

    // Expuesto para componentes de otros archivos (los ids no cruzan archivos).
    readonly property int searchResultCount: searchProxyModel.count

    FolderListModel {
        id: localFolderModel
        folder: window.thumbDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        sortField: FolderListModel.Name

        onCountChanged: window.syncLocalModel()
        onStatusChanged: { if (status === FolderListModel.Ready) window.syncLocalModel() }
    }

    // Tracks the highest index we have already synced into localProxyModel
    // so we never re-scan items we already ingested.
    property int _localSyncedCount: 0

    function syncLocalModel() {
        let folderCount = localFolderModel.count;

        // If the folder shrank (files deleted), we need a full rebuild.
        if (folderCount < window._localSyncedCount) {
            let wasAllowing = window.allowAddAnimation;
            window.allowAddAnimation = false;
            window.isModelChanging = true;

            localProxyModel.clear();
            window._localSyncedCount = 0;

            window.isModelChanging = false;
            window.syncLocalModel();
            if (wasAllowing) allowAddAnimationTimer.restart();
            return;
        }

        // Incremental append — only new items
        if (folderCount > window._localSyncedCount) {
            let batch = [];
            for (let i = window._localSyncedCount; i < folderCount; i++) {
                let fn = localFolderModel.get(i, "fileName");
                let fu = localFolderModel.get(i, "fileUrl");
                if (fn !== undefined) {
                    batch.push({ "fileName": fn, "fileUrl": String(fu) });
                }
            }

            if (batch.length > 0) {
                localProxyModel.append(batch);
            }

            window._localSyncedCount = folderCount;
        }

        if (window.currentFilter !== "Search") window.updateVisibleCount();

        // First-time focus snap
        if (!window.initialFocusSet && window.currentFilter !== "Search" && localProxyModel.count > 0) {
            window.tryFocus();
        }
    }

    function syncSearchModel() {
        let startIdx = searchProxyModel.count;
        let endIdx = searchFolderModel.count;

        if (endIdx < startIdx) {
            window.isModelChanging = true;
            searchProxyModel.clear();
            startIdx = 0;
            window.isModelChanging = false;
        }

        let batch = [];
        for (let i = startIdx; i < endIdx; i++) {
            let fn = searchFolderModel.get(i, "fileName");
            let fu = searchFolderModel.get(i, "fileUrl");
            if (fn !== undefined) {
                batch.push({ "fileName": fn, "fileUrl": String(fu) });
            }
        }

        if (batch.length > 0) {
            searchProxyModel.append(batch);
        }

        if (window.currentFilter === "Search") window.updateVisibleCount();

        if (window.currentFilter === "Search" && window.hasSearched) {
            if (!window.searchIndexRestored) {
                window.trySearchFocus();
            }

            if (window.isScrollingBlocked && startIdx === 0 && searchProxyModel.count > 0 && window.lastSearchName === "") {
                viewHost.forceLayout();
                viewHost.setCurrentIndex(0);
                viewHost.centerView(0);
            }
        }
    }

    FolderListModel {
        id: searchFolderModel
        folder: window.searchDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        sortField: FolderListModel.Name

        onFolderChanged: {
            window.isModelChanging = true;
            searchProxyModel.clear()
            window.isModelChanging = false;
        }

        onCountChanged: window.syncSearchModel()
        onStatusChanged: { if (status === FolderListModel.Ready) window.syncSearchModel() }
    }

    // ── Grid delegates back into the root state (the ListView lives in the
    // grid component and exposes `view`). ────────────────────────────────────
    function gridIndexChanged() {
        window.isItemAnimating = true;
        itemAnimationTimer.restart();

        if (window.currentFilter !== "Search") return;

        if (!window.isModelChanging && window.hasSearched && window.searchIndexRestored) {
            let ci = viewHost.currentIndex;
            if (ci >= 0 && ci < searchProxyModel.count) {
                let fname = searchProxyModel.get(ci).fileName;
                if (fname !== undefined && fname !== "") {
                    window.lastSearchName = String(fname);
                    searchState.lastName = String(fname);
                }
            }
        }
    }

    function gridWheel(wheel) {
        if (window.isScrollingBlocked || window.isApplying || window.confirmOpen) {
            wheel.accepted = true;
            return;
        }

        if (scrollThrottle.running) {
            wheel.accepted = true;
            return;
        }

        let dx = wheel.angleDelta.x;
        let dy = wheel.angleDelta.y;
        let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;

        scrollAccum += delta;

        if (Math.abs(scrollAccum) >= scrollThreshold) {
            window.stepToNextValidIndex(scrollAccum > 0 ? -1 : 1);
            scrollAccum = 0;
            scrollThrottle.start();
        }

        wheel.accepted = true;
    }

    function gridFocus() {
        viewHost.forceActiveFocus();
    }

    // Davinci is a full-screen picker; use the same smoked lens as the rest
    // of the shell instead of a solid plate. The filter bar and grid cards keep
    // their own opaque surfaces where they need contrast.
    // On Hyprland the picker owns the full-bleed lens and the grid starts
    // below the filter bar. The niri shell keeps the shared lens, so both
    // switches follow the active compositor.
    readonly property bool useOwnLens: false
    property bool hideShadow: false
    property bool disableSharedGlass: true

    // The presentation views need more vertical room than the compact
    // cover-flow strip. Keep cover-flow at the original picker height, but
    // grow the whole panel for grid/library/stage/palette and re-center it.
    // Main.qml follows these targets live when the mode changes.
    readonly property bool expandedView: viewMode !== "coverflow"
    readonly property real pickerHeight: expandedView
        ? Math.min(window.s(1150), Screen.height - window.s(40))
        : window.s(650)
    property real targetMasterHeight: pickerHeight
    property real targetMasterY: Math.floor((Screen.height - pickerHeight) / 2)

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: window.showFilterBar ? window.toolbarClearance : 0
        color: _theme.base
        visible: useOwnLens && !Theme.liquidGlass
        z: -1
    }

    LiquidGlass {
        anchors.fill: parent
        anchors.topMargin: window.showFilterBar ? window.toolbarClearance : 0
        enabled: useOwnLens && Theme.liquidGlass
        screenPosOverride: {
            const p = window.mapToItem(null, 0, 0);
            return Qt.vector2d(p.x, p.y);
        }
        tintColor: "#101018"
        tintAmount: 0.42
        interiorShade: 0.38
        bezel: Math.max(12, Math.min(28, Math.min(width, height) * 0.20))
        frost: Math.max(10, Math.min(22, Math.min(width, height) * 0.16))
        rim: 0.95
        // The picker is full-bleed at x=0..screen width. Keep the top/bottom
        // edge lit, but do not draw a specular strip against the side bezels.
        rimSides: Qt.vector4d(0, 1, 0, 1)
    }

    // ── View: grid + top filter bar ────────────────────────────────────────
    DavinciViewHost {
        id: viewHost
        ctx: window
        theme: _theme
        mode: window.viewMode
        gridColumns: window.gridColumns
        anchors.fill: parent
        anchors.topMargin: window.showFilterBar ? window.toolbarClearance : 0
    }

    DavinciFilterBar {
        id: filterBar
        visible: window.showFilterBar
        ctx: window
        theme: _theme
        monitors: monitorModel
        settings: searchState
    }

    ConfirmDialog {
        id: confirmDialog
        ctx: window
        theme: _theme
        open: window.confirmOpen
        title: "Delete wallpaper?"
        message: window.confirmTarget !== "" ? window.getCleanName(window.confirmTarget) : ""
        onConfirmed: window.confirmDelete()
        onDismissed: window.cancelDelete()
    }

    SearchKeysPanel {
        id: keysPanel
        ctx: window
        theme: _theme
        open: window.keysPanelOpen
        keys: window.providerKeys
        onSaveRequested: (name, value) => window.saveProviderKey(name, value)
        onClosed: window.keysPanelOpen = false
    }

    // Settings changes (including the main panel) refresh the picker live.
    Connections {
        target: Config
        function onRevChanged() {
            window.applyPersonalization();
        }
    }

    onViewModeChanged: {
        window.initialFocusSet = false;
    }

    Connections {
        target: viewHost
        function onViewLoaded() {
            window.applyFilters(true);
            viewHost.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        // Refresh the thumbnail cache on every open, including direct IPC or
        // settings launches that do not go through qs_manager.sh. The kernel
        // locks concurrent runs, so this remains cheap.
        Quickshell.execDetached([window.cliPath(), "thumbs"]);
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + decodeURIComponent(window.searchDir.replace("file://", "")) + "'"]);

        window.loadMonitors();

        // Load the davinci personalization block. Older view keys are no
        // longer read; the canonical settings live under "davinci".
        let raw = Config.rawSettings.davinci;
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
            Config.setSetting("davinci", Personalization.defaults("davinci"));
        }
        window.applyPersonalization();
        window.resolveCli();

        // Real slideshow state; the persisted flag can be stale after reboot.
        window.refreshSlideshowState();

        viewHost.forceActiveFocus();
        window.processMarkers();
        window.triggerColorExtraction();
    }

    Component.onDestruction: {
        // Cierra la búsqueda y limpia su caché (thumbs + map + cursor).
        let cli = window.cliPath();
        Quickshell.execDetached([cli, "search", "--clear"]);
        if (window.hasSearched) {
            window.hasSearched = false;
            searchState.searched = false;
            searchState.lastName = "";
        }
    }
}
