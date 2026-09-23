using UnityEngine;
namespace Purrington.Presentation {
 // Fixtures for the three Paw Mart rooms laid out in ShopPlan.PawMart (plan space, -z toward the street door).
 public static class PawMartArt {
  public static void Build(GodotGeometry geometry,Transform parent,float origin){
   void Box(string name,float x,float y,float z,float w,float h,float d,string color)=>geometry.Build(parent,ManagerCatArt.Node(name,new Vector3(origin+x,y,z),new Vector3(w,h,d),color));
   // Grocery hall: staggered timber boards.
   for(int row=0;row<12;row++){float z=-4.5f+row*.52f,split=-3.6f+(row%3)*1.7f;Box("Pale timber floorboard",(-5.95f+split)/2,.07f,z,split+5.95f-.02f,.04f,.5f,row%2==0?"C9A674":"D2AD77");Box("Pale timber floorboard",(split+1.45f)/2,.07f,z,1.45f-split-.02f,.04f,.5f,row%2==0?"D2AD77":"C9A674");}
   Box("Welcome mat",-2.25f,.1f,-4.2f,1.3f,.03f,.8f,"BF7958");
   // Checkout by the door, with the pantry along the side wall behind the cashier.
   Box("Checkout timber counter",-4.4f,.65f,-2,2.5f,1.15f,.9f,"B3824C");
   Box("Checkout cream top",-4.4f,1.25f,-2,2.6f,.1f,1,"EFE2C9");
   Box("Checkout belt",-4.9f,1.32f,-2,1.25f,.04f,.65f,"425C35");
   Box("Register base",-3.6f,1.4f,-1.95f,.45f,.2f,.4f,"BBB6A5");
   Box("Register display",-3.6f,1.61f,-2.05f,.4f,.25f,.1f,"244335");
   Box("Treat jar",-3.2f,1.45f,-2.1f,.26f,.32f,.26f,"DCE5C5");Box("Treat jar lid",-3.2f,1.64f,-2.1f,.28f,.06f,.28f,"BF7958");
   foreach(float z in new[]{-.35f,.7f}){
    Box("Pantry shelf back",-5.8f,1.15f,z,.12f,2,1.05f,"B3824C");
    foreach(float y in new[]{.35f,.95f,1.55f}){
     Box("Pantry shelf",-5.45f,y,z,.7f,.08f,1.05f,"D2AD77");
     foreach(float dz in new[]{-.3f,0f,.3f}){Box("Cream pantry carton",-5.45f,y+.21f,z+dz,.3f,.35f,.21f,"EFE2C9");Box("Carton moss label",-5.29f,y+.2f,z+dz,.02f,.1f,.16f,y>1?"BF7958":"738448");}
    }
   }
   // A central gondola the shoppers circle.
   Box("Gondola base",-.5f,.2f,-1.1f,.8f,.3f,2.4f,"B3824C");
   foreach(float y in new[]{.62f,1.02f}){
    Box("Gondola shelf",-.5f,y,-1.1f,.8f,.06f,2.4f,"D2AD77");
    for(int i=0;i<5;i++){float z=-2.1f+i*.5f;string[] tins={"BF7958","D7AE55","9FB7C9","738448","E6B7C1"};Box("Fish tin",-.68f,y+.14f,z,.22f,.22f,.3f,tins[i]);Box("Kibble box",-.32f,y+.18f,z,.22f,.3f,.34f,tins[(i+2)%5]);}
   }
   Box("Gondola topper",-.5f,1.4f,-1.1f,.9f,.1f,2.5f,"425C35");
   foreach(float y in new[]{.18f,.35f,.52f}){
    Box("Stacked basket base",-5.35f,y,-3.9f,.7f,.055f,.7f,"BF7958");
    foreach(float x in new[]{-5.68f,-5.02f})Box("Basket stack side",x,y+.09f,-3.9f,.045f,.18f,.7f,"BF7958");
    foreach(float z in new[]{-4.23f,-3.57f})Box("Basket stack end",-5.35f,y+.09f,z,.7f,.18f,.045f,"BF7958");
   }
   Plant(Box,1f,-4.35f);
   // Fresh market: mint and cream checker tiles, produce bins, chilled milk and a bakery table.
   for(int i=0;i<6;i++)for(int j=0;j<9;j++)Box("Market tile",1.5f+.375f+i*.75f,.07f,-2.25f+.39f+j*.778f,.73f,.04f,.76f,(i+j)%2==0?"DCE5C5":"F4F1E8");
   string[] produce={"BF7958","738448","D7AE55"};string[] produceNames={"Terracotta apples","Leafy produce","Golden pears"};
   for(int b=0;b<3;b++){
    float z=-1.3f+b*1.35f;
    Box("Produce bin timber base",5.3f,.45f,z,1.1f,.8f,1.1f,"B3824C");
    Box("Produce bin inset",5.3f,.88f,z,1.04f,.1f,1.04f,"425C35");
    foreach(float dx in new[]{-.3f,0f,.3f})foreach(float dz in new[]{-.3f,0f,.3f}){Box(produceNames[b],5.3f+dx,1.03f,z+dz,.23f,.22f,.23f,produce[b]);Box("Produce stem",5.3f+dx,1.16f,z+dz,.04f,.06f,.04f,"425C35");}
   }
   Box("Chilled cabinet frame",3.4f,1.18f,4.4f,1.85f,2.2f,.7f,"425C35");
   Box("Chilled cabinet pale interior",3.4f,1.18f,4.02f,1.64f,1.98f,.06f,"DCE5C5");
   foreach(float y in new[]{.43f,1.03f,1.63f}){
    Box("Cold shelf",3.4f,y,3.9f,1.65f,.06f,.38f,"BBB6A5");
    foreach(float x in new[]{-.48f,0f,.48f}){Box("Milk bottle",3.4f+x,y+.19f,3.88f,.22f,.32f,.2f,"F8F3E3");Box("Milk cap",3.4f+x,y+.37f,3.88f,.15f,.06f,.16f,"738448");}
   }
   Box("Bakery table",2.9f,.45f,1.9f,1.4f,.8f,1,"D2AD77");Box("Bakery cloth",2.9f,.87f,1.9f,1.5f,.05f,1.1f,"F4F1E8");
   foreach(float dx in new[]{-.4f,0f,.4f}){Box("Bread loaf",2.9f+dx,.99f,1.75f,.3f,.18f,.5f,"C9A074");Box("Loaf score",2.9f+dx,1.09f,1.75f,.2f,.03f,.08f,"E8D3B2");}
   Box("Muffin tray",2.9f,.94f,2.25f,.8f,.04f,.35f,"BBB6A5");foreach(float dx in new[]{-.25f,0f,.25f})Box("Berry muffin",2.9f+dx,1.02f,2.25f,.16f,.14f,.16f,"C9B6E4");
   // Stockroom: crates, sacks, a trolley and the shop cat's cushion.
   foreach(var c in new[]{new Vector3(-5.3f,0,4.1f),new Vector3(-4.35f,0,4.1f),new Vector3(-5.3f,.72f,4.1f)}){Box("Supply crate",c.x,c.y+.36f,c.z,.85f,.7f,.85f,"B3824C");Box("Crate slat",c.x,c.y+.36f,c.z-.44f,.87f,.1f,.02f,"D2AD77");}
   Box("Stock shelf",-2.2f,1.1f,4.35f,2.6f,.08f,.5f,"D2AD77");Box("Stock shelf",-2.2f,.5f,4.35f,2.6f,.08f,.5f,"D2AD77");
   foreach(float x in new[]{-3.2f,-2.5f,-1.8f,-1.2f}){Box("Stock box",x,.72f,4.35f,.5f,.36f,.4f,"E8D3B2");Box("Stock box",x+.1f,1.32f,4.35f,.45f,.36f,.4f,x<-2?"DCE5C5":"E6B7C1");}
   foreach(float dx in new[]{0f,.55f})Box("Kibble sack",-.2f+dx,.4f,3.9f,.5f,.7f,.4f,"EFE2C9");
   Box("Hand trolley",.9f,.6f,2.4f,.6f,1.1f,.08f,"425C35");Box("Trolley wheel",.9f,.12f,2.5f,.7f,.2f,.2f,"244335");
   Box("Cat cushion",-3.9f,.14f,2.5f,1,.16f,.8f,"C9B6E4");Box("Cushion rim",-3.9f,.24f,2.85f,1,.14f,.12f,"B3A2D0");
  }
  internal static void Plant(System.Action<string,float,float,float,float,float,float,string> box,float x,float z){box("Plant pot",x,.3f,z,.5f,.5f,.5f,"BF7958");box("Plant leaves",x,.8f,z,.65f,.55f,.65f,"738448");box("Plant leaves",x,1.15f,z,.4f,.3f,.4f,"8FA35E");}
 }
}
