pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/**
 * Local OpenCode V2 client for desktop widgets.
 *
 * The Python bridge owns the HTTP connection and writes a normalized snapshot to
 * ~/.local/state/quickshell/user/opencode/state.json. This singleton reads that
 * file as a fallback and consumes live snapshots from the bridge's stdout. It
 * exposes actions through the `opencode api` CLI, so no password or service URL
 * ever reaches QML.
 *
 * OpenCode is allowed to be absent or not running. In that case `connectionState`
 * is `not_running` and the widget should show an empty state instead of an error.
 */
Singleton {
    id: root

    readonly property string statePath: FileUtils.trimFileProtocol(
        Quickshell.env("QS_OPENCODE_STATE_PATH") || `${Directories.state}/user/opencode/state.json`
    )
    readonly property string bridgeScript: Quickshell.shellPath("scripts/ai/opencode-bridge.py")

    property var snapshot: ({
        schema: 1,
        state: "starting",
        connected: false,
        reason: "",
        checkedAt: 0,
        heartbeatAt: 0,
        retryInMs: 2000,
        stale: false,
        sessions: [],
        permissions: [],
        forms: [],
        stats: null
    })

    property double now: Date.now()
    property string lastBridgeError: ""
    property string lastActionError: ""
    property bool actionBusy: false
    property bool bridgeEnabled: true
    property bool shuttingDown: false

    readonly property string connectionState: root.snapshot.state || "unknown"
    readonly property bool connected: root.snapshot.connected === true
    readonly property bool stale: root.snapshot.stale === true
    readonly property double lastUpdated: root.snapshot.heartbeatAt || root.snapshot.checkedAt || 0
    readonly property bool heartbeatStale: root.lastUpdated > 0 && (root.now - root.lastUpdated > 30000)
    readonly property bool bridgeLooksAlive: root.lastUpdated > 0 && (root.now - root.lastUpdated < 15000)
    readonly property bool bridgeRunning: bridgeProcess.running

    readonly property string effectiveState: {
        if (root.heartbeatStale && root.connected) return "reconnecting";
        if (root.connectionState === "connected" && !root.connected) return "reconnecting";
        return root.connectionState;
    }

    readonly property var sessions: root.snapshot.sessions || []
    readonly property var permissions: root.snapshot.permissions || []
    readonly property var forms: root.snapshot.forms || []
    readonly property var stats: root.snapshot.stats || null
    readonly property var rootSessions: root.sessions.filter(s => !s.parentID)
    readonly property int pendingCount: root.permissions.length
    readonly property int workingCount: root.rootSessions.filter(s => s.status === "working").length
    readonly property int waitingCount: {
        const waiting = {};
        root.permissions.forEach(p => { waiting[p.sessionID] = true; });
        return Object.keys(waiting).length;
    }

    readonly property var sortedSessions: {
        const rank = { waiting: 0, working: 1, error: 2, idle: 3 };
        return root.rootSessions.slice().sort((a, b) => {
            const byStatus = (rank[a.status] ?? 9) - (rank[b.status] ?? 9);
            if (byStatus !== 0) return byStatus;
            return (b.updated || 0) - (a.updated || 0);
        });
    }

    readonly property string statusText: {
        if (root.effectiveState === "not_installed") return "OpenCode is not installed";
        if (root.effectiveState === "not_running") return "OpenCode is not running";
        if (root.effectiveState === "starting") return "Connecting to OpenCode…";
        if (root.effectiveState === "incompatible") return "OpenCode version is not supported";
        if (root.effectiveState === "reconnecting") return "Reconnecting to OpenCode…";
        if (root.effectiveState === "error") return "OpenCode connection error";
        if (root.waitingCount > 0) return `${root.waitingCount} waiting for you`;
        if (root.workingCount > 0) return `${root.workingCount} working`;
        return "OpenCode is ready";
    }

    signal permissionRequested(var permission)
    signal sessionFinished(var session)

    property var knownPermissionIDs: ({})
    property bool permissionBaselineReady: false
    property var previousSessionStatus: ({})

    function sessionById(sessionID) {
        return root.sessions.find(s => s.id === sessionID) || null;
    }

    function permissionForSession(sessionID) {
        return root.permissions.find(p => p.sessionID === sessionID) || null;
    }

    function applySnapshot(text) {
        if (!text || text.trim().length === 0) return;
        try {
            const data = JSON.parse(text);
            if (!data || typeof data !== "object") return;
            root.snapshot = data;
            root.now = Date.now();
            root.processNotifications();
        } catch (error) {
            console.warn("[OpenCode] Invalid state file:", error);
        }
    }

    function processNotifications() {
        const permissionIDs = {};
        root.permissions.forEach(permission => { permissionIDs[permission.id] = true; });

        if (!root.permissionBaselineReady) {
            root.knownPermissionIDs = permissionIDs;
            root.permissionBaselineReady = true;
        } else {
            const fresh = root.permissions.filter(permission => !root.knownPermissionIDs[permission.id]);
            root.knownPermissionIDs = permissionIDs;
            if (fresh.length > 0 && root.connected) {
                root.permissionRequested(fresh[0]);
                root.notifyPermission(fresh);
            }
        }

        const statuses = {};
        root.rootSessions.forEach(session => { statuses[session.id] = session.status; });
        if (Object.keys(root.previousSessionStatus).length === 0) {
            root.previousSessionStatus = statuses;
            return;
        }
        root.rootSessions.forEach(session => {
            const previous = root.previousSessionStatus[session.id];
            if (previous === "working" && (session.status === "idle" || session.status === "error")) {
                root.sessionFinished(session);
                root.notifyFinished(session);
            }
        });
        root.previousSessionStatus = statuses;
    }

    function notifyPermission(permissions) {
        if (permissions.length === 0) return;
        const first = permissions[0];
        const resources = (first.resources || []).join(" ").replace(/[<>&]/g, "");
        const title = permissions.length === 1
            ? "OpenCode · permission needed"
            : `OpenCode · ${permissions.length} permissions needed`;
        const body = `${first.sessionTitle || "Session"}: ${first.action || "action"} ${resources}`.slice(0, 240);
        Quickshell.execDetached(["notify-send", "-a", "opencode", "-u", "critical", "-i", "utilities-terminal", title, body]);
    }

    function notifyFinished(session) {
        const cost = typeof session.cost === "number" ? ` · $${session.cost.toFixed(3)}` : "";
        const title = session.status === "error" ? "OpenCode · session failed" : "OpenCode · session finished";
        const body = `${session.title || "Session"}${cost}`;
        const urgency = session.status === "error" ? "critical" : "normal";
        Quickshell.execDetached(["notify-send", "-a", "opencode", "-u", urgency, "-i", "utilities-terminal", title, body]);
    }

    function startBridge() {
        if (!root.bridgeEnabled || root.shuttingDown || bridgeProcess.running) return;
        console.log("[OpenCode] starting bridge:", root.bridgeScript);
        bridgeProcess.running = true;
    }

    function restartBridge() {
        if (root.shuttingDown) return;
        bridgeProcess.running = false;
        bridgeRestartTimer.restart();
    }

    function retryNow() {
        root.restartBridge();
    }

    function shellQuote(value) {
        return `'${StringUtils.shellSingleQuoteEscape(String(value))}'`;
    }

    function openOpenCode(directory) {
        const target = directory && directory.length > 0 ? directory : Directories.home;
        const terminal = Config.options.apps.terminal || "kitty -1";
        Quickshell.execDetached(["bash", "-c", `${terminal} opencode ${root.shellQuote(target)}`]);
    }

    function openSession(sessionID, directory) {
        const target = directory && directory.length > 0 ? directory : Directories.home;
        const terminal = Config.options.apps.terminal || "kitty -1";
        const sessionPart = sessionID ? ` -s ${root.shellQuote(sessionID)}` : "";
        Quickshell.execDetached(["bash", "-c", `${terminal} opencode${sessionPart} ${root.shellQuote(target)}`]);
    }

    function startService() {
        Quickshell.execDetached(["opencode", "service", "start"]);
    }

    function runAction(args) {
        if (root.actionBusy) {
            root.lastActionError = "Another OpenCode action is still running";
            return false;
        }
        actionProcess.command = ["opencode", "api", ...args];
        root.actionBusy = true;
        root.lastActionError = "";
        actionProcess.running = true;
        return true;
    }

    function replyPermission(sessionID, requestID, decision) {
        if (!["once", "always", "reject"].includes(decision)) {
            root.lastActionError = `Invalid permission decision: ${decision}`;
            return false;
        }
        return root.runAction([
            "post",
            `/api/session/${sessionID}/permission/${requestID}/reply`,
            "--data",
            JSON.stringify({ decision: decision })
        ]);
    }

    function interrupt(sessionID) {
        return root.runAction(["post", `/api/session/${sessionID}/interrupt`]);
    }

    function compact(sessionID) {
        return root.runAction(["post", `/api/session/${sessionID}/compact`]);
    }

    function deleteSession(sessionID) {
        return root.runAction(["delete", `/api/session/${sessionID}`]);
    }

    function prompt(sessionID, text) {
        if (!text || text.trim().length === 0) return false;
        return root.runAction([
            "post",
            `/api/session/${sessionID}/prompt`,
            "--data",
            JSON.stringify({ text: text })
        ]);
    }

    FileView {
        id: stateFile
        path: Qt.resolvedUrl(root.statePath)
        watchChanges: true
        onFileChanged: this.reload()
        onLoadedChanged: {
            if (this.loaded) root.applySnapshot(stateFile.text());
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.snapshot = {
                    schema: 1,
                    state: "starting",
                    connected: false,
                    reason: "",
                    checkedAt: 0,
                    heartbeatAt: 0,
                    retryInMs: 2000,
                    stale: false,
                    sessions: [],
                    permissions: [],
                    forms: [],
                    stats: null
                };
                return;
            }
            console.warn("[OpenCode] Failed to read state file:", error);
        }
    }

    Timer {
        id: stateFileRetryTimer
        interval: 2000
        repeat: true
        running: root.lastUpdated === 0 || root.effectiveState !== "connected"
        onTriggered: stateFile.reload()
    }

    Process {
        id: bridgeProcess
        command: ["python3", root.bridgeScript, "--watch", "--stdout", "--state-path", root.statePath]
        running: false
        stdout: SplitParser {
            onRead: (line) => root.applySnapshot(line)
        }
        stderr: StdioCollector {
            id: bridgeStderr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.lastBridgeError = bridgeStderr.text.trim() || `bridge exited with ${exitCode}`;
                console.warn("[OpenCode] bridge exited:", exitCode, root.lastBridgeError);
            }
            if (!root.shuttingDown && !root.bridgeLooksAlive) {
                bridgeRestartTimer.restart();
            }
        }
    }

    Process {
        id: actionProcess
        running: false
        stdout: StdioCollector {
            id: actionStdout
        }
        stderr: StdioCollector {
            id: actionStderr
        }
        onExited: (exitCode, exitStatus) => {
            root.actionBusy = false;
            if (exitCode !== 0) {
                root.lastActionError = (actionStderr.text || actionStdout.text || `opencode api exited with ${exitCode}`).trim();
                console.warn("[OpenCode] Action failed:", root.lastActionError);
            } else {
                root.lastActionError = "";
            }
        }
    }

    Timer {
        id: bridgeRestartTimer
        interval: 5000
        repeat: false
        onTriggered: root.startBridge()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            root.now = Date.now();
            if (root.bridgeEnabled && !root.shuttingDown && !bridgeProcess.running && !bridgeRestartTimer.running && !root.bridgeLooksAlive) {
                root.startBridge();
            }
        }
    }

    Component.onCompleted: {
        root.now = Date.now();
        root.startBridge();
    }

    Component.onDestruction: {
        root.shuttingDown = true;
        bridgeProcess.running = false;
    }
}
