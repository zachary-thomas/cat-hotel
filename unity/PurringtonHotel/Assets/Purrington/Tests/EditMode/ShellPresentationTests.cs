using Newtonsoft.Json.Linq;using NUnit.Framework;using Purrington.Domain;using Purrington.Presentation;using UnityEngine;
namespace Purrington.Tests {
public sealed class ShellPresentationTests {
 [Test]public void WallRunsMapOntoRoomWallSides(){
  VoxelWorld.ShellWallPlacement(new WallRun{axis='v',x=2,z=3,length=4,inward=1,kind="wall"},1.1f,out var o,out float w,out float d,out int side);
  Assert.AreEqual(2,side);Assert.AreEqual(0f,w);Assert.AreEqual(4.4f,d,1e-4f);Assert.AreEqual(2.2f,o.x,1e-4f);Assert.AreEqual(3.3f,o.z,1e-4f);
  VoxelWorld.ShellWallPlacement(new WallRun{axis='v',x=2,z=3,length=1,inward=-1,kind="wall"},1.1f,out o,out w,out d,out side);Assert.AreEqual(0,side);
  VoxelWorld.ShellWallPlacement(new WallRun{axis='h',x=2,z=3,length=2,inward=1,kind="wall"},1.1f,out o,out w,out d,out side);Assert.AreEqual(3,side);Assert.AreEqual(2.2f,w,1e-4f);Assert.AreEqual(0f,d);
  VoxelWorld.ShellWallPlacement(new WallRun{axis='h',x=2,z=3,length=2,inward=-1,kind="wall"},1.1f,out o,out w,out d,out side);Assert.AreEqual(1,side);}
 [Test]public void CutawayKeepsBackAndInteriorWallsTall(){
  Assert.AreEqual(2.1f,VoxelWorld.CutawayHeight(2,1),1e-4f);Assert.AreEqual(2.1f,VoxelWorld.CutawayHeight(3,1),1e-4f);
  Assert.AreEqual(.25f,VoxelWorld.CutawayHeight(0,-1),1e-4f);Assert.AreEqual(.25f,VoxelWorld.CutawayHeight(1,-1),1e-4f);
  Assert.AreEqual(2.1f,VoxelWorld.CutawayHeight(2,0),1e-4f);}
 [Test]public void DraggedRoomReleaseDoesNotOverwriteDraft(){
  var payload=new JObject{{"x",2},{"y",3},{"w",4},{"h",3}};
  bool releaseClick=VoxelWorld.ShouldSendReleaseClick(true,false);
  if(releaseClick)payload=new JObject{{"x",5},{"y",6},{"w",1},{"h",1}};
  Assert.IsFalse(releaseClick);Assert.AreEqual(4,(int)payload["w"]);Assert.AreEqual(3,(int)payload["h"]);
  Assert.IsTrue(VoxelWorld.ShouldSendReleaseClick(false,false));}
 [Test]public void FloorsStackAndHideAboveTheViewedFloor(){
  Assert.AreEqual(0f,VoxelWorld.FloorY(0),1e-4f);Assert.AreEqual(VoxelWorld.FloorHeight,VoxelWorld.FloorY(1),1e-4f);Assert.AreEqual(-VoxelWorld.FloorHeight,VoxelWorld.FloorY(-1),1e-4f);
  Assert.IsTrue(VoxelWorld.FloorVisible(1,1));Assert.IsTrue(VoxelWorld.FloorVisible(0,1));Assert.IsFalse(VoxelWorld.FloorVisible(2,1));
  Assert.IsFalse(VoxelWorld.FloorVisible(0,-1),"viewing the basement hides everything above it");Assert.IsTrue(VoxelWorld.FloorVisible(-1,0),"the basement stays built under the ground floor");}
 [Test]public void StairsRiseAwayFromEveryDoorSide(){
  float w=2*VoxelWorld.Unit,d=3*VoxelWorld.Unit;
  for(int side=0;side<4;side++){
   var low=VoxelWorld.StairStepCenter(side,w,d,0);var high=VoxelWorld.StairStepCenter(side,w,d,5);
   Assert.AreEqual(VoxelWorld.FloorHeight/12,low.y,1e-4f);
   Assert.AreEqual(VoxelWorld.FloorHeight,high.y*2,1e-4f,"top step meets the upper landing");
   if(side==0)Assert.Greater(low.x,high.x);if(side==2)Assert.Less(low.x,high.x);
   if(side==1)Assert.Greater(low.z,high.z);if(side==3)Assert.Less(low.z,high.z);
  }
 }
}
}
