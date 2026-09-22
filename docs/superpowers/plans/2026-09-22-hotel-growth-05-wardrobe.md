# Cat Wardrobe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cats can wear clothes. There are 12 voxel wear items across head, neck and back slots. Nine are bought with Cat Coins into a shared hotel wardrobe, and three are signature gifts from Miso, Clover and Bean at friendship 50. You try items on in the care view before buying, and outfits show wherever the cat appears.

**Architecture:** Domain: `HotelWardrobe.cs` (the `Wardrobe` content registry, `OwnsWear`/`BuyWear`/`Dress` transactions), `CatState.outfit` and `HotelState.wardrobe` (optional save fields, so no version bump), strict-JSON and validation rules, and a gift message in `Care`. Content: `Resources/Content/Wardrobe.json`, with parts authored as voxel boxes in anchor units. Presentation: `CatOutfitView` builds the boxes under the `GodotCatRig` `head`/`body` bindings sized from their bounds, and `WardrobePanel` (a `HotelUI` partial) opens from the care view.

**Tech Stack:** C# 9, Newtonsoft.Json, the .NET 9 domain harness, Unity 6000.3 URP, uGUI/TextMeshPro.

**Spec:** [hotel-growth design](../specs/2026-09-22-hotel-growth-design.md): "Wardrobe". **Depends on:** plan 02 Task 2 (lane C branches from there). The presentation tasks wait until plan 03 has merged, to avoid conflicts in `HotelUI`.

---

## Files

