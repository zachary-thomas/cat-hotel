using UnityEngine;
using System.Collections.Generic;
namespace Purrington.Presentation {
 // Fixtures for the three boutique rooms laid out in ShopPlan.Clothing (plan space, -z toward the street door).
 public static class ClothingStoreArt {
  public static void Build(GodotGeometry geometry,Transform root,float x){
   void Box(string name,float px,float y,float z,float w,float h,float d,string color){geometry.Build(root,ManagerCatArt.Node(name,new Vector3(x+px,y,z),new Vector3(w,h,d),color));}
   // Boutique floor: warm boards, two garment racks, a sweater table and the till beside the door.
   for(int row=0;row<7;row++)for(int col=0;col<5;col++)Box("Boutique floorboard",-1.75f+.7f+col*1.4f,.061f,-4.5f+.375f+row*.75f,1.37f,.04f,.72f,(row+col)%3==0?"B3824C":"D2AD77");
   Box("Round rug",.9f,.09f,-2.4f,1.8f,.03f,1.6f,"E6B7C1");Box("Rug centre",.9f,.1f,-2.4f,1.1f,.03f,.9f,"F4F1E8");
   foreach(float side in new[]{-1f,.2f}){
    foreach(float z in new[]{-3.5f,-1.4f}){Box("Rack upright",side,1.15f,z,.12f,2.2f,.12f,"425C35");Box("Rack foot",side,.12f,z,.75f,.16f,.3f,"B3824C");}
    Box("Rack rail",side,2.2f,-2.45f,.12f,.12f,2.3f,"B3824C");
    string[] colors=side<0?new[]{"BF7958","E6B7C1","C9B6E4"}:new[]{"738448","9FB7C9","D7AE55"};
    for(int i=0;i<3;i++){float z=-3.1f+i*.65f;Box("Hanger",side,2.05f,z,.55f,.1f,.09f,"D2AD77");Box("Hanging garment",side,1.6f,z,.7f,.8f,.3f,colors[i]);}
   }
   Box("Sweater table",4.5f,.4f,-3.75f,1.1f,.7f,.7f,"D2AD77");
   for(int i=0;i<3;i++)Box("Folded sweater",4.5f,.8f+i*.1f,-3.75f,.7f,.1f,.45f,i%2==0?"C9B6E4":"F4F1E8");
   Box("Checkout counter",3.85f,.65f,-1.3f,2.4f,1.15f,1,"B3824C");
   Box("Counter top",3.85f,1.26f,-1.3f,2.6f,.12f,1.15f,"EFE2C9");
   Box("Register",4.5f,1.48f,-1.25f,.5f,.3f,.4f,"425C35");
   for(int i=0;i<3;i++)Box("Folded clothes",3.1f,1.38f+i*.12f,-1.3f,.55f,.1f,.5f,i%2==0?"BF7958":"738448");
   PawMartArt.Plant(Box,-1.3f,-4.1f);
   // Fitting room: mirror, try-on platform, a curtained booth and a pouf.
   Box("Fitting rug",-3.5f,.09f,1.2f,2.6f,.03f,2.6f,"C9B6E4");
   Box("Mirror frame",-3.5f,1.45f,4.25f,1.7f,2.35f,.2f,"B3824C");
   Box("Mirror",-3.5f,1.45f,4.12f,1.45f,2.1f,.08f,"DCE5C5");
   Box("Try on platform",-3.5f,.12f,3,1.8f,.22f,1.5f,"D2AD77");
   Box("Curtain rod",-4.45f,2.3f,-.55f,1.3f,.06f,.06f,"D7AE55");
   Box("Changing curtain",-4.45f,1.25f,-.55f,1.2f,2,.08f,"E6B7C1");
   foreach(float dx in new[]{-.4f,0f,.4f})Box("Curtain fold",-4.45f+dx,1.25f,-.6f,.1f,2,.06f,"D98FA3");
   Box("Booth side",-3.85f,1.25f,-1.25f,.08f,2,1.4f,"F4E4D8");
   Box("Pouf",-2.6f,.25f,.5f,.7f,.4f,.7f,"9FB7C9");Box("Pouf button",-2.6f,.46f,.5f,.12f,.04f,.12f,"F4F1E8");
   // Accessory salon: the three slot mannequins, a hat shelf, a jewellery case and a reading chair.
   Box("Salon rug",1.8f,.09f,2.6f,3.6f,.03f,2,"F4F1E8");
   string[] slots={"head","neck","back"};
   for(int i=0;i<3;i++){
    float px=.8f+i*1.4f;Box("Display plinth",px,.18f,3.75f,.85f,.35f,.85f,"D2AD77");
    var rig=new GodotCatRig(geometry,root,ManagerCatArt.Recipe(geometry,"cream","solid"),120+i);
    rig.Root.name=char.ToUpper(slots[i][0])+slots[i].Substring(1)+" display mannequin";
    rig.Root.localPosition=new Vector3(x+px,.36f,3.75f);rig.Root.localScale=Vector3.one*.55f;rig.Root.localRotation=Quaternion.Euler(0,180,0);
    // Reuse catalogue geometry on the same bindings as the fitting cat.
    var item=System.Array.Find(Purrington.Domain.Wardrobe.All,w=>w.slot==slots[i]&&w.giftCat<0&&w.quest==null);
    if(item!=null)CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>{{slots[i],item.id}});
   }
   Box("Hat shelf",4.9f,1.6f,2.4f,.4f,.06f,2,"B3824C");
   foreach(float dz in new[]{-.6f,0f,.6f}){Box("Hat brim",4.9f,1.66f,2.4f+dz,.36f,.04f,.36f,dz==0?"D7AE55":"BF7958");Box("Hat crown",4.9f,1.78f,2.4f+dz,.22f,.2f,.22f,dz==0?"D7AE55":"BF7958");}
   Box("Jewellery case",4.55f,.55f,1.35f,.9f,1,.6f,"B3824C");Box("Jewellery glass",4.55f,1.08f,1.35f,.8f,.06f,.5f,"DCE5C5");
   foreach(float dx in new[]{-.25f,0f,.25f})Box("Brooch",4.55f+dx,1.13f,1.35f,.1f,.04f,.1f,dx==0?"9FB7C9":"E6B7C1");
   Box("Reading chair seat",-.9f,.4f,3.7f,.9f,.3f,.8f,"738448");Box("Reading chair back",-.9f,.85f,4.05f,.9f,.7f,.15f,"738448");
   foreach(float dx in new[]{-.42f,.42f})Box("Chair arm",-.9f+dx,.65f,3.7f,.12f,.3f,.8f,"5F7040");
  }
 }
}
