using System.IO;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Purrington.Editor
{
    // Builds the voxel world in the open scene outside Play mode, so the hotel and Main Street can be inspected in the Scene view.
    // The preview reads the player's save but never writes it, is never saved into the scene, and rebuilds after each script reload.
    [InitializeOnLoad]
    static class WorldScenePreview
    {
        const string ModeKey = "Purrington.WorldPreview.Mode", HotelMenu = "Purrington/Preview/Hotel", StreetMenu = "Purrington/Preview/Main Street", OffMenu = "Purrington/Preview/Clear preview";
        const string PreviewName = "Purrington preview (not saved)", RenderName = "Purrington render (not saved)";
        static GameObject root;
        static Volume volume; static VolumeProfile sharedProfile;
        static AmbientMode ambientMode; static Color sky, equator, ground; static bool ambientSaved;

        sealed class ReadOnlyStore : ISaveStore
        {
            readonly ISaveStore inner; public ReadOnlyStore(ISaveStore inner) { this.inner = inner; }
            public HotelState Load() => inner.Load();
            public bool Save(HotelState state) => true;
        }

        static WorldScenePreview()
        {
            EditorApplication.playModeStateChanged += state =>
            {
                if (state == PlayModeStateChange.ExitingEditMode) Clear();
                else if (state == PlayModeStateChange.EnteredEditMode) Restore();
            };
            AssemblyReloadEvents.beforeAssemblyReload += Clear;
            // Opening the Meadow scene shows the hotel straight away; the scene itself only holds the runtime bootstrapper.
            UnityEditor.SceneManagement.EditorSceneManager.sceneOpened += (scene, _) => { if (IsMeadow(scene.path) && Mode == 0) Mode = 1; Restore(); };
            if (Mode == 0 && IsMeadow(UnityEngine.SceneManagement.SceneManager.GetActiveScene().path)) Mode = 1;
            Restore();
        }

        const string MeadowScene = "Assets/Purrington/Scenes/Meadow.unity";
        static bool IsMeadow(string path) => path == MeadowScene;

        [MenuItem("Purrington/Open Meadow scene", priority = 10)]
        public static void OpenMeadow()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode || !UnityEditor.SceneManagement.EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            UnityEditor.SceneManagement.EditorSceneManager.OpenScene(MeadowScene);
            EditorApplication.ExecuteMenuItem("Window/General/Scene");
            if (Mode == 0) Mode = 1;
            Build(Mode);
        }

        static int Mode { get => SessionState.GetInt(ModeKey, 0); set => SessionState.SetInt(ModeKey, value); }
        // A one-shot update hook rather than delayCall: a delayCall queued during a script reload is sometimes never run.
        static void Restore() { if (Mode != 0 && !EditorApplication.isPlayingOrWillChangePlaymode) { EditorApplication.update -= RestoreOnce; EditorApplication.update += RestoreOnce; } }
        static void RestoreOnce() { EditorApplication.update -= RestoreOnce; if (Mode != 0 && !EditorApplication.isPlayingOrWillChangePlaymode && !EditorApplication.isCompiling) Build(Mode); }

        [MenuItem(HotelMenu, priority = 20)] static void PreviewHotel() => Build(Mode = 1);
        [MenuItem(StreetMenu, priority = 21)] static void PreviewStreet() => Build(Mode = 2);
        [MenuItem(OffMenu, priority = 40)] static void ClearPreview() { Mode = 0; Clear(); }
        [MenuItem(HotelMenu, true)] [MenuItem(StreetMenu, true)] [MenuItem(OffMenu, true)]
        static bool CanPreview()
        {
            Menu.SetChecked(HotelMenu, Mode == 1); Menu.SetChecked(StreetMenu, Mode == 2);
            return !EditorApplication.isPlayingOrWillChangePlaymode;
        }

        static void Build(int mode)
        {
            Clear();
            if (mode == 0 || EditorApplication.isPlayingOrWillChangePlaymode) return;
            try
            {
                var model = LoadModel();

                SaveEnvironment();

                root = new GameObject(PreviewName);
                var world = root.AddComponent<VoxelWorld>();
                world.Initialize(model);
                if (mode == 2) { world.EnterTownMode(); world.FitTown(); }
                foreach (var t in root.GetComponentsInChildren<Transform>(true)) t.gameObject.hideFlags = HideFlags.DontSave;
                Frame(world, mode);
            }
            catch (System.Exception ex) { Debug.LogError("Purrington preview failed: " + ex); Clear(); Mode = 0; }
        }

        // The world tints ambient light and swaps the grading profile; remember both so Clear can put them back.
        static void SaveEnvironment()
        {
            ambientMode = RenderSettings.ambientMode; sky = RenderSettings.ambientSkyColor; equator = RenderSettings.ambientEquatorColor; ground = RenderSettings.ambientGroundColor; ambientSaved = true;
            volume = Object.FindFirstObjectByType<Volume>(); sharedProfile = volume ? volume.sharedProfile : null;
        }

        // The player's save, opened read-only (a fresh starter hotel when there is none).
        static HotelModel LoadModel()
        {
            TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);
            Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);
            var content = ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
            ISaveStore store = null;
            if (ParityProfile.TryOpen(Application.persistentDataPath, out var profile, out _))
                store = new ReadOnlyStore(new JournalSaveStore(Path.Combine(profile, "hotel"), new NewtonsoftSaveCodec()));
            var model = new HotelModel(store ?? new ReadOnlyStore(new EmptyStore()), content);
            if (!model.LoadOrCreate().success) { model = new HotelModel(new ReadOnlyStore(new EmptyStore()), content); model.LoadOrCreate(); }
            return model;
        }

        // Renders any destination off screen, without Play mode and without touching the save, for quick art checks:
        // map 0 Meadow, 1 Seaside, 2 Forest, 3 Snowcap; exterior shows roofs instead of the cutaway.
        public static void RenderShot(int map, bool exterior, float minute, string file, float zoom = 1)
        {
            bool wasPreviewing = Mode != 0; Clear();
            var host = new GameObject(RenderName) { hideFlags = HideFlags.DontSave };
            var texture = new RenderTexture(1920, 1080, 24, RenderTextureFormat.ARGB32) { antiAliasing = 4 };
            try
            {
                SaveEnvironment();
                var model = LoadModel();
                model.State.currentHotel = Mathf.Clamp(map, 0, 3); model.State.settings.exterior = exterior;
                var world = host.AddComponent<VoxelWorld>();
                world.Initialize(model);
                if (minute >= 0) world.Lighting?.Pin(minute);
                var camera = world.WorldCamera; camera.targetTexture = texture; camera.aspect = 1920f / 1080;
                typeof(VoxelWorld).GetMethod("UpdateCamera", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)?.Invoke(world, null);
                if (zoom > 0) camera.orthographicSize *= zoom;
                // Step the animated destination life a few seconds in so boats, birds and smoke are mid-motion.
                typeof(VoxelWorld).GetMethod("UpdateLife", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)?.Invoke(world, new object[] { 3.7f });
                camera.Render();
                var previous = RenderTexture.active; RenderTexture.active = texture;
                var image = new Texture2D(1920, 1080, TextureFormat.RGB24, false); image.ReadPixels(new Rect(0, 0, 1920, 1080), 0, 0); image.Apply();
                RenderTexture.active = previous;
                Directory.CreateDirectory(Path.GetDirectoryName(file)); File.WriteAllBytes(file, image.EncodeToPNG()); Object.DestroyImmediate(image);
                camera.targetTexture = null;
            }
            finally
            {
                Object.DestroyImmediate(host); Clear(); texture.Release(); Object.DestroyImmediate(texture);
                if (wasPreviewing) Restore();
            }
        }

        static void Frame(VoxelWorld world, int mode)
        {
            var view = SceneView.lastActiveSceneView; if (view == null || root == null) return;
            const float u = VoxelWorld.Unit;
            // The render root mirrors z, so lot coordinates flip sign on the way to world space.
            var bounds = mode == 2 ? new Bounds(new Vector3(0, 1, -18 * u), new Vector3(70 * u, 4, 36 * u)) : new Bounds(Vector3.zero, new Vector3(30 * u, 4, 30 * u));
            // Match the game's isometric angle so the Scene view reads like the Game view.
            view.rotation = world.WorldCamera ? world.WorldCamera.transform.rotation : Quaternion.Euler(35, 225, 0); view.orthographic = true; view.Frame(bounds, false);
        }

        static void Clear()
        {
            if (root != null) Object.DestroyImmediate(root);
            root = null;
            // Leftovers from an interrupted preview or render (for example across a script reload) are found by name.
            for (int i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++)
                foreach (var stale in UnityEngine.SceneManagement.SceneManager.GetSceneAt(i).GetRootGameObjects())
                    if (stale.name == PreviewName || stale.name == RenderName) Object.DestroyImmediate(stale);
            if (volume != null && sharedProfile != null && volume.sharedProfile != sharedProfile)
            {
                var clone = volume.sharedProfile; volume.sharedProfile = sharedProfile;
                if (clone != null && !AssetDatabase.Contains(clone)) Object.DestroyImmediate(clone);
            }
            volume = null; sharedProfile = null;
            RestoreAmbient();
        }

        static void RestoreAmbient()
        {
            if (ambientSaved)
            {
                RenderSettings.ambientMode = ambientMode; RenderSettings.ambientSkyColor = sky; RenderSettings.ambientEquatorColor = equator; RenderSettings.ambientGroundColor = ground;
                ambientSaved = false;
            }
        }

        sealed class EmptyStore : ISaveStore { public HotelState Load() => null; public bool Save(HotelState state) => true; }
    }
}
