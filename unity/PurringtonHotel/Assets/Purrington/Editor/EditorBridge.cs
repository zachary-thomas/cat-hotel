using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Purrington.Presentation;
using UnityEditor;
using UnityEditor.Compilation;
using UnityEditor.TestTools.TestRunner.Api;
using UnityEngine;

namespace Purrington.Editor
{
    // Lets command-line tooling drive the Editor that is already open, so the project never has to be closed for a
    // batch-mode run. tools/unity-bridge.ps1 writes Temp/ClaudeBridge/request.json; this polls for it, runs the action
    // (refresh, test, build, capture, play, stop, ping) and writes response.json. Work that spans a domain reload
    // (compiling, entering or leaving Play mode) is carried in SessionState.
    [InitializeOnLoad]
    static class EditorBridge
    {
        static readonly string Dir = Path.GetFullPath(Path.Combine(Application.dataPath, "../Temp/ClaudeBridge"));
        const string PendingKey = "Purrington.Bridge.Pending", ErrorsKey = "Purrington.Bridge.Errors";
        static double nextPoll, nextBeat;

        [Serializable] class Request { public string id = "", action = "", filter = "", tab = "", stage = ""; public float wait = 4, minute = -1; public int map = -1; public bool exterior; public float zoom = 1; public double since; }
        [Serializable] class Response { public string id, action, status, message, file; public int passed, failed, skipped; public string[] failures = new string[0]; }

        static EditorBridge()
        {
            EditorApplication.update += Poll;
            // Play always starts from the game's first build scene (Bootstrap), whichever scene is open for editing.
            EditorApplication.delayCall += UseBootstrapForPlay;
            CompilationPipeline.assemblyCompilationFinished += (assembly, messages) =>
            {
                var errors = messages.Where(m => m.type == CompilerMessageType.Error).Select(m => m.file + "(" + m.line + "): " + m.message).ToArray();
                if (errors.Length > 0) SessionState.SetString(ErrorsKey, SessionState.GetString(ErrorsKey, "") + string.Join("\n", errors) + "\n");
            };
        }

        static void Poll()
        {
            double now = EditorApplication.timeSinceStartup;
            if (now >= nextBeat) { nextBeat = now + 2; try { Directory.CreateDirectory(Dir); File.WriteAllText(Path.Combine(Dir, "alive"), DateTime.UtcNow.ToString("o")); } catch (IOException) { } }
            if (now < nextPoll) return;
            nextPoll = now + .25;
            var pending = SessionState.GetString(PendingKey, "");
            if (pending.Length > 0) { Continue(JsonUtility.FromJson<Request>(pending)); return; }
            var path = Path.Combine(Dir, "request.json");
            if (!File.Exists(path)) return;
            Request request;
            try { request = JsonUtility.FromJson<Request>(File.ReadAllText(path)); File.Delete(path); }
            catch (Exception) { return; }
            Begin(request);
        }

        static void UseBootstrapForPlay()
        {
            var first = EditorBuildSettings.scenes.FirstOrDefault(x => x.enabled);
            var scene = first == null ? null : AssetDatabase.LoadAssetAtPath<SceneAsset>(first.path);
            if (scene != null) UnityEditor.SceneManagement.EditorSceneManager.playModeStartScene = scene;
        }

        static void Save(Request r) => SessionState.SetString(PendingKey, JsonUtility.ToJson(r));

        static void Reply(Request r, string status, string message, Action<Response> fill = null)
        {
            SessionState.EraseString(PendingKey);
            var response = new Response { id = r.id, action = r.action, status = status, message = message };
            fill?.Invoke(response);
            Directory.CreateDirectory(Dir);
            var temp = Path.Combine(Dir, "response.tmp");
            File.WriteAllText(temp, JsonUtility.ToJson(response, true));
            var target = Path.Combine(Dir, "response.json");
            if (File.Exists(target)) File.Delete(target);
            File.Move(temp, target);
        }

