using System;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 public static class ManagerCatArt {
  public static readonly string[] Coats={"honey","cream","ginger","cocoa","gray","charcoal"};
  public static readonly string[] Markings={"solid","tuxedo","tabby","patchwork"};
  static JArray Matrix(Vector3 p,Vector3 s)=>new JArray(s.x,0,0,0,s.y,0,0,0,s.z,p.x,p.y,p.z);
  internal static JObject Node(string name,Vector3 at,Vector3 size,string color=null,string binding=null){
   var node=new JObject{{"name",name},{"transform",Matrix(at,size)},{"children",new JArray()}};
   if(binding!=null)node["binding"]=binding;
   if(color!=null)node["parts"]=new JArray(new JObject{{"mesh","cube"},{"color",color},{"transform",Matrix(Vector3.zero,Vector3.one)}});
   return node;
  }
  static JObject Add(JObject parent,string name,Vector3 at,Vector3 size,string color=null,string binding=null){var node=Node(name,at,size,color,binding);((JArray)parent["children"]).Add(node);return node;}
  // Town cats reuse the hotel's own voxel cat so everyone shares one silhouette. Coat recolors the fur; markings choose the shade parts.
  const string BaseFur="#d99c51",BaseShade="#b07e42",BaseInk="#28352d";
  public static JObject Recipe(GodotGeometry geometry,string coat,string markings){
   var content=TownContent.Current;if(!content.HasCoat(coat)||!content.HasMarkings(markings))throw new ArgumentException("Unknown manager appearance");
   string fur=content.CoatColor(coat).TrimStart('#');
   string shade=markings=="tuxedo"?"F4EAD5":markings=="patchwork"?(Luma(fur)>.6f?"C4843F":"EAD6AF"):Scale(fur,markings=="tabby"?.66f:.82f);
   var root=(JObject)geometry.Recipe("cats","0").DeepClone();root["name"]="Manager cat";
   // Dark coats get cream eyes and whiskers so the face still reads.
   Recolor(root,"#"+fur,"#"+shade,Luma(fur)<.35f?"#E9DDB8":BaseInk);
   return root;
  }
  static void Recolor(JToken node,string fur,string shade,string ink){
   if(node["parts"] is JArray parts)foreach(var part in parts){string c=(string)part["color"]??"";if(c.StartsWith(BaseFur,StringComparison.OrdinalIgnoreCase))part["color"]=fur+c.Substring(7);else if(c.StartsWith(BaseShade,StringComparison.OrdinalIgnoreCase))part["color"]=shade+c.Substring(7);else if(c.StartsWith(BaseInk,StringComparison.OrdinalIgnoreCase))part["color"]=ink+c.Substring(7);}
   if(node["children"] is JArray children)foreach(var child in children)Recolor(child,fur,shade,ink);
  }
  static float Luma(string hex){ColorUtility.TryParseHtmlString("#"+hex,out var c);return .2126f*c.r+.7152f*c.g+.0722f*c.b;}
  static string Scale(string hex,float k){ColorUtility.TryParseHtmlString("#"+hex,out var c);return ColorUtility.ToHtmlStringRGB(new Color(c.r*k,c.g*k,c.b*k));}
 }
}
