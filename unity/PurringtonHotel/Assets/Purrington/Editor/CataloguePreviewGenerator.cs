using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Presentation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace Purrington.Editor
{
    public static class CataloguePreviewGenerator
    {
        const string Output = "Assets/Resources/Art/build-previews";
        const int Resolution = 384;

        [MenuItem("Purrington/Art/Regenerate catalogue previews")]
        public static void GenerateAll()
        {
            if(EditorApplication.isPlaying)throw new InvalidOperationException("Stop Play mode before generating catalogue previews.");
            Directory.CreateDirectory(Output);
            var scene=EditorSceneManager.NewPreviewScene();
            var oldAmbient=RenderSettings.ambientLight;
            var oldMode=RenderSettings.ambientMode;
            var oldActive=RenderTexture.active;
            GodotGeometry geometry=null;
            var target=new RenderTexture(Resolution,Resolution,24,RenderTextureFormat.ARGB32){antiAliasing=4};
            var pixels=new Texture2D(Resolution,Resolution,TextureFormat.RGBA32,false);
            int count=0;
            try
            {
                geometry=new GodotGeometry();
                RenderSettings.ambientMode=AmbientMode.Flat;
                RenderSettings.ambientLight=ConceptTheme.ColorOf("E9E0C9")*.78f;
                var camera=Create(scene,"Catalogue camera").AddComponent<Camera>();
                camera.enabled=false;camera.orthographic=true;camera.nearClipPlane=.01f;camera.farClipPlane=100;
                camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=ConceptTheme.Cream;
                camera.scene=scene;camera.targetTexture=target;camera.allowHDR=false;
                camera.transform.rotation=Quaternion.Euler(30,315,0);
                camera.GetUniversalAdditionalCameraData().renderPostProcessing=false;
                var light=Create(scene,"Soft golden catalogue light").AddComponent<Light>();
                light.type=LightType.Directional;light.intensity=1.12f;light.color=ConceptTheme.ColorOf("FFF0D5");
                light.transform.rotation=Quaternion.Euler(46,28,0);light.shadows=LightShadows.Soft;light.shadowStrength=.48f;
                foreach(var item in geometry.Data["items"])
                {
                    string id=(string)item["id"];
                    var holder=Create(scene,id);holder.transform.localScale=new Vector3(1,1,-1);
                    try
                    {
                        var root=geometry.Build(holder.transform,(JObject)item["root"]);
                        var renderers=root.GetComponentsInChildren<MeshRenderer>();
                        if(renderers.Length==0)throw new InvalidOperationException("No model surfaces for "+id);
                        var bounds=renderers[0].bounds;
                        foreach(var renderer in renderers.Skip(1))bounds.Encapsulate(renderer.bounds);
                        var inverse=Quaternion.Inverse(camera.transform.rotation);
                        float halfWidth=0,halfHeight=0;
                        for(int i=0;i<8;i++)
                        {
                            var corner=inverse*Vector3.Scale(bounds.extents,new Vector3((i&1)==0?-1:1,(i&2)==0?-1:1,(i&4)==0?-1:1));
                            halfWidth=Mathf.Max(halfWidth,Mathf.Abs(corner.x));halfHeight=Mathf.Max(halfHeight,Mathf.Abs(corner.y));
                        }
                        camera.orthographicSize=Mathf.Max(.3f,Mathf.Max(halfWidth,halfHeight)*1.18f);
                        camera.transform.position=bounds.center-camera.transform.forward*25;
                        camera.Render();RenderTexture.active=target;
                        pixels.ReadPixels(new Rect(0,0,Resolution,Resolution),0,0);pixels.Apply();
                        string path=Output+"/"+id.Replace('_','-')+".png";
                        File.WriteAllBytes(path,pixels.EncodeToPNG());
                        AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
                        var importer=(TextureImporter)AssetImporter.GetAtPath(path);
                        importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Single;
                        importer.mipmapEnabled=false;importer.alphaIsTransparency=true;importer.maxTextureSize=512;
                        importer.textureCompression=TextureImporterCompression.Uncompressed;importer.filterMode=FilterMode.Bilinear;
                        importer.SaveAndReimport();
                        if(!AssetDatabase.LoadAssetAtPath<Sprite>(path))throw new InvalidOperationException("Sprite import failed: "+path);
                        count++;
                    }
                    finally { UnityEngine.Object.DestroyImmediate(holder); }
                }
                if(count<38)throw new InvalidOperationException("Catalogue preview coverage incomplete: "+count);
                AssetDatabase.SaveAssets();
                Debug.Log("Catalogue previews generated and verified: "+count+" actual-model sprites in "+Output);
            }
            finally
            {
                RenderTexture.active=oldActive;RenderSettings.ambientMode=oldMode;RenderSettings.ambientLight=oldAmbient;
                geometry?.Dispose();UnityEngine.Object.DestroyImmediate(pixels);target.Release();UnityEngine.Object.DestroyImmediate(target);
                EditorSceneManager.ClosePreviewScene(scene);
            }
        }
        static GameObject Create(Scene scene,string name)
        {
            var value=new GameObject(name);SceneManager.MoveGameObjectToScene(value,scene);return value;
        }
    }
}

