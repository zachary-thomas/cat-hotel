using System.Collections.Generic;
using UnityEngine;
namespace Purrington.Presentation {
 // One shared construction for every cart. Positions use the stage's authored local coordinates.
 public sealed class ShoppingCartRig {
  public Transform Root {get;}
  public float FrontOffset=>.8f;
  public float WheelAngle {get;private set;}
  public string Contents {get;private set;}="";
  readonly Transform[] wheels=new Transform[4];
  readonly Transform basketContents,produce,bundle;
  public IReadOnlyList<Transform> Wheels=>wheels;
  public ShoppingCartRig(GodotGeometry geometry,Transform parent,string owner){
   Root=MainStreetArt.Group(parent,owner+" shopping cart");
   void Box(string name,Vector3 at,Vector3 size,string color,Transform target=null)=>geometry.Build(target??Root,ManagerCatArt.Node(name,at,size,color));
   Box("Timber chassis",new Vector3(0,.16f,0),new Vector3(.56f,.07f,.66f),"B3824C");
   Box("Basket floor",new Vector3(0,.34f,0),new Vector3(.6f,.06f,.65f),"D2AD77");
   foreach(float x in new[]{-.28f,.28f}){
    Box("Handle arm",new Vector3(x,.22f,-.37f),new Vector3(.055f,.055f,.34f),"425C35");
    foreach(float z in new[]{-.3f,0f,.3f})Box("Basket upright",new Vector3(x,.46f,z),new Vector3(.045f,.26f,.045f),"738448");
    foreach(float y in new[]{.39f,.56f})Box("Basket side rail",new Vector3(x,y,0),new Vector3(.05f,.04f,.65f),"738448");
   }
   foreach(float z in new[]{-.3f,.3f})foreach(float y in new[]{.39f,.56f})Box("Basket end rail",new Vector3(0,y,z),new Vector3(.6f,.04f,.05f),"738448");
   Box("Paw handle",new Vector3(0,.22f,-.52f),new Vector3(.6f,.055f,.065f),"425C35");
   for(int i=0;i<4;i++){
    wheels[i]=MainStreetArt.Group(Root,"Wheel "+i);wheels[i].localPosition=new Vector3(i<2?-.29f:.29f,.10f,i%2==0?-.25f:.25f);
    Box("Voxel tire",Vector3.zero,new Vector3(.10f,.2f,.2f),"244335",wheels[i]);
    Box("Wheel hub",Vector3.zero,new Vector3(.12f,.07f,.07f),"BBB6A5",wheels[i]);
   }
   basketContents=MainStreetArt.Group(Root,"Basket contents");produce=MainStreetArt.Group(basketContents,"Welcome produce");bundle=MainStreetArt.Group(basketContents,"Market parcels");
   foreach(float x in new[]{-.15f,.15f})Box("Apple",new Vector3(x,.44f,.1f),new Vector3(.18f,.16f,.18f),"BF7958",produce);
   Box("Leafy greens",new Vector3(0,.48f,-.12f),new Vector3(.3f,.22f,.18f),"738448",produce);
   Box("Market parcel",new Vector3(0,.49f,0),new Vector3(.4f,.28f,.38f),"EFE2C9",bundle);
   Box("Parcel ribbon",new Vector3(0,.64f,0),new Vector3(.08f,.025f,.4f),"BF7958",bundle);SetContents("");
  }
  public void SetContents(string id){Contents=id??"";produce.gameObject.SetActive(Contents!=""&&Contents!="market_bundle");bundle.gameObject.SetActive(Contents=="market_bundle");}
  // travelDistance is accumulated path length, so stationary frames never spin wheels.
  public void SetPose(Vector3 catPosition,Quaternion facing,float travelDistance,bool reducedMotion){
   Root.localPosition=catPosition+facing*Vector3.forward*FrontOffset;Root.localRotation=facing;
   WheelAngle=reducedMotion?0:Mathf.Repeat(travelDistance/.10f*Mathf.Rad2Deg,360);
   foreach(var wheel in wheels)wheel.localRotation=Quaternion.Euler(WheelAngle,0,0);
   basketContents.localPosition=reducedMotion?Vector3.zero:Vector3.up*(Mathf.Sin(travelDistance*10)*.012f);
  }
 }
}

