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
    static class QaShotWatcher
    {
        const string RelRequest = "docs/art/qa-shots/_capture-hotel-overview.request";
        const string RelOutput = "docs/art/qa-shots/hotel-overview-expanded.png";
        static bool armed;
        static bool running;

        static QaShotWatcher()
        {
            EditorApplication.update += Tick;
            EditorApplication.playModeStateChanged += OnPlayMode;
        }

        static void OnPlayMode(PlayModeStateChange state)
        {
            if (state == PlayModeStateChange.EnteredPlayMode && File.Exists(RequestPath()))
                EditorApplication.delayCall += () => TryStart();
        }

        static string RepoRoot()
        {
            var assets = Application.dataPath.Replace('\\', '/');
            var proj = Directory.GetParent(assets)?.FullName;          // PurringtonHotel
            var unity = Directory.GetParent(proj ?? "")?.FullName;     // unity
            return Directory.GetParent(unity ?? "")?.FullName ?? "";   // repo
        }

        static string RequestPath() => Path.Combine(RepoRoot(), RelRequest.Replace('/', Path.DirectorySeparatorChar));
        static string OutputPath() => Path.Combine(RepoRoot(), RelOutput.Replace('/', Path.DirectorySeparatorChar));

        static void Tick()
        {
            if (running) return;
            if (!File.Exists(RequestPath())) { armed = false; return; }
            if (!EditorApplication.isPlaying)
            {
                if (!armed)
                {
                    armed = true;
                    Debug.Log("[QaShot] request seen; entering play mode. root=" + RepoRoot());
                    EditorApplication.isPlaying = true;
                }
                return;
            }
            TryStart();
        }

        static void TryStart()
        {
            if (running || !EditorApplication.isPlaying || !File.Exists(RequestPath())) return;
            var ui = Object.FindFirstObjectByType<HotelUI>();
            if (ui == null)
            {
                Debug.LogWarning("[QaShot] HotelUI not ready yet");
                return;
            }
            running = true;
            ui.StartCoroutine(CaptureRoutine(ui));
        }

        static IEnumerator CaptureRoutine(HotelUI ui)
        {
            Debug.Log("[QaShot] capturing hotel overview");
            ui.Navigate("Hotel");
            var field = typeof(HotelUI).GetField("compactObjective", BindingFlags.Instance | BindingFlags.NonPublic);
            if (field != null) field.SetValue(ui, false);
            var rebuild = typeof(HotelUI).GetMethod("Rebuild", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
            rebuild?.Invoke(ui, null);
            yield return null;
            yield return new WaitForSecondsRealtime(0.75f);
            yield return new WaitForEndOfFrame();
            var outPath = OutputPath();
            Directory.CreateDirectory(Path.GetDirectoryName(outPath) ?? RepoRoot());
            var tex = ScreenCapture.CaptureScreenshotAsTexture();
            File.WriteAllBytes(outPath, tex.EncodeToPNG());
            Object.Destroy(tex);
            try { File.Delete(RequestPath()); } catch { }
            Debug.Log("[QaShot] wrote " + outPath + " bytes=" + new FileInfo(outPath).Length);
            running = false;
            armed = false;
        }
    }
}
#endif