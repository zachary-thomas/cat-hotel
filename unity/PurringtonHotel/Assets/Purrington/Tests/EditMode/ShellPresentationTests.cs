using NUnit.Framework;using Purrington.Domain;using Purrington.Presentation;using UnityEngine;
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
}
}