- Create: `unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json`
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelWardrobe.cs`
- Modify: `…/Domain/HotelState.cs`, `HotelModel.cs`, `StrictSaveJson.cs`, `HotelValidation.cs`
- Create: `tests/unity-domain/WardrobeSuites.cs`; modify `tests/unity-domain/Purrington.Domain.Tests.csproj`, `Program.cs`
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/CatOutfitView.cs`, `WardrobePanel.cs`
- Modify: `…/Presentation/HotelApp.cs:65`, `VoxelWorld.cs:44` (`SyncActors`), `VoxelWorldCare.cs:7`, `NeighborhoodView.cs:44`, `HotelUI.cs` / the care panel
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/WardrobeTests.cs`

`…/Domain/` is `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/`.

---

### Task 1: Wardrobe domain

**Files:** `Wardrobe.json`, `HotelWardrobe.cs`, `HotelState.cs`, `HotelModel.cs`, `StrictSaveJson.cs`, `HotelValidation.cs`, `tests/unity-domain/*`

- [ ] **Step 1: Add the content file**

Create `unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json`:

```json
{
  "schema": 1,
  "note": "Parts are voxel boxes [x,y,z,w,h,d] in anchor units: 1 = the anchor's width. Origin: head = top center of the head; neck = front top of the body; back = top center of the body.",
  "items": [
    {"id": "sun_hat", "name": "Straw sun hat", "slot": "head", "price": 180, "parts": [
      {"box": [-0.75, 0.0, -0.75, 1.5, 0.08, 1.5], "color": "E8C77A"},
      {"box": [-0.35, 0.08, -0.35, 0.7, 0.3, 0.7], "color": "E8C77A"},
      {"box": [-0.36, 0.1, -0.36, 0.72, 0.08, 0.72], "color": "C0584A"}]},
    {"id": "beanie", "name": "Cozy beanie", "slot": "head", "price": 120, "parts": [
      {"box": [-0.45, -0.05, -0.45, 0.9, 0.3, 0.9], "color": "6E8FB5"},
      {"box": [-0.1, 0.25, -0.1, 0.2, 0.2, 0.2], "color": "F4EFE6"}]},
    {"id": "flower_crown", "name": "Flower crown", "slot": "head", "price": 150, "parts": [
      {"box": [-0.5, 0.0, -0.5, 1.0, 0.08, 1.0], "color": "7C9B58"},
      {"box": [-0.5, 0.06, -0.5, 0.16, 0.16, 0.16], "color": "F2A6B8"},
      {"box": [0.34, 0.06, -0.5, 0.16, 0.16, 0.16], "color": "F7E27A"},
      {"box": [-0.5, 0.06, 0.34, 0.16, 0.16, 0.16], "color": "FFFFFF"},
      {"box": [0.34, 0.06, 0.34, 0.16, 0.16, 0.16], "color": "C9A7E8"}]},
    {"id": "sailor_cap", "name": "Sailor cap", "slot": "head", "price": 160, "parts": [
      {"box": [-0.45, 0.0, -0.45, 0.9, 0.2, 0.9], "color": "FFFFFF"},
      {"box": [-0.46, 0.0, -0.46, 0.92, 0.06, 0.92], "color": "2E4E7A"}]},
    {"id": "tiny_crown", "name": "Tiny crown", "slot": "head", "price": 0, "giftCat": 0, "giftBond": 50, "parts": [
      {"box": [-0.3, 0.0, -0.3, 0.6, 0.12, 0.6], "color": "E0B84A"},
      {"box": [-0.3, 0.12, -0.3, 0.12, 0.12, 0.12], "color": "E0B84A"},
      {"box": [0.18, 0.12, -0.3, 0.12, 0.12, 0.12], "color": "E0B84A"},
      {"box": [-0.3, 0.12, 0.18, 0.12, 0.12, 0.12], "color": "E0B84A"},
      {"box": [0.18, 0.12, 0.18, 0.12, 0.12, 0.12], "color": "E0B84A"}]},
    {"id": "bow_tie", "name": "Bow tie", "slot": "neck", "price": 90, "parts": [
      {"box": [-0.32, -0.12, 0.0, 0.24, 0.2, 0.08], "color": "C0584A"},
      {"box": [-0.08, -0.1, 0.0, 0.16, 0.16, 0.1], "color": "8E3A30"},
      {"box": [0.08, -0.12, 0.0, 0.24, 0.2, 0.08], "color": "C0584A"}]},
    {"id": "bandana", "name": "Bandana", "slot": "neck", "price": 80, "parts": [
      {"box": [-0.4, -0.25, -0.05, 0.8, 0.25, 0.1], "color": "D9534F"},
      {"box": [-0.15, -0.4, -0.03, 0.3, 0.15, 0.08], "color": "D9534F"}]},
    {"id": "bell_collar", "name": "Bell collar", "slot": "neck", "price": 70, "parts": [
      {"box": [-0.45, -0.08, -0.3, 0.9, 0.08, 0.35], "color": "3F7F6E"},
      {"box": [-0.07, -0.2, 0.0, 0.14, 0.14, 0.12], "color": "E6C45A"}]},
    {"id": "knit_scarf", "name": "Knitted scarf", "slot": "neck", "price": 0, "giftCat": 1, "giftBond": 50, "parts": [
      {"box": [-0.48, -0.12, -0.35, 0.96, 0.14, 0.4], "color": "E58B5A"},
      {"box": [0.15, -0.45, 0.0, 0.14, 0.35, 0.08], "color": "E58B5A"}]},
    {"id": "sweater", "name": "Striped sweater", "slot": "back", "price": 200, "parts": [
      {"box": [-0.52, -0.3, -0.45, 1.04, 0.32, 0.9], "color": "B8465A"},
      {"box": [-0.53, -0.18, -0.46, 1.06, 0.07, 0.92], "color": "F4EFE6"}]},
    {"id": "raincoat", "name": "Raincoat", "slot": "back", "price": 190, "parts": [
      {"box": [-0.54, -0.35, -0.48, 1.08, 0.38, 0.96], "color": "F2C94C"}]},
    {"id": "hero_cape", "name": "Hero cape", "slot": "back", "price": 0, "giftCat": 2, "giftBond": 50, "parts": [
      {"box": [-0.45, -0.02, -0.2, 0.9, 0.06, 0.9], "color": "6A4C93"}]}
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `tests/unity-domain/WardrobeSuites.cs`:

```csharp
using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Purrington.Domain;

static class WardrobeSuites
{
	public static void RunWardrobe(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		Wardrobe.LoadJson(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json"));
		Check(Wardrobe.All.Length==12&&Wardrobe.Slots.All(s=>Wardrobe.All.Count(w=>w.slot==s)>=3),"wardrobe: 12 items across head, neck and back");
		Check(Wardrobe.All.Count(w=>w.giftCat>=0)==3,"wardrobe: three signature gifts");
		var store=new MemoryStore();var m=new HotelModel(store,content);m.LoadOrCreate();m.State.coins=1000;
		Check(m.State.cats[0].known&&m.State.cats[0].outfit.Count==0&&m.State.wardrobe.Count==0,"wardrobe: fresh hotels start undressed");
		double coins=m.State.coins;var bought=m.BuyWear("sun_hat");
		Check(bought.success&&m.OwnsWear("sun_hat")&&Math.Abs(coins-m.State.coins-180)<.01&&bought.cost==180,"wardrobe: buying a sun hat costs 180");
		coins=m.State.coins;Check(m.BuyWear("sun_hat").success&&Math.Abs(coins-m.State.coins)<.01,"wardrobe: buying twice is free and harmless");
		var gift=m.BuyWear("tiny_crown");Check(!gift.success&&gift.message.Contains("gift from"),"wardrobe: gifts can't be bought ("+gift.message+")");
		Check(m.Dress(0,"head","sun_hat").success&&m.State.cats[0].outfit["head"]=="sun_hat","wardrobe: dress Miso in the sun hat");
		Check(!m.Dress(0,"neck","sun_hat").success,"wardrobe: hats don't go on necks");
		var unowned=m.Dress(0,"neck","bow_tie");Check(!unowned.success&&unowned.message.Contains("Buy"),"wardrobe: unowned wear can't be worn");
		Check(!m.Dress(8,"head","sun_hat").success,"wardrobe: unknown cats can't be dressed");
		m.State.cats[0].bond=49;var care=m.Care(0,m.State.cats[0].favoriteAction);
		Check(care.success&&care.message.Contains("gave you the tiny crown"),"wardrobe: reaching friendship 50 brings Miso's gift ("+care.message+")");
		Check(m.OwnsWear("tiny_crown")&&m.Dress(0,"head","tiny_crown").success,"wardrobe: the gift can be worn");
		var codec=new NewtonsoftSaveCodec();var restored=codec.Deserialize(codec.Serialize(m.State));
		Check(HotelModel.Valid(restored)&&restored.cats[0].outfit["head"]=="tiny_crown"&&restored.wardrobe.Contains("sun_hat"),"wardrobe: outfits and purchases survive a save");
		var legacy=JObject.Parse(codec.Serialize(m.State));((JObject)legacy).Remove("wardrobe");foreach(var c in legacy["cats"])((JObject)c).Remove("outfit");
		var old=new HotelModel(new MemoryStore(),content);old.LoadOrCreate();Check(old.RestoreJson(legacy.ToString())&&old.State.cats.All(c=>c.outfit.Count==0),"wardrobe: older saves load undressed");
		var bad=JObject.Parse(codec.Serialize(m.State));bad["cats"][0]["outfit"]["head"]=5;Check(!old.RestoreJson(bad.ToString()),"wardrobe: strict JSON rejects a non-string outfit");
		var wrongSlot=JObject.Parse(codec.Serialize(m.State));wrongSlot["cats"][0]["outfit"]["neck"]="sun_hat";Check(!old.RestoreJson(wrongSlot.ToString()),"wardrobe: validation rejects wear in the wrong slot");
		Check(m.Dress(0,"head","").success&&!m.State.cats[0].outfit.ContainsKey("head"),"wardrobe: undress a slot");
		store.fail=true;coins=m.State.coins;Check(!m.BuyWear("beanie").success&&Math.Abs(coins-m.State.coins)<.01&&!m.OwnsWear("beanie"),"wardrobe: a failed save buys nothing");store.fail=false;
		m.State.coins=10;Check(!m.BuyWear("beanie").success,"wardrobe: can't afford a beanie with 10 coins");
		Check(m.SetGodMode(true).success&&m.BuyWear("beanie").success&&m.State.coins==10,"wardrobe: God mode dresses for free");
		Console.WriteLine("Wardrobe suite passed");
	}
}
```

In `tests/unity-domain/Purrington.Domain.Tests.csproj`, add `<Compile Include="WardrobeSuites.cs" />` after `<Compile Include="ConstructionSuites.cs" />`. In `tests/unity-domain/Program.cs`, insert `WardrobeSuites.RunWardrobe(Check,P,content);` right after `ConstructionSuites.RunGodMode(Check,P,content);`.

- [ ] **Step 3: Run to verify it fails**

Run: `dotnet run --project tests/unity-domain`
Expected: build error `The name 'Wardrobe' does not exist in the current context`.

- [ ] **Step 4: Create `HotelWardrobe.cs`**

```csharp
using System;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
public sealed class WearDefinition {public string id,name,slot;public double price;public int giftCat=-1,giftBond=50;public JArray parts=new JArray();}
// Wear items come from Resources/Content/Wardrobe.json; Presentation loads the text and calls LoadJson, tests read the file directly.
public static class Wardrobe {
 public static readonly string[] Slots={"head","neck","back"};
 public static WearDefinition[] All=Array.Empty<WearDefinition>();
 public static WearDefinition Find(string id){return Array.Find(All,w=>w.id==id);}
 public static void LoadJson(string json){var items=JObject.Parse(json)["items"] as JArray??throw new FormatException("Wardrobe needs items");var all=items.Select(i=>new WearDefinition{id=(string)i["id"],name=(string)i["name"],slot=(string)i["slot"],price=(double?)i["price"]??0,giftCat=(int?)i["giftCat"]??-1,giftBond=(int?)i["giftBond"]??50,parts=i["parts"] as JArray??new JArray()}).ToArray();if(all.Any(w=>string.IsNullOrEmpty(w.id)||string.IsNullOrEmpty(w.name)||!Slots.Contains(w.slot)||w.price<0)||all.Select(w=>w.id).Distinct().Count()!=all.Length)throw new FormatException("Invalid wardrobe item");All=all;}
}
public sealed partial class HotelModel {
 // Bought items live in State.wardrobe; signature gifts are owned while their cat's friendship stays at the gift level, so nothing needs migrating.
 public bool OwnsWear(string id){var w=Wardrobe.Find(id);if(w==null)return false;return State.wardrobe.Contains(id)||w.giftCat>=0&&w.giftCat<State.cats.Count&&State.cats[w.giftCat].known&&State.cats[w.giftCat].bond>=w.giftBond;}
 public CommandResult BuyWear(string id){var w=Wardrobe.Find(id);if(w==null)return CommandResult.Fail("Choose something from the wardrobe.");if(OwnsWear(id))return CommandResult.Ok(w.name+" is already in the wardrobe.");if(w.giftCat>=0)return CommandResult.Fail(w.name+" is a gift from "+State.cats[w.giftCat].name+" at friendship "+w.giftBond+".");double price=State.settings.godMode?0:w.price;if(State.coins+.0001<price)return CommandResult.Fail("Need "+Math.Ceiling(price-State.coins)+" more Cat Coins.");var r=Transaction(()=>{State.coins-=price;State.wardrobe.Add(id);},w.name+" added to the wardrobe");r.cost=r.success?price:0;return r;}
 public CommandResult Dress(int catId,string slot,string id){var c=State.cats.Find(v=>v.id==catId&&v.known);if(c==null)return CommandResult.Fail("Meet this cat first.");if(!Wardrobe.Slots.Contains(slot))return CommandResult.Fail("Choose head, neck or back.");if(string.IsNullOrEmpty(id))return Transaction(()=>c.outfit.Remove(slot),c.name+" changed back");var w=Wardrobe.Find(id);if(w==null||w.slot!=slot)return CommandResult.Fail("That doesn't go there.");if(!OwnsWear(id))return CommandResult.Fail("Buy this in the wardrobe first.");return Transaction(()=>c.outfit[slot]=id,c.name+" looks wonderful in the "+w.name.ToLowerInvariant());}
}
}
```

- [ ] **Step 5: Apply the save, validation and gift edits**

**1. `…/Domain/HotelState.cs`** · replace exactly once:

```csharp
public string name,preference,favoriteAction;
```

with:

```csharp
public string name,preference,favoriteAction;public Dictionary<string,string> outfit=new Dictionary<string,string>();
```

**2. `…/Domain/HotelState.cs`** · replace exactly once:

```csharp
public List<string> entitlements=new List<string>();
```

with:

```csharp
public List<string> entitlements=new List<string>(); public List<string> wardrobe=new List<string>();
```

**3. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
s.entitlements==null||
```

with:

```csharp
s.entitlements==null||s.wardrobe==null||s.cats.Any(c=>c==null||c.outfit==null)||
```

**4. `…/Domain/StrictSaveJson.cs`** · replace exactly once:

```csharp
Fields(j,"hotels,storage,cats,entitlements",JTokenType.Array);
```

with:

```csharp
Fields(j,"hotels,storage,cats,entitlements",JTokenType.Array);Fields(j,"wardrobe",JTokenType.Array,true);foreach(var w in (JArray)j["wardrobe"]??new JArray())Require(w.Type==JTokenType.String);
```

**5. `…/Domain/StrictSaveJson.cs`** · replace exactly once:

```csharp
Numbers(c,"friend",true,true);
```

with:

```csharp
Numbers(c,"friend",true,true);Fields(c,"outfit",JTokenType.Object,true);foreach(var o in ((JObject)c["outfit"]??new JObject()).Properties())Require(o.Value.Type==JTokenType.String);
```

**6. `…/Domain/HotelValidation.cs`** · replace exactly once:

```csharp
if(s.entitlements.Distinct().Count()!=s.entitlements.Count
```

with:

```csharp
if(s.wardrobe.Distinct().Count()!=s.wardrobe.Count)return false;if(Wardrobe.All.Length>0){if(s.wardrobe.Any(w=>Wardrobe.Find(w)==null))return false;foreach(var c in s.cats)foreach(var o in c.outfit){var w=Wardrobe.Find(o.Value);if(!Wardrobe.Slots.Contains(o.Key)||w==null||w.slot!=o.Key)return false;}}if(s.entitlements.Distinct().Count()!=s.entitlements.Count
```

**7. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
int gain=c.favoriteAction==tool?6:3;var r=Transaction(()=>{c.bond=Math.Min(100,c.bond+gain);c.lastCare=State.elapsed;},c.name+" loved that! +"+gain+" friendship");
```

with:

```csharp
int gain=c.favoriteAction==tool?6:3;var gift=Wardrobe.All.FirstOrDefault(w=>w.giftCat==c.id&&c.bond<w.giftBond&&c.bond+gain>=w.giftBond);var r=Transaction(()=>{c.bond=Math.Min(100,c.bond+gain);c.lastCare=State.elapsed;},c.name+" loved that! +"+gain+" friendship"+(gift!=null?" · "+c.name+" gave you the "+gift.name.ToLowerInvariant()+"!":""));
```

- [ ] **Step 6: Run to verify it passes**

Run: `dotnet run --project tests/unity-domain`
Expected: `Wardrobe suite passed` and `PASS <n> checks` (676044 on the plan-02 base during planning, 676099 with plans 02–04 applied).

- [ ] **Step 7: Commit**

```bash
git add unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json unity/PurringtonHotel/Assets/Purrington/Runtime/Domain tests/unity-domain
git commit -m "feat(domain): cat wardrobe with bought wear and friendship gifts"
```

---

### Task 2: Load wear content and dress the rigs

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/CatOutfitView.cs`
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/WardrobeTests.cs`
- Modify: `…/Presentation/HotelApp.cs:65`, `VoxelWorld.cs:44`, `VoxelWorldCare.cs:7`

- [ ] **Step 1: Write the failing EditMode tests**

```csharp
using System.Collections.Generic;using NUnit.Framework;using Purrington.Domain;using Purrington.Presentation;using UnityEngine;
namespace Purrington.Tests {
public sealed class WardrobeTests {
 [Test]public void WardrobeContentLoadsFromResources(){Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);Assert.AreEqual(12,Wardrobe.All.Length);}
 [Test]public void OutfitPiecesSitOnTheirAnchorsAndClearAway(){
  Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);
  using(var g=new GodotGeometry()){var parent=new GameObject("Rig parent").transform;try{
   var rig=new GodotCatRig(g,parent,"cats","0",0);
   CatOutfitView.Apply(g,rig,new Dictionary<string,string>{{"head","sun_hat"},{"neck","bow_tie"}});
   var hat=rig.Bindings["head"].Find("Wear_head");Assert.IsNotNull(hat);Assert.AreEqual(3,hat.childCount);
   Assert.IsNotNull(rig.Bindings["body"].Find("Wear_neck"));
   CatOutfitView.Apply(g,rig,new Dictionary<string,string>());
   Assert.IsNull(rig.Bindings["head"].Find("Wear_head"));Assert.IsNull(rig.Bindings["body"].Find("Wear_neck"));
  }finally{Object.DestroyImmediate(parent.gameObject);}}}
}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `.\tools\unity.ps1 Test`
Expected: compile error `The name 'CatOutfitView' does not exist in the current context`.

- [ ] **Step 3: Create `CatOutfitView.cs`**

```csharp
using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
// Builds wear boxes under a cat rig. Parts are authored in anchor units: 1 = the anchor's width. Origin: head = top center of the head; neck = front top of the body; back = top center of the body.
public static class CatOutfitView {
 public static string Signature(IDictionary<string,string> outfit){return outfit==null?"":string.Join("|",Wardrobe.Slots.Select(s=>outfit.TryGetValue(s,out var id)?id:""));}
 public static void Apply(GodotGeometry geometry,GodotCatRig rig,IDictionary<string,string> outfit){foreach(var slot in Wardrobe.Slots){var anchor=Anchor(rig,slot);if(anchor==null)continue;var old=anchor.Find("Wear_"+slot);if(old)Release(old.gameObject);if(outfit==null||!outfit.TryGetValue(slot,out var id)||string.IsNullOrEmpty(id))continue;var wear=Wardrobe.Find(id);if(wear==null)continue;var bounds=LocalBounds(anchor);float unit=Mathf.Max(.05f,bounds.size.x);var origin=slot=="neck"?new Vector3(bounds.center.x,bounds.max.y,bounds.max.z):new Vector3(bounds.center.x,bounds.max.y,bounds.center.z);var root=new GameObject("Wear_"+slot).transform;root.SetParent(anchor,false);root.localPosition=origin;foreach(var part in wear.parts){var b=part["box"];var cube=GameObject.CreatePrimitive(PrimitiveType.Cube);Release(cube.GetComponent<Collider>());cube.name="Wear part";cube.transform.SetParent(root,false);var size=new Vector3((float)b[3],(float)b[4],(float)b[5])*unit;cube.transform.localPosition=new Vector3((float)b[0],(float)b[1],(float)b[2])*unit+size/2;cube.transform.localScale=size;cube.GetComponent<MeshRenderer>().sharedMaterial=geometry.Material((string)part["color"]);}}}
 static Transform Anchor(GodotCatRig rig,string slot){rig.Bindings.TryGetValue(slot=="head"?"head":"body",out var t);return t;}
 // Bounds of the anchor's own meshes in its local space, ignoring worn pieces and child limbs such as ears.
 static Bounds LocalBounds(Transform anchor){var filters=anchor.GetComponents<MeshFilter>();if(filters.Length==0)filters=anchor.GetComponentsInChildren<MeshFilter>().Where(f=>!f.GetComponentsInParent<Transform>().Any(p=>p.name.StartsWith("Wear_"))).ToArray();var result=new Bounds(Vector3.zero,Vector3.zero);bool any=false;foreach(var f in filters){if(f.sharedMesh==null)continue;var mb=f.sharedMesh.bounds;for(int i=0;i<8;i++){var corner=mb.center+Vector3.Scale(mb.extents,new Vector3((i&1)==0?-1:1,(i&2)==0?-1:1,(i&4)==0?-1:1));var local=anchor.InverseTransformPoint(f.transform.TransformPoint(corner));if(!any){result=new Bounds(local,Vector3.zero);any=true;}else result.Encapsulate(local);}}return any?result:new Bounds(Vector3.zero,Vector3.one*.3f);}
 static void Release(Object o){if(Application.isPlaying)Object.Destroy(o);else Object.DestroyImmediate(o);}
}
}
```

- [ ] **Step 4: Load wear content with the reference content**

At `HotelApp.cs:65`, right after the reference manifest is loaded and validated, add `Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);`.

- [ ] **Step 5: Dress every cat that appears**

- **Hotel actors** (`VoxelWorld.cs:44`, `SyncActors`): after the rig for actor `a` is found or created, and only for guests (`a.kind==ActorKind.Guest`), apply the outfit whenever it changes. Add `readonly Dictionary<string,string> outfitShown=new Dictionary<string,string>();` in `VoxelWorldShell.cs`, then:

```csharp
if(a.kind==ActorKind.Guest&&a.catId>=0&&a.catId<model.State.cats.Count){var outfit=model.State.cats[a.catId].outfit;string sig=CatOutfitView.Signature(outfit);if(!outfitShown.TryGetValue(a.id,out var shown)||shown!=sig){CatOutfitView.Apply(geometry,rig,outfit);outfitShown[a.id]=sig;}}
```

- **Care view** (`VoxelWorldCare.cs:7`): after `careRig=new GodotCatRig(geometry,careStage,"cats",catId.ToString(),catId);` add `CatOutfitView.Apply(geometry,careRig,model.State.cats[catId].outfit);`. Also add `public void PreviewOutfit(IDictionary<string,string> outfit){if(careRig!=null)CatOutfitView.Apply(geometry,careRig,outfit);}` to `VoxelWorldCare.cs` for the try-on flow.
- **Street neighbors** (`NeighborhoodView.cs:44`) are not roster cats. Leave them undressed.

- [ ] **Step 6: Run the tests and look at it**

Run: `.\tools\unity.ps1 Test` (exit 0). In Play mode, give Miso a sun hat and bow tie through the Unity CLI's C# execution: `HotelApp` model → `BuyWear`, then `Dress`. Check that the hat sits on the head between the ears and that the bow tie sits under the chin, facing forward.
- If the tie faces backward, the body's forward axis is −z. Use `bounds.min.z` for the neck origin instead.
- Record which axis was right in a code comment.

- [ ] **Step 7: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/WardrobeTests.cs*
git commit -m "feat(world): cats wear their outfits in the hotel and care view"
```

---

### Task 3: Wardrobe panel with try-on

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/WardrobePanel.cs`
- Modify: the care panel (`HotelUI.CarePanel` → `GestureCarePanel`; find it with `grep -n "void GestureCarePanel" unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/*.cs`)

- [ ] **Step 1: Create `WardrobePanel.cs`**

```csharp
using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
    public sealed partial class HotelUI
    {
        bool wardrobeOpen;string wardrobeSlot="head";string tryingOn="";
        // Try-on previews on the care rig without spending; Buy & wear commits both steps.
        void WardrobePanel(RectTransform content)
        {
            var cat=app.Model.State.cats[careCat];var row=Row(content,50);
            foreach(var slot in Wardrobe.Slots){string chosen=slot;Button(row,char.ToUpper(slot[0])+slot.Substring(1),()=>{wardrobeSlot=chosen;tryingOn="";app.World.PreviewOutfit(cat.outfit);Rebuild();},slot==wardrobeSlot?Gold:Mint,13);}
            cat.outfit.TryGetValue(wardrobeSlot,out var worn);
            Card(content,"Nothing","Take it off","Wear",()=>Wear(cat.id,""),Mint);
            foreach(var wear in Wardrobe.All.Where(w=>w.slot==wardrobeSlot))
            {
                var w=wear;bool owned=app.Model.OwnsWear(w.id);
                string note=w.id==worn?"Wearing now":owned?"In the wardrobe":w.giftCat>=0?"Gift from "+app.Model.State.cats[w.giftCat].name+" at friendship "+w.giftBond:w.price.ToString("N0")+" coins";
                string action=w.id==worn?"Worn":tryingOn==w.id&&!owned&&w.giftCat<0?"Buy & wear":owned?"Wear":w.giftCat>=0?"Locked":"Try on";
                Card(content,w.name,note,action,()=>
                {
                    if(owned){Wear(cat.id,w.id);return;}
                    if(w.giftCat>=0){ShowNotice(note,false);return;}
                    if(tryingOn!=w.id){tryingOn=w.id;var preview=new Dictionary<string,string>(cat.outfit){[w.slot]=w.id};app.World.PreviewOutfit(preview);Rebuild();return;}
                    var bought=app.Model.BuyWear(w.id);app.Report(bought);if(bought.success){app.Audio?.PlayEffect("spend");Wear(cat.id,w.id);}else ShowNotice(bought.message,true);
                },w.id==worn?Gold:Mint);
            }
        }
        void Wear(int catId,string id){var r=app.Model.Dress(catId,wardrobeSlot,id);tryingOn="";app.Report(r);app.World.PreviewOutfit(app.Model.State.cats[catId].outfit);Rebuild();ShowNotice(r.message,!r.success);}
        void CloseWardrobe(){if(!wardrobeOpen)return;wardrobeOpen=false;tryingOn="";if(careCat>=0)app.World.PreviewOutfit(app.Model.State.cats[careCat].outfit);}
    }
}
```

This uses the existing `HotelUI` helpers `Row`, `Button`, `Card`, `ShowNotice`, `Rebuild`, `app.Report`, the colors `Gold`/`Mint`, and `careCat`. If one of them has a different signature, match the existing callers in `HotelParityUI.cs`.

- [ ] **Step 2: Open it from the care panel**

In `GestureCarePanel`, add a **Wardrobe** button to the care action row that sets `wardrobeOpen=!wardrobeOpen;Rebuild();`. When `wardrobeOpen` is true, render `WardrobePanel(content)` in place of the care tool grid. Call `CloseWardrobe()` from `CloseCare`, so an unbought try-on never sticks.

- [ ] **Step 3: Run the tests and play-check**

Run: `.\tools\unity.ps1 Test` (exit 0). In Play mode:
1. Open Miso and tap Wardrobe → Head → Straw sun hat. It previews on Miso and coins are unchanged.
2. Tap **Buy & wear**. Coins drop by 180 and the hat stays after closing care.
3. The guest Miso in the hotel wears it too.
4. Tiny crown shows "Gift from Miso at friendship 50".
5. Close care mid-try-on and reopen. The hat you didn't buy is gone.

- [ ] **Step 4: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation
git commit -m "feat(ui): wardrobe with try-on, buy & wear, and friendship gifts"
```

---

### Task 4: Wear art pass and Gate 3 captures (voxel art agent + Unity QA agent)

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json` (part tuning only)
- Create: `docs/art/qa-shots/hotel-growth/wardrobe-*.png`

- [ ] **Step 1: Tune the parts on real cats.** For each of the 12 items, capture it on three differently sized cats (a kitten, Miso and the largest roster cat) in the care view. Adjust only the `box` numbers and colors in `Wardrobe.json` until each item reads clearly at phone size and doesn't clip through ears or legs. Keep the colors in the concept palette (`docs/art/STYLE-GUIDE.md`).
- [ ] **Step 2: Re-run both harnesses.** `dotnet run --project tests/unity-domain` (the item count and gift checks guard the content), then `.\tools\unity.ps1 Test`.
- [ ] **Step 3: Capture Gate 3.** Save `docs/art/qa-shots/hotel-growth/wardrobe-care-{portrait,landscape}.png`, `wardrobe-roaming.png` (three dressed guests in the hotel) and `wardrobe-grid.png` (all 12 items). Reload the save and confirm outfits persist.
- [ ] **Step 4: Commit**

```bash
git add unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json docs/art/qa-shots/hotel-growth
git commit -m "art: tune wear items; wardrobe QA captures"
```

## Verification record

Task 1 was applied on 2026-09-22 to scratch copies of the plan-02 base (lane C's starting point) and of the full plan 02–04 stack. Both ran green: `PASS 676044` and `PASS 676099` checks, including the Godot oracle. Tasks 2–4 are Unity presentation code and were **not** compiled during planning. Their `tools/unity.ps1 Test` and Play-mode steps are the gates.
