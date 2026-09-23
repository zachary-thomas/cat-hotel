namespace Purrington.Domain
{
 /// <summary>One deliberate gesture per pointer sequence, measured in canvas reference units.</summary>
 public sealed class CareGestureRecognizer
 {
  public const float StrokePixels=36f, HoldSeconds=.45f, BrushPixels=28f, WandDragPixels=40f, YarnFlickSpeed=900f, YarnDragPixels=48f, PulseSeconds=1f;
  public string Tool {get;private set;}="pet";
  public float PathPixels {get;private set;}
  public float HoldTime {get;private set;}
  public float PulseClock=>0f;
  public bool Contact {get;private set;}
  public bool Recognized {get;private set;}
  public bool ConsumedInitial {get;private set;}
  public void SetTool(string tool){Tool=string.IsNullOrEmpty(tool)?"pet":tool;ClearMotion();}
  public void Begin()=>ClearMotion();
  public void ClearMotion(){PathPixels=HoldTime=0;Contact=Recognized=ConsumedInitial=false;}
  public void Move(float distance)
  {
   if(float.IsNaN(distance)||float.IsInfinity(distance)||distance<1f)return;
   if((Tool=="pet"||Tool=="brush")&&!Contact)return;
   PathPixels+=distance;
   if(Tool=="pet"&&Contact&&PathPixels>=StrokePixels || Tool=="brush"&&Contact&&PathPixels>=BrushPixels || Tool=="wand"&&PathPixels>=WandDragPixels)Recognized=true;
  }
  public void SetContact(bool onCat)
  {
   Contact=onCat;
   if(!onCat){HoldTime=0;if((Tool=="pet"||Tool=="brush")&&!ConsumedInitial){PathPixels=0;Recognized=false;}}
  }
  public void Tick(float dt){if(dt>0&&Contact&&Tool=="pet"){HoldTime+=dt;if(HoldTime>=HoldSeconds)Recognized=true;}}
  public bool TryInitialReward(){if(!Recognized||ConsumedInitial)return false;ConsumedInitial=true;return true;}
  // Kept for callers compiled against the earlier API; holding never awards repeated pulses.
  public bool TryPulseReward()=>false;
  public bool CompleteYarnOrWand(float releaseSpeed)
  {
   if(Tool=="yarn")Recognized=PathPixels>=YarnDragPixels&&releaseSpeed>=YarnFlickSpeed;
   else if(Tool=="wand")Recognized=PathPixels>=WandDragPixels;
   else return false;
   return TryInitialReward();
  }
  // Placement and assisted actions are intents. Only the cat's completed response can reward them.
  public bool TapPlacement()=>false;
  public bool AccessibilityUse()=>false;
  public bool ChaseActive(bool held,float playRemaining)=>(Tool=="wand"||Tool=="yarn")&&(held||playRemaining>0)&&Recognized;
 }
}
