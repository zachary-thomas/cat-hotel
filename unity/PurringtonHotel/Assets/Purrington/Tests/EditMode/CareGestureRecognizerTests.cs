using NUnit.Framework;
using Purrington.Domain;

namespace Purrington.Tests
{
 public sealed class CareGestureRecognizerTests
 {
  [Test]
  public void PetRequiresStrokeOrHold_NotMereTouch()
  {
   var g = new CareGestureRecognizer();
   g.SetTool("pet");
   g.Begin();
   g.SetContact(true);
   Assert.IsFalse(g.TryInitialReward(), "tap alone must not reward");
   g.Move(CareGestureRecognizer.StrokePixels);
   Assert.IsTrue(g.TryInitialReward(), "stroke distance should reward");
  }

  [Test]
  public void PetHoldAfterThresholdRewards()
  {
   var g = new CareGestureRecognizer();
   g.SetTool("pet");
   g.Begin();
   g.SetContact(true);
   g.Tick(CareGestureRecognizer.HoldSeconds);
   Assert.IsTrue(g.TryInitialReward());
  }

  [Test]
  public void BrushRequiresCoatStroke()
  {
   var g = new CareGestureRecognizer();
   g.SetTool("brush");
   g.Begin();
   g.SetContact(true);
   g.Move(CareGestureRecognizer.BrushPixels - 1f);
   Assert.IsFalse(g.TryInitialReward());
   g.Move(2f);
   Assert.IsTrue(g.TryInitialReward());
  }

  [Test]
  public void WandRequiresDrag_YarnAcceptsFlick()
  {
   var wand = new CareGestureRecognizer();
   wand.SetTool("wand");
   wand.Begin();
   Assert.IsFalse(wand.CompleteYarnOrWand(0f));
   wand.Move(CareGestureRecognizer.WandDragPixels);
   Assert.IsTrue(wand.TryInitialReward());

   var yarn = new CareGestureRecognizer();
   yarn.SetTool("yarn");
   yarn.Begin();
   Assert.IsTrue(yarn.CompleteYarnOrWand(CareGestureRecognizer.YarnFlickSpeed));
  }

  [Test]
  public void CushionAndBoxRewardOnTap()
  {
   var cushion = new CareGestureRecognizer();
   cushion.SetTool("cushion");
   cushion.Begin();
   Assert.IsTrue(cushion.TapPlacement());

   var box = new CareGestureRecognizer();
   box.SetTool("box");
   box.Begin();
   Assert.IsTrue(box.TapPlacement());
  }

  [Test]
  public void PulseOnlyWhileGestureStaysActive()
  {
   var g = new CareGestureRecognizer();
   g.SetTool("pet");
   g.Begin();
   g.SetContact(true);
   g.Move(CareGestureRecognizer.StrokePixels);
   Assert.IsTrue(g.TryInitialReward());
   g.Tick(CareGestureRecognizer.PulseSeconds);
   Assert.IsTrue(g.TryPulseReward());
   g.SetContact(false);
   g.Tick(CareGestureRecognizer.PulseSeconds);
   Assert.IsFalse(g.TryPulseReward());
  }
 }
}