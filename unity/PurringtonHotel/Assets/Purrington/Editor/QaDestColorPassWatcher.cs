#if UNITY_EDITOR
using System.Collections;
using System.IO;
using System.Reflection;
using Purrington.Presentation;
using UnityEditor;
using UnityEngine;

namespace Purrington.EditorTools
{
    [InitializeOnLoad]
    static class QaDestColorPassWatcher
    {
        const string RelRequest = "docs/art/qa-shots/_capture-dest-color-pass.request";
        const string SessionArmed = "QaDest.armed";
        const string SessionRunning = "QaDest.running";
        const string SessionCleared = "QaDest.cleared";
        static readonly string[] RelOutputs =
        {
            "docs/art/qa-shots/seaside-day-color-pass.png",
            "docs/art/qa-shots/forest-day-color-pass.png",
            "docs/art/qa-shots/snowcap-day-color-pass.png",
        };
        static readonly int[] DestIndices = { 1, 2, 3 };

        static QaDestColorPassWatcher()
        {
            Debug.Log("[QaDest] watcher loaded armed=" + SessionState.GetBool(SessionArmed, false) +
                      " cleared=" + SessionState.GetBool(SessionCleared, false));
            EditorApplication.update += Tick;
            EditorApplication.playModeStateChanged += OnPlayMode;
        }

        static void OnPlayMode(PlayModeStateChange state)
        {
            if (state == PlayModeStateChange.EnteredPlayMode && File.Exists(RequestPath()))
                EditorApplication.delayCall += TryStart;
        }

        static string RepoRoot()
        {
            var assets = Application.dataPath.Replace('\\', '/');
            var proj = Directory.GetParent(assets)?.FullName;
            var unity = Directory.GetParent(proj ?? "")?.FullName;
            return Directory.GetParent(unity ?? "")?.FullName ?? "";
        }

        static string RequestPath() => Path.Combine(RepoRoot(), RelRequest.Replace('/', Path.DirectorySeparatorChar));
        static string OutputPath(int i) => Path.Combine(RepoRoot(), RelOutputs[i].Replace('/', Path.DirectorySeparatorChar));

        static void ClearCorruptSaves()
        {
            var roots = new[]
            {
                Path.Combine(Application.persistentDataPath, "parity-v2"),
                Application.persistentDataPath,
            };
            foreach (var dir in roots)
            {
                if (!Directory.Exists(dir)) continue;
                foreach (var name in new[] { "hotel.0.save", "hotel.1.save" })
                {
                    var p = Path.Combine(dir, name);
                    if (!File.Exists(p)) continue;
                    var bak = p + ".art-qa-bak-" + System.DateTime.Now.ToString("yyyyMMdd-HHmmss");
                    try
                    {
                        File.Copy(p, bak, false);
                        File.Delete(p);
                        Debug.Log("[QaDest] cleared save " + p);
                    }
                    catch (System.Exception e)
                    {
                        Debug.LogWarning("[QaDest] save clear failed: " + e.Message);
                    }
                }
            }
            SessionState.SetBool(SessionCleared, true);
        }

        static void ResetSession()
        {
            SessionState.SetBool(SessionArmed, false);
            SessionState.SetBool(SessionRunning, false);
            SessionState.SetBool(SessionCleared, false);
        }

        static void Tick()
        {
            if (!File.Exists(RequestPath()))
            {
                if (SessionState.GetBool(SessionArmed, false) || SessionState.GetBool(SessionCleared, false))
                    ResetSession();
                return;
            }

            if (SessionState.GetBool(SessionRunning, false)) return;

            if (EditorApplication.isPlaying)
            {
                // Only bounce out once if saves not cleared yet this run
                if (!SessionState.GetBool(SessionCleared, false))
                {
                    Debug.Log("[QaDest] play active; exiting once to clear saves");
                    ClearCorruptSaves();
                    EditorApplication.isPlaying = false;
                    SessionState.SetBool(SessionArmed, true);
                    return;
                }
                TryStart();
                return;
            }

            // Edit mode: clear if needed, then enter play
            if (!SessionState.GetBool(SessionArmed, false))
            {
                if (!SessionState.GetBool(SessionCleared, false))
                    ClearCorruptSaves();
                SessionState.SetBool(SessionArmed, true);
                Debug.Log("[QaDest] request seen; entering play mode. root=" + RepoRoot());
                EditorApplication.isPlaying = true;
            }
            else if (SessionState.GetBool(SessionCleared, false) && !EditorApplication.isPlaying)
            {
                // Armed after bounce — re-enter play
                Debug.Log("[QaDest] re-entering play after save clear");
                EditorApplication.isPlaying = true;
            }
        }

        static void TryStart()
        {
            if (!EditorApplication.isPlaying || !File.Exists(RequestPath())) return;
            if (SessionState.GetBool(SessionRunning, false)) return;
            var app = Object.FindFirstObjectByType<HotelApp>();
            if (app == null || app.Model == null || app.UI == null)
            {
                Debug.LogWarning("[QaDest] HotelApp not ready yet");
                return;
            }
            if (!string.IsNullOrEmpty(app.LastMessage) &&
                app.LastMessage.IndexOf("recovered", System.StringComparison.OrdinalIgnoreCase) >= 0)
            {
                Debug.LogError("[QaDest] save recovery still blocked: " + app.LastMessage);
                try { File.Delete(RequestPath()); } catch { }
                ResetSession();
                EditorApplication.isPlaying = false;
                return;
            }
            SessionState.SetBool(SessionRunning, true);
            app.UI.StartCoroutine(CaptureRoutine(app));
        }

        static IEnumerator CaptureRoutine(HotelApp app)
        {
            Debug.Log("[QaDest] god mode + travel captures");
            var god = app.Model.SetGodMode(true);
            app.Report(god, false);
            Debug.Log("[QaDest] SetGodMode -> " + god.success + " " + god.message);
            yield return null;
            yield return new WaitForSecondsRealtime(0.8f);

            for (int i = 0; i < DestIndices.Length; i++)
            {
                int hotel = DestIndices[i];
                var travel = app.Model.Travel(hotel);
                app.Report(travel, false);
                Debug.Log("[QaDest] Travel " + hotel + " -> " + travel.success + " " + travel.message +
                          " current=" + app.Model.State.currentHotel);
                app.UI.Navigate("Hotel");
                var field = typeof(HotelUI).GetField("compactObjective", BindingFlags.Instance | BindingFlags.NonPublic);
                if (field != null) field.SetValue(app.UI, false);
                var rebuild = typeof(HotelUI).GetMethod("Rebuild", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
                rebuild?.Invoke(app.UI, null);
                yield return null;
                yield return new WaitForSecondsRealtime(1.6f);
                yield return new WaitForEndOfFrame();
                var outPath = OutputPath(i);
                Directory.CreateDirectory(Path.GetDirectoryName(outPath) ?? RepoRoot());
                var tex = ScreenCapture.CaptureScreenshotAsTexture();
                File.WriteAllBytes(outPath, tex.EncodeToPNG());
                Object.Destroy(tex);
                Debug.Log("[QaDest] wrote " + outPath + " bytes=" + new FileInfo(outPath).Length);
            }

            try { File.Delete(RequestPath()); } catch { }
            ResetSession();
            Debug.Log("[QaDest] done - exiting play mode");
            EditorApplication.isPlaying = false;
        }
    }
}
#endif