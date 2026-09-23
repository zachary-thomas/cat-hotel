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
