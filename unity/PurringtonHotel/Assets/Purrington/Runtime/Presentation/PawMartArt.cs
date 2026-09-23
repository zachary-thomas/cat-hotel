using UnityEngine;
namespace Purrington.Presentation {
 public static class PawMartArt {
  public static void Build(GodotGeometry geometry,Transform parent,float origin){
   void Box(string name,float x,float y,float z,float w,float h,float d,string color)=>geometry.Build(parent,ManagerCatArt.Node(name,new Vector3(origin+x,y,z),new Vector3(w,h,d),color));
   for(int row=0;row<16;row++)for(int board=0;board<4;board++){
    float start=-4.35f+board*2.2f+(row%2)*1.1f;float end=Mathf.Min(4.35f,start+2.18f);
    if(start<4.35f)Box("Pale timber floorboard",(start+end)/2,.07f,-3.75f+row*.5f,end-start,.04f,.48f,row%3==0?"C9A674":"D2AD77");
    if(board==0&&row%2==1)Box("Short staggered floorboard",-3.81f,.07f,-3.75f+row*.5f,1.08f,.04f,.48f,"D2AD77");
   }
   // Wall shelving leaves the central cashier approach and both browsing loops clear.
   foreach(float x in new[]{-3f,-1.8f}){
    Box("Pantry shelf back",x,1.15f,3.6f,1.05f,2,.12f,"B3824C");
    foreach(float y in new[]{.35f,.95f,1.55f}){
     Box("Pantry shelf",x,y,3.28f,1.05f,.08f,.7f,"D2AD77");
     foreach(float dx in new[]{-.3f,0f,.3f}){
      Box("Cream pantry carton",x+dx,y+.21f,3.26f,.21f,.35f,.3f,"EFE2C9");
      Box("Carton moss label",x+dx,y+.2f,3.1f,.16f,.1f,.02f,"738448");
     }
    }
   }
   Box("Chilled cabinet frame",.05f,1.18f,3.55f,1.85f,2.2f,.7f,"425C35");
   Box("Chilled cabinet pale interior",.05f,1.18f,3.17f,1.64f,1.98f,.06f,"DCE5C5");
   foreach(float y in new[]{.43f,1.03f,1.63f}){
    Box("Cold shelf",.05f,y,3.05f,1.65f,.06f,.38f,"BBB6A5");
    foreach(float x in new[]{-.48f,0f,.48f}){Box("Milk bottle",x,y+.19f,3.03f,.22f,.32f,.2f,"F8F3E3");Box("Milk cap",x,y+.37f,3.03f,.15f,.06f,.16f,"738448");}
   }
   foreach(float z in new[]{-1.3f,.25f}){
    Box("Produce bin timber base",-3.45f,.45f,z,1.1f,.8f,1.1f,"B3824C");
    Box("Produce bin inset",-3.45f,.88f,z,1.04f,.1f,1.04f,"425C35");
    foreach(float dx in new[]{-.3f,0f,.3f})foreach(float dz in new[]{-.3f,0f,.3f}){
     Box(z<0?"Terracotta apples":"Leafy produce",-3.45f+dx,1.03f,z+dz,.23f,.22f,.23f,z<0?"BF7958":"738448");
     Box("Produce stem",-3.45f+dx,1.16f,z+dz,.04f,.06f,.04f,"425C35");
    }
   }
   Box("Checkout timber counter",2.65f,.65f,2.45f,2.5f,1.15f,.9f,"B3824C");
   Box("Checkout cream top",2.65f,1.25f,2.45f,2.6f,.10f,1,"EFE2C9");
   Box("Checkout belt",2.2f,1.32f,2.45f,1.25f,.04f,.65f,"425C35");
   Box("Register base",3.25f,1.40f,2.5f,.45f,.2f,.4f,"BBB6A5");
   Box("Register display",3.25f,1.61f,2.6f,.4f,.25f,.1f,"244335");
   foreach(float y in new[]{.18f,.35f,.52f}){
    Box("Stacked basket base",3.5f,y,-2.5f,.7f,.055f,.7f,"BF7958");
    foreach(float x in new[]{3.17f,3.83f})Box("Basket stack side",x,y+.09f,-2.5f,.045f,.18f,.7f,"BF7958");
    foreach(float z in new[]{-2.83f,-2.17f})Box("Basket stack end",3.5f,y+.09f,z,.7f,.18f,.045f,"BF7958");
   }
  }
 }
}
