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
		foreach(bool doorRoomFirst in new[]{true,false})
		{
			var s=HotelModel.Copy(m.State);s.version=2;foreach(var hh in s.hotels)hh.floors.Clear();var h0=s.hotels[0];h0.objects.Clear();h0.paths.Clear();
			var a=new RoomState{id="room_a",kind="regular",x=0,z=0,width=4,depth=3,rotation=0};var b=new RoomState{id="room_b",kind="regular",x=4,z=0,width=4,depth=3,rotation=0};var c=new RoomState{id="room_c",kind="shared",x=0,z=5,width=3,depth=3,floor=1};
			h0.rooms=doorRoomFirst?new List<RoomState>{a,b,c}:new List<RoomState>{b,a,c};h0.paths["1,1"]=new PathState{style="brick",paid=6};double before=s.coins;
			Check(ShellMigration.Upgrade(s),"migration: touching rooms upgrade");var g=HotelModel.Floor(h0,0);
			Check(g.edges.TryGetValue("v:4,1",out var shared)&&shared.kind=="door"&&shared.room=="room_a","migration: a door flush against a neighbour survives (door room first="+doorRoomFirst+")");
			Check(g.edges.Values.Count(e=>e.room=="room_c"&&e.kind=="door")==4&&c.floor==0,"migration: lounges keep four doors and v2 rooms land on the ground floor");
			Check(!h0.paths.ContainsKey("1,1")&&Math.Abs(s.coins-before-6)<.01,"migration: paths under rooms are refunded");
			string once=JsonConvert.SerializeObject(s);ShellMigration.Upgrade(s);Check(once==JsonConvert.SerializeObject(s),"migration: upgrading twice changes nothing");
		}
		var gate=HotelModel.Copy(m.State);gate.version=2;Check(!HotelModel.Valid(gate),"migration: Valid requires save v3");
		var huge=HotelModel.Copy(m.State);huge.version=2;huge.hotels[0].floors.Clear();huge.hotels[0].rooms.Add(new RoomState{id="room_huge",kind="regular",width=2000000000,depth=2000000000});
		Check(ShellMigration.Upgrade(huge)&&!HotelModel.Valid(huge),"migration: absurd v2 rooms are skipped, then rejected, without hanging");
		var noFloors=JObject.Parse(JsonConvert.SerializeObject(m.State));((JObject)noFloors["hotels"][0]).Remove("floors");Check(!restored.RestoreJson(noFloors.ToString()),"migration: v3 saves must carry floors");
		Console.WriteLine("Shell migration suite passed");
	}
	// Finds a w×d area of owned, empty land with a one-cell margin (no rooms, objects, paths, shell or protected scenery).
	// Searches the base lot and owned plots for a w×d area of empty land with a one-cell margin.
	public static bool FindClear(HotelModel m,int w,int d,out int x,out int z)
	{
		var rects=new List<float[]>{m.Map()["base"].Select(v=>(float)v).ToArray()};
		foreach(var p in m.Map()["plots"])if(m.Hotel().plots.Contains((string)p["id"]))rects.Add(p["rect"].Select(v=>(float)v).ToArray());
		foreach(var r in rects)for(x=(int)r[0]+1;x+w+1<=r[0]+r[2];x++)for(z=(int)r[1]+1;z+d+1<=r[1]+r[3];z++)if(Clear(m,x,z,w,d))return true;
		x=z=0;return false;
	}
	// Grants every plot except the last `keep` so tests have open land; Execute re-validates everything afterwards.
	public static void OwnPlots(HotelModel m,int keep=0){var ids=m.Map()["plots"].Select(p=>(string)p["id"]).ToList();m.Hotel().plots=ids.Take(ids.Count-keep).ToList();}
	public static bool Clear(HotelModel m,int x,int z,int w,int d)
	{
		var h=m.Hotel();float x0=x-1,z0=z-1,x1=x+w+1,z1=z+d+1;
		foreach(var r in h.rooms){HotelModel.RoomSize(r,out float rw,out float rd);if(x0<r.x+rw&&x1>r.x&&z0<r.z+rd&&z1>r.z)return false;}
		foreach(var o in h.objects){HotelModel.Size(o,out float ow,out float od);if(x0<o.x+ow&&x1>o.x&&z0<o.z+od&&z1>o.z)return false;}
		foreach(var s in (m.Map()["scenery"]??new JArray()).Where(v=>(bool?)v["protected"]==true)){float sx=(float)s["x"],sz=(float)s["y"],ss=(float?)s["size"]??2;if(x0<sx+ss&&x1>sx&&z0<sz+ss&&z1>sz)return false;}
		for(int i=x-1;i<x+w+1;i++)for(int j=z-1;j<z+d+1;j++){if(h.paths.ContainsKey(i+","+j))return false;if(h.floors.Any(f=>f.cells.ContainsKey(ShellGrid.Cell(i,j))))return false;}
		return true;
	}
	public static void RunNavigation(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var store=new MemoryStore();var m=new HotelModel(store,content);m.LoadOrCreate();OwnPlots(m);
		Check(FindClear(m,3,3,out int x,out int z),"nav: found clear land");
		var ground=HotelModel.Floor(m.Hotel(),0,true);foreach(var c in ShellGrid.Cells(x,z,3,3))ground.cells[c]=0;Check(m.Save().success,"nav: save island");
		var outside=new LotPoint(x-1.5f,z+1.5f);var inside=new LotPoint(x+1.5f,z+1.5f);
		var sealedIsland=new HotelModel(store,content);sealedIsland.LoadOrCreate();
		Check(sealedIsland.Route(outside,inside,false).Count==0,"nav: shell walls block a sealed island");
		ground.edges[ShellGrid.Edge('v',x,z+1)]=new EdgeState{kind="door"};Check(m.Save().success,"nav: save door");
		var doored=new HotelModel(store,content);doored.LoadOrCreate();
		Check(doored.Route(outside,inside,false).Count>0,"nav: an exterior door lets cats in");
		Check(doored.Route(new LotPoint(x+.25f,z+.25f),new LotPoint(x+2.75f,z+2.75f)).Count>0,"nav: shell floor is walkable in the constructed graph");
		ground.edges[ShellGrid.Edge('v',x,z+1)].kind="window";Check(m.Save().success,"nav: save window");
		var glazed=new HotelModel(store,content);glazed.LoadOrCreate();
		Check(glazed.Route(outside,inside,false).Count==0,"nav: windows block like walls");
		Check(glazed.GuestCapacity(0)==4&&glazed.Rate(0)==64,"nav: Meadow capacity/rate unchanged with shell walls");
		Console.WriteLine("Shell navigation suite passed");
	}
}