        static void Begin(Request r)
        {
            r.since = EditorApplication.timeSinceStartup;
            switch (r.action)
            {
                case "ping":
                    var start = UnityEditor.SceneManagement.EditorSceneManager.playModeStartScene;
                    Reply(r, "ok", "Unity " + Application.unityVersion + (EditorApplication.isPlaying ? " (playing)" : "") + (EditorApplication.isCompiling ? " (compiling)" : "") + " | open scene: " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().path + " | world preview: " + (GameObject.Find("Purrington preview (not saved)") ? "shown" : "off") + " (mode " + SessionState.GetInt("Purrington.WorldPreview.Mode", 0) + ")" + " | roots: " + string.Join(", ", UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects().Select(g => g.name)) + " | Play starts from: " + (start ? AssetDatabase.GetAssetPath(start) : "the open scene"));
                    return;
                case "stop":
                    if (EditorApplication.isPlaying) { EditorApplication.isPlaying = false; r.stage = "exiting"; Save(r); } else Reply(r, "ok", "Not playing.");
                    return;
                case "refresh": case "meadow": case "render": case "test": case "build": case "capture": case "play":
                    if (EditorApplication.isPlaying && r.action != "capture") { EditorApplication.isPlaying = false; r.stage = "leaving play"; Save(r); return; }
                    // Every action starts from freshly compiled scripts.
                    SessionState.EraseString(ErrorsKey);
                    AssetDatabase.Refresh();
                    r.stage = "compiling"; Save(r);
                    return;
                default:
                    Reply(r, "error", "Unknown action " + r.action + ". Use ping, refresh, meadow, render, test, build, capture, play or stop.");
                    return;
            }
        }

        static void Continue(Request r)
        {
            double elapsed = EditorApplication.timeSinceStartup - r.since;
            switch (r.stage)
            {
                case "leaving play":
                    if (EditorApplication.isPlaying) return;
                    r.stage = ""; Begin(r); return;
                case "exiting":
                    if (EditorApplication.isPlaying) return;
                    Reply(r, "ok", r.action == "capture" ? "Captured. " + r.tab : "Stopped.", x => x.file = r.filter);
                    return;
                case "compiling":
                    // Give a refresh a moment to start compiling before deciding it had nothing to do.
                    if (elapsed < 1.5 || EditorApplication.isCompiling || EditorApplication.isUpdating) return;
                    var errors = SessionState.GetString(ErrorsKey, "");
                    if (EditorUtility.scriptCompilationFailed || errors.Length > 0) { Reply(r, "error", "Scripts have compiler errors.", x => x.failures = errors.Split(new[] { '\n' }, StringSplitOptions.RemoveEmptyEntries)); return; }
                    Run(r);
                    return;
                case "testing":
                    if (elapsed > 900) Reply(r, "error", "Tests did not report back within 15 minutes.");
                    return;
                case "playing":
                    if (!EditorApplication.isPlaying) { if (elapsed > 60) Reply(r, "error", "Play mode did not start."); return; }
                    if (r.action == "play") { Reply(r, "ok", "Playing."); return; }
                    if (elapsed < r.wait) return;
                    var app = UnityEngine.Object.FindFirstObjectByType<HotelApp>();
                    if (app != null && !string.IsNullOrEmpty(r.tab)) app.UI?.Navigate(r.tab);
                    if (app != null && r.minute >= 0) app.World?.Lighting?.Pin(r.minute);
                    r.stage = "posing"; r.since = EditorApplication.timeSinceStartup; Save(r);
                    return;
                case "posing":
                    // Let panels finish sliding in and lighting settle before the shot.
                    if (elapsed < .8) return;
                    // capture -Filter pop shows an income pop half a second before the shot, once the panels have settled.
                    // capture -Filter "click:Stairs up|click:Rotate" presses those UI buttons (by name) before the shot.
                    if (r.filter.StartsWith("click:"))
                    {
                        foreach (var name in r.filter.Split('|').Select(x => x.StartsWith("click:") ? x.Substring(6) : x))
                        {
                            var button = UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Button>(FindObjectsSortMode.None).FirstOrDefault(b => b.name == name && b.isActiveAndEnabled);
                            if (button != null) button.onClick.Invoke(); else Debug.LogWarning("Bridge: no button named " + name);
                        }
                        r.filter = "clicked"; r.since = EditorApplication.timeSinceStartup; Save(r); return;
                    }
                    if (r.filter == "pop") { UnityEngine.Object.FindFirstObjectByType<HotelApp>()?.World?.PopIncome(42); r.filter = "popped"; r.since = EditorApplication.timeSinceStartup + .3; Save(r); return; }
                    var file = Path.GetFullPath(Path.Combine(Application.dataPath, "../../../builds/unity/editor-captures", DateTime.Now.ToString("yyyyMMdd-HHmmss") + (string.IsNullOrEmpty(r.tab) ? "" : "-" + r.tab) + ".png"));
                    Directory.CreateDirectory(Path.GetDirectoryName(file));
                    ScreenCapture.CaptureScreenshot(file);
                    var capturedApp = UnityEngine.Object.FindFirstObjectByType<HotelApp>();
                    r.tab = "(income pops so far: " + VoxelFx.PopCount + ", coins " + (capturedApp != null ? System.Math.Floor(capturedApp.Model.State.coins).ToString("N0") : "?") + ")";
                    r.filter = file; r.stage = "saving"; r.since = EditorApplication.timeSinceStartup; Save(r);
                    return;
                case "saving":
                    // The screenshot is written at the end of a frame; wait for the file before leaving Play mode.
                    if (!File.Exists(r.filter) || new FileInfo(r.filter).Length == 0) { if (elapsed > 20) { EditorApplication.isPlaying = false; Reply(r, "error", "The Game view did not render a screenshot. Make sure the Game view tab is visible."); } return; }
                    EditorApplication.isPlaying = false; r.stage = "exiting"; Save(r);
                    return;
                default:
                    Reply(r, "error", "Lost track of " + r.action + " at stage " + r.stage + ".");
                    return;
            }
        }

