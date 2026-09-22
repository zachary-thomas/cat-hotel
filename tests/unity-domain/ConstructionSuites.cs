using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Purrington.Domain;

static class ConstructionSuites
{
	public static void RunBuilding(Action<bool,string> Check, Func<string,JObject> P, ParityContent content)
	{
		var store=new MemoryStore();
		var m=new HotelModel(store,content);
		Check(m.LoadOrCreate().success,"building: starter loads");
		m.State.coins=100000;
		string original=JsonConvert.SerializeObject(m.State);
		var room=m.Hotel().rooms[0];
		Check(m.RoomStatus(room.id).ready,"building: starter bedroom ready");
		var bed=m.Hotel().objects.First(o=>o.room==room.id && Catalog.Find(o.itemId)?.role=="bed");
		Check(m.Execute("store_object",P("{\"id\":\""+bed.id+"\"}")).success,"building: store last bed");
		Check(!m.RoomStatus(room.id).ready,"building: empty bedroom inactive");
		Check(m.Undo().success && m.RoomStatus(room.id).ready,"building: undo restores bed + readiness");
		Check(!m.Quote("resize_room",P("{\"id\":\""+room.id+"\",\"w\":8,\"h\":6}")).success,"building: resize blocked through hall");
		Check(m.Execute("buy_plot",P("{\"id\":\"east\"}")).success,"building: buy east plot");
		int objectCount=m.Hotel().objects.Count;
		Check(m.Execute("copy_room",P("{\"id\":\""+room.id+"\",\"x\":12,\"y\":-10,\"rotation\":0}")).success,"building: copy furnished cottage");
		Check(m.Hotel().objects.Count>objectCount,"building: copy has distinct furniture");
		var copy=m.Hotel().rooms[m.Hotel().rooms.Count-1];
		Check(!m.RoomStatus(copy.id).ready,"building: disconnected cottage unfinished");
		double before=m.State.coins;
		Check(m.Execute("resize_room",P("{\"id\":\""+copy.id+"\",\"w\":8,\"h\":6}")).success,"building: resize on clear land");
		Check(Math.Abs(m.State.coins-(before-300))<0.01,"building: +12 cells costs 300");
		Check(m.Execute("resize_room",P("{\"id\":\""+copy.id+"\",\"w\":6,\"h\":6}")).success,"building: shrink room");
		Check(Math.Abs(m.State.coins-before)<0.01,"building: shrink refunds extra floor");
		var cells=new JArray();
		for(int x=10;x<20;x++) for(int y=-3;y<-1;y++) cells.Add(new JArray(x,y));
		for(int x=18;x<20;x++) for(int y=-8;y<-1;y++) cells.Add(new JArray(x,y));
		Check(m.Execute("paint_path",new JObject{{"cells",cells},{"style","earth"}}).success,"building: paint earth path");
		Check(m.RoomStatus(copy.id).ready,"building: connected cottage opens");
		Check(m.Execute("erase_path",P("{\"cells\":[[18,-5],[19,-5]]}")).success,"building: erase path cells");
		Check(!m.RoomStatus(copy.id).ready,"building: erased path closes cottage");
		Check(m.Undo().success && m.RoomStatus(copy.id).ready,"building: undo path reopens cottage");
		int stored=m.State.storage.Count;
		Check(m.Execute("remove_room",P("{\"id\":\""+copy.id+"\"}")).success,"building: remove cottage");
		Check(m.State.storage.Count>stored,"building: furniture kept in storage");

		store.state=JsonConvert.DeserializeObject<HotelState>(original);
		Check(m.LoadOrCreate().success,"building: restore starter for uncapped rooms");
		m.State.coins=100000;
		m.Hotel().rooms.Clear(); m.Hotel().floors.Clear(); m.Hotel().objects.Clear(); m.Hotel().paths.Clear();
		for(int i=0;i<12;i++){
			int x=-12+(i%4)*6, y=-12+(i/4)*7;
			Check(m.Execute("place_room",P("{\"kind\":\"regular\",\"x\":"+x+",\"y\":"+y+",\"w\":4,\"h\":3,\"rotation\":0}")).success,"building: place room "+(i+1));
		}
		Check(m.Hotel().rooms.Count==12,"building: no eight-room cap");
		var roundTrip=new HotelModel(new MemoryStore{state=HotelModel.Copy(m.State)},content);
		Check(roundTrip.LoadOrCreate().success && roundTrip.Hotel().rooms.Count==12,"building: >8 rooms survive save");

		store.state=JsonConvert.DeserializeObject<HotelState>(original);
		Check(m.LoadOrCreate().success,"building: restore for housekeeper");
		m.Hotel().level=3;
		Check(m.Execute("hire_housekeeper",new JObject()).success,"building: hire Daisy");
		Check(m.Hotel().maid,"building: maid flag saved");
		Check(m.Venues().Count(v=>v.role=="bed" && v.open)>=2,"building: open beds exposed");

		var bad=JsonConvert.DeserializeObject<HotelState>(original);
		bad.hotels[0].rooms[0].paid=-500;
		Check(!HotelModel.Valid(bad),"building: negative paid rejected");

		store.state=JsonConvert.DeserializeObject<HotelState>(original);
		Check(m.LoadOrCreate().success,"building: restore for sealed wall");
		m.Hotel().rooms=new List<RoomState>{new RoomState{id="sealed",kind="regular",name="Sealed",x=-10,z=-10,width=4,depth=3,rotation=0,paid=0}};
		m.Hotel().objects=new List<ObjectState>{new ObjectState{id="wall_bed",itemId="mat",room="sealed",x=-10,z=-9,rotation=0,paid=0}};
		m.Hotel().paths.Clear();
		for(int x=-11;x<11;x++) m.Hotel().paths[x+",10"]=new PathState{style="earth",paid=0};
		for(int y=-10;y<11;y++) m.Hotel().paths["-11,"+y]=new PathState{style="earth",paid=0};
		Check(!m.RoomStatus("sealed").ready,"building: sealed-wall bed not readied by exterior path");
		Console.WriteLine("Building suite passed");
	}

