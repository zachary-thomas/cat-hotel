# Lawn Color Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make owned land blend with the world's ground on all four maps, so the Meadow lot no longer reads as a pasted-on green tile.

**Architecture:** The owned-parcel recipes in `GodotGeometry.json` were authored with their own lawn swatches. The world meadow is a separate 400×400 ground part with the concept-graded color. When a parcel is owned, `VoxelWorld.BuildOwnedPlots` recolors its lawn recipe to the world ground's color, found as the largest-area part in the map's `groundWithoutParcels` recipe, before building it. Both surfaces then share one cached material.

**Tech Stack:** Unity 6000.3 URP, Newtonsoft.Json (`JObject`), NUnit EditMode tests.

**Spec:** [hotel-growth design](../specs/2026-09-22-hotel-growth-design.md), "Why" item 1.

---

## Root cause (confirmed during planning)

Largest ground part per map (`groundWithoutParcels`) compared with the owned-parcel lawn part (`parcels[owned=true].root`):

| Map | World ground | Owned lot (authored) | After `ConceptTheme.Surface` remap |
|---|---|---|---|
| 0 Meadow | `#83a36e` | `#60a830` | `#82934D` (olive, visibly different) |
| 1 Seaside | `#cfbb90` | `#e6d0a0` | unchanged (lighter sand) |
| 2 Forest | `#758c64` | `#829b6f` | unchanged (lighter moss) |
| 3 Snowcap | `#c2cdcb` | `#d7e4e2` | unchanged (brighter snow) |

The owned-lot swatches all differ from the world ground on every map. Meadow's is the most visible because the remap sends `#60a830` to olive while the world is sage.

## Files

- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/GodotGeometry.cs` (add `LawnColor`, `Recolor`; add `using System.Linq;`)
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorld.cs:43` (`BuildOwnedPlots`)
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LawnColorTests.cs`
- Create: `docs/art/qa-shots/hotel-growth/lawn-{meadow,seaside,forest,snowcap}.png`

---

### Task 1: Lawn helpers with tests

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LawnColorTests.cs`
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/GodotGeometry.cs`

- [x] **Step 1: Write the failing tests**

```csharp
using System.Collections.Generic;using System.Linq;using NUnit.Framework;using Newtonsoft.Json.Linq;using Purrington.Presentation;
namespace Purrington.Tests {
public sealed class LawnColorTests {
 static IEnumerable<string> Colors(JToken recipe){return recipe.SelectTokens("..parts[*].color").Select(c=>(string)c);}
 [Test]public void LawnColorIsTheWorldGroundSwatch(){using(var g=new GodotGeometry()){Assert.AreEqual("#83a36eff",GodotGeometry.LawnColor((JObject)g.Map(0)["groundWithoutParcels"]));Assert.AreEqual("#cfbb90ff",GodotGeometry.LawnColor((JObject)g.Map(1)["groundWithoutParcels"]));Assert.AreEqual("#758c64ff",GodotGeometry.LawnColor((JObject)g.Map(2)["groundWithoutParcels"]));Assert.AreEqual("#c2cdcbff",GodotGeometry.LawnColor((JObject)g.Map(3)["groundWithoutParcels"]));}}
 [Test]public void OwnedParcelLawnMatchesWorldGroundOnEveryMap(){using(var g=new GodotGeometry())for(int i=0;i<4;i++){var map=g.Map(i);string lawn=GodotGeometry.LawnColor((JObject)map["groundWithoutParcels"]);foreach(var parcel in map["parcels"].Where(p=>(bool)p["owned"])){var colors=Colors(GodotGeometry.Recolor((JObject)parcel["root"],lawn)).ToArray();Assert.IsNotEmpty(colors,"map "+i+" parcel "+parcel["id"]+" has lawn parts");foreach(string c in colors)Assert.AreEqual(lawn,c,"map "+i+" parcel "+parcel["id"]);Assert.AreEqual(g.Material(lawn).color,g.Material(colors[0]).color,"shared material color");}}}
 [Test]public void RecolorLeavesTheAuthoredRecipeUntouched(){using(var g=new GodotGeometry()){var root=(JObject)g.Map(0)["parcels"].First(p=>(bool)p["owned"])["root"];string before=root.ToString();GodotGeometry.Recolor(root,"#000000ff");Assert.AreEqual(before,root.ToString());}}
}
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run (PowerShell, repo root): `.\tools\unity.ps1 Test`
Expected: a compile failure in `LawnColorTests.cs` because `'GodotGeometry' does not contain a definition for 'LawnColor'`, and the Unity CLI exits non-zero. Check `builds/unity/test-results.xml` or the CLI output.

- [x] **Step 3: Implement the helpers in `GodotGeometry.cs`**

Add `using System.Linq;` to the using block at the top. Then insert these two members directly after `public JObject Map(int index) { … }` (line 17):

```csharp
 // Owned-lot recipes predate the concept color pass. Lawns reuse the world's own ground swatch so owned land never reads as a pasted tile.
 public static string LawnColor(JObject ground) { string best=null;double area=-1;void Walk(JToken n){foreach(var p in n["parts"]??new JArray()){var t=p["transform"] as JArray;double a=t==null||t.Count!=12?0:Math.Abs((double)t[0]*(double)t[8]);if(a>area){area=a;best=(string)p["color"];}}foreach(var c in n["children"]??new JArray())Walk(c);}Walk(ground);return best??"#83a36eff"; }
 public static JObject Recolor(JObject recipe,string color) { var copy=(JObject)recipe.DeepClone();foreach(var p in copy.SelectTokens("..parts[*]").OfType<JObject>().ToList())p["color"]=color;return copy; }
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `.\tools\unity.ps1 Test`
Expected: exit code 0; the three `LawnColorTests` pass, and the existing suites are unchanged.

- [x] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/GodotGeometry.cs unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LawnColorTests.cs unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LawnColorTests.cs.meta
git commit -m "fix: lawn helpers pick the world ground swatch for owned land"
```

(Unity generates the `.meta` during the test run. If it's missing, run `.\tools\unity.ps1 Test` once more before committing.)

### Task 2: Use the world lawn for owned parcels

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorld.cs:43`

- [x] **Step 1: Replace `BuildOwnedPlots`**

Current (line 43, first member):

```csharp
 void BuildOwnedPlots(){foreach(var parcel in geometry.Map(currentMap)["parcels"]){string id=(string)parcel["id"];bool owned=id=="base"||model.Hotel().plots.Contains(id);if((bool)parcel["owned"]==owned)geometry.Build(layout,(JObject)parcel["root"]);}}
```

Replace with:

```csharp
 void BuildOwnedPlots(){string lawn=GodotGeometry.LawnColor((JObject)geometry.Map(currentMap)["groundWithoutParcels"]);foreach(var parcel in geometry.Map(currentMap)["parcels"]){string id=(string)parcel["id"];bool owned=id=="base"||model.Hotel().plots.Contains(id);if((bool)parcel["owned"]!=owned)continue;var root=(JObject)parcel["root"];geometry.Build(layout,owned?GodotGeometry.Recolor(root,lawn):root);}}
```

Unowned parcels keep their authored "for sale" dressing. Only the owned lawn is recolored.

- [x] **Step 2: Run the EditMode tests**

Run: `.\tools\unity.ps1 Test`
Expected: exit code 0.

- [x] **Step 3: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorld.cs
git commit -m "fix: owned land uses each map's world lawn color"
```

### Task 3: Visual verification on all four maps (Unity QA agent)

**Files:**
- Create: `docs/art/qa-shots/hotel-growth/lawn-meadow.png`, `lawn-seaside.png`, `lawn-forest.png`, `lawn-snowcap.png`

- [x] **Step 1: Build the preview**

Run: `.\tools\unity.ps1 Windows`
Expected: exit code 0; `builds/unity/Windows/PurringtonHotel.exe` updated.

- [x] **Step 2: Capture each map in God mode.** In the running preview, open Settings, enable God mode, then use Map to visit each destination. Use `unity:unity-cli` to drive the editor Game view if preferred. Capture the Hotel view at default zoom, and once in Build → Land so the owned outline is visible.

- [x] **Step 3: Check the captures.** The owned-lot boundary must be invisible against the surrounding meadow, sand, moss and snow. Paths, rooms and the plot-for-sale signs are unchanged. Compare against `docs/art/qa-shots/meadow-day-color-pass.png` (before).

- [x] **Step 4: Commit the captures**

```bash
git add docs/art/qa-shots/hotel-growth/lawn-*.png
git commit -m "docs: lawn color QA captures for all maps"
```
