using System.Collections.Generic;
using UnityEngine;

namespace Purrington.Presentation {
 // Voxel particle effects in world space: hearts while a cat is petted, coin sparkles as guests earn, blossom petals by day
 // and fireflies at night. Every particle is a small cube or voxel mesh so effects match the world's look.
 // With reduced motion on, nothing is emitted and the ambient emitters stay quiet.
 public sealed class VoxelFx {
  public readonly Transform Root;
  readonly ParticleSystem hearts,coins,petalsPink,petalsWhite,fireflies;
  float heartClock;
  public VoxelFx(GodotGeometry geometry,Transform parent){
   Root=new GameObject("Voxel effects").transform;Root.SetParent(parent,false);
   var cube=Cube();
   hearts=Make("Hearts",HeartMesh(cube),geometry.Material("F2A7B5"),false,m=>{m.startLifetime=1.3f;m.startSpeed=new ParticleSystem.MinMaxCurve(.5f,.9f);m.startSize=new ParticleSystem.MinMaxCurve(.22f,.32f);m.gravityModifier=-.12f;},true);
   coins=Make("Coin sparkle",cube,geometry.GlowTwin(geometry.Material("F7CC62")),false,m=>{m.startLifetime=.9f;m.startSpeed=new ParticleSystem.MinMaxCurve(1.4f,2.4f);m.startSize=new ParticleSystem.MinMaxCurve(.07f,.12f);m.gravityModifier=.9f;m.startRotation3D=true;},false);
   petalsPink=Make("Blossom petals",cube,geometry.Material("F2A7B5"),true,m=>{m.startLifetime=9;m.startSpeed=.05f;m.startSize=new ParticleSystem.MinMaxCurve(.07f,.1f);m.gravityModifier=.012f;m.startRotation3D=true;},false);
   petalsWhite=Make("White petals",cube,geometry.Material("F4F1E8"),true,m=>{m.startLifetime=9;m.startSpeed=.05f;m.startSize=new ParticleSystem.MinMaxCurve(.06f,.09f);m.gravityModifier=.012f;m.startRotation3D=true;},false);
   fireflies=Make("Fireflies",cube,geometry.GlowTwin(geometry.Material(Purrington.Domain.SurfacePalette.LanternGlow)),true,m=>{m.startLifetime=new ParticleSystem.MinMaxCurve(3,5);m.startSpeed=.08f;m.startSize=new ParticleSystem.MinMaxCurve(.05f,.08f);},false);
   foreach(var petals in new[]{petalsPink,petalsWhite}){var shape=petals.shape;shape.shapeType=ParticleSystemShapeType.Box;shape.scale=new Vector3(26,.5f,26);var drift=petals.velocityOverLifetime;drift.enabled=true;drift.space=ParticleSystemSimulationSpace.World;drift.x=new ParticleSystem.MinMaxCurve(.15f,.35f);drift.y=new ParticleSystem.MinMaxCurve(-.22f,-.14f);drift.z=new ParticleSystem.MinMaxCurve(-.1f,.1f);var spin=petals.rotationOverLifetime;spin.enabled=true;spin.separateAxes=true;spin.x=spin.y=spin.z=new ParticleSystem.MinMaxCurve(-2,2);}
   {var shape=fireflies.shape;shape.shapeType=ParticleSystemShapeType.Box;shape.scale=new Vector3(22,1.6f,22);var noise=fireflies.noise;noise.enabled=true;noise.strength=.35f;noise.frequency=.4f;noise.scrollSpeed=.2f;var fade=fireflies.sizeOverLifetime;fade.enabled=true;fade.size=new ParticleSystem.MinMaxCurve(1,new AnimationCurve(new Keyframe(0,0),new Keyframe(.2f,1),new Keyframe(.8f,1),new Keyframe(1,0)));}
   {var shape=coins.shape;shape.shapeType=ParticleSystemShapeType.Cone;shape.angle=28;shape.radius=.08f;shape.rotation=new Vector3(-90,0,0);var spin=coins.rotationOverLifetime;spin.enabled=true;spin.separateAxes=true;spin.y=new ParticleSystem.MinMaxCurve(-6,6);}
   {var shape=hearts.shape;shape.shapeType=ParticleSystemShapeType.Cone;shape.angle=18;shape.radius=.15f;shape.rotation=new Vector3(-90,0,0);var grow=hearts.sizeOverLifetime;grow.enabled=true;grow.size=new ParticleSystem.MinMaxCurve(1,new AnimationCurve(new Keyframe(0,.2f),new Keyframe(.2f,1.1f),new Keyframe(.35f,1),new Keyframe(1,0)));}
  }
  ParticleSystem Make(string name,Mesh mesh,Material material,bool looping,System.Action<ParticleSystem.MainModule> setup,bool faceView){
   var go=new GameObject(name);go.transform.SetParent(Root,false);var ps=go.AddComponent<ParticleSystem>();ps.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
   var main=ps.main;main.playOnAwake=false;main.loop=looping;main.simulationSpace=ParticleSystemSimulationSpace.World;main.maxParticles=looping?160:60;main.scalingMode=ParticleSystemScalingMode.Hierarchy;setup(main);
   var emission=ps.emission;emission.rateOverTime=0;
   var renderer=go.GetComponent<ParticleSystemRenderer>();renderer.renderMode=ParticleSystemRenderMode.Mesh;renderer.mesh=mesh;renderer.sharedMaterial=material;renderer.alignment=faceView?ParticleSystemRenderSpace.View:ParticleSystemRenderSpace.World;renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
   if(looping)ps.Play();
   return ps;
  }
  public Transform Attach(Transform parent){Root.SetParent(parent,false);return Root;}
  public bool Motion=true;
  public int Live=>hearts.particleCount+coins.particleCount+petalsPink.particleCount+petalsWhite.particleCount+fireflies.particleCount;
  // While a cat is being petted, a heart floats up every half second from above its head.
  public void Affection(Vector3 head,float dt){if(!Motion)return;heartClock-=dt;if(heartClock>0)return;heartClock=.55f;hearts.transform.position=head;hearts.Emit(1);}
  public void Hearts(Vector3 at,int count=4){if(!Motion)return;hearts.transform.position=at;hearts.Emit(count);}
  public void Coins(Vector3 at,int count=8){if(!Motion)return;coins.transform.position=at;coins.Emit(count);}
  // center is the ground point in the middle of the view; glow is the evening/night lamp level from WorldLighting.
  public void Ambient(Vector3 center,float glow,bool outdoors){
   bool on=Motion&&outdoors;float day=Mathf.Clamp01(1-glow*2.5f),night=Mathf.Clamp01((glow-.45f)*2.5f);
   foreach(var petals in new[]{petalsPink,petalsWhite}){petals.transform.position=center+Vector3.up*6.5f;var e=petals.emission;e.rateOverTime=on?day*(petals==petalsPink?2.4f:1.2f):0;}
   fireflies.transform.position=center+Vector3.up*1.1f;var f=fireflies.emission;f.rateOverTime=on?night*5:0;
  }
  static Mesh Cube(){var g=GameObject.CreatePrimitive(PrimitiveType.Cube);var mesh=g.GetComponent<MeshFilter>().sharedMesh;Object.DestroyImmediate(g);return mesh;}
  // A flat 5x4 voxel heart, one unit wide, facing +z.
  static Mesh heart;
  static Mesh HeartMesh(Mesh cube){
   if(heart)return heart;
   string[] rows={".#.#.","#####",".###.","..#.."};var parts=new List<CombineInstance>();
   for(int r=0;r<rows.Length;r++)for(int c=0;c<5;c++)if(rows[r][c]=='#')parts.Add(new CombineInstance{mesh=cube,transform=Matrix4x4.TRS(new Vector3((c-2)*.2f,(1.5f-r)*.2f,0),Quaternion.identity,new Vector3(.2f,.2f,.12f))});
   heart=new Mesh{name="Voxel heart"};heart.CombineMeshes(parts.ToArray(),true,true);heart.RecalculateBounds();return heart;
  }
 }
}
