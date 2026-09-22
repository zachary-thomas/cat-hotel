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
   string origin=content.NearestStreetTarget(start,2.5f);
   if(origin==null)return empty;
   var distance=new Dictionary<string,float>(StringComparer.Ordinal){{origin,0}};
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
     while(current!=origin){current=previous[current];ids.Add(current);}
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