        static void Run(Request r)
        {
            switch (r.action)
            {
                case "refresh":
                    Reply(r, "ok", "Scripts compiled.");
                    return;
                case "render":
                    try
                    {
                        var shot = Path.GetFullPath(Path.Combine(Application.dataPath, "../../../builds/unity/editor-captures", DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-map" + Math.Max(0, r.map) + (r.exterior ? "-exterior" : "") + ".png"));
                        WorldScenePreview.RenderShot(Math.Max(0, r.map), r.exterior, r.minute, shot, r.zoom);
                        Reply(r, "ok", "Rendered.", x => x.file = shot);
                    }
                    catch (Exception e) { Reply(r, "error", e.Message); }
                    return;
                case "meadow":
                    // Only switches away from a scene with nothing unsaved, so the bridge never discards the user's edits.
                    if (UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty) { Reply(r, "error", "The open scene has unsaved changes; use Purrington > Open Meadow scene."); return; }
                    WorldScenePreview.OpenMeadow();
                    Reply(r, "ok", "Meadow scene open with the hotel preview.");
                    return;
                case "build":
                    try { ProjectSetup.BuildWindows(); Reply(r, "ok", "Windows preview built."); }
                    catch (Exception e) { Reply(r, "error", e.Message); }
                    return;
                case "capture": case "play":
                    UseBootstrapForPlay();
                    EditorApplication.ExecuteMenuItem("Window/General/Game");
                    r.stage = "playing"; r.since = EditorApplication.timeSinceStartup; Save(r);
                    EditorApplication.isPlaying = true;
                    return;
                case "test":
                    r.stage = "testing"; Save(r);
                    var api = ScriptableObject.CreateInstance<TestRunnerApi>();
                    api.RegisterCallbacks(new Results(r));
                    var filter = new Filter { testMode = TestMode.EditMode };
                    if (!string.IsNullOrEmpty(r.filter)) filter.groupNames = new[] { r.filter };
                    api.Execute(new ExecutionSettings(filter));
                    return;
            }
        }

        sealed class Results : ICallbacks
        {
            readonly Request request; readonly List<string> failures = new List<string>(); int passed, failed, skipped;
            public Results(Request request) { this.request = request; }
            public void RunStarted(ITestAdaptor tests) { }
            public void TestStarted(ITestAdaptor test) { }
            public void TestFinished(ITestResultAdaptor result)
            {
                if (result.HasChildren) return;
                if (result.TestStatus == TestStatus.Passed) passed++;
                else if (result.TestStatus == TestStatus.Failed) { failed++; failures.Add(result.FullName + ": " + result.Message?.Trim()); }
                else skipped++;
            }
            public void RunFinished(ITestResultAdaptor result)
            {
                Reply(request, failed == 0 ? "ok" : "failed", passed + " passed, " + failed + " failed, " + skipped + " skipped.", x => { x.passed = passed; x.failed = failed; x.skipped = skipped; x.failures = failures.ToArray(); });
            }
        }
    }
}
