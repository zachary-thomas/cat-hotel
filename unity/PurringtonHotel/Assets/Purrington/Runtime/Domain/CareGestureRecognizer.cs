namespace Purrington.Domain
{
 /// <summary>Pure care-gesture gates. Presentation feeds motion; HotelModel.Care still owns friendship.</summary>
 public sealed class CareGestureRecognizer
 {
  public const float StrokePixels = 36f;
  public const float HoldSeconds = 0.45f;
  public const float BrushPixels = 28f;
  public const float WandDragPixels = 40f;
  public const float YarnFlickSpeed = 900f;
  public const float YarnDragPixels = 48f;
  public const float PulseSeconds = 1f;

  public string Tool { get; private set; } = "pet";
  public float PathPixels { get; private set; }
  public float HoldTime { get; private set; }
  public float PulseClock { get; private set; }
  public bool Contact { get; private set; }
  public bool Recognized { get; private set; }
  public bool ConsumedInitial { get; private set; }

  public void SetTool(string tool)
  {
   Tool = string.IsNullOrEmpty(tool) ? "pet" : tool;
   ClearMotion();
  }

  public void Begin() { ClearMotion(); }

  public void ClearMotion()
  {
   PathPixels = HoldTime = PulseClock = 0f;
   Contact = Recognized = ConsumedInitial = false;
  }

  public void Move(float deltaPixels)
  {
   if (deltaPixels > 0f) PathPixels += deltaPixels;
   EvaluateMotion();
  }

  public void SetContact(bool onCat)
  {
   Contact = onCat;
   if (!onCat) HoldTime = 0f;
   else EvaluateMotion();
  }

  public void Tick(float dt)
  {
   if (dt <= 0f) return;
   if (Contact && (Tool == "pet" || Tool == "brush"))
   {
    HoldTime += dt;
    if (Tool == "pet" && HoldTime >= HoldSeconds) Recognized = true;
   }
   if (Recognized && ActiveForPulse()) PulseClock += dt;
  }

  public bool TryInitialReward()
  {
   if (!Recognized || ConsumedInitial) return false;
   ConsumedInitial = true;
   PulseClock = 0f;
   return true;
  }

  public bool TryPulseReward()
  {
   if (!Recognized || !ActiveForPulse() || PulseClock < PulseSeconds) return false;
   PulseClock = 0f;
   return true;
  }

  public bool CompleteYarnOrWand(float releaseSpeed)
  {
   if (Tool == "yarn")
   {
    if (releaseSpeed >= YarnFlickSpeed || PathPixels >= YarnDragPixels) Recognized = true;
    return TryInitialReward();
   }
   if (Tool == "wand")
   {
    if (PathPixels >= WandDragPixels) Recognized = true;
    return TryInitialReward();
   }
   return false;
  }

  public bool TapPlacement()
  {
   if (Tool != "cushion" && Tool != "box") return false;
   Recognized = true;
   return TryInitialReward();
  }

  public bool AccessibilityUse()
  {
   Recognized = true;
   ConsumedInitial = true;
   PulseClock = 0f;
   if (Tool == "pet" || Tool == "brush") Contact = true;
   return true;
  }

  public bool ChaseActive(bool held, float playRemaining)
  {
   return (Tool == "wand" || Tool == "yarn") && (held || playRemaining > 0f) && Recognized;
  }

  bool ActiveForPulse()
  {
   if (Tool == "pet" || Tool == "brush") return Contact;
   if (Tool == "wand" || Tool == "yarn") return Recognized;
   return false;
  }

  void EvaluateMotion()
  {
   switch (Tool)
   {
    case "pet":
     if (Contact && PathPixels >= StrokePixels) Recognized = true;
     break;
    case "brush":
     if (Contact && PathPixels >= BrushPixels) Recognized = true;
     break;
    case "wand":
     if (PathPixels >= WandDragPixels) Recognized = true;
     break;
    case "yarn":
     if (PathPixels >= YarnDragPixels) Recognized = true;
     break;
   }
  }
 }
}