	public static void RunGodMode(Action<bool,string> Check, Func<string,JObject> P, ParityContent content)
	{
		var store=new MemoryStore();
		var m=new HotelModel(store,content);
		Check(m.LoadOrCreate().success,"god: starter loads");
		Check(!m.State.settings.godMode,"god: starts off");
		m.State.coins=0;
		string before=JsonConvert.SerializeObject(m.State);
		store.fail=true;
		Check(!m.SetGodMode(true).success && JsonConvert.SerializeObject(m.State)==before,"god: failed save rolls back");
		store.fail=false;
		Check(m.SetGodMode(true).success && m.State.settings.godMode,"god: enable");
		for(int i=0;i<4;i++){
			Check(m.Hotel(i).owned && m.Hotel(i).plots.Count==3,"god: unlocks hotel+plots "+i);
			var travel=m.CanTravel(i);
			Check(travel.success && travel.cost==0,"god: free travel "+i);
		}
		Check(m.State.cats.All(c=>c.known),"god: all cats known");
		Check(m.Execute("hire_housekeeper",new JObject()).success,"god: housekeeper at level 1");
		Check(m.Execute("upgrade",P("{\"service\":0}")).success,"god: free upgrade");
		Check(m.Execute("train",P("{\"staff\":0}")).success,"god: free train");
		Check(m.CatalogPrice("place_room",JObject.Parse("{\"kind\":\"suite\",\"w\":4,\"h\":5}"))==0,"god: suite catalog free");
		Check(m.CatalogPrice("place_template",JObject.Parse("{\"template\":\"milkshake\"}"))==0,"god: milkshake catalog free");
		var payload=JObject.Parse("{\"kind\":\"suite\",\"name\":\"Debug cottage\",\"x\":12,\"y\":-10,\"w\":4,\"h\":5,\"rotation\":0}");
		Check(m.Quote("place_room",payload).cost==0 && m.Execute("place_room",payload).success,"god: empty-wallet suite");
		string roomId=m.Hotel().rooms[m.Hotel().rooms.Count-1].id;
		Check(m.Hotel().rooms.Last().paid==0,"god: paid==0 on free room");
		Check(m.Execute("place_object",JObject.Parse("{\"item\":\"blanket\",\"x\":12.5,\"y\":-9.5,\"rotation\":0}")).success,"god: bond gate bypass");
		Check(m.Execute("resize_room",P("{\"id\":\""+roomId+"\",\"w\":6,\"h\":5}")).success,"god: free resize");
		Check(m.Execute("paint_path",JObject.Parse("{\"style\":\"brick\",\"cells\":[[18,-7],[18,-6]]}")).success,"god: free brick path");
		Check(m.Hotel().paths.ContainsKey("18,-7") && m.Hotel().paths["18,-7"].paid==0,"god: path paid==0");
		Check(m.State.coins==0,"god: wallet unchanged");
		string stable=JsonConvert.SerializeObject(m.State);
		Check(!m.Execute("place_room",payload).success && JsonConvert.SerializeObject(m.State)==stable,"god: overlap still rejected");
		Check(m.Undo().success && m.Redo().success && m.State.coins==0,"god: undo/redo while free");
		var reopened=new HotelModel(new MemoryStore{state=HotelModel.Copy(m.State)},content);
		Check(reopened.LoadOrCreate().success && reopened.State.settings.godMode,"god: persists on reopen");
		Check(reopened.SetGodMode(false).success && !reopened.State.settings.godMode,"god: disable");
		Check(reopened.Hotel().rooms.Count==m.Hotel().rooms.Count && reopened.Hotel(3).owned,"god: keeps geometry+unlocks");
		Check(!reopened.Undo().success,"god: history cleared on toggle");
		Check(Math.Abs(reopened.CatalogPrice("place_object",JObject.Parse("{\"item\":\"bench\"}"))-90)<0.01,"god: normal prices return");
		Check(!reopened.Execute("place_object",JObject.Parse("{\"item\":\"bench\",\"x\":16,\"y\":7,\"rotation\":0}")).success,"god: funds checks return");
		Check(reopened.Execute("remove_room",P("{\"id\":\""+roomId+"\"}")).success && reopened.State.coins==0,"god: no refund for free room");
		Check(reopened.Execute("erase_path",JObject.Parse("{\"cells\":[[18,-7],[18,-6]]}")).success && reopened.State.coins==0,"god: no refund for free path");
		var legacy=new HotelModel(new MemoryStore(),content); legacy.LoadOrCreate();
		var legacyState=HotelModel.Copy(legacy.State); legacyState.settings.godMode=false;
		var missing=new HotelModel(new MemoryStore{state=legacyState},content);
		Check(missing.LoadOrCreate().success && !missing.State.settings.godMode,"god: default off");
		Console.WriteLine("God mode suite passed");
	}
}
