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
  public static JObject Recipe(string coat,string markings){
   var content=TownContent.Current;if(!content.HasCoat(coat)||!content.HasMarkings(markings))throw new ArgumentException("Unknown manager appearance");
   string fur=content.CoatColor(coat),ink=coat=="charcoal"||coat=="cocoa"?"F8F3E3":"244335",pattern=coat=="cream"?"80634E":"EAD6AF";
   var root=Node("Manager cat",Vector3.zero,Vector3.one);var body=Add(root,"Body",Vector3.zero,Vector3.one,null,"body");
   Add(body,"Fur torso",new Vector3(0,.53f,0),new Vector3(.55f,.48f,.75f),fur);
   var head=Add(body,"Head",new Vector3(0,.91f,.28f),Vector3.one,null,"head");Add(head,"Fur head",Vector3.zero,new Vector3(.66f,.48f,.49f),fur);
   for(int i=0;i<2;i++){
    float x=i==0?-.21f:.21f;var ear=Add(head,"Ear",new Vector3(x,.3f,0),new Vector3(.18f,.24f,.20f),fur,"ears."+i);Add(ear,"Inner ear",new Vector3(0,0,.52f),new Vector3(.48f,.58f,.1f),"D6A182");
    Add(head,"Eye",new Vector3(x*.72f,.035f,.255f),new Vector3(.075f,.09f,.028f),ink,"eyes."+i);
   }
   Add(head,"Nose",new Vector3(0,-.08f,.28f),new Vector3(.08f,.06f,.06f),"D6A182");Add(head,"Mouth",new Vector3(0,-.14f,.285f),new Vector3(.025f,.04f,.02f),ink,"mouth");
   for(int i=0;i<4;i++){var leg=Add(body,"Leg",new Vector3(i<2?-.19f:.19f,.27f,i%2==0?-.25f:.25f),Vector3.one,null,"legs."+i);Add(leg,"Fur paw",new Vector3(0,-.08f,0),new Vector3(.19f,.30f,.22f),markings=="tuxedo"?pattern:fur);}
   var tail=Add(body,"Tail",new Vector3(0,.55f,-.37f),Vector3.one,null,"tail");Add(tail,"Fur tail",new Vector3(0,.19f,-.09f),new Vector3(.15f,.52f,.16f),fur);
   if(markings=="tuxedo")Add(body,"Marking bib",new Vector3(0,.59f,.382f),new Vector3(.33f,.35f,.035f),pattern);
   if(markings=="tabby")for(int i=0;i<3;i++)foreach(float side in new[]{-1f,1f})Add(body,"Marking stripe",new Vector3(side*.28f,.57f,-.25f+i*.23f),new Vector3(.025f,.34f,.065f),pattern);
   if(markings=="patchwork"){Add(head,"Marking crown",new Vector3(-.17f,.246f,0),new Vector3(.27f,.025f,.35f),pattern);Add(body,"Marking flank",new Vector3(.28f,.54f,-.1f),new Vector3(.025f,.3f,.32f),pattern);Add(body,"Marking back",new Vector3(-.05f,.78f,-.15f),new Vector3(.35f,.025f,.25f),"BF7958");}
   Add(head,"Head wear binding",new Vector3(0,.25f,0),Vector3.one,null,"wear.head");Add(body,"Neck wear binding",new Vector3(0,.77f,.27f),Vector3.one,null,"wear.neck");Add(body,"Back wear binding",new Vector3(0,.79f,-.08f),Vector3.one,null,"wear.back");
   return root;
  }
 }
}
