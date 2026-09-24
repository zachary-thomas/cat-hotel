using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // Item tints (B2): a furnishing's colorful parts turn to the chosen hue; wood, neutrals and lights keep their color.
 public sealed partial class VoxelWorld {
  Transform BuildTinted(Transform parent,JObject recipe,int tint){
   if(tint<=0||!Paint.ValidTint(tint))return geometry.Build(parent,recipe);
   var before=geometry.ColorMap;float hue=Paint.TintHues[tint]/360f;
   geometry.ColorMap=c=>TintColor(before!=null?before(c):c,hue);
   try{return geometry.Build(parent,recipe);}finally{geometry.ColorMap=before;}
  }
  public static string TintColor(string color,float hue){
   if(string.IsNullOrEmpty(color))return color;
   string hex=color.TrimStart('#');if(hex.Length<6)return color;string rgb=hex.Substring(0,6),alpha=hex.Substring(6);
   if(SurfacePalette.Glows(rgb)||!ColorUtility.TryParseHtmlString("#"+rgb,out var c))return color;
   Color.RGBToHSV(c,out float h,out float s,out float v);
   bool wood=h>=15/360f&&h<=48/360f&&s<.8f;
   if(s<.22f||v<.25f||wood)return color;
   var tinted=Color.HSVToRGB(hue,Mathf.Max(s,.35f),v);
   return "#"+ColorUtility.ToHtmlStringRGB(tinted)+alpha;
  }
 }
}
