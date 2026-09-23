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
			Check(HotelModel.Valid(s),"migration: touching rooms still load (door room first="+doorRoomFirst+")");
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
	public static JObject Paint(int x,int z,int w,int d,bool buy=false)
	{
		var cells=new JArray();for(int i=0;i<w;i++)for(int j=0;j<d;j++)cells.Add(new JArray(x+i,z+j));
		var p=new JObject{{"floor",0},{"cells",cells}};if(buy)p["buy"]=true;return p;
	}
	public static void RunGrow(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m,1);
		Check(FindClear(m,4,4,out int x,out int z),"grow: clear land");
		double coins=m.State.coins;var r=m.Execute("paint_floor",Paint(x,z,4,1));
		Check(r.success,"grow: paint a strip ("+r.message+")");Check(Math.Abs(coins-m.State.coins-80)<.01,"grow: 4 tiles cost 80");
		Check(!m.Execute("paint_floor",Paint(x,z,4,1)).success,"grow: repainting existing floor is rejected");
		coins=m.State.coins;Check(m.Execute("paint_floor",Paint(x,z,4,2)).success&&Math.Abs(coins-m.State.coins-80)<.01,"grow: an overlapping drag charges only the new tiles");
		coins=m.State.coins;Check(m.Execute("erase_floor",Paint(x,z+1,4,1)).success&&Math.Abs(m.State.coins-coins-80)<.01,"grow: erasing refunds");
		Check(m.Undo().success&&HotelModel.Floor(m.Hotel(),0).cells.ContainsKey(ShellGrid.Cell(x,z+1)),"grow: undo restores erased floor");
		var plot=m.Map()["plots"].First(p=>!m.Hotel().plots.Contains((string)p["id"]));var rect=plot["rect"];int ux=0,uz=0;bool found=false;
		for(int i=(int)(float)rect[0]+1;i<(int)(float)rect[0]+(int)(float)rect[2]-1&&!found;i++)for(int j=(int)(float)rect[1]+1;j<(int)(float)rect[1]+(int)(float)rect[3]-1&&!found;j++)if(Clear(m,i,j,1,1)){ux=i;uz=j;found=true;}
		Check(found,"grow: clear cell on unowned plot");
		Check(!m.Quote("paint_floor",Paint(ux,uz,1,1)).success,"grow: unowned land rejected without buy");
		var q=m.Quote("paint_floor",Paint(ux,uz,1,1,true));Check(q.success&&Math.Abs(q.cost-((double)plot["cost"]+20))<.01,"grow: buy flag quotes plot + tile ("+q.cost+")");
		Check(m.Execute("paint_floor",Paint(ux,uz,1,1,true)).success&&m.Hotel().plots.Contains((string)plot["id"]),"grow: painting buys the plot");
		string pathKey=m.Hotel().paths.Keys.FirstOrDefault(k=>{var s=k.Split(',');int px=int.Parse(s[0]),pz=int.Parse(s[1]);return m.Hotel().objects.All(o=>{HotelModel.Size(o,out float ow,out float od);return !(px+1>o.x&&px<o.x+ow&&pz+1>o.z&&pz<o.z+od);})&&(m.Map()["scenery"]??new JArray()).All(s2=>(bool?)s2["protected"]!=true||!(px+1>(float)s2["x"]&&px<(float)s2["x"]+((float?)s2["size"]??2)&&pz+1>(float)s2["y"]&&pz<(float)s2["y"]+((float?)s2["size"]??2)));});
		Check(pathKey!=null,"grow: a free path cell exists");
		var parts=pathKey.Split(',');double paidPath=m.Hotel().paths[pathKey].paid;coins=m.State.coins;
		var pp=m.Execute("paint_floor",Paint(int.Parse(parts[0]),int.Parse(parts[1]),1,1));
		Check(pp.success&&!m.Hotel().paths.ContainsKey(pathKey)&&Math.Abs(coins-m.State.coins-(20-paidPath))<.01,"grow: floor replaces and refunds a path ("+pp.message+")");
		Check(m.SetGodMode(true).success&&m.Quote("paint_floor",Paint(x,z+2,1,1)).cost==0,"grow: God mode growth is free");
		Console.WriteLine("Shell grow suite passed");
	}
	public static void RunShellLoadGate(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m);
		Check(FindClear(m,3,3,out int x,out int z),"gate: clear land");Check(m.Execute("paint_floor",Paint(x,z,3,3)).success,"gate: island");
		Check(HotelModel.Valid(m.State),"gate: a painted island is valid");
		string cell=ShellGrid.Cell(x,z);var ground=HotelModel.Floor(m.Hotel(),0);
		Func<Action<HotelState>,bool> tampered=mutate=>{var s=HotelModel.Copy(m.State);mutate(s);return HotelModel.Valid(s);};
		Check(!tampered(s=>HotelModel.Floor(s.hotels[s.currentHotel],0).cells[cell]=21),"gate: overpaid tiles are rejected");
		Check(!tampered(s=>HotelModel.Floor(s.hotels[s.currentHotel],0).cells[ShellGrid.Cell(500,500)]=0),"gate: tiles off the lot are rejected");
		Check(!tampered(s=>s.hotels[s.currentHotel].floors.Add(new FloorState{level=3})),"gate: unknown floor levels are rejected");
		Check(!tampered(s=>HotelModel.Floor(s.hotels[s.currentHotel],0).edges["v:"+(x+1)+","+z]=new EdgeState{kind="open"}),"gate: inside archways are rejected");
		Check(!tampered(s=>HotelModel.Floor(s.hotels[s.currentHotel],0).edges["v:"+(x+40)+","+z]=new EdgeState{kind="wall"}),"gate: walls off the floor are rejected");
		Check(!tampered(s=>s.hotels[s.currentHotel].rooms.Add(new RoomState{id="room"+s.nextId++,kind="regular",x=x+1,z=z,width=4,depth=3})),"gate: half-inside rooms are rejected");
		Check(m.SetGodMode(true).success&&m.Execute("paint_floor",Paint(x+3,z,1,1)).success&&HotelModel.Floor(m.Hotel(),0).cells[ShellGrid.Cell(x+3,z)]==0,"gate: God mode tiles are stored as free, so they never refund coins");
		Console.WriteLine("Shell load gate suite passed");
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
	public static void RunShellUndo(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m);FindClear(m,6,5,out int x,out int z);
		double coins=m.State.coins;int rooms=m.Hotel().rooms.Count,cells=HotelModel.Floor(m.Hotel(),0).cells.Count;
		Check(m.Execute("draw_room",Room(x,z,4,3,0)).success,"undo: draw room");
		Check(m.Undo().success&&m.Hotel().rooms.Count==rooms&&HotelModel.Floor(m.Hotel(),0).cells.Count==cells&&Math.Abs(m.State.coins-coins)<.01,"undo: drawing a room undoes floor, room and coins");
		Check(m.Redo().success&&m.Hotel().rooms.Count==rooms+1&&HotelModel.Interior(m.Hotel(),m.Hotel().rooms.Last()),"undo: redo restores the interior room");
		Check(HotelModel.Valid(m.State),"undo: state stays valid");
		Console.WriteLine("Shell undo suite passed");
	}
	public static void RunDraw(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var f=new FloorState();foreach(var c in ShellGrid.Cells(0,0,3,2))f.cells[c]=0;f.edges["h:1,2"]=new EdgeState{kind="door"};
		var runs=ShellDraw.Runs(f);
		Check(runs.Count(r=>r.kind=="door")==1&&runs.Sum(r=>r.length)==10,"draw: 3x2 island outline is 10 edges with one door");
		var south=runs.Where(r=>r.axis=='h'&&r.z==2).OrderBy(r=>r.x).ToList();
		Check(south.Count==3&&south[0].kind=="wall"&&south[1].kind=="door"&&south[2].kind=="wall"&&south.All(r=>r.inward==-1),"draw: a door splits the south wall into wall/door/wall facing inward");
		Check(runs.Single(r=>r.axis=='h'&&r.z==0).length==3&&runs.Single(r=>r.axis=='h'&&r.z==0).inward==1,"draw: the north wall merges into one run");
		f.edges["v:1,0"]=new EdgeState{kind="wall"};Check(ShellDraw.Runs(f).Any(r=>r.axis=='v'&&r.x==1&&r.inward==0),"draw: interior walls face both ways");
		Check(ShellDraw.NearestEdge(2.1f,5.5f)=="v:2,5"&&ShellDraw.NearestEdge(2.5f,5.9f)=="h:2,6","draw: taps pick the nearest edge");
		Check(ShellDraw.Line(0,0,3,1).Count==4&&ShellDraw.Line(0,0,3,1).Last()==(3,1),"draw: strokes fill the cells between samples");
		Check(ShellDraw.NextKind(f,"h:0,0")=="door"&&ShellDraw.NextKind(f,"h:1,2")=="window"&&ShellDraw.NextKind(f,"v:1,0")=="door","draw: tapping cycles wall → door → window");
		f.edges["h:0,0"]=new EdgeState{kind="window"};Check(ShellDraw.NextKind(f,"h:0,0")=="open","draw: outside windows cycle to an archway");
		f.edges["v:1,0"].kind="window";Check(ShellDraw.NextKind(f,"v:1,0")=="wall","draw: inside windows cycle back to a wall");
		var pavilion=new HotelModel(new MemoryStore(),content);pavilion.LoadOrCreate();pavilion.State.coins=100000;OwnPlots(pavilion);Check(FindClear(pavilion,4,3,out int px,out int pz),"draw: clear land for a pavilion");
		Check(pavilion.Execute("place_room",new JObject{{"kind","regular"},{"x",px},{"y",pz},{"w",4},{"h",3},{"rotation",0},{"door",1}}).success,"draw: pavilion with an explicit south door");
		Check(pavilion.MovementSegmentClear(new LotPoint(px+1.75f,pz+2.75f),new LotPoint(px+1.75f,pz+3.25f),false)&&!pavilion.MovementSegmentClear(new LotPoint(px+3.75f,pz+1.25f),new LotPoint(px+4.25f,pz+1.25f),false),"draw: pavilion navigation opens only on its explicit door side");
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m);
		Check(FindClear(m,8,6,out int x,out int z),"draw: clear land");
		Check(m.Execute("paint_floor",Paint(x,z+3,8,1)).success,"draw: hallway south of the new room");
		var draft=m.RoomDraft(x+3,z+2,x,z,"regular");
		Check((int)draft["rotation"]==0&&(int)draft["door"]==1&&(int)draft["w"]==4&&(int)draft["h"]==3&&(int)draft["x"]==x&&(int)draft["y"]==z,"draw: a 4x3 drag puts its door on the hallway side ("+draft.ToString(Newtonsoft.Json.Formatting.None)+")");
		var drawn=m.Execute("draw_room",draft);Check(drawn.success,"draw: drafted room is valid ("+drawn.message+")");var room=m.Hotel().rooms.Last();
		Check(ShellGrid.WallAt(HotelModel.Floor(m.Hotel(),0),"h:"+(x+1)+","+(z+3))=="door","draw: the double door opens onto the hallway");
		HotelModel.DoorPosition(room,out float dx,out float dz);Check(Math.Abs(dx-(x+2))<.01&&Math.Abs(dz-(z+3.25f))<.01,"draw: DoorPosition follows the door side ("+dx+","+dz+")");
		Check(m.Execute("move_room",new JObject{{"id",room.id},{"x",x},{"y",z},{"rotation",room.rotation}}).success&&room.door==1,"draw: moving without turning keeps the door side");
		Check(!m.Quote("draw_room",m.RoomDraft(x+5,z,x+7,z+2,"regular")).success,"draw: a 3x3 bedroom is refused");
		Console.WriteLine("Shell draw suite passed");
	}
	public static JObject Room(int x,int z,int w,int d,int rotation,string kind="regular")
	{
		return new JObject{{"kind",kind},{"x",x},{"y",z},{"w",w},{"h",d},{"rotation",rotation},{"floor",0}};
	}
	public static void RunRooms(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m);
		Check(FindClear(m,6,10,out int cx,out int cz),"rooms: clear land");int x=cx,z=cz+2;
		double coins=m.State.coins;var a=m.Execute("draw_room",Room(x,z,4,3,0));Check(a.success,"rooms: draw on bare land ("+a.message+")");
		var first=m.Hotel().rooms.Last();Check(HotelModel.Interior(m.Hotel(),first),"rooms: drawn room is interior");
		double fitting=Math.Round(450*.45,MidpointRounding.AwayFromZero);
		Check(Math.Abs(coins-m.State.coins-(12*20+fitting))<.01,"rooms: 12 tiles + fitting ("+(coins-m.State.coins)+")");
		var ground=HotelModel.Floor(m.Hotel(),0);
		Check(ground.edges.TryGetValue("v:"+(x+4)+","+(z+1),out var door)&&door.kind=="door"&&door.room==first.id,"rooms: centered door on the rotation side");
		Check(m.Execute("draw_room",Room(x,z+3,4,3,0)).success,"rooms: neighbor room shares a wall");
		var second=m.Hotel().rooms.Last();ground=HotelModel.Floor(m.Hotel(),0);
		Check(ShellGrid.Boundary(x,z,4,3).Intersect(ShellGrid.Boundary(x,z+3,4,3)).All(e=>ground.edges.TryGetValue(e,out var w)&&w.kind=="wall"&&w.room==first.id),"rooms: shared wall is owned once");
		Check(!m.Execute("erase_floor",Paint(x,z,1,1)).success,"rooms: can't erase floor under a room");
		Check(m.Execute("paint_floor",Paint(x+4,z,1,6)).success,"rooms: hallway alongside both rooms");ground=HotelModel.Floor(m.Hotel(),0);
		Check(ShellGrid.WallAt(ground,"v:"+(x+4)+","+(z+1))=="door","rooms: door now opens onto the hallway");
		Check(ShellGrid.WallAt(ground,"h:"+(x+4)+","+(z+1))==null,"rooms: hallway is open floor");
		coins=m.State.coins;Check(m.Execute("remove_room",P("{\"id\":\""+first.id+"\"}")).success&&Math.Abs(m.State.coins-coins-fitting)<.01,"rooms: removing refunds the fitting");
		ground=HotelModel.Floor(m.Hotel(),0);
		Check(ground.cells.ContainsKey(ShellGrid.Cell(x,z))&&!ground.edges.Values.Any(e=>e.room==first.id),"rooms: removed room leaves lobby floor and no walls");
		Check(ground.edges.TryGetValue("h:"+x+","+(z+3),out var kept)&&kept.room==second.id,"rooms: neighbor now owns the shared wall");
		var half=m.Quote("place_room",Room(x,z-2,4,3,0));Check(!half.success&&half.message.Contains("fully inside"),"rooms: half-inside rooms are rejected ("+half.message+")");
		Check(!m.Quote("draw_room",Room(x,z,4,3,0,"terrace")).success,"rooms: terraces can't be drawn inside");
		var pavilion=new HotelModel(new MemoryStore(),content);pavilion.LoadOrCreate();pavilion.State.coins=100000;OwnPlots(pavilion);FindClear(pavilion,6,5,out int px,out int pz);
		coins=pavilion.State.coins;Check(pavilion.Execute("place_room",Room(px,pz,4,3,0)).success&&Math.Abs(coins-pavilion.State.coins-450)<.01&&!HotelModel.Interior(pavilion.Hotel(),pavilion.Hotel().rooms.Last()),"rooms: place_room on bare land is still a 450-coin pavilion");
		Console.WriteLine("Shell rooms suite passed");
	}
	public static void RunInteriorEdits(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;var lot=m.Hotel();lot.rooms.Clear();lot.floors.Clear();lot.objects.Clear();lot.paths.Clear();
		Check(FindClear(m,8,10,out int x,out int z),"edits: clear land");
		Check(m.Execute("draw_room",Room(x,z,4,3,0)).success,"edits: interior bedroom");var room=m.Hotel().rooms.Last();
		double coins=m.State.coins;var moved=m.Execute("move_room",new JObject{{"id",room.id},{"x",x+1},{"y",z}});
		Check(moved.success&&HotelModel.Interior(m.Hotel(),room)&&Math.Abs(coins-m.State.coins-60)<.01,"edits: nudging onto bare land grows the hotel by 3 tiles ("+moved.message+")");
		Check(HotelModel.Floor(m.Hotel(),0).cells.ContainsKey(ShellGrid.Cell(x,z)),"edits: the vacated column stays as lobby floor");
		coins=m.State.coins;var grown=m.Execute("resize_room",new JObject{{"id",room.id},{"w",5},{"h",3}});
		Check(grown.success&&HotelModel.Interior(m.Hotel(),room)&&Math.Abs(coins-m.State.coins-(33+60))<.01,"edits: widening charges the resize and the new tiles ("+grown.message+")");
		Check(m.Execute("paint_floor",Paint(x,z+5,5,3)).success,"edits: floor for the copy");
		coins=m.State.coins;var copied=m.Execute("copy_room",new JObject{{"id",room.id},{"x",x},{"y",z+5}});var copy=m.Hotel().rooms.Last();
		double fitting=Math.Round((450+3*25)*.45,MidpointRounding.AwayFromZero);
		Check(copied.success&&copy.id!=room.id&&HotelModel.Interior(m.Hotel(),copy)&&Math.Abs(copy.paid-fitting)<.01&&Math.Abs(coins-m.State.coins-fitting)<.01,"edits: a copy onto hotel floor is an interior room at the fitting price ("+copied.message+", "+(coins-m.State.coins)+")");
		coins=m.State.coins;Check(m.Execute("resize_room",new JObject{{"id",copy.id},{"w",4},{"h",3}}).success&&Math.Abs(copy.paid-203)<.01&&Math.Abs(m.State.coins-coins-33)<.01,"edits: shrinking an interior room refunds only the fitting difference");
		Check(!m.Quote("draw_room",Room(x,z,20000,20000,0)).success,"edits: absurd drawings are refused up front");
		Check(HotelModel.Valid(m.State),"edits: the hotel stays valid");
		var pav=new HotelModel(new MemoryStore(),content);pav.LoadOrCreate();pav.State.coins=100000;var plot=pav.Hotel();plot.rooms.Clear();plot.floors.Clear();plot.objects.Clear();plot.paths.Clear();
		Check(FindClear(pav,4,8,out int px,out int pz),"edits: land for a pavilion");
		Check(pav.Execute("place_room",Room(px,pz,4,3,0)).success,"edits: pavilion");var hut=pav.Hotel().rooms.Last();
		Check(pav.Execute("paint_floor",Paint(px,pz+4,4,3)).success,"edits: floor to move it onto");
		coins=pav.State.coins;Check(pav.Execute("move_room",new JObject{{"id",hut.id},{"x",px},{"y",pz+4}}).success&&HotelModel.Interior(pav.Hotel(),hut)&&Math.Abs(hut.paid-203)<.01&&Math.Abs(pav.State.coins-coins-247)<.01,"edits: moving a pavilion into the hotel refunds down to the fitting");
		Console.WriteLine("Shell interior edits suite passed");
	}
	static JObject EdgePayload(string kind,params string[] edges){return new JObject{{"floor",0},{"kind",kind},{"edges",new JArray(edges)}};}
	public static void RunLobby(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m);
		Check(FindClear(m,5,5,out int x,out int z),"lobby: clear land");
		var indoorOnly=Catalog.All.FirstOrDefault(i=>i.surfaces.Length==1&&i.surfaces[0]=="indoor"&&i.width<=2&&i.depth<=2&&i.bond==0);
		var outdoorOnly=Catalog.All.FirstOrDefault(i=>i.surfaces.Length==1&&i.surfaces[0]=="outdoor"&&i.width<=2&&i.depth<=2&&i.bond==0);
		Check(indoorOnly!=null,"lobby: catalogue has an indoor-only item");
		var outside=m.PreviewObject(indoorOnly.id,x,z);Check(!outside.success&&outside.message.Contains("indoor"),"lobby: indoor item refused on bare land ("+outside.message+")");
		Check(m.Execute("paint_floor",Paint(x,z,4,4)).success,"lobby: paint lobby");
		var inLobby=m.PlaceObject(indoorOnly.id,x,z);Check(inLobby.success,"lobby: indoor item placed in the lobby ("+inLobby.message+")");
		var placed=m.Hotel().objects.Last();Check(placed.room=="","lobby: lobby furniture belongs to no room");
		if(outdoorOnly!=null){var o=m.PreviewObject(outdoorOnly.id,x+2,z+2);Check(!o.success&&o.message.Contains("outside"),"lobby: outdoor-only item refused indoors ("+o.message+")");}
		var straddle=m.PreviewObject(indoorOnly.id,x+3.5f,z+1);Check(!straddle.success,"lobby: furniture can't straddle the outer wall ("+straddle.message+")");
		HotelModel.Size(placed,out float pw,out float pd);
		if(pw>1){var across=m.Quote("set_edge",EdgePayload("wall","v:"+(x+1)+","+z));Check(!across.success&&across.message.Contains("across a wall"),"lobby: walls can't split furniture ("+across.message+")");}
		Console.WriteLine("Shell lobby suite passed");
	}
	public static void RunEdges(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m);
		Check(FindClear(m,8,4,out int x,out int z),"edges: clear land");Check(m.Execute("paint_floor",Paint(x,z,3,3)).success,"edges: lobby");
		string west="v:"+x+","+(z+1),inner="v:"+(x+1)+","+z;
		double coins=m.State.coins;Check(m.Execute("set_edge",EdgePayload("window",west)).success&&Math.Abs(coins-m.State.coins-15)<.01,"edges: exterior window costs 15");
		Check(ShellGrid.WallAt(HotelModel.Floor(m.Hotel(),0),west)=="window","edges: window stored");
		coins=m.State.coins;Check(m.Execute("set_edge",EdgePayload("door",west)).success&&Math.Abs(coins-m.State.coins-5)<.01,"edges: swapping window for door charges the difference");
		coins=m.State.coins;Check(m.Execute("set_edge",EdgePayload("wall",inner)).success&&Math.Abs(coins-m.State.coins-5)<.01,"edges: interior wall costs 5");
		var arch=m.Quote("set_edge",EdgePayload("open",inner));Check(!arch.success&&arch.message.Contains("Archways"),"edges: no archways inside");
		coins=m.State.coins;Check(m.Execute("set_edge",EdgePayload("none",west)).success&&Math.Abs(m.State.coins-coins-20)<.01,"edges: removing refunds");
		Check(ShellGrid.WallAt(HotelModel.Floor(m.Hotel(),0),west)=="wall","edges: removed exterior door falls back to a wall");
		Check(!m.Quote("set_edge",EdgePayload("wall","v:"+(x+50)+","+z)).success,"edges: edges must touch the hotel");
		Check(m.Execute("draw_room",Room(x+3,z,4,3,0)).success,"edges: room beside the lobby");var room=m.Hotel().rooms.Last();
		string roomInside="v:"+(x+4)+","+z,roomWall="v:"+(x+3)+","+(z+1);
		Check(HotelModel.Floor(m.Hotel(),0).edges.TryGetValue(roomWall,out var owned)&&owned.room==room.id,"edges: the wall facing the lobby belongs to the room");
		var cut=m.Quote("set_edge",EdgePayload("wall",roomInside));Check(!cut.success&&cut.message.Contains("cut through"),"edges: no walls through rooms");
		var keep=m.Quote("set_edge",EdgePayload("none",roomWall));Check(!keep.success&&keep.message.Contains("encloses"),"edges: room walls can't be removed ("+keep.message+")");
		Check(!m.Quote("set_edge",EdgePayload("none","h:"+x+","+z)).success,"edges: nothing to remove on a plain outside wall");
		Check(m.Execute("set_edge",EdgePayload("window",roomWall)).success,"edges: a room wall can become a window");
		Check(m.Execute("remove_room",P("{\"id\":\""+room.id+"\"}")).success&&ShellGrid.WallAt(HotelModel.Floor(m.Hotel(),0),roomWall)=="window","edges: player windows outlive the room");
		Console.WriteLine("Shell edges suite passed");
	}
	public static JObject PaintOn(int level,int x,int z,int w,int d){var p=Paint(x,z,w,d);p["floor"]=level;return p;}
	public static JObject RoomOn(int level,int x,int z,int w,int d,int rotation,string kind="regular"){var p=Room(x,z,w,d,rotation,kind);p["floor"]=level;return p;}
	public static JObject Furnish(string item,int level,float x,float z,int rotation=0){return new JObject{{"item",item},{"x",x},{"y",z},{"rotation",rotation},{"floor",level}};}
	public static void RunFloors(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;var lot=m.Hotel();lot.rooms.Clear();lot.floors.Clear();lot.objects.Clear();lot.paths.Clear();
		Check(FindClear(m,10,8,out int x,out int z),"floors: clear land");
		Check(m.Execute("paint_floor",Paint(x,z,8,7)).success,"floors: ground floor island");
		Check(m.Execute("set_edge",EdgePayload("door","v:"+x+","+(z+3))).success,"floors: front door");
		var stairs=RoomOn(0,x+1,z+1,2,3,0,"stairs");
		var early=m.Quote("draw_room",stairs);Check(!early.success&&early.message.Contains("level 3"),"floors: upstairs opens at hotel level 3 ("+early.message+")");
		m.Hotel().level=3;
		Check(m.FloorLock(1)==null&&m.FloorLock(2).Contains("level 5"),"floors: FloorLock explains locked floors for the UI");
		Check(!m.Quote("paint_floor",PaintOn(1,x+4,z,1,1)).success,"floors: no painting upstairs before a stairwell");
		double coins=m.State.coins;var built=m.Execute("draw_room",stairs);Check(built.success,"floors: stairs built ("+built.message+")");
		Check(HotelModel.Floor(m.Hotel(),1)?.cells.Count==6,"floors: stairs open a 2x3 landing upstairs");
		Check(Math.Abs(coins-m.State.coins-188)<.01,"floors: stairs cost 68 fitting + 120 landing ("+(coins-m.State.coins)+")");
		var off=m.Quote("paint_floor",PaintOn(1,x+9,z,1,1));Check(!off.success&&off.message.Contains("underneath"),"floors: upstairs needs floor underneath ("+off.message+")");
		Check(m.Execute("paint_floor",PaintOn(1,x+3,z,5,4)).success,"floors: grow upstairs over the ground floor");
		var above=m.Quote("erase_floor",Paint(x+4,z+1,1,1));Check(!above.success&&above.message.Contains("above"),"floors: can't erase ground under upstairs ("+above.message+")");
		var landing=m.Quote("erase_floor",PaintOn(1,x+1,z+1,1,1));Check(!landing.success&&landing.message.Contains("stairs"),"floors: can't erase the landing ("+landing.message+")");
		var draft=m.RoomDraft(x+4,z,x+7,z+2,"regular",1);Check((int)draft["door"]==1,"floors: upstairs bedroom opens onto the landing hall");
		Check(m.Execute("draw_room",draft).success,"floors: bedroom upstairs");var room=m.Hotel().rooms.Last();
		Check(room.floor==1&&HotelModel.Interior(m.Hotel(),room),"floors: upstairs bedroom is interior");
		var garden=m.Quote("draw_room",RoomOn(1,x+3,z+3,3,3,0,"garden"));Check(!garden.success&&garden.message.Contains("Upstairs holds"),"floors: gardens belong on the roof ("+garden.message+")");
		var roof=m.Quote("draw_room",RoomOn(1,x+3,z,2,3,0,"stairs"));Check(!roof.success&&roof.message.Contains("level 5"),"floors: the rooftop opens at hotel level 5 ("+roof.message+")");
		Check(!m.Quote("draw_room",RoomOn(0,x+4,z+4,3,3,0,"spa")).success,"floors: no spas on the ground floor");
		m.Hotel().level=7;
		var down=m.Execute("draw_room",RoomOn(-1,x+5,z+4,2,3,0,"stairs"));Check(down.success,"floors: basement stairs open the basement ("+down.message+")");
		Check(HotelModel.Floor(m.Hotel(),-1)?.cells.Count==6,"floors: the basement starts under its stairs");
		var outside=m.Quote("paint_floor",PaintOn(-1,x+9,z,1,1));Check(!outside.success&&outside.message.Contains("under the hotel"),"floors: the basement stays under the hotel");
		var stair=m.Hotel().rooms.First(r=>r.kind=="stairs"&&r.floor==0);int stairCells=HotelModel.Floor(m.Hotel(),1).cells.Count;coins=m.State.coins;
		Check(!m.Quote("remove_room",new JObject{{"id",stair.id}}).success,"floors: occupied upstairs room keeps its last stairwell");
		foreach(var action in new[]{"move_room","resize_room","copy_room"}){
			var edit=action=="resize_room"?new JObject{{"id",stair.id},{"w",3},{"h",3}}:new JObject{{"id",stair.id},{"x",x+2},{"y",z+1}};
			var result=m.Quote(action,edit);Check(!result.success&&result.message.Contains("stairs"),"floors: "+action+" refuses unsupported stair edits ("+result.message+")");
		}
		Check(HotelModel.Floor(m.Hotel(),1).cells.Count==stairCells&&Math.Abs(coins-m.State.coins)<.01,"floors: refused stair edits preserve landing and coins");
		Check(HotelModel.Valid(m.State),"floors: the saved multilevel hotel is valid");
		var reopened=new HotelModel(new MemoryStore{state=HotelModel.Copy(m.State)},content);Check(reopened.LoadOrCreate().success&&HotelModel.Floor(reopened.Hotel(),1)?.cells.Count==stairCells&&HotelModel.Floor(reopened.Hotel(),-1)?.cells.Count==6,"floors: stairs and landings survive a save reload");
		Console.WriteLine("Shell floors suite passed");
	}
	public static void RunStairSafety(Action<bool,string> Check,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;var h=m.Hotel();h.rooms.Clear();h.floors.Clear();h.objects.Clear();h.paths.Clear();h.level=7;
		Check(FindClear(m,10,8,out int x,out int z),"stairs: clear land");
		Check(m.Execute("paint_floor",Paint(x,z,8,6)).success,"stairs: ground shell");
		Check(m.Execute("draw_room",RoomOn(0,x+1,z+1,2,3,0,"stairs")).success,"stairs: first upper stair");
		var first=h.rooms.Last();string internalEdge="v:"+(x+2)+","+(z+2);
		foreach(int level in new[]{0,1})foreach(string kind in new[]{"wall","window"}){
			var blocked=m.Quote("set_edge",new JObject{{"floor",level},{"kind",kind},{"edges",new JArray(internalEdge)}});
			Check(!blocked.success,"stairs: "+kind+" cannot block stair interior on floor "+level);
		}
		Check(m.Execute("set_edge",new JObject{{"floor",1},{"kind","door"},{"edges",new JArray(internalEdge)}}).success,"stairs: passable landing edge allowed");
		Check(m.Execute("set_edge",new JObject{{"floor",0},{"kind","door"},{"edges",new JArray(internalEdge)}}).success,"stairs: passable lower stair edge allowed");
		var blockedSave=HotelModel.Copy(m.State);HotelModel.Floor(blockedSave.hotels[0],1).edges[internalEdge]=new EdgeState{kind="wall"};Check(!HotelModel.Valid(blockedSave),"stairs: blocked saved landing rejected");
		blockedSave=HotelModel.Copy(m.State);HotelModel.Floor(blockedSave.hotels[0],0).edges[internalEdge]=new EdgeState{kind="window"};Check(!HotelModel.Valid(blockedSave),"stairs: blocked saved lower flight rejected");
		var orphan=HotelModel.Copy(m.State);orphan.hotels[0].rooms.RemoveAll(r=>r.id==first.id);Check(!HotelModel.Valid(orphan),"stairs: orphan upper floor rejected on reload");
		Check(m.Execute("paint_floor",PaintOn(1,x+3,z+1,1,1)).success,"stairs: expanded upper floor");
		Check(!m.Quote("remove_room",new JObject{{"id",first.id}}).success,"stairs: last stair cannot strand paid upper floor");
		Check(!m.Quote("draw_room",RoomOn(0,x+5,z+1,2,3,0,"stairs")).success,"stairs: disconnected upper landing cannot be opened");
		Check(m.Execute("paint_floor",PaintOn(1,x+4,z+1,1,1)).success,"stairs: bridge between landing sites");
		Check(m.Execute("draw_room",RoomOn(0,x+5,z+1,2,3,0,"stairs")).success,"stairs: connected alternative upper stair");
		string bridgeEdge="v:"+(x+5)+","+(z+1);
		Check(!m.Quote("set_edge",new JObject{{"floor",1},{"kind","wall"},{"edges",new JArray(bridgeEdge)}}).success,"stairs: divider cannot split the continuous upper floor");
		HotelModel.Floor(m.Hotel(),1).edges[bridgeEdge]=new EdgeState{kind="wall"};
		Check(!m.Quote("remove_room",new JObject{{"id",first.id}}).success,"stairs: wall-isolated landing cannot lose its only stair");
		HotelModel.Floor(m.Hotel(),1).edges.Remove(bridgeEdge);
		Check(m.Execute("set_edge",new JObject{{"floor",1},{"kind","door"},{"edges",new JArray(bridgeEdge)}}).success,"stairs: door joins the landing islands");
		Check(m.Execute("remove_room",new JObject{{"id",first.id}}).success&&HotelModel.Floor(m.Hotel(),1).cells.Count>6,"stairs: connected alternative route allows removal and retains paid floor");
		var isolatedSave=HotelModel.Copy(m.State);HotelModel.Floor(isolatedSave.hotels[0],1).edges[bridgeEdge]=new EdgeState{kind="wall"};Check(!HotelModel.Valid(isolatedSave),"stairs: disconnected retained island rejected on reload");
		var lone=new HotelModel(new MemoryStore(),content);lone.LoadOrCreate();lone.State.coins=100000;lone.Hotel().rooms.Clear();lone.Hotel().floors.Clear();lone.Hotel().objects.Clear();lone.Hotel().paths.Clear();lone.Hotel().level=7;
		Check(FindClear(lone,6,5,out int lx,out int lz),"stairs: clear land for safe removal");
		Check(lone.Execute("paint_floor",Paint(lx,lz,6,5)).success,"stairs: second ground shell");
		Check(lone.Execute("draw_room",RoomOn(0,lx+1,lz+1,2,3,0,"stairs")).success,"stairs: lone upper stair");
		var upper=lone.Hotel().rooms.Last();double before=lone.State.coins;
		Check(lone.Execute("remove_room",new JObject{{"id",upper.id}}).success&&HotelModel.Floor(lone.Hotel(),1)==null&&Math.Abs(lone.State.coins-before-188)<.01,"stairs: empty upper landing removed and refunded");
		Check(lone.Execute("draw_room",RoomOn(-1,lx+3,lz+1,2,3,0,"stairs")).success,"stairs: lone basement stair");
		var lower=lone.Hotel().rooms.Last();before=lone.State.coins;
		orphan=HotelModel.Copy(lone.State);orphan.hotels[0].rooms.RemoveAll(r=>r.id==lower.id);Check(!HotelModel.Valid(orphan),"stairs: orphan basement floor rejected on reload");
		Check(lone.Execute("remove_room",new JObject{{"id",lower.id}}).success&&HotelModel.Floor(lone.Hotel(),-1)==null&&Math.Abs(lone.State.coins-before-188)<.01,"stairs: empty basement floor removed and refunded");
		Check(lone.Execute("draw_room",RoomOn(-1,lx+1,lz+1,2,3,0,"stairs")).success,"stairs: first basement route");
		var firstLower=lone.Hotel().rooms.Last();
		Check(lone.Execute("draw_room",RoomOn(-1,lx+3,lz+1,2,3,0,"stairs")).success,"stairs: second basement route");
		string basementDoor="v:"+(lx+3)+","+(lz+2);
		Check(lone.Execute("set_edge",new JObject{{"floor",-1},{"kind","door"},{"edges",new JArray(basementDoor)}}).success,"stairs: shared basement passage stays open");
		Check(lone.Execute("remove_room",new JObject{{"id",firstLower.id}}).success&&HotelModel.Floor(lone.Hotel(),-1).cells.Count==12,"stairs: connected basement alternative retains paid floor");
		Check(HotelModel.Valid(m.State)&&HotelModel.Valid(lone.State),"stairs: edited hotels remain loadable");
		Console.WriteLine("Shell stair safety suite passed");
	}
}
