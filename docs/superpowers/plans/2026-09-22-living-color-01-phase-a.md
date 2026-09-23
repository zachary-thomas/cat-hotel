# Living Color and Day/Night (Phase A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Unity hotel look like `assets/ui/mobile` (bright pastel voxel world, soft light, glowing lamps), add a 24-minute day/night cycle with light night-time behavior, and restyle the HUD chrome to `docs/concept-art`, all without changing the isometric camera or the save format.

**Architecture:** Pure logic goes in `Runtime/Domain`, so the fast .NET harness tests it: the clock (`HotelClock`), the palette table and color math (`SurfacePalette`), keyframe parsing and interpolation (`DayCycle`), and night behavior. Presentation stays a thin layer: `WorldLighting` applies an evaluated `DayLight` to the sun, ambient, camera and a runtime copy of the grading profile; `GodotGeometry` picks deterministic tone variants and drives window emission; `HotelUI` uses `ConceptTheme.Ui` tokens. Grading and mobile SSAO are asset changes made by `ProjectSetup.ConfigureRendering`.

**Tech Stack:** Unity 6000.3.24f1, URP 17.3, C# 9, Newtonsoft.Json, uGUI + TextMeshPro, NUnit EditMode, the .NET 9 domain harness (`tests/unity-domain`).

**Spec:** [living color and day/night design](../specs/2026-09-22-living-color-day-night-design.md). **Roadmap for Phases B–D:** [living color roadmap](2026-09-22-living-color-00-roadmap.md).

## Global Constraints

- Unity only: `unity/PurringtonHotel`. Do not edit the Godot project, `GodotReference.json` or `GodotGeometry.json`.
- The orthographic 36.59° / 315° camera, framing and pan/zoom do not change. No perspective, tilt-shift or DOF.
- No save schema change: no new `StrictSaveJson` fields, no version bump. `settings.evening` stays in `SettingsState` but nothing reads it.
- Never edit the "Godot oracle" section of `tests/unity-domain/Program.cs`. `Rate()`, `GuestCapacity()`, room status and construction are identical at every time of day.
- `DayLengthSeconds = 1440`, `StartMinute = 480` (08:00). Phases: Dawn 05:00–07:30, Day 07:30–17:30, Dusk 17:30–20:00, Night 20:00–05:00. Daylight `sin(π·t)^0.6` over 04:30–20:30.
- Existing C# files use dense one-line members: match that style when editing them. New files may be conventionally formatted.
- `VoxelWorld.cs`, `HotelUI.cs`, `CatSpeechOverlay.cs`, `VoxelWorldPreview.cs`, `VoxelWorldSpeech.cs`, `tests/unity-domain/Program.cs`, `tests/unity-domain/ShellSuites.cs` and the font assets carry **uncommitted user work**. Never `git add` whole files you did not otherwise change. For shared files, stage only your hunks (`git add -p`), and never revert or reformat their other lines.
- Every new Unity asset or script needs its `.meta` file. Let Unity generate it by opening or refreshing the project (running `.\tools\unity.ps1 Test` imports), then commit the generated `.meta`.
- Harness command (repo root): `dotnet run --project tests/unity-domain`. The final line must be `PASS <n> checks`.
- Unity tests: `.\tools\unity.ps1 Test` writes `builds/unity/test-results.xml`.

## Review Focus

1. **Travelling to another destination after dark:** materials built for the new map must pick up the current glow, or windows stay dark until the next change. Task 5 pins this with a test that creates a glass material after `SetGlow`.
2. **Reduced motion on at night:** lamps must still glow when `settings.motion` is false, because `GodotObjectMotion.Advance` returns early in that path. Task 6 adds the emission to both paths, and the Task 9 smoke run checks a lamp at pinned night with motion off.
3. **Existing saves with arbitrary or invalid `elapsed`:** negative, NaN, infinite or very large values must read as a valid clock and never throw. Task 1 tests each.
4. **360×640 at text scale 1.5:** the new clock chip and two-line wallet must fit the header without spilling off screen. Task 8 uses the compact label, and the Task 9 smoke run checks the chip text and the existing panel bounds at that size.
5. **Missing or malformed `DayCycle.json`:** this must fail loudly at startup with a message naming the file and field, not produce black lighting. Task 3 tests `DayCycle.Parse` errors, and `WorldLighting.Initialize` throws into `HotelApp`'s existing error path.

---

