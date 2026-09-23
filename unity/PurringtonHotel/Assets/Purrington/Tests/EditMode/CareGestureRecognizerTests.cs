using NUnit.Framework;
using Purrington.Domain;
namespace Purrington.Tests
{
 public sealed class CareGestureRecognizerTests
 {
  [Test] public void PetNeedsDeliberateStrokeOrHold(){var g=new CareGestureRecognizer();g.SetContact(true);Assert.IsFalse(g.TryInitialReward());g.Move(36);Assert.IsTrue(g.TryInitialReward());Assert.IsFalse(g.TryInitialReward());}
  [Test] public void PetHoldCompletesOnce(){var g=new CareGestureRecognizer();g.SetContact(true);g.Tick(.45f);Assert.IsTrue(g.TryInitialReward());g.Tick(20);Assert.IsFalse(g.TryPulseReward());Assert.IsFalse(g.TryInitialReward());}
  [TestCase("pet")][TestCase("brush")] public void OffCatTravelDoesNotCount(string tool){var g=new CareGestureRecognizer();g.SetTool(tool);g.Move(1000);g.SetContact(true);Assert.AreEqual(0,g.PathPixels);Assert.IsFalse(g.TryInitialReward());}
  [TestCase("pet")][TestCase("brush")] public void BrokenContactResetsIncompleteStroke(string tool){var g=new CareGestureRecognizer();g.SetTool(tool);g.SetContact(true);g.Move(20);g.SetContact(false);g.SetContact(true);g.Move(20);Assert.IsFalse(g.TryInitialReward());}
  [Test] public void BrushNeedsMotionNotHold(){var g=new CareGestureRecognizer();g.SetTool("brush");g.SetContact(true);g.Tick(10);Assert.IsFalse(g.TryInitialReward());g.Move(28);Assert.IsTrue(g.TryInitialReward());}
  [Test] public void TinyJitterDoesNotBuildBrushStroke(){var g=new CareGestureRecognizer();g.SetTool("brush");g.SetContact(true);for(int i=0;i<1000;i++)g.Move(.2f);Assert.IsFalse(g.TryInitialReward());}
  [Test] public void FeatherRequiresDrag(){var g=new CareGestureRecognizer();g.SetTool("wand");Assert.IsFalse(g.CompleteYarnOrWand(0));g.Move(40);Assert.IsTrue(g.TryInitialReward());Assert.IsFalse(g.TryInitialReward());}
  [Test] public void YarnNeedsBothDistanceAndFastRelease(){var g=new CareGestureRecognizer();g.SetTool("yarn");g.Move(100);Assert.IsFalse(g.TryInitialReward());Assert.IsFalse(g.CompleteYarnOrWand(100));g.Begin();Assert.IsFalse(g.CompleteYarnOrWand(1000));g.Move(48);Assert.IsTrue(g.CompleteYarnOrWand(900));Assert.IsFalse(g.CompleteYarnOrWand(900));}
  [TestCase("box")][TestCase("cushion")] public void PlacementAndAssistanceNeverDirectlyReward(string tool){var g=new CareGestureRecognizer();g.SetTool(tool);Assert.IsFalse(g.TapPlacement());Assert.IsFalse(g.AccessibilityUse());Assert.IsFalse(g.TryInitialReward());}
  [Test] public void CancelOrToolChangeDiscardsMotion(){var g=new CareGestureRecognizer();g.SetTool("wand");g.Move(40);g.ClearMotion();Assert.IsFalse(g.TryInitialReward());g.Move(40);g.SetTool("pet");Assert.IsFalse(g.TryInitialReward());}
 }
}
