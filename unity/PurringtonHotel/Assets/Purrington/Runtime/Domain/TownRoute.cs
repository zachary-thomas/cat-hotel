using System;
using System.Collections.Generic;
using System.Linq;

namespace Purrington.Domain
{
 public static class TownRoute
 {
  public static List<LotPoint> Find(TownContent content,LotPoint start,string targetId)
  {
   var empty=new List<LotPoint>();
   if(content==null||!content.IsStreetTarget(targetId))return empty;
   if(float.IsNaN(start.x)||float.IsNaN(start.z)||float.IsInfinity(start.x)||float.IsInfinity(start.z))return empty;
   // Saved street positions may lie between nodes. Join only the authored link
   // containing the start; an arbitrary nearby point must not create a shortcut.
   string linkA=null,linkB=null;float nearest=float.MaxValue;
   foreach(var a in content.StreetIds)foreach(var b in content.Neighbors(a))
   {
    if(string.CompareOrdinal(a,b)>=0)continue;
    var pa=content.Point(a);var pb=content.Point(b);
    float dx=pb.x-pa.x,dz=pb.z-pa.z,length2=dx*dx+dz*dz;
    if(length2<.000001f)continue;
    float t=Math.Max(0,Math.Min(1,((start.x-pa.x)*dx+(start.z-pa.z)*dz)/length2));
    var projected=new LotPoint(pa.x+t*dx,pa.z+t*dz);
    float gap=start.Distance(projected);
    if(gap<nearest){nearest=gap;linkA=a;linkB=b;}
   }
   if(linkA==null||nearest>.0001f)return empty;
   var distance=new Dictionary<string,float>(StringComparer.Ordinal)
   {
    {linkA,start.Distance(content.Point(linkA))},
    {linkB,start.Distance(content.Point(linkB))}
   };
   var previous=new Dictionary<string,string>(StringComparer.Ordinal);
   var remaining=new HashSet<string>(content.StreetIds,StringComparer.Ordinal);
   while(remaining.Count>0)
   {
    string current=remaining.Where(distance.ContainsKey).OrderBy(id=>distance[id]).ThenBy(id=>id,StringComparer.Ordinal).FirstOrDefault();
    if(current==null)break;
    remaining.Remove(current);
    if(current==targetId)
    {
     var ids=new List<string>{current};
     while(previous.TryGetValue(current,out string prior)){current=prior;ids.Add(current);}
     ids.Reverse();
     var points=ids.Select(content.Point).ToList();
     if(start.Distance(points[0])>.001f)points.Insert(0,start);
     return points;
    }
    foreach(var neighbor in content.Neighbors(current))
    {
     if(!remaining.Contains(neighbor))continue;
     float next=distance[current]+content.Point(current).Distance(content.Point(neighbor));
     if(!distance.TryGetValue(neighbor,out float old)||next<old){distance[neighbor]=next;previous[neighbor]=current;}
    }
   }
   return empty;
  }
 }
}
