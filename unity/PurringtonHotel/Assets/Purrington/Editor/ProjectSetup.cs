using System;
using System.IO;
using System.Linq;
using Purrington.Domain;
using Purrington.Presentation;
using TMPro;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Purrington.Editor
{
    public static class ProjectSetup
    {
        const string Root="Assets/Purrington";
        static double textDeadline;
        public static void PrepareTextResources()
        {
            if(Resources.Load<TMP_Settings>("TMP Settings")!=null){EditorApplication.Exit(0);return;}
            textDeadline=EditorApplication.timeSinceStartup+180;
            EditorApplication.update+=WaitForTextResources;
            TMP_PackageResourceImporter.ImportResources(true,false,false);
        }
        static void WaitForTextResources()
        {
            if(Resources.Load<TMP_Settings>("TMP Settings")!=null)
            {
                EditorApplication.update-=WaitForTextResources;
                AssetDatabase.SaveAssets();EditorApplication.Exit(0);
            }
            else if(EditorApplication.timeSinceStartup>textDeadline)
            {
                Debug.LogError("TMP resources import timed out");EditorApplication.Exit(2);
            }
        }
        [MenuItem("Purrington/Configure project")]
        public static void Configure()
        {
            Directory.CreateDirectory(Root+"/Scenes");
            Directory.CreateDirectory(Root+"/Prefabs");
            Directory.CreateDirectory("Assets/Resources/Fonts");
            Directory.CreateDirectory("Assets/Resources/Content");
            AssetDatabase.Refresh();
            PlayerSettings.companyName="Purrington";
            PlayerSettings.productName="Purrington Hotel Unity Preview";
            PlayerSettings.bundleVersion="0.1.0";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android,"com.purrington.hotel.unitypreview");
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.iOS,"com.purrington.hotel.unitypreview");
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.Portrait;
            PlayerSettings.defaultScreenWidth=430;
            PlayerSettings.defaultScreenHeight=932;
            PlayerSettings.fullScreenMode=FullScreenMode.Windowed;
            PlayerSettings.resizableWindow=true;
            PlayerSettings.runInBackground=true;
            PlayerSettings.colorSpace=ColorSpace.Linear;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures=AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion=AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.iOS.targetOSVersionString="15.0";
            EditorSettings.serializationMode=SerializationMode.ForceText;
            QualitySettings.vSyncCount=0;
            QualitySettings.antiAliasing=4;
            QualitySettings.shadows=UnityEngine.ShadowQuality.All;
            QualitySettings.shadowDistance=45;
            QualitySettings.shadowResolution=UnityEngine.ShadowResolution.High;
            ConfigureRendering();
            var settings=new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
            var input=settings.FindProperty("activeInputHandler");if(input!=null){input.intValue=1;settings.ApplyModifiedPropertiesWithoutUndo();}
            if(Resources.Load<TMP_Settings>("TMP Settings")==null)
            {
                TMP_PackageResourceImporter.ImportResources(true,false,false);
                AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            }
            TMP_Settings.LoadDefaultSettings();
            Font("Nunito");Font("Fredoka");
            Content();
            var shader=Shader.Find("Universal Render Pipeline/Lit");
            if(shader==null)throw new InvalidOperationException("URP Lit shader is required.");
            if(AssetDatabase.LoadAssetAtPath<Material>("Assets/Resources/WorldMaterial.mat")==null)
                AssetDatabase.CreateAsset(new Material(shader),"Assets/Resources/WorldMaterial.mat");
            GlowMaterial();
            var waterShader=Shader.Find("Purrington/Authored Water");
            if(waterShader==null)throw new InvalidOperationException("Authored water shader is required.");
            if(AssetDatabase.LoadAssetAtPath<Material>("Assets/Resources/AuthoredWater.mat")==null)
                AssetDatabase.CreateAsset(new Material(waterShader),"Assets/Resources/AuthoredWater.mat");
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            var root=new GameObject("Purrington Hotel");root.AddComponent<HotelApp>();root.AddComponent<HotelAudio>();
            var volume=new GameObject("Warm voxel grading").AddComponent<Volume>();volume.isGlobal=true;
            volume.sharedProfile=AssetDatabase.LoadAssetAtPath<VolumeProfile>("Assets/Resources/ParityGrading.asset");
            PrefabUtility.SaveAsPrefabAsset(root,Root+"/Prefabs/HotelRuntime.prefab");
            EditorSceneManager.SaveScene(scene,Root+"/Scenes/Bootstrap.unity");
            // Named world/care scenes are explicit authoring entrypoints sharing the same runtime prefab.
            EditorSceneManager.SaveScene(scene,Root+"/Scenes/Meadow.unity",true);
            EditorSceneManager.SaveScene(scene,Root+"/Scenes/CatCare.unity",true);
            EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(Root+"/Scenes/Bootstrap.unity",true)};
            AssetDatabase.SaveAssets();
            Debug.Log("PURRINGTON_SETUP_OK: voxel isometric Meadow, portrait mobile, fresh Unity saves.");
        }

        [MenuItem("Purrington/Apply rendering settings")]
        public static void ConfigureRendering()
        {
            var desktop=ConfigurePipeline("PC",4096,140,4);
            var mobile=ConfigurePipeline("Mobile",2048,100,2);
            GraphicsSettings.defaultRenderPipeline=desktop;
            int original=QualitySettings.GetQualityLevel();
            for(int i=0;i<QualitySettings.names.Length;i++)
            {
                QualitySettings.SetQualityLevel(i,false);
                QualitySettings.renderPipeline=QualitySettings.names[i].IndexOf("Mobile",StringComparison.OrdinalIgnoreCase)>=0?mobile:desktop;
                QualitySettings.antiAliasing=4;
            }
            QualitySettings.SetQualityLevel(original,false);
            var renderer=AssetDatabase.LoadAssetAtPath<UniversalRendererData>("Assets/Settings/PC_Renderer.asset");
            foreach(var feature in renderer.rendererFeatures)
            {
                if(feature==null||feature.GetType().Name!="ScreenSpaceAmbientOcclusion")continue;
                feature.SetActive(true);
                var data=new SerializedObject(feature);
                Set(data,"m_Settings.Intensity",.32f);Set(data,"m_Settings.Radius",.22f);
                Set(data,"m_Settings.DirectLightingStrength",.15f);
                Set(data,"m_Settings.Downsample",false);data.ApplyModifiedPropertiesWithoutUndo();
                EditorUtility.SetDirty(feature);
            }
            AddMobileSsao(renderer);
            GlowMaterial();
            const string path="Assets/Resources/ParityGrading.asset";
            var profile=AssetDatabase.LoadAssetAtPath<VolumeProfile>(path);
            if(profile==null){profile=ScriptableObject.CreateInstance<VolumeProfile>();AssetDatabase.CreateAsset(profile,path);}
            T Get<T>() where T:VolumeComponent{if(!profile.TryGet<T>(out var c)){c=profile.Add<T>(true);AssetDatabase.AddObjectToAsset(c,profile);}c.active=true;EditorUtility.SetDirty(c);return c;}
            var colors=Get<ColorAdjustments>();colors.contrast.Override(6);colors.saturation.Override(20);colors.postExposure.Override(.1f);
            Get<Tonemapping>().mode.Override(TonemappingMode.Neutral);
            var bloom=Get<Bloom>();bloom.threshold.Override(1f);bloom.intensity.Override(.4f);bloom.scatter.Override(.7f);bloom.tint.Override(new Color(1f,.96f,.9f));bloom.highQualityFiltering.Override(false);
            var split=Get<SplitToning>();split.highlights.Override(new Color(.97f,.93f,.87f));split.shadows.Override(new Color(.68f,.74f,.86f));split.balance.Override(0);
            Get<LiftGammaGain>().lift.Override(new Vector4(1f,1f,1f,.03f));
            var balance=Get<WhiteBalance>();balance.temperature.Override(0);balance.tint.Override(0);
            if(profile.TryGet<Vignette>(out var vignette)){profile.Remove<Vignette>();UnityEngine.Object.DestroyImmediate(vignette,true);}
            EditorUtility.SetDirty(profile);
            AssetDatabase.SaveAssets();
        }
        // URP Lit's _EMISSION is a shader_feature: player builds keep that variant only if a built material enables it.
        // Glass and lamp materials clone this template at runtime, so their night glow survives variant stripping.
        public static Material GlowMaterial()
        {
            const string path="Assets/Resources/WorldGlowMaterial.mat";
            var shader=Shader.Find("Universal Render Pipeline/Lit");
            if(shader==null)throw new InvalidOperationException("URP Lit shader is required.");
            var material=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(material==null){material=new Material(shader);AssetDatabase.CreateAsset(material,path);}
            material.shader=shader;material.enableInstancing=true;material.SetColor("_EmissionColor",Color.black);
            // RealtimeEmissive, not None: URP's material postprocessor re-derives _EMISSION from these flags on import and would clear it.
            material.globalIlluminationFlags=MaterialGlobalIlluminationFlags.RealtimeEmissive;material.EnableKeyword("_EMISSION");
            EditorUtility.SetDirty(material);AssetDatabase.SaveAssets();
            return material;
        }
        // Mobile gets its own SSAO copy of the desktop feature: downsampled, low samples, soft contact shading.
        static void AddMobileSsao(UniversalRendererData desktop)
        {
            var mobile=AssetDatabase.LoadAssetAtPath<UniversalRendererData>("Assets/Settings/Mobile_Renderer.asset");
            if(mobile==null)throw new FileNotFoundException("Missing Mobile_Renderer");
            var feature=mobile.rendererFeatures.FirstOrDefault(f=>f!=null&&f.GetType().Name=="ScreenSpaceAmbientOcclusion");
            if(feature==null)
            {
                var source=desktop.rendererFeatures.First(f=>f!=null&&f.GetType().Name=="ScreenSpaceAmbientOcclusion");
                feature=UnityEngine.Object.Instantiate(source);feature.name=source.name;
                AssetDatabase.AddObjectToAsset(feature,mobile);
                var data=new SerializedObject(mobile);
                var list=data.FindProperty("m_RendererFeatures");list.arraySize++;list.GetArrayElementAtIndex(list.arraySize-1).objectReferenceValue=feature;
                AssetDatabase.TryGetGUIDAndLocalFileIdentifier(feature,out string _,out long id);
                var ids=data.FindProperty("m_RendererFeatureMap");ids.arraySize++;ids.GetArrayElementAtIndex(ids.arraySize-1).longValue=id;
                data.ApplyModifiedPropertiesWithoutUndo();
            }
            feature.SetActive(true);
            var settings=new SerializedObject(feature);
            Set(settings,"m_Settings.Intensity",.4f);Set(settings,"m_Settings.Radius",.25f);Set(settings,"m_Settings.DirectLightingStrength",.15f);
            Set(settings,"m_Settings.Downsample",true);
            var samples=settings.FindProperty("m_Settings.Samples");if(samples!=null)samples.enumValueIndex=samples.enumNames.Length-1; // lowest sample count
            settings.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(feature);EditorUtility.SetDirty(mobile);
        }
        static UniversalRenderPipelineAsset ConfigurePipeline(string name,int resolution,float distance,int cascades)
        {
            var asset=AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>("Assets/Settings/"+name+"_RPAsset.asset");
            if(asset==null)throw new FileNotFoundException("Missing "+name+" render pipeline");
            var data=new SerializedObject(asset);
            Set(data,"m_RenderScale",1f);Set(data,"m_MSAA",4);Set(data,"m_MainLightShadowmapResolution",resolution);
            Set(data,"m_ShadowDistance",distance);Set(data,"m_ShadowCascadeCount",cascades);
            Set(data,"m_MainLightShadowsSupported",true);Set(data,"m_SoftShadowsSupported",true);
            data.ApplyModifiedPropertiesWithoutUndo();EditorUtility.SetDirty(asset);
            return asset;
        }
        static void Set(SerializedObject data,string name,float value){var p=data.FindProperty(name);if(p==null)throw new MissingFieldException(name);p.floatValue=value;}
        static void Set(SerializedObject data,string name,int value){var p=data.FindProperty(name);if(p==null)throw new MissingFieldException(name);p.intValue=value;}
        static void Set(SerializedObject data,string name,bool value){var p=data.FindProperty(name);if(p==null)throw new MissingFieldException(name);p.boolValue=value;}

        static void Font(string name)
        {
            var path="Assets/Resources/Fonts/"+name+" SDF.asset";
            var font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(path);
            if(font==null)
            {
                var source=AssetDatabase.LoadAssetAtPath<UnityEngine.Font>("Assets/Resources/Fonts/"+name+".ttf");
                if(source==null)throw new FileNotFoundException("Missing licensed font "+name);
                font=TMP_FontAsset.CreateFontAsset(source);
                font.name=name+" SDF";
                AssetDatabase.CreateAsset(font,path);
                foreach(var atlas in font.atlasTextures)AssetDatabase.AddObjectToAsset(atlas,font);
                AssetDatabase.AddObjectToAsset(font.material,font);
            }
            font.normalStyle=.75f;font.boldStyle=1.5f;
            font.material.SetFloat("_WeightNormal",font.normalStyle);
            font.material.SetFloat("_WeightBold",font.boldStyle);
            font.TryAddCharacters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 !?.,:;+-/%()'\"·→");
            EditorUtility.SetDirty(font);
            EditorUtility.SetDirty(font.material);
        }

        sealed class SeedStore : ISaveStore
        {
            public HotelState Load()=>null;
            public bool Save(HotelState state)=>true;
        }
        static void Content()
        {
            const string cataloguePath="Assets/Resources/Content/Catalogue.asset";
            if(AssetDatabase.LoadAssetAtPath<ItemCatalogDefinition>(cataloguePath)==null)
            {
                var catalogue=ScriptableObject.CreateInstance<ItemCatalogDefinition>();catalogue.items=Catalog.All;
                AssetDatabase.CreateAsset(catalogue,cataloguePath);
            }
            const string meadowPath="Assets/Resources/Content/Meadow.asset";
            if(AssetDatabase.LoadAssetAtPath<MeadowDefinition>(meadowPath)==null)
            {
                var model=new HotelModel(new SeedStore());model.LoadOrCreate();
                var meadow=ScriptableObject.CreateInstance<MeadowDefinition>();meadow.starterHotel=model.State;
                AssetDatabase.CreateAsset(meadow,meadowPath);
            }
        }

        [MenuItem("Purrington/Build Windows preview")]
        public static void BuildWindows()=>Build(BuildTarget.StandaloneWindows64,"Windows/PurringtonHotel.exe");
        public static void ConfigureAndBuildWindows(){Configure();BuildWindows();}
        [MenuItem("Purrington/Build Android preview")]
        public static void BuildAndroid()=>Build(BuildTarget.Android,"Android/PurringtonHotel.apk");
        [MenuItem("Purrington/Export iOS project")]
        public static void BuildIOS()=>Build(BuildTarget.iOS,"iOS");
        static void Build(BuildTarget target,string destination)
        {
            var output=Path.GetFullPath(Path.Combine(Application.dataPath,"../../../builds/unity",destination));
            Directory.CreateDirectory(Path.GetDirectoryName(output));
            var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions{scenes=EditorBuildSettings.scenes.Where(x=>x.enabled).Select(x=>x.path).ToArray(),locationPathName=output,target=target,options=BuildOptions.Development});
            if(report.summary.result!=BuildResult.Succeeded)throw new InvalidOperationException("Build failed: "+report.summary.result);
            Debug.Log("PURRINGTON_BUILD_OK "+output);
        }
    }
}
