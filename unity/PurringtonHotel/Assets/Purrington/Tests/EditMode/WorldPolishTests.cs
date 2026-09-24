using System.Linq;
using System.Reflection;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // QA regressions: voxel lettering must sit inside its board, and cats at furniture must not put their faces through it.
 public sealed class WorldPolishTests {
  static readonly BindingFlags Private=BindingFlags.Instance|BindingFlags.NonPublic;
  sealed class MemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
  GameObject root;
  [SetUp] public void Setup(){ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);root=new GameObject("polish test");}
  [TearDown] public void Cleanup(){Object.DestroyImmediate(root);}
  static Bounds Measure(Transform t){var renderers=t.GetComponentsInChildren<Renderer>(true);var b=renderers[0].bounds;foreach(var r in renderers)b.Encapsulate(r.bounds);return b;}

  [Test] public void EverySignsLettersFitOnItsBoardAndTheMarketArchIsCentered(){
   using(var geometry=new GodotGeometry()){
    var model=new HotelModel(new MemoryStore(),ParityContent.Current);Assert.IsTrue(model.LoadOrCreate().success);
    var art=new MainStreetArt(geometry,root.transform,TownContent.Current);var square=new TownSquareArt(geometry,art.Root,TownContent.Current,model);
    square.Market.gameObject.SetActive(true);
    int checkedSigns=0;
    foreach(var letters in art.Root.GetComponentsInChildren<Transform>(true).Where(t=>t.name.StartsWith("Store sign")||t.name.EndsWith("letters")||t.name.EndsWith(" sign")&&t.parent.name.StartsWith("Market kiosk"))){
     var board=letters.parent.Cast<Transform>().Where(s=>s.name=="Signboard"||s.name=="Shop signboard"||s.name=="Awning").OrderBy(s=>Mathf.Abs(Measure(s).center.x-Measure(letters).center.x)).FirstOrDefault();
     Assert.That(board,Is.Not.Null,letters.name+" has a board");
     Bounds text=Measure(letters),face=Measure(board);
     Assert.That(text.size.x,Is.LessThanOrEqualTo(face.size.x-.1f),letters.name+" fits its board");
     Assert.That(text.center.x,Is.EqualTo(face.center.x).Within(.02f),letters.name+" is centered");
     checkedSigns++;
    }
    Assert.That(checkedSigns,Is.GreaterThanOrEqualTo(6),"hotel, both shops, market arch and both kiosks");
    var arch=art.Root.GetComponentsInChildren<Transform>(true).First(t=>t.name=="Market arch");
    Assert.That(arch.position.x,Is.EqualTo(TownContent.Current.Point("square").x*VoxelWorld.Unit).Within(.01f),"market arch spans the path to the square");
    Assert.That(arch.GetComponentsInChildren<Transform>(true).Any(t=>t.name=="Market letters"),Is.True);
   }
  }

  [Test] public void CatsAtADeskKeepTheirNoseOutsideIt(){
   var model=new HotelModel(new MemoryStore(),ParityContent.Current);Assert.IsTrue(model.LoadOrCreate().success);
   var world=root.AddComponent<VoxelWorld>();world.Initialize(model);
   var geometry=(GodotGeometry)typeof(VoxelWorld).GetField("geometry",Private).GetValue(world);
   var renderRoot=(Transform)typeof(VoxelWorld).GetField("renderRoot",Private).GetValue(world);
   var clear=typeof(VoxelWorld).GetMethod("ClearVenue",Private);var reach=typeof(VoxelWorld).GetMethod("NoseReach",Private);
   int tested=0,moved=0;
   foreach(var venue in model.Venues().Where(v=>v.role=="reception"||v.role=="bar"||v.role=="food"||v.role=="water")){
    var o=model.State.objects.First(x=>x.id==venue.id);HotelModel.Size(o,out float w,out float d);
    foreach(var slot in venue.slots.Concat(venue.staffSlot!=null?new[]{venue.staffSlot}:new VenueSlot[0])){
     var rig=new GodotCatRig(geometry,renderRoot,"cats","0",0);rig.Root.localScale=Vector3.one*.83f;
     var actor=new ActorSnapshot{kind=slot==venue.staffSlot?ActorKind.Staff:ActorKind.Guest,id="probe",action="greet",venueId=venue.id,x=slot.x,z=slot.z,facing=slot.facing};
     var args=new object[]{actor,rig,new Vector3(slot.x*VoxelWorld.Unit,.18f,slot.z*VoxelWorld.Unit),slot.facing};clear.Invoke(world,args);
     var at=(Vector3)args[2];float r=(float)reach.Invoke(world,new object[]{rig});
     var nose=new Vector2(at.x,at.z)+new Vector2(Mathf.Sin(slot.facing),Mathf.Cos(slot.facing))*(r-.05f);
     bool inside=nose.x>o.x*VoxelWorld.Unit&&nose.x<(o.x+w)*VoxelWorld.Unit&&nose.y>o.z*VoxelWorld.Unit&&nose.y<(o.z+d)*VoxelWorld.Unit;
     Assert.IsFalse(inside,venue.item+" slot "+slot.key+" puts the cat's nose inside the furniture");
     Assert.That(Vector2.Distance(new Vector2(at.x,at.z),new Vector2(slot.x,slot.z)*VoxelWorld.Unit),Is.LessThan(.5f),"the cat stays at its slot");
     if(Vector2.Distance(new Vector2(at.x,at.z),new Vector2(slot.x,slot.z)*VoxelWorld.Unit)>.01f)moved++;
     Object.DestroyImmediate(rig.Root.gameObject);tested++;
    }
   }
   // The authored slots are closer than a head length, so the pose must actually step some cats back.
   Assert.That(moved,Is.GreaterThan(0),"approach slots clip without the step back");
   Assert.That(tested,Is.GreaterThan(1),"the starter hotel has a staffed desk with a guest side and a staff side");
  }
 }
}
