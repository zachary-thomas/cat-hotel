using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.Rendering;

namespace Purrington.Presentation {
// Recipes are exported by executing the original Godot constructors. Affine part
// matrices are applied to mesh vertices, so nonuniform scale and shear survive.
public sealed class GodotGeometry : IDisposable {
 public readonly JObject Data;
 readonly Dictionary<string,Material> materials=new Dictionary<string,Material>();
 readonly Dictionary<string,Mesh> meshes=new Dictionary<string,Mesh>();
 readonly Dictionary<string,Mesh> primitives=new Dictionary<string,Mesh>();
 readonly List<Material> glass=new List<Material>();readonly Dictionary<Material,Material> twins=new Dictionary<Material,Material>();
 public static readonly Color GlowColor=new Color(1f,.835f,.565f);float glowLevel=0;
 static string BaseHex(string key){string hex=key.Split('~')[0].Split('|')[0].TrimStart('#');return hex.Length>=6?hex.Substring(0,6):hex;}
 static bool Varies(string hex){return !hex.StartsWith("water|")&&!SurfacePalette.Glows(BaseHex(hex));}
 public Material Material(string hex,Vector3 position){hex=hex??"#ffffffff";if(!Varies(hex))return Material(hex);int v=SurfacePalette.Variant(position.x,position.y,position.z);return Material(v==0?hex:hex+"~"+v);}
 // Glow changes almost every frame at dawn and dusk: walk only the glass list, and skip steps under 0.01 (but always land on 0).
 public void SetGlow(float level){if(Mathf.Abs(level-glowLevel)<.01f&&(level!=0||glowLevel==0))return;glowLevel=level;foreach(var m in glass)if(m)Emit(m);}
 // Builds strip URP Lit's _EMISSION shader_feature unless a Resources material keeps it, so glow-capable materials clone WorldGlowMaterial.
 static Material Lit(bool glow){var template=glow?Resources.Load<Material>("WorldGlowMaterial"):null;return template?new Material(template):new Material(Shader.Find("Universal Render Pipeline/Lit"));}
 public Material GlowTwin(Material source){if(!source)return source;if(twins.TryGetValue(source,out var m))return m;m=Lit(true);m.color=source.color;m.enableInstancing=true;m.SetFloat("_Smoothness",source.HasProperty("_Smoothness")?source.GetFloat("_Smoothness"):.12f);m.EnableKeyword("_EMISSION");m.globalIlluminationFlags=MaterialGlobalIlluminationFlags.None;m.SetColor("_EmissionColor",Color.black);twins.Add(source,m);return m;}
 void Emit(Material m){m.EnableKeyword("_EMISSION");m.globalIlluminationFlags=MaterialGlobalIlluminationFlags.None;m.SetColor("_EmissionColor",GlowColor*glowLevel);}
 public GodotGeometry() { var asset=Resources.Load<TextAsset>("Content/GodotGeometry"); if(!asset) throw new InvalidOperationException("Missing required Godot geometry export"); Data=JObject.Parse(asset.text); }
 public JObject Recipe(string collection,string id) { foreach(var r in Data[collection]??new JArray()) if((string)r["id"]==id) return (JObject)r["root"]; throw new InvalidOperationException("Missing authored geometry: "+collection+"/"+id); }
 public JObject Map(int index) { return (JObject)Data["maps"][index]; }
 // Owned-lot recipes predate the concept color pass. Lawns reuse the world's own ground swatch so owned land never reads as a pasted tile.
 public static string LawnColor(JObject ground) { string best=null;double area=-1;void Walk(JToken n){foreach(var p in n["parts"]??new JArray()){var t=p["transform"] as JArray;double a=t==null||t.Count!=12?0:Math.Abs((double)t[0]*(double)t[8]);if(a>area){area=a;best=(string)p["color"];}}foreach(var c in n["children"]??new JArray())Walk(c);}Walk(ground);return best??"#83a36eff"; }
 public static JObject Recolor(JObject recipe,string color) { var copy=(JObject)recipe.DeepClone();foreach(var p in copy.SelectTokens("..parts[*]").OfType<JObject>().ToList())p["color"]=color;return copy; }
 public static JObject VisibleParcel(JObject parcel,bool owned) => owned?null:(JObject)parcel["root"];
 public Material Material(string hex) { hex=hex??"#ffffffff"; if(materials.TryGetValue(hex,out var m))return m; int variant=0;string swatch=hex;int tilde=hex.IndexOf('~');if(tilde>0){int.TryParse(hex.Substring(tilde+1),out variant);swatch=hex.Substring(0,tilde);} bool water=swatch.StartsWith("water|");var fields=water?swatch.Split('|'):null;string value=water?fields[1]:swatch;ColorUtility.TryParseHtmlString(value.StartsWith("#")?value:"#"+value,out var color); if(!water)color=ConceptTheme.Surface(value); if(variant>0){var toned=ConceptTheme.ColorOf(SurfacePalette.Tone(ColorUtility.ToHtmlStringRGB(color),variant));toned.a=color.a;color=toned;} bool glassy=!water&&SurfacePalette.Glows(BaseHex(swatch));m=water?new Material(Shader.Find("Purrington/Authored Water")):Lit(glassy);m.color=color;m.enableInstancing=true;if(water){m.SetColor("_BaseColor",color);m.SetFloat("_ShoreZ",float.Parse(fields[2],System.Globalization.CultureInfo.InvariantCulture));}if(!water)m.SetFloat("_Smoothness",.12f); if(glassy){glass.Add(m);Emit(m);} materials.Add(hex,m);return m; }
 public static Matrix4x4 Matrix(JToken value) { if(!(value is JArray a)||a.Count!=12)return Matrix4x4.identity; var m=Matrix4x4.identity;for(int c=0;c<4;c++) for(int r=0;r<3;r++)m[r,c]=(float)a[c*3+r];return m; }
 Mesh Primitive(string kind) { if(primitives.TryGetValue(kind,out var mesh))return mesh;var g=GameObject.CreatePrimitive(kind=="sphere"?PrimitiveType.Sphere:kind=="cylinder"?PrimitiveType.Cylinder:kind=="plane"?PrimitiveType.Plane:PrimitiveType.Cube);mesh=g.GetComponent<MeshFilter>().sharedMesh; Release(g);primitives[kind]=mesh;return mesh; }
 // Optional build-time filter on each part's world position; false skips the part. Used to clear lots for new town buildings.
 public System.Func<Vector3,bool> PartFilter;
 // Optional Unity-side recolor of exported swatches (per-destination ground tuning); exported JSON stays untouched.
 public System.Func<string,string> ColorMap;
 public Transform Build(Transform parent,JObject recipe,Dictionary<string,Transform> bindings=null) {return BuildAffine(parent,recipe,bindings,Matrix4x4.identity); }
 Transform BuildAffine(Transform parent,JObject recipe,Dictionary<string,Transform> bindings,Matrix4x4 carry,bool villageRoad=false) {
  if(recipe==null)throw new InvalidOperationException("Null authored geometry recipe");
  villageRoad=villageRoad||(string)recipe["name"]=="VillageRoad";
  var t=new GameObject((string)recipe["name"]??"Authored part").transform;t.SetParent(parent,false);var authored=carry*Matrix(recipe["transform"]);Apply(t,authored);var residual=Matrix4x4.TRS(t.localPosition,t.localRotation,t.localScale).inverse*authored;
  if(recipe["meta"] is JObject metadata && metadata.HasValues)t.gameObject.AddComponent<GodotNodeMetadata>().Values=metadata;t.gameObject.SetActive((bool?)recipe["visible"]??true);string binding=(string)recipe["binding"];if(bindings!=null&&!string.IsNullOrEmpty(binding))bindings[binding]=t;
  var parts=recipe["parts"] as JArray;if(parts!=null){var batches=new Dictionary<string,List<CombineInstance>>();foreach(var p in parts){if(PartFilter!=null){var at=(t.localToWorldMatrix*residual*Matrix(p["transform"])).GetColumn(3);if(!PartFilter(new Vector3(at.x,at.y,at.z)))continue;}string color=(string)p["color"]??"#ffffffff";if(ColorMap!=null)color=ColorMap(color);if(villageRoad&&color.StartsWith("#f0d8c0",StringComparison.OrdinalIgnoreCase))color="#BBB6A5";if((string)p["material"]=="water")color="water|"+((string)p["water"]?["deep_color"]??color)+"|"+((float?)p["water"]?["shore_z"]??-1000).ToString("R",System.Globalization.CultureInfo.InvariantCulture);if(!color.StartsWith("water|")){var world=(authored*Matrix(p["transform"])).GetColumn(3);int v=Varies(color)?SurfacePalette.Variant(world.x,world.y,world.z):0;if(v>0)color+="~"+v;}if(!batches.TryGetValue(color,out var list))batches[color]=list=new List<CombineInstance>(); list.Add(new CombineInstance{mesh=Primitive((string)p["mesh"]??"cube"),transform=residual*Matrix(p["transform"])});}foreach(var batch in batches){var go=new GameObject("Authored surfaces");go.transform.SetParent(t,false);var mesh=SharedMesh(batch.Value);go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<MeshRenderer>().sharedMaterial=Material(batch.Key);}}
  if(recipe["text"]!=null){var text=t.gameObject.AddComponent<TextMesh>();text.text=(string)recipe["text"];text.fontSize=48;text.characterSize=((float?)recipe["pixelSize"]??.006f)*10;text.anchor=TextAnchor.MiddleCenter;ColorUtility.TryParseHtmlString((string)recipe["color"]??"#fff5de",out var color);text.color=color;if((bool?)recipe["billboard"]??false)t.gameObject.AddComponent<VoxelBillboard>();}
  foreach(var child in recipe["children"]??new JArray())BuildAffine(t,(JObject)child,bindings,residual,villageRoad);return t;
 }
 Mesh SharedMesh(List<CombineInstance> parts){if(parts.Count==1&&parts[0].transform==Matrix4x4.identity)return parts[0].mesh;var key=new System.Text.StringBuilder();foreach(var p in parts){key.Append(p.mesh.GetInstanceID());for(int i=0;i<16;i++)key.Append('|').Append(p.transform[i].ToString("R",System.Globalization.CultureInfo.InvariantCulture));}string id=key.ToString();if(meshes.TryGetValue(id,out var found))return found;var mesh=new Mesh{indexFormat=IndexFormat.UInt32};mesh.CombineMeshes(parts.ToArray());mesh.RecalculateBounds();meshes.Add(id,mesh);return mesh;}
 public static void Apply(Transform t,Matrix4x4 m){t.localPosition=m.GetColumn(3);t.localRotation=m.rotation;t.localScale=m.lossyScale;}
 static void Release(UnityEngine.Object value){if(Application.isPlaying)UnityEngine.Object.Destroy(value);else UnityEngine.Object.DestroyImmediate(value);}
 public void Dispose(){foreach(var m in materials.Values)Release(m);foreach(var m in twins.Values)Release(m);glass.Clear();twins.Clear();foreach(var m in meshes.Values)Release(m);}
}
public sealed class GodotNodeMetadata:MonoBehaviour{public JObject Values;}
public sealed class VoxelBillboard:MonoBehaviour{void LateUpdate(){if(Camera.main)transform.rotation=Camera.main.transform.rotation;}}
}





