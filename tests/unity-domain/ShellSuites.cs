using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Purrington.Domain;

static class ShellSuites
{
	public static void RunGrid(Action<bool,string> Check)
	{
		Check(ShellGrid.Cell(-3,4)=="-3,4","grid: cell key");
		Check(ShellGrid.TryCell("-3,4",out int x,out int z)&&x==-3&&z==4,"grid: parse cell");
		Check(!ShellGrid.TryCell("03,4",out _,out _)&&!ShellGrid.TryCell("1,2,3",out _,out _),"grid: reject non-canonical cells");
		Check(ShellGrid.TryEdge("v:2,5",out char axis,out x,out z)&&axis=='v'&&x==2&&z==5,"grid: parse edge");
		Check(!ShellGrid.TryEdge("d:2,5",out _,out _,out _)&&!ShellGrid.TryEdge("v2,5",out _,out _,out _),"grid: reject bad edges");
		ShellGrid.Sides("v:2,5",out var a,out var b);Check(a=="1,5"&&b=="2,5","grid: vertical edge sides");
		ShellGrid.Sides("h:2,5",out a,out b);Check(a=="2,4"&&b=="2,5","grid: horizontal edge sides");
		Check(ShellGrid.Boundary(0,0,4,3).Distinct().Count()==14,"grid: 4x3 perimeter has 14 edges");
		Check(ShellGrid.Inside(0,0,4,3).Distinct().Count()==17,"grid: 4x3 has 17 interior edges");
		Check(ShellGrid.DoorEdges(0,0,4,3,0).SequenceEqual(new[]{"v:4,1"}),"grid: odd side gets one centered door edge");
		Check(ShellGrid.DoorEdges(0,0,4,3,1).SequenceEqual(new[]{"h:1,3","h:2,3"}),"grid: even side gets a centered double door");
		var f=new FloorState();foreach(var c in ShellGrid.Cells(0,0,2,1))f.cells[c]=0;
		Check(ShellGrid.WallAt(f,"v:0,0")=="wall"&&ShellGrid.Exterior(f,"v:0,0"),"grid: outline is a derived wall");
		Check(ShellGrid.WallAt(f,"v:1,0")==null,"grid: open floor between indoor cells");
		Check(ShellGrid.WallAt(f,"v:5,5")==null,"grid: bare land has no wall");
		f.edges["v:0,0"]=new EdgeState{kind="door"};Check(ShellGrid.WallAt(f,"v:0,0")=="door","grid: stored edge overrides the derived wall");
		Check(ShellGrid.Edges(f).Count()==7,"grid: a 2x1 island has 7 edges");
		ShellGrid.EdgeCenter("h:2,5",out float cx,out float cz);Check(cx==2.5f&&cz==5,"grid: edge center");
		Check(ShellGrid.Price("door")==20&&ShellGrid.Price("window")==15&&ShellGrid.Price("wall")==5&&ShellGrid.Price("open")==10,"grid: edge prices");
		Console.WriteLine("Shell grid suite passed");
	}

	public static void RunMigration(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);Check(m.LoadOrCreate().success,"migration: starter loads");
		Check(m.State.version==3,"migration: starter is save v3");
		for(int i=0;i<4;i++)
		{
			var h=m.Hotel(i);var ground=HotelModel.Floor(h,0);Check(ground!=null,"migration: ground floor exists "+i);
			int area=h.rooms.Where(r=>HotelModel.IndoorKind(r.kind)).Sum(r=>r.width*r.depth);
			Check(ground.cells.Count==area,"migration: shell cells equal indoor room area on map "+i+" ("+ground.cells.Count+" vs "+area+")");
			foreach(var r in h.rooms.Where(v=>HotelModel.IndoorKind(v.kind)))
			{
				Check(HotelModel.Interior(h,r),"migration: room is interior "+r.id);
				Check(ground.edges.Values.Any(e=>e.room==r.id&&e.kind=="door"),"migration: room keeps a door "+r.id);
			}
		}
		Check(m.GuestCapacity()==4&&m.Rate()==64,"migration: Meadow capacity/rate unchanged ("+m.GuestCapacity()+"/"+m.Rate()+")");
		var legacy=JObject.Parse(JsonConvert.SerializeObject(m.State));legacy["version"]=2;
		foreach(var h in legacy["hotels"]){((JObject)h).Remove("floors");foreach(var r in h["rooms"])((JObject)r).Remove("floor");foreach(var o in h["objects"])((JObject)o).Remove("floor");}
		var restored=new HotelModel(new MemoryStore(),content);restored.LoadOrCreate();
		Check(restored.RestoreJson(legacy.ToString()),"migration: a v2 save restores");
		Check(restored.State.version==3&&HotelModel.Floor(restored.Hotel(0),0).cells.Count==HotelModel.Floor(m.Hotel(0),0).cells.Count,"migration: v2 restore rebuilds the shell");
		var bad=JObject.Parse(JsonConvert.SerializeObject(m.State));bad["hotels"][0]["floors"][0]["edges"]["v:0,0"]=new JObject{{"kind",5},{"room",""},{"paid",0}};
		Check(!restored.RestoreJson(bad.ToString()),"migration: strict JSON rejects a non-string edge kind");
		Check(!HotelModel.Valid(new HotelState{version=2}),"migration: unmigrated state is invalid");
		Console.WriteLine("Shell migration suite passed");
	}
}
