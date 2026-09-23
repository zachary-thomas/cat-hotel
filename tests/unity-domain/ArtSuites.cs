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
			foreach(int v in new[]{1,2}){double d=Math.Abs(SurfacePalette.Hue(r.target)-SurfacePalette.Hue(SurfacePalette.Tone(r.target,v)));d=Math.Min(d,360-d);Check(SurfacePalette.Chroma(r.target)<.13||d<=12,"palette: tone "+v+" keeps the hue of "+r.target);}
		}
	}

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
}
