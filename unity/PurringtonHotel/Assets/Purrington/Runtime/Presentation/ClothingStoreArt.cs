using UnityEngine;
using System.Collections.Generic;
namespace Purrington.Presentation {
 public static class ClothingStoreArt {
  public static void Build(GodotGeometry geometry,Transform root,float x){
   void Box(string name,float px,float y,float z,float w,float h,float d,string color){geometry.Build(root,ManagerCatArt.Node(name,new Vector3(x+px,y,z),new Vector3(w,h,d),color));}
   for(int row=0;row<10;row++)for(int col=0;col<6;col++)Box("Boutique floorboard",-3.75f+col*1.5f,.061f,-3.6f+row*.8f,1.47f,.04f,.77f,(row+col)%3==0?"B3824C":"D2AD77");
   foreach(float side in new[]{-3.2f,-1.3f}){
    foreach(float z in new[]{-2.3f,.2f}){Box("Rack upright",side,1.15f,z,.12f,2.2f,.12f,"425C35");Box("Rack foot",side,.12f,z,.75f,.16f,.3f,"B3824C");}
    Box("Rack rail",side,2.2f,-1.05f,.12f,.12f,2.65f,"B3824C");
    foreach(float z in new[]{-1.9f,-1.1f,-.3f}){Box("Hanger",side,2.05f,z,.55f,.1f,.09f,"D2AD77");Box("Hanging garment",side,1.6f,z,.7f,.8f,.3f,z<-1.5f?"BF7958":"738448");}
   }
   Box("Mirror frame",-2.8f,1.45f,3.74f,1.7f,2.35f,.2f,"B3824C");
   Box("Mirror",-2.8f,1.45f,3.6f,1.45f,2.1f,.08f,"DCE5C5");
   Box("Try on platform",-2.8f,.12f,2.45f,1.8f,.22f,1.5f,"D2AD77");
   Box("Checkout counter",2,.65f,2.3f,3.2f,1.15f,1,"B3824C");
   Box("Counter top",2,1.26f,2.3f,3.4f,.12f,1.15f,"EFE2C9");
   Box("Register",2.5f,1.48f,2.35f,.5f,.3f,.4f,"425C35");
   for(int i=0;i<3;i++)Box("Folded clothes",3.15f,1.38f+i*.12f,2.3f,.55f,.1f,.5f,i%2==0?"BF7958":"738448");
   string[] slots={"head","neck","back"};
   for(int i=0;i<3;i++){
    float z=-2.5f+i*1.2f;Box("Display plinth",3.5f,.18f,z,.85f,.35f,.85f,"D2AD77");
    var rig=new GodotCatRig(geometry,root,ManagerCatArt.Recipe("cream","solid"),120+i);
    rig.Root.name=char.ToUpper(slots[i][0])+slots[i].Substring(1)+" display mannequin";
    rig.Root.localPosition=new Vector3(x+3.5f,.36f,z);rig.Root.localScale=Vector3.one*.55f;
    // Reuse catalogue geometry on the same bindings as the fitting cat.
    var item=System.Array.Find(Purrington.Domain.Wardrobe.All,w=>w.slot==slots[i]&&w.giftCat<0&&w.quest==null);
    if(item!=null)CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>{{slots[i],item.id}});
   }
  }
 }
}