### Task 0: Baseline captures and mobile performance sample

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/PreviewVerification.cs:82-87`
- Create: `docs/art/qa-shots/living-color/baseline/` (captures + `performance.txt`, `performance-mobile.txt`)

**Interfaces:**
- Produces: `performance-mobile.txt` in the capture folder, which Task 9 compares against.

- [ ] **Step 1: Add a mobile-quality sample after the existing desktop sample.** In `PreviewVerification.cs`, directly after the `File.WriteAllText(Path.Combine(output,"performance.txt"),...)` line (line 87), insert:

```csharp
            int previousQuality=QualitySettings.GetQualityLevel();int mobileQuality=System.Array.FindIndex(QualitySettings.names,n=>n.IndexOf("Mobile",System.StringComparison.OrdinalIgnoreCase)>=0);
            if(mobileQuality>=0)QualitySettings.SetQualityLevel(mobileQuality,true);
            Screen.SetResolution(390,844,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(1);app.UI.Navigate("Hotel");
            sampleStart=Time.realtimeSinceStartup;frames=0;worst=0;while(frames<180){yield return null;frames++;worst=Mathf.Max(worst,Time.unscaledDeltaTime);}
            sampleTime=Time.realtimeSinceStartup-sampleStart;
            File.WriteAllText(Path.Combine(output,"performance-mobile.txt"),"quality="+(mobileQuality>=0?QualitySettings.names[mobileQuality]:"none")+"; 390x844; frames="+frames+"; averageMs="+(sampleTime/frames*1000).ToString("F2",System.Globalization.CultureInfo.InvariantCulture)+"; worstMs="+(worst*1000).ToString("F1",System.Globalization.CultureInfo.InvariantCulture));
            QualitySettings.SetQualityLevel(previousQuality,true);
```

- [ ] **Step 2: Build and run the smoke QA on the unchanged look.**

Run (PowerShell, repo root):
```powershell
.\tools\unity.ps1 Windows; .\tools\unity.ps1 QA
```
Expected: `PASS: startup, ...` printed from `result.txt`.

- [ ] **Step 3: Save the baseline.** Copy `builds/unity/captures/hotel-430x932.png`, `11-hotel-desktop.png`, `08-hotel-360x640-150.png`, `performance.txt` and `performance-mobile.txt` into `docs/art/qa-shots/living-color/baseline/`.

- [ ] **Step 4: Commit.**
```bash
git add -p unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/PreviewVerification.cs
git add docs/art/qa-shots/living-color/baseline
git commit -m "test(qa): record baseline captures and mobile frame time before living color"
```

---

### Task 1: Hotel clock (Domain)

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelClock.cs` (+ `.meta`)
- Create: `tests/unity-domain/ArtSuites.cs`
- Modify: `tests/unity-domain/Purrington.Domain.Tests.csproj` (add `<Compile Include="ArtSuites.cs" />` after `ShellSuites.cs`)
- Modify: `tests/unity-domain/Program.cs` (one call, placed next to `ShellSuites.RunGrid(Check);`)

**Interfaces:**
- Produces: `enum DayPhase { Dawn, Day, Dusk, Night }`; `readonly struct ClockReading { int day; float minute; DayPhase phase; float daylight; int Hour; int MinuteOfHour; }`; `static class HotelClock { const float DayLengthSeconds, StartMinute, DawnStart, DayStart, DuskStart, NightStart, Sunrise, Sunset; ClockReading Read(double elapsed); DayPhase PhaseAt(float minute); float Daylight(float minute); string Label(ClockReading r, bool compact); }`; `HotelModel.Clock` (`ClockReading`).

- [ ] **Step 1: Write the failing clock suite.** Create `tests/unity-domain/ArtSuites.cs`:

```csharp
using System;
using System.Linq;
using Purrington.Domain;

static class ArtSuites
{
	public static void RunClock(Action<bool,string> Check,ParityContent content)
	{
		var r=HotelClock.Read(0);
		Check(r.day==1&&r.minute==480&&r.phase==DayPhase.Day,"clock: a new hotel opens Day 1 at 08:00");
		Check(HotelClock.Label(r,false)=="Day 1 · 08:00"&&HotelClock.Label(r,true)=="08:00","clock: full and compact labels");
		r=HotelClock.Read(1440-480);
		Check(r.day==2&&r.minute==0&&r.phase==DayPhase.Night,"clock: midnight starts the next day");
		foreach(var (m,p) in new[]{(299f,DayPhase.Night),(300f,DayPhase.Dawn),(449f,DayPhase.Dawn),(450f,DayPhase.Day),(1049f,DayPhase.Day),(1050f,DayPhase.Dusk),(1199f,DayPhase.Dusk),(1200f,DayPhase.Night),(1439f,DayPhase.Night)})
			Check(HotelClock.PhaseAt(m)==p,"clock: phase at minute "+m);
		r=HotelClock.Read(200*1440.0+90);
		Check(r.day==201&&Math.Abs(r.minute-570)<.01f,"clock: exact after 200 days");
		float stored=200*1440f+90f;r=HotelClock.Read(stored);
		Check(r.day==201&&Math.Abs(r.minute-570)<1f,"clock: float State.elapsed keeps minute precision");
		foreach(double bad in new[]{-5,double.NaN,double.PositiveInfinity,double.NegativeInfinity})
			Check(HotelClock.Read(bad).day==1&&HotelClock.Read(bad).minute==480,"clock: invalid elapsed "+bad+" reads as a fresh hotel");
		Check(HotelClock.Read(1e12).day>1&&HotelClock.Read(1e12).minute>=0&&HotelClock.Read(1e12).minute<1440,"clock: huge elapsed stays in range");
		float last=0;
		for(float m=0;m<1440;m+=.5f){float d=HotelClock.Daylight(m);Check(d>=0&&d<=1,"clock: daylight in range at "+m);Check(Math.Abs(d-last)<.08f,"clock: daylight continuous at "+m);last=d;}
		Check(HotelClock.Daylight(250)==0&&HotelClock.Daylight(1250)==0&&HotelClock.Daylight(750)>.99f,"clock: daylight is zero at night and full at 12:30");
		var model=new HotelModel(new MemoryStore(),content);model.LoadOrCreate();model.State.elapsed=600;
		Check(model.Clock.minute==1080&&model.Clock.phase==DayPhase.Dusk,"clock: HotelModel.Clock reads State.elapsed");
		double rate=model.Rate();int capacity=model.GuestCapacity();model.State.elapsed=960;
		Check(model.Clock.phase==DayPhase.Night&&model.Rate()==rate&&model.GuestCapacity()==capacity,"clock: income and capacity ignore time of day");
	}
}
```

Register it: add `<Compile Include="ArtSuites.cs" />` to the harness `.csproj`, and in `Program.cs` insert `ArtSuites.RunClock(Check,content);` immediately before `ShellSuites.RunGrid(Check);`, which is on line 17.

- [ ] **Step 2: Run the harness to verify it fails.**
Run: `dotnet run --project tests/unity-domain`
Expected: build error `The name 'HotelClock' does not exist in the current context`.

- [ ] **Step 3: Implement the clock.** Create `Runtime/Domain/HotelClock.cs`:

```csharp
using System;

namespace Purrington.Domain
{
    public enum DayPhase { Dawn, Day, Dusk, Night }

    public readonly struct ClockReading
    {
        public readonly int day;
        public readonly float minute;
        public readonly DayPhase phase;
        public readonly float daylight;
        public ClockReading(int day, float minute, DayPhase phase, float daylight) { this.day = day; this.minute = minute; this.phase = phase; this.daylight = daylight; }
        public int Hour => (int)(minute / 60);
        public int MinuteOfHour => (int)minute % 60;
    }

    // Time of day is derived from played seconds, so it needs no save field and pauses while the app is closed.
    public static class HotelClock
    {
        public const float DayLengthSeconds = 1440f, StartMinute = 480f;
        public const float DawnStart = 300f, DayStart = 450f, DuskStart = 1050f, NightStart = 1200f;
        public const float Sunrise = 270f, Sunset = 1230f;

        public static ClockReading Read(double elapsed)
        {
            if (double.IsNaN(elapsed) || double.IsInfinity(elapsed) || elapsed < 0) elapsed = 0;
            double total = StartMinute + elapsed;
            double days = Math.Floor(total / DayLengthSeconds);
            float minute = (float)(total - days * DayLengthSeconds);
            if (minute < 0 || minute >= DayLengthSeconds) minute = 0;
            int day = days >= int.MaxValue - 1 ? int.MaxValue : (int)days + 1;
            return new ClockReading(day, minute, PhaseAt(minute), Daylight(minute));
        }

        public static DayPhase PhaseAt(float minute) =>
            minute < DawnStart || minute >= NightStart ? DayPhase.Night :
            minute < DayStart ? DayPhase.Dawn :
            minute < DuskStart ? DayPhase.Day : DayPhase.Dusk;

        public static float Daylight(float minute)
        {
            if (minute <= Sunrise || minute >= Sunset) return 0;
            return (float)Math.Pow(Math.Sin(Math.PI * (minute - Sunrise) / (Sunset - Sunrise)), .6);
        }

        public static string Label(ClockReading r, bool compact)
        {
            string time = r.Hour.ToString("00") + ":" + r.MinuteOfHour.ToString("00");
            return compact ? time : "Day " + r.day + " · " + time;
        }
    }

    public sealed partial class HotelModel { public ClockReading Clock => HotelClock.Read(State.elapsed); }
}
```

- [ ] **Step 4: Run the harness to verify it passes.**
Run: `dotnet run --project tests/unity-domain`
Expected: the final line is `PASS <n> checks`, where n is at least the previous count plus the new checks. `Godot oracle construction/maps passed` is still printed.

- [ ] **Step 5: Commit.** (Program.cs has user edits: stage only your line.)
```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelClock.cs tests/unity-domain/ArtSuites.cs tests/unity-domain/Purrington.Domain.Tests.csproj
git add -p tests/unity-domain/Program.cs
git commit -m "feat(domain): derive a 24-minute day/night clock from played time"
```
After Unity next imports (Task 2's test run), commit `HotelClock.cs.meta`.

---

### Task 2: Pastel surface palette and UI tokens (Domain + ConceptTheme)

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/SurfacePalette.cs` (+ `.meta`)
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/ConceptTheme.cs` (whole file, shown below)
- Modify: `tests/unity-domain/ArtSuites.cs` (add `RunPalette`), `tests/unity-domain/Program.cs` (one call)

**Interfaces:**
- Consumes: nothing.
- Produces: `SurfacePalette.Row { string source, target; bool authored; }`; `SurfacePalette.Rows`; `bool TryMap(string hex6, out string target)`; `bool IsGlass(string hex6)`; `int Variant(float x, float y, float z)` returning 0–2; `string Tone(string hex6, int variant)`; color math `Chroma`, `Value`, `Hue`, `RelativeLuminance`, `Contrast(a,b)`; UI token constants `Ink, InkSoft, Card, CardEdge, Sage, Leaf, LeafText, Coin, CoinRim` (hex6 strings). `ConceptTheme.Ui.{Ink,InkSoft,Card,CardEdge,Sage,Leaf,LeafText,Coin,CoinRim}` (`Color`) and `ConceptTheme.Ui.All` (`Color[]`, includes white).

- [ ] **Step 1: Write the failing palette suite.** Append to `ArtSuites`:

```csharp
	public static void RunPalette(Action<bool,string> Check)
	{
		var rows=SurfacePalette.Rows;
		Check(rows.Select(r=>r.source.ToLowerInvariant()).Distinct().Count()==rows.Length,"palette: one row per source");
		Check(!rows.Any(r=>rows.Any(o=>o.source.Equals(r.target,StringComparison.OrdinalIgnoreCase))),"palette: no chained remaps");
		double Median(System.Collections.Generic.IEnumerable<double> xs){var a=xs.OrderBy(x=>x).ToArray();return a.Length%2==1?a[a.Length/2]:(a[a.Length/2-1]+a[a.Length/2])/2;}
		Check(Median(rows.Select(r=>SurfacePalette.Chroma(r.target)))>=.25,"palette: median chroma is at least 0.25");
		Check(Median(rows.Select(r=>SurfacePalette.Value(r.target)))>=.85,"palette: median HSV value is at least 0.85 (high-key)");
		var lum=rows.Select(r=>SurfacePalette.RelativeLuminance(r.target)).ToArray();
		Check(lum.Max()-lum.Min()>=.40,"palette: light/dark spread keeps shapes readable");
		foreach(var r in rows.Where(r=>r.authored&&SurfacePalette.Chroma(r.source)>=.12))
		{
			double d=Math.Abs(SurfacePalette.Hue(r.source)-SurfacePalette.Hue(r.target));d=Math.Min(d,360-d);
			Check(d<=25,"palette: "+r.source+" keeps its hue family");
		}
		Check(SurfacePalette.TryMap("60A830",out var lawn)&&lawn=="8CC84B","palette: lookup ignores case");
		Check(!SurfacePalette.TryMap("123456",out _),"palette: unknown colors pass through");
		Check(SurfacePalette.IsGlass("90bfc0")&&SurfacePalette.IsGlass("b5ddcf")&&!SurfacePalette.IsGlass("fff8e9"),"palette: glass roles");
		foreach(var (fg,bg) in new[]{(SurfacePalette.Ink,SurfacePalette.Card),(SurfacePalette.Ink,SurfacePalette.Sage),(SurfacePalette.InkSoft,SurfacePalette.Card),(SurfacePalette.InkSoft,SurfacePalette.Sage),(SurfacePalette.LeafText,SurfacePalette.Sage),("FFFFFF",SurfacePalette.Leaf)})
			Check(SurfacePalette.Contrast(fg,bg)>=4.5,"palette: UI contrast "+fg+" on "+bg);
		for(int i=0;i<200;i++){int v=SurfacePalette.Variant(i*.37f,i%3*.5f,-i*.91f);Check(v>=0&&v<=2&&v==SurfacePalette.Variant(i*.37f,i%3*.5f,-i*.91f),"palette: variant is stable and in range");}
		Check(Enumerable.Range(0,60).Select(i=>SurfacePalette.Variant(i,0,i*2)).Distinct().Count()==3,"palette: all three tone variants occur");
		foreach(var r in rows)
		{
			Check(SurfacePalette.Tone(r.target,0)==r.target.ToUpperInvariant(),"palette: variant 0 is the base");
			Check(SurfacePalette.Value(SurfacePalette.Tone(r.target,1))>=SurfacePalette.Value(r.target)-.001&&SurfacePalette.Value(SurfacePalette.Tone(r.target,2))<=SurfacePalette.Value(r.target)+.001,"palette: light and dark tones for "+r.target);
			foreach(int v in new[]{1,2}){double d=Math.Abs(SurfacePalette.Hue(r.target)-SurfacePalette.Hue(SurfacePalette.Tone(r.target,v)));d=Math.Min(d,360-d);Check(SurfacePalette.Chroma(r.target)<.08||d<=12,"palette: tone "+v+" keeps the hue of "+r.target);}
		}
	}
```

Register it in `Program.cs` immediately after `ArtSuites.RunClock(Check,content);`: `ArtSuites.RunPalette(Check);`

- [ ] **Step 2: Run the harness to verify it fails.**
Run: `dotnet run --project tests/unity-domain`
Expected: build error `The name 'SurfacePalette' does not exist`.

- [ ] **Step 3: Implement `SurfacePalette`.** Create `Runtime/Domain/SurfacePalette.cs`:

```csharp
using System;
using System.Collections.Generic;

namespace Purrington.Domain
{
    // World surface roles and HUD tokens. Targets are sampled from assets/ui/mobile (world) and docs/concept-art (HUD).
    public static class SurfacePalette
    {
        public readonly struct Row
        {
            public readonly string source, target; public readonly bool authored;
            public Row(string source, string target, bool authored) { this.source = source; this.target = target; this.authored = authored; }
        }

        // authored=true: a legacy Godot color whose hue family must survive. false: a presentation literal given a new role.
        public static readonly Row[] Rows =
        {
            new Row("60a830","8CC84B",true), new Row("186030","4FA64A",true), new Row("a86030","D39A5A",true),
            new Row("f0d8c0","EAC08A",true), new Row("ede8d9","E4DCCB",true), new Row("fff8e9","FFF4DF",true),
            new Row("f0a830","F7CC62",true), new Row("ffd16f","F7CC62",true), new Row("ffab97","F08C7C",true),
            new Row("60d6a6","8ED9AE",true), new Row("dfd2f5","C3B2EE",true), new Row("f078a8","F5AEB4",true),
            new Row("a8d8f0","A9DDF6",true), new Row("dba5b0","F2A7B2",true), new Row("d7a4ba","E7A9C6",true),
            new Row("87b7a5","86CFA4",true), new Row("9dc4b5","9ED8BA",true), new Row("e6a1a6","F49AA2",true),
            new Row("ebb2b6","F6A9B0",true), new Row("74c5c5","7FD3CF",true), new Row("83d4d0","92DDD8",true),
            new Row("a8e9df","B2EEE4",true), new Row("b2e9df","BDF1E7",true), new Row("d7b5c4","EDBBD0",true),
            new Row("a892b9","B9A2DD",true), new Row("bfaecb","CDBDEB",true), new Row("e1c8d3","F2D3E0",true),
            new Row("ca9eae","E7A2B8",true), new Row("d4afbd","EDB5C7",true), new Row("dd929f","F2949F",true),
            new Row("e19fab","F4A3B0",true), new Row("e59889","F29A8A",true), new Row("ecb3a8","F6B8AB",true),
            new Row("edc76a","F7CC62",true), new Row("f7d880","F9DC84",true), new Row("c295c0","D69AD2",true),
            new Row("caa3c8","DFAEDA",true), new Row("9783a7","A58DD0",true), new Row("ac97bc","BBA4DD",true),
            new Row("b3a0c2","C4AEE3",true), new Row("b3c8cf","B4D8E6",true), new Row("bed5dc","C3E2EE",true),
            new Row("a7bbc2","A6CFE0",true), new Row("9eacc1","98A9EA",true), new Row("a8b7cd","A5B6EE",true),
            new Row("94a1b4","8E9FE0",true), new Row("9eb9b1","9FD1BF",true), new Row("b2cfcb","B6E0D8",true),
            new Row("9cb8b0","9ACFBC",true),
            // Destination lawns (world-map.png): Meadow, Seaside sand, Forest grass, Snowcap snow.
            new Row("83a36e","8CC84B",false), new Row("cfbb90","F3E2B5",false), new Row("758c64","6FAE55",false), new Row("c2cdcb","F4F7FB",false),
            // Room and shell literals: wainscot panels, per-destination roofs, window frame and panes, hedges.
            new Row("738448","8FD7A8",false), new Row("7e8c65","9ADCB2",false), new Row("87936e","86D2A0",false), new Row("697f59","7ECB98",false),
            new Row("a87868","6DBB6A",false), new Row("82a9a2","5C9EE0",false), new Row("7c8e6d","B0703F",false), new Row("d9e1d7","F1F5FA",false),
            new Row("90bfc0","A9DDF6",false), new Row("b5ddcf","C8EBFA",false), new Row("88ab72","6CC06A",false), new Row("6e9b62","5FB35C",false),
        };

        public const string Ink = "244335", InkSoft = "4E6555", Card = "FBF6E9", CardEdge = "E6DCC4", Sage = "DCE5C5";
        public const string Leaf = "4E7F3A", LeafText = "2E6B2C", Coin = "E9B43A", CoinRim = "B9832A";

        static readonly string[] glass = { "90bfc0", "b5ddcf" };
        static Dictionary<string, string> map;

        public static bool TryMap(string hex6, out string target)
        {
            if (map == null) { var m = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase); foreach (var r in Rows) m[r.source] = r.target; map = m; }
            target = null;
            return hex6 != null && map.TryGetValue(hex6, out target);
        }

        public static bool IsGlass(string hex6) => hex6 != null && Array.Exists(glass, g => g.Equals(hex6, StringComparison.OrdinalIgnoreCase));

        // Stable per-voxel tone pick from a rounded position; never UnityEngine.Random, so captures repeat.
        public static int Variant(float x, float y, float z)
        {
            unchecked
            {
                int h = (int)Math.Round(x * 2) * 73856093 ^ (int)Math.Round(y * 2) * 19349663 ^ (int)Math.Round(z * 2) * 83492791;
                return (int)((uint)h % 3u);
            }
        }

        // 0 = base, 1 = 4% lighter nudged warm, 2 = 4% darker nudged cool.
        public static string Tone(string hex6, int variant)
        {
            Rgb(hex6, out double r, out double g, out double b);
            if (variant == 1) { r = Mix(r * 1.04, 1.00, .03); g = Mix(g * 1.04, .886, .03); b = Mix(b * 1.04, .690, .03); }
            else if (variant == 2) { r = Mix(r * .96, .722, .03); g = Mix(g * .96, .784, .03); b = Mix(b * .96, .910, .03); }
            return Hex(r, g, b);
        }

        public static double Chroma(string hex) { Rgb(hex, out var r, out var g, out var b); return Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b)); }
        public static double Value(string hex) { Rgb(hex, out var r, out var g, out var b); return Math.Max(r, Math.Max(g, b)); }
        public static double Hue(string hex)
        {
            Rgb(hex, out var r, out var g, out var b);
            double max = Math.Max(r, Math.Max(g, b)), c = Chroma(hex);
            if (c <= 0) return 0;
            double h = max == r ? ((g - b) / c) % 6 : max == g ? (b - r) / c + 2 : (r - g) / c + 4;
            h *= 60; return h < 0 ? h + 360 : h;
        }
        public static double RelativeLuminance(string hex)
        {
            Rgb(hex, out var r, out var g, out var b);
            double L(double c) => c <= .03928 ? c / 12.92 : Math.Pow((c + .055) / 1.055, 2.4);
            return .2126 * L(r) + .7152 * L(g) + .0722 * L(b);
        }
        public static double Contrast(string a, string b)
        {
            double x = RelativeLuminance(a), y = RelativeLuminance(b);
            return (Math.Max(x, y) + .05) / (Math.Min(x, y) + .05);
        }

        public static void Rgb(string hex, out double r, out double g, out double b)
        {
            hex = (hex ?? "000000").TrimStart('#');
            if (hex.Length < 6) throw new FormatException("Expected a six-digit hex color, got '" + hex + "'.");
            r = Convert.ToInt32(hex.Substring(0, 2), 16) / 255.0; g = Convert.ToInt32(hex.Substring(2, 2), 16) / 255.0; b = Convert.ToInt32(hex.Substring(4, 2), 16) / 255.0;
        }
        static double Mix(double a, double b, double t) => a + (b - a) * t;
        static string Hex(double r, double g, double b)
        {
            int C(double v) => (int)Math.Round(Math.Max(0, Math.Min(1, v)) * 255);
            return C(r).ToString("X2") + C(g).ToString("X2") + C(b).ToString("X2");
        }
    }
}
```

- [ ] **Step 4: Run the harness to verify it passes.**
Run: `dotnet run --project tests/unity-domain`
Expected: `PASS <n> checks`. If a tone hue check fails for a near-gray row, only then raise that row's chroma exemption from `.08` to `.10`. Never loosen the palette guard itself.

- [ ] **Step 5: Point `ConceptTheme` at the table and add UI tokens.** Replace the whole body of `Runtime/Presentation/ConceptTheme.cs` with:

```csharp
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
    // World roles come from assets/ui/mobile; HUD tokens from docs/concept-art. Both live in SurfacePalette.
    public static class ConceptTheme
    {
        public static Color Ink => ColorOf(SurfacePalette.Ink);
        public static Color Cream => ColorOf("F8F3E3");
        public static Color Sage => ColorOf(SurfacePalette.Sage);
        public static Color Moss => ColorOf("789B58");
        public static Color Clay => ColorOf("D6A182");
        public static Color Honey => ColorOf("D7AE55");
        public static class Ui
        {
            public static Color Ink => ColorOf(SurfacePalette.Ink);
            public static Color InkSoft => ColorOf(SurfacePalette.InkSoft);
            public static Color Card => ColorOf(SurfacePalette.Card);
            public static Color CardEdge => ColorOf(SurfacePalette.CardEdge);
            public static Color Sage => ColorOf(SurfacePalette.Sage);
            public static Color Leaf => ColorOf(SurfacePalette.Leaf);
            public static Color LeafText => ColorOf(SurfacePalette.LeafText);
            public static Color Coin => ColorOf(SurfacePalette.Coin);
            public static Color CoinRim => ColorOf(SurfacePalette.CoinRim);
            public static Color[] All => new[] { Ink, InkSoft, Card, CardEdge, Sage, Leaf, LeafText, Coin, CoinRim, Color.white };
        }
        public static Color ColorOf(string hex)
        {
            ColorUtility.TryParseHtmlString("#"+hex.TrimStart('#'),out var color);
            return color;
        }
        // Paths have their own role: legacy geometry reused the timber swatch for paving.
        public static string PathColor(string style,float x,float z)
        {
            Color color=ColorOf(style=="gravel"?"C7C1AD":style=="brick"?"AAA895":"BBB6A5");
            int tile=Mathf.Abs(Mathf.RoundToInt(x)*17+Mathf.RoundToInt(z)*31)%5;
            color*=.96f+tile*.02f;color.a=1;
            return ColorUtility.ToHtmlStringRGB(color);
        }
        public static Color Surface(string authored)
        {
            string key=(authored??"ffffffff").TrimStart('#');
            ColorUtility.TryParseHtmlString("#"+key,out var original);
            if(key.Length>=6&&SurfacePalette.TryMap(key.Substring(0,6),out var replacement)){var mapped=ColorOf(replacement);mapped.a=original.a;return mapped;}
            return original;
        }
    }
}
```

(`PathColor` is unchanged. Keep `Ink/Cream/Sage/Moss/Clay/Honey`, because `HotelUI` and other panels use them.)

- [ ] **Step 6: Run the Unity EditMode tests.**
Run: `.\tools\unity.ps1 Test`
Expected: exit code 0; `builds/unity/test-results.xml` shows no failures. `LawnColorTests` still pass, because they assert authored hexes, not remapped colors.

- [ ] **Step 7: Commit.**
```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/SurfacePalette.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/SurfacePalette.cs.meta unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelClock.cs.meta unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/ConceptTheme.cs tests/unity-domain/ArtSuites.cs
git add -p tests/unity-domain/Program.cs
git commit -m "feat(art): retarget world surfaces to the pastel mobile art and add HUD tokens"
```

---

### Task 3: Day-cycle keyframes (Domain parser + content)

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/DayCycle.cs` (+ `.meta`)
- Create: `unity/PurringtonHotel/Assets/Resources/Content/DayCycle.json` (+ `.meta`)
- Modify: `tests/unity-domain/ArtSuites.cs` (add `RunDayCycle`), `tests/unity-domain/Program.cs` (one call)

**Interfaces:**
- Produces: `sealed class DayCycle { static DayCycle Parse(string json); int Count; DayLight Evaluate(float minute); }`; `readonly struct DayLight { float sunPitch, sunYaw, sunIntensity, shadowStrength, exposure, temperature, glow; float[] sun, sky, equator, ground, background; }` (colors are **linear** RGB, 3 floats each).

- [ ] **Step 1: Write the failing suite.** Append to `ArtSuites`:

```csharp
	public static void RunDayCycle(Action<bool,string> Check)
	{
		string json=System.IO.File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/DayCycle.json");
		var cycle=DayCycle.Parse(json);
		Check(cycle.Count>=6,"day cycle: at least six keys");
		var noon=cycle.Evaluate(750);Check(noon.glow==0&&noon.sunIntensity>=1.1f&&Math.Abs(noon.shadowStrength-.58f)<.001f,"day cycle: bright noon, no glow, soft 0.58 shadows");
		var night=cycle.Evaluate(1380);Check(night.glow==1&&night.sunIntensity<.4f,"day cycle: night glows and dims the light");
		Check(night.sky.Max()>.05f,"day cycle: night ambient never goes black");
		var key=cycle.Evaluate(1050);var before=cycle.Evaluate(1049.9f);Check(Math.Abs(key.sunPitch-before.sunPitch)<.1f,"day cycle: continuous into a key");
		var wrapA=cycle.Evaluate(1439.99f);var wrapB=cycle.Evaluate(0);Check(Math.Abs(wrapA.glow-wrapB.glow)<.01f&&Math.Abs(wrapA.sky[2]-wrapB.sky[2])<.01f,"day cycle: continuous across midnight");
		for(float m=0;m<1440;m+=7.5f){var l=cycle.Evaluate(m);Check(l.glow>=0&&l.glow<=1&&l.sun.All(c=>c>=0&&c<=1),"day cycle: values in range at "+m);}
		var noGlow=Newtonsoft.Json.Linq.JObject.Parse(json);((Newtonsoft.Json.Linq.JObject)noGlow["keys"][1]).Remove("glow");
		Check(json.Contains("\"minute\": 750"),"day cycle: test fixture has a 12:30 key");
		foreach(var (bad,why) in new[]{("{}","keys"),(json.Replace("\"minute\": 750","\"minute\": 100"),"order"),(noGlow.ToString(),"glow")})
		{
			try{DayCycle.Parse(bad);Check(false,"day cycle: rejects "+why);}
			catch(FormatException e){Check(e.Message.Contains("DayCycle.json")&&e.Message.Contains(why),"day cycle: error names file and "+why);}
		}
	}
```

Register it in `Program.cs` after `ArtSuites.RunPalette(Check);`: `ArtSuites.RunDayCycle(Check);`

- [ ] **Step 2: Run to verify it fails.**
Run: `dotnet run --project tests/unity-domain`
Expected: build error, `DayCycle` does not exist.

- [ ] **Step 3: Add the keyframes.** Create `Resources/Content/DayCycle.json`. The references are noted per key, and every key carries every field.

```json
{
  "keys": [
    { "minute": 0,    "sunPitch": 40, "sunYaw": 208, "sun": "93A6E2", "sunIntensity": 0.3,  "shadowStrength": 0.35, "sky": "6070B0", "equator": "4F5C98", "ground": "40604C", "background": "3B4A7A", "exposure": -0.15, "temperature": -20, "glow": 1 },
    { "minute": 300,  "sunPitch": 10, "sunYaw": 60,  "sun": "F7B7A3", "sunIntensity": 0.55, "shadowStrength": 0.45, "sky": "E8B8C8", "equator": "D9B7C9", "ground": "8FAE7A", "background": "F1C6C9", "exposure": -0.05, "temperature": 6,   "glow": 0.6 },
    { "minute": 450,  "sunPitch": 30, "sunYaw": 45,  "sun": "FFE6C4", "sunIntensity": 1.0,  "shadowStrength": 0.55, "sky": "FFF1D6", "equator": "F4E6C8", "ground": "B9D98A", "background": "CFEAF7", "exposure": 0.05,  "temperature": 4,   "glow": 0 },
    { "minute": 750,  "sunPitch": 52, "sunYaw": 28,  "sun": "FFF6E2", "sunIntensity": 1.2,  "shadowStrength": 0.58, "sky": "FFF4DE", "equator": "F6EBD2", "ground": "BFDD92", "background": "BFE6F8", "exposure": 0.1,   "temperature": 0,   "glow": 0 },
    { "minute": 1050, "sunPitch": 22, "sunYaw": 355, "sun": "FFD39A", "sunIntensity": 1.05, "shadowStrength": 0.6,  "sky": "FFE3BD", "equator": "F7D8B0", "ground": "B5CF84", "background": "F6DDB8", "exposure": 0.05,  "temperature": 10,  "glow": 0.15 },
    { "minute": 1170, "sunPitch": 9,  "sunYaw": 340, "sun": "F6A98A", "sunIntensity": 0.6,  "shadowStrength": 0.45, "sky": "E9B8C4", "equator": "C9B0D8", "ground": "8C9F7A", "background": "D7B3CF", "exposure": -0.05, "temperature": 4,   "glow": 0.85 },
    { "minute": 1290, "sunPitch": 38, "sunYaw": 215, "sun": "93A6E2", "sunIntensity": 0.3,  "shadowStrength": 0.35, "sky": "6070B0", "equator": "4F5C98", "ground": "40604C", "background": "3F4E82", "exposure": -0.15, "temperature": -20, "glow": 1 }
  ]
}
```

(05:00 dawn is soft pink-gold; 07:30 and 12:30 are the sunny high-key look of `welcome-hotel.png` and `upgrade-lounge.png`; 17:30 is golden; 19:30 is the peach-to-lilac dusk of `lantern-gathering.png`; 21:30 to midnight is a friendly blue-violet night with glow 1.)

- [ ] **Step 4: Implement the parser and interpolation.** Create `Runtime/Domain/DayCycle.cs`:

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Purrington.Domain
{
    public readonly struct DayLight
    {
        public readonly float sunPitch, sunYaw, sunIntensity, shadowStrength, exposure, temperature, glow;
        public readonly float[] sun, sky, equator, ground, background; // linear RGB
        public DayLight(float sunPitch, float sunYaw, float sunIntensity, float shadowStrength, float exposure, float temperature, float glow, float[] sun, float[] sky, float[] equator, float[] ground, float[] background)
        { this.sunPitch = sunPitch; this.sunYaw = sunYaw; this.sunIntensity = sunIntensity; this.shadowStrength = shadowStrength; this.exposure = exposure; this.temperature = temperature; this.glow = glow; this.sun = sun; this.sky = sky; this.equator = equator; this.ground = ground; this.background = background; }
    }

    public sealed class DayCycle
    {
        static readonly string[] Numbers = { "minute", "sunPitch", "sunYaw", "sunIntensity", "shadowStrength", "exposure", "temperature", "glow" };
        static readonly string[] Colors = { "sun", "sky", "equator", "ground", "background" };
        sealed class Key { public float[] n = new float[Numbers.Length]; public float[][] c = new float[Colors.Length][]; }
        readonly List<Key> keys;
        DayCycle(List<Key> keys) { this.keys = keys; }
        public int Count => keys.Count;

        public static DayCycle Parse(string json)
        {
            JObject root;
            try { root = JObject.Parse(json ?? ""); } catch (Exception e) { throw new FormatException("DayCycle.json is not valid JSON: " + e.Message); }
            if (!(root["keys"] is JArray array) || array.Count < 2) throw new FormatException("DayCycle.json needs a \"keys\" array with at least two keys.");
            var list = new List<Key>();
            for (int i = 0; i < array.Count; i++)
            {
                if (!(array[i] is JObject o)) throw new FormatException("DayCycle.json keys[" + i + "] must be an object.");
                var k = new Key();
                for (int f = 0; f < Numbers.Length; f++)
                {
                    var t = o[Numbers[f]];
                    if (t == null || (t.Type != JTokenType.Integer && t.Type != JTokenType.Float)) throw new FormatException("DayCycle.json keys[" + i + "] is missing number \"" + Numbers[f] + "\".");
                    k.n[f] = (float)t;
                }
                for (int f = 0; f < Colors.Length; f++)
                {
                    var t = o[Colors[f]];
                    if (t == null || t.Type != JTokenType.String) throw new FormatException("DayCycle.json keys[" + i + "] is missing color \"" + Colors[f] + "\".");
                    try { k.c[f] = Linear((string)t); } catch (FormatException) { throw new FormatException("DayCycle.json keys[" + i + "] color \"" + Colors[f] + "\" is not a hex color."); }
                }
                if (k.n[0] < 0 || k.n[0] >= 1440) throw new FormatException("DayCycle.json keys[" + i + "] minute must be in [0, 1440).");
                if (list.Count > 0 && k.n[0] <= list[list.Count - 1].n[0]) throw new FormatException("DayCycle.json keys must be in increasing minute order (keys[" + i + "]).");
                if (k.n[7] < 0 || k.n[7] > 1) throw new FormatException("DayCycle.json keys[" + i + "] glow must be in [0, 1].");
                list.Add(k);
            }
            return new DayCycle(list);
        }

        public DayLight Evaluate(float minute)
        {
            minute = ((minute % 1440f) + 1440f) % 1440f;
            int b = keys.FindIndex(k => k.n[0] > minute); if (b < 0) b = 0;
            int a = (b - 1 + keys.Count) % keys.Count;
            var ka = keys[a]; var kb = keys[b];
            float span = ((kb.n[0] - ka.n[0]) + 1440f) % 1440f; if (span <= 0) span = 1440f;
            float t = (((minute - ka.n[0]) + 1440f) % 1440f) / span;
            float N(int f) => ka.n[f] + (kb.n[f] - ka.n[f]) * t;
            float yawDelta = ((kb.n[2] - ka.n[2] + 540f) % 360f) - 180f;
            float[] C(int f) => new[] { ka.c[f][0] + (kb.c[f][0] - ka.c[f][0]) * t, ka.c[f][1] + (kb.c[f][1] - ka.c[f][1]) * t, ka.c[f][2] + (kb.c[f][2] - ka.c[f][2]) * t };
            return new DayLight(N(1), ka.n[2] + yawDelta * t, N(3), N(4), N(5), N(6), N(7), C(0), C(1), C(2), C(3), C(4));
        }

        static float[] Linear(string hex)
        {
            SurfacePalette.Rgb(hex, out var r, out var g, out var b);
            float L(double c) => (float)(c <= .04045 ? c / 12.92 : Math.Pow((c + .055) / 1.055, 2.4));
            return new[] { L(r), L(g), L(b) };
        }
    }
}
```

Every error message must contain `DayCycle.json` and the offending field or rule (the tests check `keys`, `order` and `glow`).

- [ ] **Step 5: Run to verify it passes.**
Run: `dotnet run --project tests/unity-domain`
Expected: `PASS <n> checks`.

- [ ] **Step 6: Commit** (include both `.meta` files after the next Unity import).
```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/DayCycle.cs unity/PurringtonHotel/Assets/Resources/Content/DayCycle.json tests/unity-domain/ArtSuites.cs
git add -p tests/unity-domain/Program.cs
git commit -m "feat(domain): day-cycle keyframes with validated parsing and wraparound interpolation"
```

---

### Task 4: Night behavior (Domain)

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelNight.cs` (+ `.meta`)
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelLife.cs` (lines 9, 23, 31: three in-line edits)
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelVisitors.cs:34`
- Modify: `tests/unity-domain/ArtSuites.cs` (add `RunNight`), `tests/unity-domain/Program.cs` (one call)

**Interfaces:**
- Consumes: `HotelModel.Clock` (Task 1).
- Produces: private helpers on `HotelModel`: `bool SunClosed`, `double NightPreference(VenueSnapshot v)`, `float SleepDuration(Actor a)`, `bool NightNap(string phase, string action)`, `bool VisitorsResting`.

- [ ] **Step 1: Write the failing suite.** Append to `ArtSuites`:

```csharp
	public static void RunNight(Action<bool,string> Check,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();
		Check(m.Venues().Any(v=>v.open&&v.role=="bed"),"night: starter hotel has an open bed");
		m.State.elapsed=14*60; // 22:00
		Check(m.Clock.phase==DayPhase.Night,"night: setup at 22:00");
		bool napped=false;
		for(int t=0;t<600;t++)
		{
			m.Tick(.5f);
			foreach(var a in m.Actors)
			{
				Check(a.kind!=ActorKind.DayVisitor,"night: no day visitor arrives at night");
				var v=m.Venues().FirstOrDefault(x=>x.id==a.venueId);
				if(v!=null&&v.role=="sun")Check(!(a.phase=="activity"||a.phase.StartsWith("walk")),"night: nobody heads for a sunny spot");
				if(a.phase=="activity"&&a.action=="sleep"&&m.Clock.phase==DayPhase.Night){napped=true;Check(a.intent=="napping","night: nap intent");Check(a.activityDuration>=90&&a.activityDuration<=150,"night: naps last 90-150 s");}
			}
		}
		Check(napped,"night: at least one guest naps in a bed");
		var day=new HotelModel(new MemoryStore(),content);day.LoadOrCreate();day.State.elapsed=2*60; // 10:00
		bool visitor=false,shortSleep=true;
		for(int t=0;t<400;t++){day.Tick(.5f);foreach(var a in day.Actors){if(a.kind==ActorKind.DayVisitor)visitor=true;if(a.phase=="activity"&&a.action=="sleep"&&a.activityDuration>11.01f)shortSleep=false;}}
		if(day.Venues().Any(v=>v.open&&v.role=="bar"))Check(visitor,"night: day visitors still arrive by day");
		Check(shortSleep,"night: daytime sleep keeps its 11 s duration");
	}
```

Register it in `Program.cs` after `ArtSuites.RunDayCycle(Check);`: `ArtSuites.RunNight(Check,content);`

- [ ] **Step 2: Run to verify it fails.**
Run: `dotnet run --project tests/unity-domain`
Expected: FAIL with `night: nap intent` or `night: no day visitor arrives at night`. If instead it fails on `night: starter hotel has an open bed`, stop and report: the starter content has changed and the test needs a bed placed first.

- [ ] **Step 3: Add the night helpers.** Create `Runtime/Domain/HotelNight.cs`:

```csharp
namespace Purrington.Domain
{
    // Night only changes where guests go and how long they sleep; income, capacity and room status never read the clock.
    public sealed partial class HotelModel
    {
        bool SunClosed => Clock.daylight < .25f;
        bool VisitorsResting => Clock.phase == DayPhase.Night;
        double NightPreference(VenueSnapshot v)
        {
            if (Clock.phase != DayPhase.Night) return 0;
            return v.role == "bed" ? 50 : v.role == "seat" || v.role == "warm" ? 3 : 0;
        }
        float SleepDuration(Actor a) => Clock.phase == DayPhase.Night ? 90 + StableHash(a.view.id ?? "") % 61u : 11;
        bool NightNap(string phase, string action) => phase == "activity" && action == "sleep" && Clock.phase == DayPhase.Night;
    }
}
```

- [ ] **Step 4: Wire it into life and visitors** (in-line edits; keep the dense style):
  - `HotelLife.cs` line 23 (`Choose`): change `Venues().Where(v=>v.open&&(a.checkedIn?v.role!="reception":v.role=="reception"))` to `Venues().Where(v=>v.open&&(a.checkedIn?v.role!="reception":v.role=="reception")&&!(v.role=="sun"&&SunClosed))`. In the `OrderByDescending(v=>1+...)` lambda, append `+NightPreference(v)` just before `+FriendScore(a,v)`.
  - `HotelLife.cs` line 31 (`Walk` arrival): change `action=="sleep"?11:7` to `action=="sleep"?SleepDuration(a):7`.
  - `HotelLife.cs` line 9 (`DescribeIntent`): insert `if(NightNap(phase,action))return "napping";` immediately before `if(phase=="activity"&&action=="sleep")return "sleeping";`.
  - `HotelVisitors.cs` `TickVisitors`: after `if (State.currentHotel != 0) return;` add the line `if (VisitorsResting) return;`.

- [ ] **Step 5: Run to verify it passes.**
Run: `dotnet run --project tests/unity-domain`
Expected: `PASS <n> checks`; the oracle line still prints; the existing 3000-tick "actor geometry safe" and "actor separation" checks still pass.

- [ ] **Step 6: Commit.**
```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelNight.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelLife.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelVisitors.cs tests/unity-domain/ArtSuites.cs
git add -p tests/unity-domain/Program.cs
git commit -m "feat(domain): guests nap at night, sunny spots close and day visitors pause"
```

---

### Task 5: Voxel tone variants and window glow (GodotGeometry)

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/GodotGeometry.cs:23` (`Material`), `:32` (part batching)
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorld.cs:53` (`Box`)
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LivingColorTests.cs` (+ `.meta`)

**Interfaces:**
- Consumes: `SurfacePalette.Variant`, `Tone`, `IsGlass` (Task 2).
- Produces: `Material GodotGeometry.Material(string hex, Vector3 position)`; `void GodotGeometry.SetGlow(float level)`; `static Color GodotGeometry.GlowColor` (`#FFD590`). Material cache keys may carry a `~N` variant suffix (N = 1 or 2).

- [ ] **Step 1: Write the failing EditMode tests.** Create `Tests/EditMode/LivingColorTests.cs`:

```csharp
using System.Linq;using NUnit.Framework;using Purrington.Domain;using Purrington.Presentation;using UnityEngine;
namespace Purrington.Tests {
public sealed class LivingColorTests {
 [Test]public void ToneVariantIsStablePerPositionAndAtMostThreePerColor(){using(var g=new GodotGeometry()){var a=g.Material("#fff8e9ff",new Vector3(1.2f,0,3.4f));Assert.AreSame(a,g.Material("#fff8e9ff",new Vector3(1.2f,0,3.4f)));var set=Enumerable.Range(0,60).Select(i=>g.Material("#fff8e9ff",new Vector3(i,0,i*2))).Distinct().ToArray();Assert.AreEqual(3,set.Length);}}
 [Test]public void PlainOverloadIsTheBaseTone(){using(var g=new GodotGeometry()){Assert.AreEqual(ConceptTheme.Surface("fff8e9"),g.Material("#fff8e9ff").color);}}
 [Test]public void GlassAndWaterNeverVary(){using(var g=new GodotGeometry()){var set=Enumerable.Range(0,30).Select(i=>g.Material("90bfc0",new Vector3(i,0,i*3))).Distinct().ToArray();Assert.AreEqual(1,set.Length);}}
 [Test]public void GlowReachesExistingAndLaterGlassMaterials(){using(var g=new GodotGeometry()){var early=g.Material("90bfc0");g.SetGlow(2.2f);var late=g.Material("b5ddcf");foreach(var m in new[]{early,late}){Assert.IsTrue(m.IsKeywordEnabled("_EMISSION"));Assert.Greater(m.GetColor("_EmissionColor").maxColorComponent,1f);}g.SetGlow(0);Assert.AreEqual(0f,early.GetColor("_EmissionColor").maxColorComponent,1e-4f);Assert.IsFalse(g.Material("fff8e9").IsKeywordEnabled("_EMISSION"));}}
}
}
```

- [ ] **Step 2: Run to verify it fails.**
Run: `.\tools\unity.ps1 Test`
Expected: compile failure in `LivingColorTests` (no `Material(string, Vector3)` or `SetGlow`).

- [ ] **Step 3: Implement it in `GodotGeometry.cs`.**
  - Add a field and helpers next to `materials`:
```csharp
 public static readonly Color GlowColor=new Color(1f,.835f,.565f);float glowLevel=0;
 static string BaseHex(string key){string hex=key.Split('~')[0].Split('|')[0].TrimStart('#');return hex.Length>=6?hex.Substring(0,6):hex;}
 static bool Varies(string hex){return !hex.StartsWith("water|")&&!SurfacePalette.IsGlass(BaseHex(hex));}
 public Material Material(string hex,Vector3 position){hex=hex??"#ffffffff";if(!Varies(hex))return Material(hex);int v=SurfacePalette.Variant(position.x,position.y,position.z);return Material(v==0?hex:hex+"~"+v);}
 public void SetGlow(float level){if(Mathf.Approximately(level,glowLevel))return;glowLevel=level;foreach(var pair in materials)if(pair.Value&&SurfacePalette.IsGlass(BaseHex(pair.Key)))Emit(pair.Value);}
 void Emit(Material m){m.EnableKeyword("_EMISSION");m.globalIlluminationFlags=MaterialGlobalIlluminationFlags.None;m.SetColor("_EmissionColor",GlowColor*glowLevel);}
```
  - In `Material(string hex)` (line 23): after `if(materials.TryGetValue(hex,out var m))return m;`, split off the variant with `int variant=0;string swatch=hex;int tilde=hex.IndexOf('~');if(tilde>0){int.TryParse(hex.Substring(tilde+1),out variant);swatch=hex.Substring(0,tilde);}`. Use `swatch` where the method currently reads `hex` for parsing, and after `color=ConceptTheme.Surface(value)` add `if(variant>0){var toned=ConceptTheme.ColorOf(SurfacePalette.Tone(ColorUtility.ToHtmlStringRGB(color),variant));toned.a=color.a;color=toned;}`. Just before `materials.Add(hex,m);` add `if(!water&&SurfacePalette.IsGlass(BaseHex(swatch)))Emit(m);` so glass created after dark glows immediately.
  - In `BuildAffine` (line 32), give each part a variant-aware batch key: after the water branch, add `if(!color.StartsWith("water|")){var world=(authored*Matrix(p["transform"])).GetColumn(3);int v=Varies(color)?SurfacePalette.Variant(world.x,world.y,world.z):0;if(v>0)color+="~"+v;}` (`authored` already equals the node transform times `residual`, so this is the part's position in the recipe's parent space and is stable between runs). The rest (`batches`, `Material(batch.Key)`) is unchanged, because `Material` understands the suffix.
  - Add `using Purrington.Domain;` at the top if missing.

- [ ] **Step 4: Use positions for procedural voxels.** In `VoxelWorld.cs` line 53 (`Box`), change `geometry.Material(color)` to `geometry.Material(color,p.TransformPoint(at))`.

- [ ] **Step 5: Run to verify it passes.**
Run: `.\tools\unity.ps1 Test`
Expected: all EditMode tests pass, including the existing `LawnColorTests`, which compare colors through the plain `Material(hex)` overload (base tone) and need no change.

- [ ] **Step 6: Commit.**
```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/GodotGeometry.cs unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LivingColorTests.cs unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LivingColorTests.cs.meta
git add -p unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorld.cs
git commit -m "feat(art): deterministic voxel tone variants and emissive window glass"
```

---

### Task 6: WorldLighting drives the cycle; retire the evening toggle

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/WorldLighting.cs` (+ `.meta`)
- Modify: `VoxelWorld.cs:15` (field), `:20` (`Initialize`), `:37` (delete `SetEvening`), `:41` (`Refresh`)
- Modify: `HotelApp.cs:75`, `ParityRenderAcceptance.cs:15,17,18,20`, `HotelParityUI.cs:368`, `GodotObjectMotion.cs:7,13,16`
- Modify: `Tests/EditMode/LivingColorTests.cs`

**Interfaces:**
- Consumes: `HotelModel.Clock`, `DayCycle.Parse/Evaluate`, `DayLight` (Tasks 1 and 3), `GodotGeometry.SetGlow/GlowColor` (Task 5).
- Produces: `VoxelWorld.Lighting` (`WorldLighting`); `WorldLighting.Initialize(HotelModel, Camera, GodotGeometry)`; `WorldLighting.Pin(float? minute)`; `float WorldLighting.Minute`; `static float WorldLighting.Glow`; `Light WorldLighting.Sun`; `static void WorldLighting.ApplyTo(Light sun, Camera cam, DayLight l)`.

- [ ] **Step 1: Write the failing test.** Append to `LivingColorTests`:

```csharp
 [Test]public void ApplyToSetsTrilightSunAndBackground(){
  var cycle=DayCycle.Parse(Resources.Load<TextAsset>("Content/DayCycle").text);
  var sun=new GameObject("sun").AddComponent<Light>();var cam=new GameObject("cam").AddComponent<Camera>();
  try{
   WorldLighting.ApplyTo(sun,cam,cycle.Evaluate(750));
   Assert.AreEqual(UnityEngine.Rendering.AmbientMode.Trilight,RenderSettings.ambientMode);Assert.AreEqual(.58f,sun.shadowStrength,1e-3f);Assert.AreEqual(1.2f,sun.intensity,1e-3f);
   var day=cam.backgroundColor;WorldLighting.ApplyTo(sun,cam,cycle.Evaluate(1380));Assert.Less(cam.backgroundColor.grayscale,day.grayscale);Assert.Less(sun.intensity,.4f);
  }finally{Object.DestroyImmediate(sun.gameObject);Object.DestroyImmediate(cam.gameObject);}}
```

- [ ] **Step 2: Run to verify it fails.**
Run: `.\tools\unity.ps1 Test`
Expected: compile failure, `WorldLighting` does not exist.

- [ ] **Step 3: Implement `WorldLighting`.** Create `Runtime/Presentation/WorldLighting.cs`:

```csharp
using System;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Purrington.Presentation
{
    // Applies the day-cycle keyframes to the sun, ambient light, sky color and a runtime copy of the grading profile.
    public sealed class WorldLighting : MonoBehaviour
    {
        public static float Glow { get; private set; }
        public Light Sun { get; private set; }
        HotelModel model; Camera cam; GodotGeometry geometry; DayCycle cycle; float? pinned;
        VolumeProfile profile; ColorAdjustments adjust; WhiteBalance balance;

        public float Minute => pinned ?? (model != null ? model.Clock.minute : HotelClock.StartMinute);

        public void Initialize(HotelModel model, Camera cam, GodotGeometry geometry)
        {
            this.model = model; this.cam = cam; this.geometry = geometry;
            var text = Resources.Load<TextAsset>("Content/DayCycle");
            if (text == null) throw new InvalidOperationException("Resources/Content/DayCycle.json is missing.");
            cycle = DayCycle.Parse(text.text);
            Sun = new GameObject("Sun and moon").AddComponent<Light>();
            Sun.transform.SetParent(transform); Sun.type = LightType.Directional; Sun.shadows = LightShadows.Soft; Sun.shadowBias = .045f; Sun.shadowNormalBias = .45f;
            var volume = FindFirstObjectByType<Volume>();
            if (volume != null && volume.sharedProfile != null)
            {
                profile = Instantiate(volume.sharedProfile); volume.profile = profile;
                profile.TryGet(out adjust); profile.TryGet(out balance);
            }
            Apply();
        }

        public void Pin(float? minute) { pinned = minute; Apply(); }

        void LateUpdate() { if (cycle != null) Apply(); }

        void Apply()
        {
            var l = cycle.Evaluate(Minute);
            ApplyTo(Sun, cam, l);
            if (adjust != null) adjust.postExposure.Override(l.exposure);
            if (balance != null) balance.temperature.Override(l.temperature);
            Glow = l.glow;
            geometry?.SetGlow(Glow * 2.2f);
        }

        public static void ApplyTo(Light sun, Camera cam, DayLight l)
        {
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = C(l.sky); RenderSettings.ambientEquatorColor = C(l.equator); RenderSettings.ambientGroundColor = C(l.ground);
            sun.transform.rotation = Quaternion.Euler(l.sunPitch, l.sunYaw, 0);
            sun.color = C(l.sun); sun.intensity = l.sunIntensity; sun.shadowStrength = l.shadowStrength;
            if (cam != null) cam.backgroundColor = C(l.background);
        }

        static Color C(float[] linear) => new Color(linear[0], linear[1], linear[2]).gamma;

        void OnDestroy() { if (profile != null) Destroy(profile); }
    }
}
```

- [ ] **Step 4: Replace the old sun in `VoxelWorld`.**
  - Line 15: replace `Light sun;` with `public WorldLighting Lighting{get;private set;}`.
  - Line 20 (`Initialize`): delete the segment from `sun=new GameObject("Warm afternoon sun")` through `RenderSettings.ambientMode=AmbientMode.Flat;`, and in its place write `Lighting=gameObject.AddComponent<WorldLighting>();Lighting.Initialize(model,WorldCamera,geometry);`.
  - Delete the whole `SetEvening(bool value)` method (line 37).
  - Line 41 (`Refresh`): delete `SetEvening(model.State.settings.evening);`.
- [ ] **Step 5: Update the callers.**
  - `HotelApp.cs:75`: delete `World.SetEvening(Model.State.settings.evening);`.
  - `ParityRenderAcceptance.cs:15`: replace `app.Model.State.settings.evening=false;app.World.SetEvening(false);` with `app.World.Lighting.Pin(750);`. Line 17: replace `app.World.SetEvening(suffix=="evening");` with `app.World.Lighting.Pin(suffix=="evening"?1170f:750f);`. Lines 18 and 20: replace `app.World.SetEvening(false);` with `app.World.Lighting.Pin(750);`, and at the very end of the acceptance run (line 20, after `FocusHotel();`) add `app.World.Lighting.Pin(null);`.
  - `HotelParityUI.cs:368`: remove the whole "Evening light" `Card(...)` statement, including its `SetViewSettings` call and `app.World.SetEvening(...)`. Leave line 366 (Exterior walls) untouched.
- [ ] **Step 6: Make lamps glow at night regardless of motion (`GodotObjectMotion.cs`).**
  - Line 7, where lamps are registered: after `lampColors[renderer]=renderer.sharedMaterial.color;` add `renderer.sharedMaterial.EnableKeyword("_EMISSION");`.
  - Add a method: `void NightLamps(){if(lampColors.Count==0)return;var glow=GodotGeometry.GlowColor*(WorldLighting.Glow*2.6f);foreach(var lamp in lampColors){lamp.Key.GetPropertyBlock(tint);tint.SetColor("_EmissionColor",glow);lamp.Key.SetPropertyBlock(tint);}}`.
  - Line 13 (`Advance`): in the `if(!motion){...}` branch, call `NightLamps();` immediately before its `return;`. Also call `NightLamps();` as the last statement of `Advance`, after the `switch` that contains the `case "lamp"` block.
- [ ] **Step 7: Run to verify it passes.**
Run: `.\tools\unity.ps1 Test`
Expected: all EditMode tests pass. Then `grep -rn "SetEvening" unity/PurringtonHotel/Assets` returns nothing.

- [ ] **Step 8: Commit.**
```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/WorldLighting.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/WorldLighting.cs.meta unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelApp.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/ParityRenderAcceptance.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelParityUI.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/GodotObjectMotion.cs unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LivingColorTests.cs
git add -p unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorld.cs
git commit -m "feat(world): day/night lighting from keyframes, window and lamp glow, retire evening toggle"
```

---

### Task 7: Grading and mobile SSAO (render assets)

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Editor/ProjectSetup.cs:103-136` (`ConfigureRendering`)
- Modify: `tools/unity.ps1` (add a `Rendering` action)
- Modify: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/Purrington.EditModeTests.asmdef` (references)
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/RenderingSetupTests.cs` (+ `.meta`)
- Regenerated assets: `Assets/Resources/ParityGrading.asset`, `Assets/Settings/Mobile_Renderer.asset`

**Interfaces:**
- Consumes: nothing new at runtime. `WorldLighting` (Task 6) already finds `ColorAdjustments` and `WhiteBalance` in the profile copy.
- Produces: `ParityGrading.asset` with ColorAdjustments, Tonemapping, Bloom, SplitToning, LiftGammaGain and WhiteBalance, and no Vignette; `Mobile_Renderer.asset` with an active SSAO feature.

- [ ] **Step 1: Reference the render pipeline and TMP from the tests.** In `Purrington.EditModeTests.asmdef`, set `"references": ["Purrington.Domain", "Purrington.Presentation", "Unity.RenderPipelines.Universal.Runtime", "Unity.RenderPipelines.Core.Runtime", "Unity.TextMeshPro"]`.

- [ ] **Step 2: Write the failing test.** Create `Tests/EditMode/RenderingSetupTests.cs`:

```csharp
using System.Linq;using NUnit.Framework;using UnityEditor;using UnityEngine.Rendering;using UnityEngine.Rendering.Universal;
namespace Purrington.Tests {
public sealed class RenderingSetupTests {
 [Test]public void GradingIsHighKeyPastel(){var p=AssetDatabase.LoadAssetAtPath<VolumeProfile>("Assets/Resources/ParityGrading.asset");Assert.IsNotNull(p);
  Assert.IsTrue(p.TryGet<ColorAdjustments>(out var c));Assert.AreEqual(20f,c.saturation.value,1e-3f);Assert.AreEqual(6f,c.contrast.value,1e-3f);
  Assert.IsTrue(p.TryGet<Bloom>(out var b)&&b.active);Assert.AreEqual(1f,b.threshold.value,1e-3f);Assert.AreEqual(.4f,b.intensity.value,1e-3f);Assert.AreEqual(.7f,b.scatter.value,1e-3f);Assert.IsFalse(b.highQualityFiltering.value);
  Assert.IsTrue(p.TryGet<SplitToning>(out var s)&&s.active);Assert.AreEqual(20f,s.balance.value,1e-3f);
  Assert.IsTrue(p.TryGet<LiftGammaGain>(out var l)&&l.active);Assert.Greater(l.lift.value.w,0f);
  Assert.IsTrue(p.TryGet<WhiteBalance>(out _));Assert.IsFalse(p.TryGet<Vignette>(out _));
  Assert.IsTrue(p.TryGet<Tonemapping>(out var t));Assert.AreEqual(TonemappingMode.Neutral,t.mode.value);}
 [Test]public void MobileRendererHasDownsampledSsao(){var r=AssetDatabase.LoadAssetAtPath<UniversalRendererData>("Assets/Settings/Mobile_Renderer.asset");var ssao=r.rendererFeatures.FirstOrDefault(f=>f!=null&&f.GetType().Name=="ScreenSpaceAmbientOcclusion");Assert.IsNotNull(ssao,"mobile SSAO feature");Assert.IsTrue(ssao.isActive);
  var data=new SerializedObject(ssao);Assert.IsTrue(data.FindProperty("m_Settings.Downsample").boolValue);Assert.AreEqual(.4f,data.FindProperty("m_Settings.Intensity").floatValue,1e-3f);}
}
}
```

- [ ] **Step 3: Run to verify it fails.**
Run: `.\tools\unity.ps1 Test`
Expected: FAIL `GradingIsHighKeyPastel` (saturation is 5) and `MobileRendererHasDownsampledSsao` (feature missing).

- [ ] **Step 4: Implement it in `ConfigureRendering`.** Replace lines 127–135 (from `const string path=...` to `AssetDatabase.SaveAssets();`) with:

```csharp
            AddMobileSsao(renderer);
            const string path="Assets/Resources/ParityGrading.asset";
            var profile=AssetDatabase.LoadAssetAtPath<VolumeProfile>(path);
            if(profile==null){profile=ScriptableObject.CreateInstance<VolumeProfile>();AssetDatabase.CreateAsset(profile,path);}
            T Get<T>() where T:VolumeComponent{if(!profile.TryGet<T>(out var c)){c=profile.Add<T>(true);AssetDatabase.AddObjectToAsset(c,profile);}c.active=true;EditorUtility.SetDirty(c);return c;}
            var colors=Get<ColorAdjustments>();colors.contrast.Override(6);colors.saturation.Override(20);colors.postExposure.Override(.1f);
            Get<Tonemapping>().mode.Override(TonemappingMode.Neutral);
            var bloom=Get<Bloom>();bloom.threshold.Override(1f);bloom.intensity.Override(.4f);bloom.scatter.Override(.7f);bloom.tint.Override(new Color(1f,.89f,.69f));bloom.highQualityFiltering.Override(false);
            var split=Get<SplitToning>();split.highlights.Override(new Color(1f,.85f,.63f));split.shadows.Override(new Color(.72f,.66f,.85f));split.balance.Override(20);
            Get<LiftGammaGain>().lift.Override(new Vector4(1f,.99f,.96f,.04f));
            var balance=Get<WhiteBalance>();balance.temperature.Override(0);balance.tint.Override(0);
            if(profile.TryGet<Vignette>(out var vignette)){profile.Remove<Vignette>();Object.DestroyImmediate(vignette,true);}
            EditorUtility.SetDirty(profile);
            AssetDatabase.SaveAssets();
```

Then add this method below `ConfigurePipeline`:

```csharp
        // Mobile gets its own SSAO copy of the desktop feature: downsampled, low samples, soft contact shading.
        static void AddMobileSsao(UniversalRendererData desktop)
        {
            var mobile=AssetDatabase.LoadAssetAtPath<UniversalRendererData>("Assets/Settings/Mobile_Renderer.asset");
            if(mobile==null)throw new FileNotFoundException("Missing Mobile_Renderer");
            var feature=mobile.rendererFeatures.FirstOrDefault(f=>f!=null&&f.GetType().Name=="ScreenSpaceAmbientOcclusion");
            if(feature==null)
            {
                var source=desktop.rendererFeatures.First(f=>f!=null&&f.GetType().Name=="ScreenSpaceAmbientOcclusion");
                feature=Object.Instantiate(source);feature.name=source.name;
                AssetDatabase.AddObjectToAsset(feature,mobile);
                var data=new SerializedObject(mobile);
                var list=data.FindProperty("m_RendererFeatures");list.arraySize++;list.GetArrayElementAtIndex(list.arraySize-1).objectReferenceValue=feature;
                AssetDatabase.TryGetGUIDAndLocalFileIdentifier(feature,out string _,out long id);
                var ids=data.FindProperty("m_RendererFeatureMap");ids.arraySize++;ids.GetArrayElementAtIndex(ids.arraySize-1).longValue=id;
                data.ApplyModifiedPropertiesWithoutUndo();
            }
            feature.SetActive(true);
            var settings=new SerializedObject(feature);
            Set(settings,"m_Settings.Intensity",.4f);Set(settings,"m_Settings.Radius",.25f);Set(settings,"m_Settings.DirectLightingStrength",.15f);
            Set(settings,"m_Settings.Downsample",true);
            var samples=settings.FindProperty("m_Settings.Samples");if(samples!=null)samples.enumValueIndex=samples.enumNames.Length-1; // lowest sample count
            settings.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(feature);EditorUtility.SetDirty(mobile);
        }
```

Add `using System.Linq;` if it's missing from `ProjectSetup.cs`. `Object` here is `UnityEngine.Object`; qualify it if `System.Object` is ambiguous.

- [ ] **Step 5: Add a rendering-only action to `tools/unity.ps1`** so the full scene setup does not rerun. Add `'Rendering'` to the `ValidateSet`, and in the `switch` add `'Rendering' { 'Purrington.Editor.ProjectSetup.ConfigureRendering' }`.

- [ ] **Step 6: Regenerate the assets and test.**
Run:
```powershell
.\tools\unity.ps1 Rendering; .\tools\unity.ps1 Test
```
Expected: both test methods pass. `git diff --stat` shows `ParityGrading.asset` and `Mobile_Renderer.asset` changed.

- [ ] **Step 7: Commit.**
```bash
git add unity/PurringtonHotel/Assets/Purrington/Editor/ProjectSetup.cs tools/unity.ps1 unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/Purrington.EditModeTests.asmdef unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/RenderingSetupTests.cs unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/RenderingSetupTests.cs.meta unity/PurringtonHotel/Assets/Resources/ParityGrading.asset unity/PurringtonHotel/Assets/Settings/Mobile_Renderer.asset
git commit -m "feat(render): high-key pastel grading with warm bloom and SSAO on mobile"
```

---

### Task 8: HUD chrome, coin and clock chip

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/UiCoin.cs` (+ `.meta`)
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelClockChip.cs` (+ `.meta`)
- Modify: `HotelUI.cs:153-163` (`RefreshValues`), `:714-748` (`Header`), `:750-782` (`Navigation`), `:784-822` (`NavigationIcon` colors)
- Modify: `Tests/EditMode/LivingColorTests.cs`

**Interfaces:**
- Consumes: `ConceptTheme.Ui.*` (Task 2), `HotelModel.Clock` and `HotelClock.Label` (Task 1).
- Produces: `static RectTransform UiCoin.Create(RectTransform parent, Sprite round, float size)`; `sealed class HotelClockChip : MonoBehaviour { void Bind(HotelModel model, TextMeshProUGUI label, Image sun, Image moon, bool compact); static float MoonAmount(float daylight); }`.

- [ ] **Step 1: Write the failing tests.** Append to `LivingColorTests`:

```csharp
 [Test]public void MoonIsFullAtNightAndHiddenAtNoon(){Assert.AreEqual(1f,HotelClockChip.MoonAmount(0),1e-4f);Assert.AreEqual(0f,HotelClockChip.MoonAmount(1),1e-4f);var dusk=HotelClockChip.MoonAmount(HotelClock.Daylight(1170));Assert.That(dusk,Is.InRange(.2f,.8f));}
 [Test]public void HudFontsCoverClockAndWalletGlyphs(){foreach(var name in new[]{"Fonts/Nunito SDF","Fonts/Fredoka SDF"}){var font=Resources.Load<TMPro.TMP_FontAsset>(name);Assert.IsNotNull(font,name);Assert.IsTrue(font.HasCharacters("0123456789·:+/ Daymin,",out var missing,false,true),name+" missing: "+(missing==null?"":string.Join("",missing)));}}
 [Test]public void CoinUsesOnlyCoinTokens(){var root=new GameObject("root",typeof(RectTransform)).GetComponent<RectTransform>();try{UiCoin.Create(root,null,26);foreach(var g in root.GetComponentsInChildren<UnityEngine.UI.Graphic>(true))Assert.That(new[]{ConceptTheme.Ui.Coin,ConceptTheme.Ui.CoinRim}.Any(c=>(c-g.color).maxColorComponent<.01f),g.name);}finally{Object.DestroyImmediate(root.gameObject);}}
```

- [ ] **Step 2: Run to verify it fails.**
Run: `.\tools\unity.ps1 Test`
Expected: compile failure, because `HotelClockChip` and `UiCoin` don't exist yet.

- [ ] **Step 3: Implement `UiCoin`.** Create `Runtime/Presentation/UiCoin.cs`:

```csharp
using UnityEngine;
using UnityEngine.UI;

namespace Purrington.Presentation
{
    // Gold paw coin from the concept art, built from rounded images so no icon font is needed.
    public static class UiCoin
    {
        public static RectTransform Create(RectTransform parent, Sprite round, float size)
        {
            var coin = Disc("Paw coin", parent, round, ConceptTheme.Ui.CoinRim, size, Vector2.zero);
            Disc("Face", coin, round, ConceptTheme.Ui.Coin, size - 4, Vector2.zero);
            float s = size / 26f;
            Disc("Pad", coin, round, ConceptTheme.Ui.CoinRim, 9 * s, new Vector2(0, -3 * s));
            foreach (var toe in new[] { new Vector2(-6, 3), new Vector2(-2, 7), new Vector2(2, 7), new Vector2(6, 3) })
                Disc("Toe", coin, round, ConceptTheme.Ui.CoinRim, 4 * s, toe * s);
            return coin;
        }

        static RectTransform Disc(string name, RectTransform parent, Sprite round, Color color, float size, Vector2 offset)
        {
            var r = new GameObject(name, typeof(RectTransform)).GetComponent<RectTransform>();
            r.SetParent(parent, false); r.anchorMin = r.anchorMax = r.pivot = new Vector2(.5f, .5f); r.sizeDelta = new Vector2(size, size); r.anchoredPosition = offset;
            var image = r.gameObject.AddComponent<Image>(); image.sprite = round; image.type = round != null ? Image.Type.Sliced : Image.Type.Simple; image.color = color; image.raycastTarget = false;
            return r;
        }
    }
}
```

- [ ] **Step 4: Implement `HotelClockChip`.** Create `Runtime/Presentation/HotelClockChip.cs`:

```csharp
using Purrington.Domain;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Purrington.Presentation
{
    // "Day 3 · 10:30" with a sun/moon glyph; refreshes once per in-game minute.
    public sealed class HotelClockChip : MonoBehaviour
    {
        HotelModel model; TextMeshProUGUI label; Image sun, moon; bool compact; int lastMinute = -1, lastDay = -1;

        public void Bind(HotelModel model, TextMeshProUGUI label, Image sun, Image moon, bool compact)
        { this.model = model; this.label = label; this.sun = sun; this.moon = moon; this.compact = compact; lastMinute = -1; Update(); }

        public static float MoonAmount(float daylight) => 1f - Mathf.Clamp01(daylight * 1.6f);

        void Update()
        {
            if (model == null) return;
            var c = model.Clock; int minute = (int)c.minute;
            if (minute == lastMinute && c.day == lastDay) return;
            lastMinute = minute; lastDay = c.day;
            label.text = HotelClock.Label(c, compact);
            float m = MoonAmount(c.daylight);
            var s = sun.color; s.a = 1 - m; sun.color = s;
            var n = moon.color; n.a = m; moon.color = n;
        }
    }
}
```

- [ ] **Step 5: Restyle the header** (`HotelUI.Header`, lines 714–748). Keep `careCat` behavior. Changes:
  - Add these statics next to line 29: `static readonly Color Card=ConceptTheme.Ui.Card,InkSoft=ConceptTheme.Ui.InkSoft,LeafText=ConceptTheme.Ui.LeafText,Coin=ConceptTheme.Ui.Coin;`. The existing `Mint` already equals the `Sage` token (`ConceptTheme.Sage` = `SurfacePalette.Sage`), so use `Mint` wherever the concept's sage tile or pill is meant.
  - `var panel=Panel("Hotel status",safe,Cream);` → `Card`.
  - Wallet chip: `var chip=Panel("Wallet chip",panel,Gold);` → `Card`, pinned to the full header height: `new Vector2(8,-22),new Vector2(8+chipW,22)`. Add `var coin=UiCoin.Create(chip,rounded,26);coin.anchorMin=coin.anchorMax=coin.pivot=new Vector2(0,.5f);coin.anchoredPosition=new Vector2(4,0);`. Set `wallet=Text(chip,"",13,Ink,true)` with `Stretch(wallet.rectTransform,34,20,8,2)` (top line). Replace the `walletRate` creation with a `Mint` (sage) sub-pill inside the chip: `var ratePill=Panel("Rate pill",chip,Mint);Pin(ratePill,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(32,3),new Vector2(-6,19));walletRate=Text(ratePill,"",10,LeafText,true);Stretch(walletRate.rectTransform,6,1,6,1);`.
  - Clock chip, only when `careCat<0`: `bool compactClock=((RectTransform)safe).rect.width<380||textScale>1.25f;float clockW=compactClock?68f:116f;var clockPanel=Panel("Clock chip",panel,Card);Pin(clockPanel,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(14+chipW,-16),new Vector2(14+chipW+clockW,16));var sunImg=Panel("Sun",clockPanel,Coin).GetComponent<UnityEngine.UI.Image>();var moonImg=Panel("Moon",clockPanel,InkSoft).GetComponent<UnityEngine.UI.Image>();foreach(var g in new[]{sunImg,moonImg}){var r=g.rectTransform;r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,.5f);r.sizeDelta=new Vector2(16,16);r.anchoredPosition=new Vector2(8,0);g.raycastTarget=false;}var clockText=Text(clockPanel,"",11,Ink,true);Stretch(clockText.rectTransform,28,2,6,2);clockPanel.gameObject.AddComponent<HotelClockChip>().Bind(app.Model,clockText,sunImg,moonImg,compactClock);`. Shift the title's left offset from `16+chipW` to `20+chipW+(careCat<0?clockW:0)`. Declare `clockW` before the `if`, as `0f` when `careCat>=0`.
  - Title: `careCat>=0?"CAT TIME":(string)app.Model.Map()["name"]` at size 14, `Ink`, bold. Enable auto-sizing on it: `title.enableAutoSizing=true;title.fontSizeMin=10*textScale;title.fontSizeMax=14*textScale;`.
  - Menu button: when `careCat<0`, `var gear=Button(panel,"",()=>{settings=!settings;Rebuild();},Card,13);` pinned as a 44×44 square at the right (`new Vector2(-52,-22),new Vector2(-8,22)`). Draw the gear: a ring of 8 `Ink` teeth (4×6 rects rotated in 45° steps around the center, radius 11), an `Ink` disc of 16 and a `Card` disc of 7 (use `Panel(...)` with the rounded sprite for discs). The care-mode "Back" button stays as it is but uses `Card` instead of `Mint`.
- [ ] **Step 6: Update `RefreshValues`** (lines 159–161): `wallet.text=Math.Floor(app.Model.State.coins).ToString("N0");` and `if(walletRate!=null)walletRate.text="+"+Math.Round(rate).ToString("N0")+" / min";else wallet.text+=" · +"+Math.Round(rate).ToString("N0")+" / min";`. Colors now come from the components, not rich text.
- [ ] **Step 7: Restyle the navigation** (`Navigation`, `NavigationIcon`):
  - `dock=Panel("Navigation",safe,Cream)` → `Card`.
  - Tab color: `tab==dest?Mint:(build?Gold:Cream)` → `tab==dest?Mint:Card`.
  - In `NavigationIcon`, replace every `Cream` argument with `Card`, and every `Coral` and `Gold` argument with `Coin`. `Ink` stays.
- [ ] **Step 8: Run to verify it passes.**
Run: `.\tools\unity.ps1 Test`
Expected: all EditMode tests pass. If `HudFontsCoverClockAndWalletGlyphs` fails on `·` for a static font asset, set that asset's atlas population mode to Dynamic in `ProjectSetup.Font` (or add the glyph). Do not change the label text to avoid `·`.
- [ ] **Step 9: Commit.**
```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/UiCoin.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/UiCoin.cs.meta unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelClockChip.cs unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelClockChip.cs.meta unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/LivingColorTests.cs
git add -p unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelUI.cs
git commit -m "feat(ui): concept-art top bar with paw coin, day clock chip and ink-on-cream navigation"
```

---

### Task 9: QA captures, chrome token check and performance gate

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/PreviewVerification.cs`
- Create: `docs/art/qa-shots/living-color/after/` (captures) and `docs/art/qa-shots/living-color/README.md`

**Interfaces:**
- Consumes: `VoxelWorld.Lighting.Pin`, `WorldLighting.Glow`, `ConceptTheme.Ui.All`, `GodotGeometry.GlowColor`.

- [ ] **Step 1: Add day/night captures and chrome checks.** In `PreviewVerification`, immediately after `app.UI.Navigate("Hotel");yield return Capture(output,"hotel-430x932");` (line 42), insert:

```csharp
            foreach(var (minute,label) in new[]{(750f,"noon"),(1050f,"golden"),(1170f,"dusk"),(1380f,"night")}){app.World.Lighting.Pin(minute);yield return Capture(output,"living-"+label+"-430x932");}
            app.World.Lighting.Pin(1380);var motion=app.Model.State.settings;app.Model.SetSettings(motion.textScale,false,motion.music,motion.sound);yield return new WaitForSecondsRealtime(.3f);
            var lamps=FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None).Where(r=>r.sharedMaterial&&r.sharedMaterial.IsKeywordEnabled("_EMISSION")&&r.HasPropertyBlock()).ToArray();
            var block=new MaterialPropertyBlock();Check(lamps.Length==0||lamps.Any(r=>{r.GetPropertyBlock(block);return block.GetColor("_EmissionColor").maxColorComponent>.5f;}),"Lamps must glow at night with reduced motion");
            app.Model.SetSettings(motion.textScale,true,motion.music,motion.sound);app.World.Lighting.Pin(null);
            var tokens=ConceptTheme.Ui.All;var safeArea=app.UI.transform.Find("SafeArea");
            foreach(var chrome in new[]{"Hotel status","Navigation"}){var root=safeArea.Find(chrome);Check(root!=null,"Missing chrome "+chrome);if(root==null)continue;
             foreach(var g in root.GetComponentsInChildren<UnityEngine.UI.Graphic>(true)){var c=g.color;c.a=1;Check(tokens.Any(t=>Mathf.Abs(t.r-c.r)<.01f&&Mathf.Abs(t.g-c.g)<.01f&&Mathf.Abs(t.b-c.b)<.01f),chrome+" uses an off-token color on "+g.name);}}
```

After the existing `app.UI.Navigate("Hotel");yield return Capture(output,"08-hotel-360x640-150");` (line 50), add:
```csharp
            var chipText=app.UI.transform.Find("SafeArea/Hotel status/Clock chip")?.GetComponentInChildren<TMPro.TextMeshProUGUI>();Check(chipText!=null&&!chipText.text.Contains("Day"),"Clock chip must be compact at 360 px / 150%");
```
After `11-hotel-desktop`, add night and noon desktop captures the same way (`Pin(750)` → `living-noon-desktop`, `Pin(1380)` → `living-night-desktop`, then `Pin(null)`).

- [ ] **Step 2: Build and run QA.**
Run:
```powershell
.\tools\unity.ps1 Windows; .\tools\unity.ps1 QA
```
Expected: `PASS: ...`. No `PURRINGTON_SMOKE_FAILED` lines in `builds/unity/captures/player.log`.

- [ ] **Step 3: Check the performance gate.** Compare `builds/unity/captures/performance-mobile.txt` `averageMs` against `docs/art/qa-shots/living-color/baseline/performance-mobile.txt`. It must be ≤ 1.10 × baseline. If it isn't, set `Mobile_Renderer` SSAO to half resolution (it already downsamples; next, lower its radius to .2 and samples to the lowest). Rerun `.\tools\unity.ps1 Rendering`, rebuild and rerun QA. Do not remove bloom or tone variants to hit the gate without asking the user.

- [ ] **Step 4: Visual review against the references.** Copy the new `living-*.png`, `hotel-430x932.png`, `08-hotel-360x640-150.png` and `performance*.txt` into `docs/art/qa-shots/living-color/after/`. Open them next to `assets/ui/mobile/welcome-hotel.png`, `upgrade-lounge.png`, `lantern-gathering.png` and `docs/concept-art/02-hotel-overview.png`. Write `docs/art/qa-shots/living-color/README.md` with: a before/after table (baseline vs noon), one line per phase (noon, golden, dusk, night) saying whether it matches its reference, both frame times, and any tuning made to `DayCycle.json` values. Tune only `DayCycle.json` values and grading numbers here. Structural changes belong in Phase B or C.

- [ ] **Step 5: Run every test suite once more.**
Run:
```powershell
dotnet run --project tests/unity-domain; .\tools\unity.ps1 Test
```
Expected: `PASS <n> checks`, and EditMode tests with 0 failures.

- [ ] **Step 6: Commit.**
```bash
git add -p unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/PreviewVerification.cs
git add docs/art/qa-shots/living-color unity/PurringtonHotel/Assets/Resources/Content/DayCycle.json
git commit -m "test(qa): living color day/night captures, chrome token check and mobile frame-time gate"
```

- [ ] **Step 7: Update the roadmap.** In `docs/superpowers/plans/2026-09-22-living-color-00-roadmap.md`, set Phase A's status to "Done (QA reviewed)" with the commit range, and note any tuning or deferred items under Phase B or C. Commit with `docs: record living color phase A`.
